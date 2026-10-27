#pragma once
#include <QObject>
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
    Q_INVOKABLE void settle() { QTest::qWait(180); }
};
