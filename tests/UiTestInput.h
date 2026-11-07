#pragma once
#include <QObject>
#include <QColor>
#include <QCursor>
#include <QImage>
#include <QRect>
#include <QQuickItem>
#include <QQuickWindow>
#include <QGuiApplication>
#include <QStyleHints>
#include <QTest>
#include <QWindow>
#include <QVariantMap>
#include <QTextLayout>
#include <QWheelEvent>
#include <QInputMethodEvent>
#include <QQuickTextDocument>
#include <QTextBlock>
#include <QtQuick/private/qquicktextinput_p_p.h>

// Send actual window events so smoke tests exercise native control behavior.
class UiTestInput : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE int cursorShape(QQuickItem *item) {
        return item && item->window() ? int(item->window()->cursor().shape()) : -1;
    }
    Q_INVOKABLE QStringList renderedFontFamilies(const QFont &font, const QString &text) {
        QTextLayout layout(text, font);
        layout.beginLayout();
        layout.createLine();
        layout.endLayout();
        QStringList families;
        for (const auto &run : layout.glyphRuns())
            families.append(run.rawFont().familyName());
        families.removeDuplicates();
        return families;
    }
    Q_INVOKABLE void click(QQuickItem *item, qreal x = -1, qreal y = -1) {
        if (!item || !item->window()) return;
        const auto point = item->mapToScene(QPointF(x < 0 ? item->width() / 2 : x,
                                                  y < 0 ? item->height() / 2 : y));
        QTest::mouseClick(item->window(), Qt::LeftButton, Qt::NoModifier, point.toPoint());
    }
    Q_INVOKABLE void pressAndHold(QQuickItem *item) {
        if (!item || !item->window()) return;
        const auto point = item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint();
        QTest::mouseMove(item->window(), point);
        QTest::mousePress(item->window(), Qt::LeftButton, Qt::NoModifier, point);
        QTest::qWait(QGuiApplication::styleHints()->mousePressAndHoldInterval() + 80);
        QTest::mouseRelease(item->window(), Qt::LeftButton, Qt::NoModifier, point);
    }
    Q_INVOKABLE void key(QQuickItem *item, int key, int modifiers = 0) {
        if (item && item->window())
            QTest::keyClick(item->window(), Qt::Key(key), Qt::KeyboardModifiers(modifiers));
    }
    Q_INVOKABLE void dragSelect(QQuickItem *item, qreal fromX, qreal fromY,
                                qreal toX, qreal toY, int steps = 12) {
        if (!item || !item->window()) return;
        const auto start = item->mapToScene(QPointF(fromX, fromY));
        const auto end = item->mapToScene(QPointF(toX, toY));
        QTest::mousePress(item->window(), Qt::LeftButton, Qt::NoModifier, start.toPoint());
        steps = qMax(1, steps);
        for (int step = 1; step <= steps; ++step) {
            QTest::mouseMove(item->window(), (start + (end - start) * (qreal(step) / steps)).toPoint());
            QTest::qWait(15);
        }
        QTest::mouseRelease(item->window(), Qt::LeftButton, Qt::NoModifier, end.toPoint());
    }
    Q_INVOKABLE QColor textFormatColor(QObject *item, int position) {
        if (!item) return {};
        QList<QTextLayout::FormatRange> ranges;
        if (auto *input = qobject_cast<QQuickTextInput *>(item)) {
            ranges = QQuickTextInputPrivate::get(input)->m_textLayout.formats();
        } else if (auto *document = qvariant_cast<QQuickTextDocument *>(item->property("textDocument"))) {
            const auto block = document->textDocument()->findBlock(position);
            if (!block.isValid()) return {};
            ranges = block.layout()->formats();
            position -= block.position();
        }
        QColor color;
        for (const auto &range : ranges)
            if (range.start <= position && position < range.start + range.length
                && range.format.hasProperty(QTextFormat::ForegroundBrush))
                color = range.format.foreground().color();
        return color;
    }
    Q_INVOKABLE void preedit(QQuickItem *item, const QString &text) {
        if (!item) return;
        QTextCharFormat format;
        format.setUnderlineStyle(QTextCharFormat::DashUnderline);
        QInputMethodEvent event(text, {{QInputMethodEvent::TextFormat, 0, int(text.size()), format}});
        QCoreApplication::sendEvent(item, &event);
    }
    Q_INVOKABLE void commitText(QQuickItem *item, const QString &text) {
        if (!item) return;
        QInputMethodEvent event;
        event.setCommitString(text);
        QCoreApplication::sendEvent(item, &event);
    }
    Q_INVOKABLE void wheel(QQuickItem *item, int delta) {
        if (!item || !item->window()) return;
        const auto point = item->mapToScene(QPointF(item->width() / 2, item->height() / 2));
        QWheelEvent event(point, item->window()->mapToGlobal(point.toPoint()),
                          QPoint(), QPoint(0, delta), Qt::NoButton, Qt::NoModifier,
                          Qt::NoScrollPhase, false);
        QCoreApplication::sendEvent(item->window(), &event);
    }
    Q_INVOKABLE void rightClick(QQuickItem *item) {
        if (!item || !item->window()) return;
        const auto point = item->mapToScene(QPointF(item->width() / 2, item->height() / 2));
        QTest::mouseClick(item->window(), Qt::RightButton, Qt::NoModifier, point.toPoint());
    }
    Q_INVOKABLE void hover(QQuickItem *item, bool inside = true) {
        if (!item || !item->window()) return;
        const auto point = item->mapToScene(inside ? QPointF(item->width() / 2, item->height() / 2)
                                                 : QPointF(-10, -10));
        QTest::mouseMove(item->window(), point.toPoint());
    }
    Q_INVOKABLE void settle(int milliseconds = 180) { QTest::qWait(milliseconds); }
    Q_INVOKABLE QColor imageColor(const QString &path, int x, int y) {
        const QImage image(path);
        if (image.isNull() || !image.rect().contains(x, y)) return {};
        return image.pixelColor(x, y);
    }
    Q_INVOKABLE QVariantMap iconPixelDifference(const QString &path, const QRect &actual,
                                                const QRect &reference, const QColor &tint,
                                                bool tinted) {
        const QImage image(path);
        if (image.isNull() || actual.size() != reference.size()
            || !image.rect().contains(actual) || !image.rect().contains(reference))
            return {{"error", 256}, {"samples", 0}};
        int error = 0, samples = 0;
        for (int y = 0; y < actual.height(); ++y) {
            for (int x = 0; x < actual.width(); ++x) {
                const QColor expected = image.pixelColor(reference.x() + x, reference.y() + y);
                // Opaque white interiors avoid antialiasing and filtering noise.
                // Dark mode and colored images compare the entire original image.
                if (tinted && (expected.red() < 252 || expected.green() < 252 || expected.blue() < 252))
                    continue;
                const QColor pixel = image.pixelColor(actual.x() + x, actual.y() + y);
                const QColor target = tinted ? tint : expected;
                error = qMax(error, qAbs(pixel.red() - target.red()));
                error = qMax(error, qAbs(pixel.green() - target.green()));
                error = qMax(error, qAbs(pixel.blue() - target.blue()));
                ++samples;
            }
        }
        return {{"error", error}, {"samples", samples}};
    }
    Q_INVOKABLE int brightnessAt(QQuickItem *item, qreal x, qreal y) {
        if (!item || !item->window()) return -1;
        const auto frame = item->window()->grabWindow();
        if (frame.isNull()) return -1;
        const auto point = item->mapToScene(QPointF(x, y));
        const int px = qBound(0, qRound(point.x() * frame.width() / item->window()->width()), frame.width() - 1);
        const int py = qBound(0, qRound(point.y() * frame.height() / item->window()->height()), frame.height() - 1);
        const auto pixel = frame.pixel(px, py);
        return qMax(qRed(pixel), qMax(qGreen(pixel), qBlue(pixel)));
    }
};
