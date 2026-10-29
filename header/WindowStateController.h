#pragma once

#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QVariantAnimation>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

// Keep Qt Quick's QML Window lifecycle and animate its real layout geometry.
class WindowStateController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QWindow *window READ window WRITE setWindow NOTIFY windowChanged REQUIRED)
    Q_PROPERTY(bool maximized READ maximized NOTIFY stateChanged)
    Q_PROPERTY(bool fullScreen READ fullScreen NOTIFY stateChanged)
    Q_PROPERTY(bool transitioning READ transitioning NOTIFY transitionChanged)
    Q_PROPERTY(qreal frameProgress READ frameProgress NOTIFY frameProgressChanged)

public:
    explicit WindowStateController(QObject *parent = nullptr);
    QWindow *window() const { return m_window; }
    void setWindow(QWindow *window);
    bool maximized() const;
    bool fullScreen() const;
    bool transitioning() const { return m_transitioning; }
    qreal frameProgress() const;
    Q_INVOKABLE void toggleMaximized(int duration = 240);
    Q_INVOKABLE void finishTransition();
    Q_INVOKABLE void minimize();

signals:
    void windowChanged();
    void stateChanged();
    void transitionChanged();
    void frameProgressChanged();

private:
    void rememberNormalGeometry();
    void rememberNativePlacement();
    void restoreNativePlacement();
    void animateGeometry(qreal progress);

    QPointer<QWindow> m_window;
    QTimer m_geometryCache;
    QVariantAnimation m_animation;
    QRect m_normalGeometry;
    QRect m_nativeNormalRect;
    QRect m_fromGeometry;
    QRect m_toGeometry;
    qreal m_fromFrameProgress = 0;
    qreal m_toFrameProgress = 0;
    qreal m_frameProgress = 0;
    bool m_transitioning = false;
    bool m_maximizing = false;
    bool m_committing = false;
};
