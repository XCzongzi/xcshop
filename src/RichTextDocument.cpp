#include "RichTextDocument.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTextBlock>
#include <QTextDocument>
#include <QTextFragment>
#include <QtQuick/private/qquicktextedit_p.h>
#include <QtQuick/private/qquicktextedit_p_p.h>
#include <QtQuick/private/qquicktextcontrol_p.h>
#include <QtQuick/private/qquicktextcontrol_p_p.h>
#include <functional>

namespace {
constexpr int Obfuscated = QTextFormat::UserProperty + 1;
constexpr int Metadata = QTextFormat::UserProperty + 2;
const QStringList colorNames = {"black", "dark_blue", "dark_green", "dark_aqua",
    "dark_red", "dark_purple", "gold", "gray", "dark_gray", "blue", "green",
    "aqua", "red", "light_purple", "yellow", "white"};
const QStringList colorValues = {"#000000", "#0000aa", "#00aa00", "#00aaaa",
    "#aa0000", "#aa00aa", "#ffaa00", "#aaaaaa", "#555555", "#5555ff", "#55ff55",
    "#55ffff", "#ff5555", "#ff55ff", "#ffff55", "#ffffff"};
QColor ink(const QString &name) {
    const int index = colorNames.indexOf(name);
    return QColor(index < 0 ? name : colorValues[index]);
}
QVariantMap style(const QTextCharFormat &format) {
    QString color = format.foreground().style() == Qt::NoBrush
        ? "white" : format.foreground().color().name();
    const int index = colorValues.indexOf(color);
    if (index >= 0) color = colorNames[index];
    return {{"color", color}, {"bold", format.fontWeight() >= QFont::Bold},
        {"italic", format.fontItalic()}, {"underlined", format.fontUnderline()},
        {"strikethrough", format.fontStrikeOut()}, {"obfuscated", format.boolProperty(Obfuscated)}};
}
void setStyle(QTextCharFormat &format, const QString &key, const QVariant &value) {
    if (key == "color") format.setForeground(ink(value.toString()));
    else if (key == "bold") format.setFontWeight(value.toBool() ? QFont::Bold : QFont::Normal);
    else if (key == "italic") format.setFontItalic(value.toBool());
    else if (key == "underlined") format.setFontUnderline(value.toBool());
    else if (key == "strikethrough") format.setFontStrikeOut(value.toBool());
    else if (key == "obfuscated") format.setProperty(Obfuscated, value.toBool());
}
}

QTextCursor *RichTextDocument::cursor() const {
    auto *edit = qobject_cast<QQuickTextEdit *>(m_target.data());
    if (!edit) return nullptr;
    auto *control = static_cast<QQuickTextEditPrivate *>(QQuickItemPrivate::get(edit))->control;
    // QQuickTextControl's methods are not exported on Windows. Access its native
    // cursor through the matching QuickPrivate headers already required by the app.
    return control ? &static_cast<QQuickTextControlPrivate *>(QObjectPrivate::get(control))->cursor : nullptr;
}
QTextDocument *RichTextDocument::document() const {
    return cursor() ? cursor()->document() : nullptr;
}
void RichTextDocument::setTarget(QObject *target) {
    if (m_target == target) return;
    if (m_target) disconnect(m_target, nullptr, this, nullptr);
    if (document()) disconnect(document(), nullptr, this, nullptr);
    m_target = target;
    if (auto *edit = qobject_cast<QQuickTextEdit *>(m_target.data())) {
        connect(edit, &QQuickTextEdit::cursorPositionChanged, this,
                &RichTextDocument::currentStyleChanged);
        connect(edit, &QQuickTextEdit::selectionStartChanged, this,
                &RichTextDocument::currentStyleChanged);
        connect(edit, &QQuickTextEdit::selectionEndChanged, this,
                &RichTextDocument::currentStyleChanged);
        connect(document(), &QTextDocument::contentsChanged, this, [this] {
            if (!m_loading && !m_normalizing) {
                normalizeSingleLine();
                emit currentStyleChanged();
                emit edited();
            }
        });
    }
    emit targetChanged();
    emit currentStyleChanged();
}
void RichTextDocument::setSingleLine(bool singleLine) {
    if (m_singleLine == singleLine) return;
    m_singleLine = singleLine;
    if (normalizeSingleLine()) {
        emit currentStyleChanged();
        emit edited();
    }
    emit singleLineChanged();
}
bool RichTextDocument::normalizeSingleLine() {
    auto *doc = document();
    if (!m_singleLine || !doc || m_normalizing) return false;
    const auto text = doc->toRawText();
    QList<int> breaks;
    for (int i = 0; i < text.size(); ++i) {
        const auto ch = text.at(i).unicode();
        if (ch == '\r' || ch == '\n' || ch == '\v' || ch == '\f'
            || ch == 0x85 || ch == 0x2028 || ch == 0x2029)
            breaks.append(i);
    }
    if (breaks.isEmpty()) return false;
    m_normalizing = true;
    QTextCursor edit(doc);
    // Keep paste/IME input and its cleanup in the same undo step. Removing only
    // separators preserves each remaining character's style and metadata.
    edit.joinPreviousEditBlock();
    for (auto it = breaks.crbegin(); it != breaks.crend(); ++it) {
        edit.setPosition(*it);
        edit.deleteChar();
    }
    edit.endEditBlock();
    m_normalizing = false;
    return true;
}
QVariantMap RichTextDocument::currentStyle() const {
    return style(cursor() ? cursor()->charFormat() : QTextCharFormat());
}
void RichTextDocument::load(const QString &source) {
    if (!document()) return;
    m_loading = true;
    m_source = source;
    m_error.clear();
    auto *doc = document();
    doc->clear();
    QTextCursor cursor(doc);
    QTextCharFormat base;
    base.setForeground(ink("white"));
    std::function<QTextCharFormat(const QJsonValue &, QTextCharFormat)> append;
    append = [&](const QJsonValue &value, QTextCharFormat format) -> QTextCharFormat {
        if (value.isArray()) {
            const auto array = value.toArray();
            if (array.isEmpty()) return format;
            const auto parent = append(array.first(), format);
            for (int i = 1; i < array.size(); ++i) append(array[i], parent);
            return parent;
        }
        if (value.isString() || value.isDouble()) {
            cursor.insertText(value.toVariant().toString(), format);
            return format;
        }
        if (!value.isObject()) {
            m_error = tr("此内容包含暂不支持的文本组件，已保留原内容。");
            return format;
        }
        auto object = value.toObject();
        for (const auto &key : {"translate", "keybind", "score", "selector", "nbt"}) {
            if (object.contains(QLatin1String(key))) {
                m_error = tr("此内容包含动态文本组件，暂不能直接编辑，已保留原内容。");
                cursor.insertText(tr("〔动态文本〕"), format);
                return format;
            }
        }
        for (auto it = object.begin(); it != object.end(); ++it)
            setStyle(format, it.key(), it.value().toVariant());
        auto metadata = format.property(Metadata).toJsonObject();
        for (auto it = object.begin(); it != object.end(); ++it) {
            if (it.key() != "text" && it.key() != "extra" && !style(base).contains(it.key()))
                metadata.insert(it.key(), it.value());
        }
        format.setProperty(Metadata, metadata);
        cursor.insertText(object.value("text").toVariant().toString(), format);
        if (object.contains("extra")) {
            // Unlike a top-level array, extra entries are siblings.
            for (const auto &child : object.value("extra").toArray()) append(child, format);
        }
        return format;
    };
    QJsonParseError error;
    const auto wrapped = QJsonDocument::fromJson(("[" + source + "]").toUtf8(), &error);
    if (source.trimmed().isEmpty() || error.error != QJsonParseError::NoError || wrapped.array().size() != 1)
        cursor.insertText(source, base);
    else
        append(wrapped.array().first(), base);
    normalizeSingleLine();
    doc->clearUndoRedoStacks();
    qobject_cast<QQuickTextEdit *>(m_target.data())->setCursorPosition(doc->characterCount() - 1);
    if (doc->isEmpty()) this->cursor()->setCharFormat(base);
    m_loading = false;
    emit errorChanged();
    emit currentStyleChanged();
}
QString RichTextDocument::serialize() const {
    if (!m_error.isEmpty()) return m_source;
    QJsonArray parts;
    QJsonObject previous;
    QString text;
    auto flush = [&] {
        if (text.isEmpty()) return;
        previous.insert("text", text);
        parts.append(previous);
        text.clear();
    };
    auto append = [&](const QString &value, const QTextCharFormat &format) {
        auto attributes = format.property(Metadata).toJsonObject();
        const auto properties = style(format);
        for (auto it = properties.begin(); it != properties.end(); ++it) {
            if (it.key() == "color" ? it.value().toString() != "white" : it.value().toBool())
                attributes.insert(it.key(), QJsonValue::fromVariant(it.value()));
        }
        if (attributes != previous) { flush(); previous = attributes; }
        text += value;
    };
    if (auto *doc = document()) {
        for (auto block = doc->begin(); block.isValid(); block = block.next()) {
            for (auto it = block.begin(); !it.atEnd(); ++it) {
                const auto fragment = it.fragment();
                if (fragment.isValid()) append(fragment.text(), fragment.charFormat());
            }
            if (block.next().isValid()) append("\n", block.charFormat());
        }
    }
    flush();
    QJsonObject result;
    if (parts.size() == 1) result = parts.first().toObject();
    else { result.insert("text", ""); if (!parts.isEmpty()) result.insert("extra", parts); }
    return QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
}
void RichTextDocument::apply(const QString &property, const QVariant &value) {
    if (!cursor() || !m_error.isEmpty()) return;
    if (property == "color" && !ink(value.toString()).isValid()) return;
    QTextCharFormat format;
    setStyle(format, property, value);
    cursor()->mergeCharFormat(format);
    emit currentStyleChanged();
}
void RichTextDocument::resetStyle() {
    if (!cursor() || !m_error.isEmpty()) return;
    QTextCharFormat format;
    format.setForeground(ink("white"));
    format.setFontWeight(QFont::Normal);
    format.setFontItalic(false);
    format.setFontUnderline(false);
    format.setFontStrikeOut(false);
    format.setProperty(Obfuscated, false);
    cursor()->mergeCharFormat(format);
    emit currentStyleChanged();
}
