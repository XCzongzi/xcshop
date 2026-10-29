#include "WindowStateController.h"

void WindowStateController::setWindow(QWindow *window)
{
    if (m_window == window)
        return;
    if (m_window)
        disconnect(m_window, nullptr, this, nullptr);
    m_window = window;
    if (m_window) {
        connect(m_window, &QWindow::windowStateChanged, this, &WindowStateController::stateChanged);
        connect(m_window, &QObject::destroyed, this, [this] {
            emit windowChanged();
            emit stateChanged();
        });
    }
    emit windowChanged();
    emit stateChanged();
}

bool WindowStateController::maximized() const
{
    return m_window && m_window->windowStates().testFlag(Qt::WindowMaximized);
}

bool WindowStateController::fullScreen() const
{
    return m_window && m_window->windowStates().testFlag(Qt::WindowFullScreen);
}

void WindowStateController::minimize()
{
    if (!m_window)
        return;
    // showMinimized() replaces the combined state, clearing WindowMaximized.
    m_window->setWindowStates(m_window->windowStates() | Qt::WindowMinimized);
    m_window->setVisible(true);
}
