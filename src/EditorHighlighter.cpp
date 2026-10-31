#include "EditorHighlighter.h"

#include <QQuickTextDocument>
#include <QAbstractTextDocumentLayout>
#include <QMouseEvent>
#include <QRegularExpression>
#include <QSyntaxHighlighter>
#include <QTextBlock>
#include <algorithm>
#include <utility>

// TextField exposes no QTextDocument. Keep the Qt-private adapter here so its
// existing validators, auto-scroll, accessibility and input-method API stay intact.
#include <QtQuick/private/qquicktextinput_p_p.h>
#include <QtQuick/private/qquicktextedit_p_p.h>

namespace {
struct PointerPosition {
    int position = 0;
    bool atSoftLineEnd = false;
};

PointerPosition pointerPosition(QObject *target, const QPointF &point) {
    QTextLayout *layout = nullptr;
    QPointF layoutPoint;
    QString text;
    int blockStart = 0;
    PointerPosition result;
    if (auto *input = qobject_cast<QQuickTextInput *>(target)) {
        auto *control = QQuickTextInputPrivate::get(input);
        result.position = control->positionAt(point.x(), point.y(), QTextLine::CursorBetweenCharacters);
        layout = &control->m_textLayout;
        layoutPoint = point + QPointF(control->hscroll - input->leftPadding(),
                                      control->vscroll - input->topPadding());
        text = input->text();
    } else if (auto *edit = qobject_cast<QQuickTextEdit *>(target)) {
        auto *control = QQuickTextEditPrivate::get(edit);
        result.position = edit->positionAt(point.x(), point.y());
        const auto block = control->document->findBlock(result.position);
        if (!block.isValid())
            return result;
        layout = block.layout();
        blockStart = block.position();
        layoutPoint = point - QPointF(control->xoff, control->yoff) - layout->position();
        text = block.text();
    }
    if (!layout || layout->lineCount() < 2)
        return result;
    int lineIndex = 0;
    while (lineIndex + 1 < layout->lineCount()) {
        const auto line = layout->lineAt(lineIndex);
        if (layoutPoint.y() < (line.rect().bottom() + layout->lineAt(lineIndex + 1).y()) / 2)
            break;
        ++lineIndex;
    }
    if (lineIndex + 1 == layout->lineCount())
        return result;
    const auto line = layout->lineAt(lineIndex);
    const int end = line.textStart() + line.textLength();
    if (end <= 0 || end > text.size() || text.at(end - 1).isSpace())
        return result;
    const int lastCharacter = layout->previousCursorPosition(end);
    const qreal leading = line.cursorToX(lastCharacter);
    const qreal trailing = line.cursorToX(end);
    // Qt's xToCursor() treats the last character of every non-final line as a
    // separator when the pointer is beyond the text. A soft wrap has no such
    // separator: the trailing half of the final grapheme must include it.
    const qreal middle = (leading + trailing) / 2;
    if ((trailing > leading && layoutPoint.x() >= middle)
        || (trailing < leading && layoutPoint.x() <= middle)) {
        result.position = blockStart + end;
        result.atSoftLineEnd = true;
    }
    return result;
}

class DocumentHighlighter final : public QSyntaxHighlighter {
public:
    explicit DocumentHighlighter(QTextDocument *document) : QSyntaxHighlighter(document) {}
    QList<QTextLayout::FormatRange> ranges;
protected:
    void highlightBlock(const QString &text) override {
        const int blockStart = currentBlock().position();
        const int blockEnd = blockStart + text.size();
        for (const auto &range : std::as_const(ranges)) {
            const int start = std::max(blockStart, range.start);
            const int end = std::min(blockEnd, range.start + range.length);
            if (start < end)
                setFormat(start - blockStart, end - start, range.format);
        }
    }
};

QList<QTextLayout::FormatRange> foregroundRanges(const QString &text,
                                                const QVariantList &syntaxRanges,
                                                bool highlightMacros,
                                                const QColor &macroColor) {
    if (syntaxRanges.isEmpty() && !highlightMacros)
        return {};
    // Merge macro colours over syntax colours before sending disjoint ranges
    // to Qt. Positions use UTF-16, just like JS strings and QML cursor positions.
    QList<QColor> colors(text.size());
    for (const auto &entry : syntaxRanges) {
        const auto range = entry.toMap();
        const int start = std::clamp(range.value("start").toInt(), 0, int(text.size()));
        const int length = std::clamp(range.value("length").toInt(), 0, int(text.size()) - start);
        const QColor color = range.value("color").value<QColor>();
        if (color.isValid())
            std::fill(colors.begin() + start, colors.begin() + start + length, color);
    }
    if (highlightMacros) {
        static const QRegularExpression macro(QStringLiteral(R"(\{\{([^{}\r\n]+)\}\})"));
        auto matches = macro.globalMatch(text);
        while (matches.hasNext()) {
            const auto match = matches.next();
            const int start = match.capturedStart();
            if (start && text.at(start - 1) == QLatin1Char('\\'))
                continue;
            std::fill(colors.begin() + start, colors.begin() + match.capturedEnd(), macroColor);
        }
    }
    QList<QTextLayout::FormatRange> result;
    for (int start = 0; start < colors.size();) {
        int end = start + 1;
        while (end < colors.size() && colors[end] == colors[start])
            ++end;
        if (colors[start].isValid()) {
            QTextCharFormat format;
            format.setForeground(colors[start]);
            result.append({start, end - start, format});
        }
        start = end;
    }
    return result;
}
}

EditorHighlighter::EditorHighlighter(QObject *parent) : QObject(parent) {}
EditorHighlighter::~EditorHighlighter() {
    delete m_documentHighlighter;
}

void EditorHighlighter::setTarget(QObject *target) {
    if (m_target == target)
        return;
    if (m_target)
        m_target->removeEventFilter(this);
    for (const auto &connection : std::as_const(m_connections))
        disconnect(connection);
    m_connections.clear();
    delete m_documentHighlighter.data();
    m_documentHighlighter = nullptr;
    m_inputFormats.clear();
    m_target = target;
    m_pointerSelecting = false;
    if (target) {
        target->installEventFilter(this);
        m_connections.append(connect(target, SIGNAL(textChanged()), this, SLOT(scheduleApply())));
        if (auto *input = qobject_cast<QQuickTextInput *>(target)) {
            m_connections.append(connect(input, &QQuickTextInput::preeditTextChanged, this, &EditorHighlighter::scheduleApply));
            m_connections.append(connect(input, &QQuickTextInput::fontChanged, this, &EditorHighlighter::scheduleApply));
            m_connections.append(connect(input, &QQuickTextInput::contentSizeChanged, this, &EditorHighlighter::scheduleApply));
        } else if (auto *document = qvariant_cast<QQuickTextDocument *>(target->property("textDocument"))) {
            m_documentHighlighter = new DocumentHighlighter(document->textDocument());
        }
    }
    emit targetChanged();
    scheduleApply();
}

bool EditorHighlighter::eventFilter(QObject *object, QEvent *event) {
    const auto type = event->type();
    if (object != m_target || (type != QEvent::MouseButtonPress && type != QEvent::MouseMove
                              && type != QEvent::MouseButtonRelease && type != QEvent::MouseButtonDblClick))
        return false;
    auto *mouse = static_cast<QMouseEvent *>(event);
    if (type == QEvent::MouseButtonDblClick) {
        m_pointerSelecting = false;
        return false;
    }
    if (!object->property("selectByMouse").toBool() || object->property("inputMethodComposing").toBool())
        return false;
    const bool press = type == QEvent::MouseButtonPress && mouse->button() == Qt::LeftButton;
    const bool release = type == QEvent::MouseButtonRelease && mouse->button() == Qt::LeftButton;
    if (!press && !(m_pointerSelecting && (release || mouse->buttons().testFlag(Qt::LeftButton))))
        return false;
    const auto hit = pointerPosition(object, mouse->position());
    if (press) {
        m_pointerSelecting = true;
        const int start = object->property("selectionStart").toInt();
        const int end = object->property("selectionEnd").toInt();
        m_pointerAnchor = mouse->modifiers().testFlag(Qt::ShiftModifier)
                ? (object->property("cursorPosition").toInt() == start ? end : start)
                : hit.position;
    }
    if (release)
        m_pointerSelecting = false;
    if (hit.atSoftLineEnd) {
        const QPointer<QObject> target = object;
        const int anchor = m_pointerAnchor;
        // Let Qt handle focus, pointer grabs and ordinary selection first.
        // Correct only the soft-wrap endpoint after that native event finishes.
        QMetaObject::invokeMethod(this, [target, anchor, position = hit.position] {
            if (target)
                QMetaObject::invokeMethod(target, "select", Q_ARG(int, anchor), Q_ARG(int, position));
        }, Qt::QueuedConnection);
    }
    return false;
}

void EditorHighlighter::setRanges(const QVariantList &ranges) {
    if (m_ranges == ranges)
        return;
    m_ranges = ranges;
    emit rangesChanged();
    scheduleApply();
}

void EditorHighlighter::setHighlightMacros(bool enabled) {
    if (m_highlightMacros == enabled)
        return;
    m_highlightMacros = enabled;
    emit highlightMacrosChanged();
    scheduleApply();
}

void EditorHighlighter::setMacroColor(const QColor &color) {
    if (m_macroColor == color)
        return;
    m_macroColor = color;
    emit macroColorChanged();
    scheduleApply();
}

void EditorHighlighter::scheduleApply() {
    if (m_applyPending)
        return;
    m_applyPending = true;
    QMetaObject::invokeMethod(this, [this] {
        m_applyPending = false;
        apply();
    }, Qt::QueuedConnection);
}

void EditorHighlighter::apply() {
    if (!m_target)
        return;
    const auto text = m_target->property("text").toString();
    const auto formats = foregroundRanges(text, m_ranges, m_highlightMacros, m_macroColor);
    if (auto *input = qobject_cast<QQuickTextInput *>(m_target)) {
        auto *control = QQuickTextInputPrivate::get(input);
        auto &layout = control->m_textLayout;
        const int preeditStart = layout.preeditAreaPosition();
        const int preeditLength = layout.preeditAreaText().size();
        auto combined = preeditLength ? layout.formats() : QList<QTextLayout::FormatRange>{};
        // Preserve Qt's IME attributes. Our colours only address committed
        // characters, leaving the composition's underline/foreground untouched.
        for (const auto &range : std::as_const(m_inputFormats))
            combined.removeAll(range);
        m_inputFormats.clear();
        for (auto range : formats) {
            if (preeditLength && range.start + range.length > preeditStart) {
                if (range.start < preeditStart) {
                    auto before = range;
                    before.length = preeditStart - range.start;
                    m_inputFormats.append(before);
                    range.length -= before.length;
                    range.start = preeditStart;
                }
                range.start += preeditLength;
            }
            m_inputFormats.append(range);
        }
        combined = m_inputFormats + combined;
        if (combined != layout.formats()) {
            layout.setFormats(combined);
            // setFormats() invalidates QTextLine data even for foreground-only
            // changes. Rebuild it before hit-testing, selection or IME queries.
            control->updateLayout();
            control->textLayoutDirty = true;
            control->updateType = QQuickTextInputPrivate::UpdatePaintNode;
            input->update();
        }
    } else if (auto *highlighter = static_cast<DocumentHighlighter *>(m_documentHighlighter.data())) {
        if (highlighter->ranges != formats) {
            highlighter->ranges = formats;
            highlighter->rehighlight();
        }
    }
}
