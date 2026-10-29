#pragma once

#include <QObject>
#include <QPointer>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

// Keep Qt Quick's QML Window lifecycle, and expose only its combined state.
class WindowStateController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QWindow *window READ window WRITE setWindow NOTIFY windowChanged REQUIRED)
    Q_PROPERTY(bool maximized READ maximized NOTIFY stateChanged)
    Q_PROPERTY(bool fullScreen READ fullScreen NOTIFY stateChanged)

public:
    using QObject::QObject;

    QWindow *window() const { return m_window; }
    void setWindow(QWindow *window);
    bool maximized() const;
    bool fullScreen() const;
    Q_INVOKABLE void minimize();

signals:
    void windowChanged();
    void stateChanged();

private:
    QPointer<QWindow> m_window;
};
