#pragma once
#include <QObject>
#include <QImage>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTest>
#include <QWindow>

// Send actual window events so smoke tests exercise native control behavior.
class UiTestInput : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void click(QQuickItem *item, qreal x = -1, qreal y = -1) {
        if (!item || !item->window()) return;
        const auto point = item->mapToScene(QPointF(x < 0 ? item->width() / 2 : x,
                                                  y < 0 ? item->height() / 2 : y));
        QTest::mouseClick(item->window(), Qt::LeftButton, Qt::NoModifier, point.toPoint());
    }
    Q_INVOKABLE void key(QQuickItem *item, int key, int modifiers = 0) {
        if (item && item->window())
            QTest::keyClick(item->window(), Qt::Key(key), Qt::KeyboardModifiers(modifiers));
    }
    Q_INVOKABLE void settle(int milliseconds = 180) { QTest::qWait(milliseconds); }
    Q_INVOKABLE QColor imageColor(const QString &path, int x, int y) {
        const QImage image(path);
        if (image.isNull() || !image.rect().contains(x, y)) return {};
        return image.pixelColor(x, y);
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
