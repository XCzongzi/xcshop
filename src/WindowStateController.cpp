#include "WindowStateController.h"
#include <QScreen>
#include <QGuiApplication>
#include <QSettings>
#include <QtMath>
#ifdef Q_OS_WIN
#include <qt_windows.h>
#endif

WindowStateController::WindowStateController(QObject *parent) : QObject(parent)
{
    m_geometryCache.setSingleShot(true);
    m_geometryCache.setInterval(0);
    connect(&m_geometryCache, &QTimer::timeout, this, &WindowStateController::rememberNormalGeometry);
    m_animation.setEasingCurve(QEasingCurve::InOutQuint);
    connect(&m_animation, &QVariantAnimation::valueChanged, this,
            [this](const QVariant &value) { animateGeometry(value.toReal()); });
    connect(&m_animation, &QVariantAnimation::finished, this, &WindowStateController::finishTransition);
}

void WindowStateController::setWindow(QWindow *window)
{
    if (m_window == window)
        return;
    finishTransition();
    if (m_window)
        disconnect(m_window, nullptr, this, nullptr);
    m_window = window;
    m_normalGeometry = {};
    m_nativeNormalRect = {};
    if (m_window) {
        connect(m_window, &QWindow::windowStateChanged, this, [this] {
            emit stateChanged();
            if (!m_transitioning)
                emit frameProgressChanged();
            m_geometryCache.start();
        });
        connect(m_window, &QWindow::xChanged, &m_geometryCache, qOverload<>(&QTimer::start));
        connect(m_window, &QWindow::yChanged, &m_geometryCache, qOverload<>(&QTimer::start));
        connect(m_window, &QWindow::widthChanged, &m_geometryCache, qOverload<>(&QTimer::start));
        connect(m_window, &QWindow::heightChanged, &m_geometryCache, qOverload<>(&QTimer::start));
        connect(m_window, &QWindow::visibilityChanged, this, [this](QWindow::Visibility visibility) {
            if (!m_committing && m_transitioning
                && (visibility == QWindow::Minimized || visibility == QWindow::Hidden)) {
                m_animation.stop();
                QTimer::singleShot(0, this, &WindowStateController::finishTransition);
            }
        });
        connect(m_window, &QObject::destroyed, this, [this] {
            m_animation.stop();
            m_transitioning = false;
            emit windowChanged();
            emit stateChanged();
            emit transitionChanged();
            emit frameProgressChanged();
        });
        m_geometryCache.start();
    }
    emit windowChanged();
    emit stateChanged();
    emit frameProgressChanged();
}

bool WindowStateController::maximized() const
{
    return m_window && m_window->windowStates().testFlag(Qt::WindowMaximized);
}

bool WindowStateController::fullScreen() const
{
    return m_window && m_window->windowStates().testFlag(Qt::WindowFullScreen);
}

qreal WindowStateController::frameProgress() const
{
    return m_transitioning ? m_frameProgress : (maximized() || fullScreen() ? 1.0 : 0.0);
}

void WindowStateController::rememberNormalGeometry()
{
    if (m_window && !m_transitioning && m_window->visibility() == QWindow::Windowed) {
        m_normalGeometry = m_window->geometry();
        rememberNativePlacement();
    }
}

void WindowStateController::saveState(const QString &path)
{
    if (!m_window || path.isEmpty())
        return;
    finishTransition();
    rememberNormalGeometry();
    if (!m_normalGeometry.isValid())
        return;
    QSettings settings(path, QSettings::IniFormat);
    settings.setValue(QStringLiteral("window/normalGeometry"), m_normalGeometry);
    settings.setValue(QStringLiteral("window/maximized"), maximized());
    settings.sync();
    if (settings.status() != QSettings::NoError)
        qWarning("Failed to save window state: %s", qPrintable(path));
}

void WindowStateController::restoreState(const QString &path)
{
    if (!m_window || path.isEmpty())
        return;
    QSettings settings(path, QSettings::IniFormat);
    QRect geometry = settings.value(QStringLiteral("window/normalGeometry")).toRect();
    if (!geometry.isValid())
        return;

    // Select the screen containing most of the saved window. If it was removed,
    // bring the window back onto the primary screen.
    QScreen *screen = QGuiApplication::primaryScreen();
    qint64 largestArea = 0;
    for (auto *candidate : QGuiApplication::screens()) {
        const QRect overlap = candidate->availableGeometry().intersected(geometry);
        const qint64 area = qint64(overlap.width()) * overlap.height();
        if (area > largestArea) {
            largestArea = area;
            screen = candidate;
        }
    }
    if (screen) {
        const QRect available = screen->availableGeometry();
        geometry.setSize(geometry.size().boundedTo(available.size())
                             .expandedTo(m_window->minimumSize()));
        geometry.moveLeft(qBound(available.left(), geometry.x(),
                                 qMax(available.left(), available.right() - geometry.width() + 1)));
        geometry.moveTop(qBound(available.top(), geometry.y(),
                                qMax(available.top(), available.bottom() - geometry.height() + 1)));
        m_window->setScreen(screen);
    }
    finishTransition();
    m_window->setWindowStates(Qt::WindowNoState);
    m_window->setGeometry(geometry);
    m_normalGeometry = geometry;
    // Create the native surface at the normal geometry before maximizing so
    // Windows also retains the correct restore placement after a restart.
    m_window->create();
    rememberNativePlacement();
    if (settings.value(QStringLiteral("window/maximized"), false).toBool())
        m_window->setWindowStates(Qt::WindowMaximized);
}

void WindowStateController::rememberNativePlacement()
{
#ifdef Q_OS_WIN
    if (!m_window || !m_window->handle())
        return;
    WINDOWPLACEMENT placement = {};
    placement.length = sizeof(placement);
    if (GetWindowPlacement(reinterpret_cast<HWND>(m_window->winId()), &placement)) {
        const RECT &rect = placement.rcNormalPosition;
        m_nativeNormalRect = QRect(rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top);
    }
#endif
}

void WindowStateController::restoreNativePlacement()
{
#ifdef Q_OS_WIN
    if (!m_window || !m_nativeNormalRect.isValid())
        return;
    const HWND handle = reinterpret_cast<HWND>(m_window->winId());
    WINDOWPLACEMENT placement = {};
    placement.length = sizeof(placement);
    if (GetWindowPlacement(handle, &placement)) {
        // Keep the native pixel/work-area coordinates saved before resizing. This
        // also works on mixed-DPI monitors without converting WINDOWPLACEMENT.
        placement.rcNormalPosition = {m_nativeNormalRect.x(), m_nativeNormalRect.y(),
                                      m_nativeNormalRect.x() + m_nativeNormalRect.width(),
                                      m_nativeNormalRect.y() + m_nativeNormalRect.height()};
        if (!m_window->isVisible())
            placement.showCmd = SW_HIDE;
        SetWindowPlacement(handle, &placement);
    }
#endif
}

void WindowStateController::toggleMaximized(int duration)
{
    if (!m_window)
        return;
    if (!m_window->isVisible() || m_window->visibility() == QWindow::Minimized || fullScreen()) {
        finishTransition();
        if (maximized() || fullScreen()) m_window->showNormal();
        else m_window->showMaximized();
        return;
    }
    const bool reversing = m_transitioning;
    const bool maximizeNext = reversing ? !m_maximizing : !maximized();
    const qreal currentFrameProgress = frameProgress();
    if (reversing) {
        m_animation.stop();
    } else {
        rememberNormalGeometry();
        rememberNativePlacement();
    }
    if (!maximizeNext && !m_normalGeometry.isValid()) {
        m_window->showNormal();
        return;
    }
    m_fromGeometry = m_window->geometry();
    m_toGeometry = maximizeNext && m_window->screen()
                       ? m_window->screen()->availableGeometry() : m_normalGeometry;
    m_maximizing = maximizeNext;
    m_fromFrameProgress = currentFrameProgress;
    m_toFrameProgress = maximizeNext ? 1.0 : 0.0;
    m_frameProgress = currentFrameProgress;
    m_transitioning = true;
    emit transitionChanged();
#ifdef Q_OS_WIN
    if (!maximizeNext) {
        // Clear only the native zoom constraint, without restoring/moving the
        // window first. Qt keeps its state until the live resize has finished.
        const HWND handle = reinterpret_cast<HWND>(m_window->winId());
        const LONG_PTR style = GetWindowLongPtr(handle, GWL_STYLE);
        SetWindowLongPtr(handle, GWL_STYLE, style & ~LONG_PTR(WS_MAXIMIZE));
    }
#else
    if (!maximizeNext) {
        m_window->showNormal();
        m_window->setGeometry(m_fromGeometry);
    }
#endif
    m_animation.setDuration(qMax(1, duration));
    m_animation.setStartValue(0.0);
    m_animation.setEndValue(1.0);
    m_animation.start();
}

void WindowStateController::animateGeometry(qreal progress)
{
    if (!m_window || !m_transitioning)
        return;
    m_frameProgress = m_fromFrameProgress + (m_toFrameProgress - m_fromFrameProgress) * progress;
    emit frameProgressChanged();
    const auto interpolate = [progress](int from, int to) { return qRound(from + (to - from) * progress); };
    m_window->setGeometry(QRect(interpolate(m_fromGeometry.x(), m_toGeometry.x()),
                               interpolate(m_fromGeometry.y(), m_toGeometry.y()),
                               interpolate(m_fromGeometry.width(), m_toGeometry.width()),
                               interpolate(m_fromGeometry.height(), m_toGeometry.height())));
}

void WindowStateController::finishTransition()
{
    if (!m_window || !m_transitioning || m_committing)
        return;
    m_committing = true;
    m_animation.stop();
    m_frameProgress = m_toFrameProgress;
    emit frameProgressChanged();
    const bool minimized = m_window->windowStates().testFlag(Qt::WindowMinimized);
    const bool visible = m_window->isVisible();
    if (minimized) {
        m_window->setGeometry(m_normalGeometry);
        m_window->setWindowStates(Qt::WindowMinimized | (m_maximizing ? Qt::WindowMaximized : Qt::WindowNoState));
    } else {
        m_window->setGeometry(m_toGeometry);
        m_window->setWindowStates(m_maximizing ? Qt::WindowMaximized : Qt::WindowNoState);
#ifdef Q_OS_WIN
        if (m_maximizing && visible && !IsZoomed(reinterpret_cast<HWND>(m_window->winId())))
            ShowWindow(reinterpret_cast<HWND>(m_window->winId()), SW_MAXIMIZE);
#endif
        if (!m_maximizing)
            m_window->setGeometry(m_toGeometry);
    }
    if (m_maximizing)
        restoreNativePlacement();
    m_transitioning = false;
    m_committing = false;
    emit transitionChanged();
    emit frameProgressChanged();
    m_geometryCache.start();
}

void WindowStateController::minimize()
{
    if (!m_window)
        return;
    finishTransition();
    // Preserve the combined state so native restore retains maximization.
    m_window->setWindowStates(m_window->windowStates() | Qt::WindowMinimized);
    m_window->setVisible(true);
}
