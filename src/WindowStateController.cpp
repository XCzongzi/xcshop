#include "WindowStateController.h"
#include <QScreen>
#include <QGuiApplication>
#include <QSettings>
#include <QPlatformSurfaceEvent>
#include <QScopedValueRollback>
#include <QtMath>
#include <functional>
#ifdef Q_OS_WIN
#include <qt_windows.h>
#include <dwmapi.h>
#include <QAbstractNativeEventFilter>

namespace {
class ScopedNativeTransitionSuppression
{
public:
    explicit ScopedNativeTransitionSuppression(QWindow *window)
        : m_handle(reinterpret_cast<HWND>(window->winId()))
    {
        const BOOL disabled = TRUE;
        m_disabled = SUCCEEDED(DwmSetWindowAttribute(m_handle, DWMWA_TRANSITIONS_FORCEDISABLED,
                                                     &disabled, sizeof(disabled)));
    }
    ~ScopedNativeTransitionSuppression()
    {
        if (m_disabled) {
            const BOOL disabled = FALSE;
            DwmSetWindowAttribute(m_handle, DWMWA_TRANSITIONS_FORCEDISABLED,
                                  &disabled, sizeof(disabled));
        }
    }

private:
    HWND m_handle;
    bool m_disabled = false;
};

bool isWindowSnapped(HWND handle)
{
    // Resolve at runtime for Qt kits whose SDK predates IsWindowArranged,
    // and Windows versions that do not export it.
    using IsWindowArrangedFunction = BOOL (WINAPI *)(HWND);
    static const auto isArranged = reinterpret_cast<IsWindowArrangedFunction>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "IsWindowArranged"));
    return isArranged && isArranged(handle);
}

class WindowsSnapFilter final : public QObject, public QAbstractNativeEventFilter
{
public:
    WindowsSnapFilter(QWindow *window, QObject *parent, std::function<void()> changed)
        : QObject(parent), m_window(window), m_changed(std::move(changed))
    {
        setObjectName(QStringLiteral("windowsSnapFilter"));
        qApp->installNativeEventFilter(this);
    }
    ~WindowsSnapFilter() override { qApp->removeNativeEventFilter(this); }

    void restoreInPlace()
    {
        const HWND handle = reinterpret_cast<HWND>(m_window->winId());
        RECT client = {};
        POINT origin = {};
        if (!GetClientRect(handle, &client) || !ClientToScreen(handle, &origin))
            return;
        // Preserve the visible client, rather than the outer maximized frame:
        // Windows' invisible resize borders disappear when leaving maximized.
        m_restoreGeometry = QRect(origin.x, origin.y, client.right, client.bottom);
        const ScopedNativeTransitionSuppression suppressNativeTransition(m_window);
        const QScopedValueRollback preserveGeometry(m_preservingGeometry, true);
        m_window->setWindowStates(Qt::WindowNoState);
    }

    bool nativeEventFilter(const QByteArray &, void *message, qintptr *result) override
    {
        const auto *msg = static_cast<MSG *>(message);
        if (!m_window || !m_window->handle()
            || msg->hwnd != reinterpret_cast<HWND>(m_window->winId()))
            return false;
        if (msg->message == WM_WINDOWPOSCHANGING && m_preservingGeometry) {
            // Clear the maximized state without visiting the saved restore
            // rectangle. The live animation owns position and size.
            auto *position = reinterpret_cast<WINDOWPOS *>(msg->lParam);
            position->x = m_restoreGeometry.x();
            position->y = m_restoreGeometry.y();
            position->cx = m_restoreGeometry.width();
            position->cy = m_restoreGeometry.height();
            position->flags &= ~(SWP_NOMOVE | SWP_NOSIZE);
            position->flags |= SWP_NOZORDER | SWP_NOACTIVATE;
        }
        if (msg->message == WM_WINDOWPOSCHANGED || msg->message == WM_EXITSIZEMOVE
            || msg->message == WM_SIZE)
            m_changed();
        if (msg->message != WM_NCCALCSIZE || !msg->wParam || !IsZoomed(msg->hwnd)
            || m_window->windowStates().testFlag(Qt::WindowFullScreen))
            return false;
        MONITORINFO monitor = {};
        monitor.cbSize = sizeof(monitor);
        if (!GetMonitorInfo(MonitorFromWindow(msg->hwnd, MONITOR_DEFAULTTONEAREST), &monitor))
            return false;
        // The native resizable style normally maximizes beyond the work area
        // to hide its frame. Our frame is QML, so use the exact work area.
        auto *client = reinterpret_cast<NCCALCSIZE_PARAMS *>(msg->lParam);
        client->rgrc[0] = monitor.rcWork;
        *result = 0;
        return true;
    }

private:
    QPointer<QWindow> m_window;
    std::function<void()> m_changed;
    QRect m_restoreGeometry;
    bool m_preservingGeometry = false;
};
}
#endif

WindowStateController::WindowStateController(QObject *parent) : QObject(parent)
{
    m_geometryCache.setSingleShot(true);
    m_geometryCache.setInterval(0);
    connect(&m_geometryCache, &QTimer::timeout, this, [this] {
        updateSnappedState();
        rememberNormalGeometry();
    });
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
    if (m_window) {
        m_window->removeEventFilter(this);
        disconnect(m_window, nullptr, this, nullptr);
    }
    m_window = window;
#ifdef Q_OS_WIN
    delete findChild<QObject *>(QStringLiteral("windowsSnapFilter"));
#endif
    m_normalGeometry = {};
    m_nativeNormalRect = {};
    if (m_snapped) {
        m_snapped = false;
        emit snappedChanged();
    }
    if (m_window) {
        m_window->installEventFilter(this);
        enableNativeSnapping();
        connect(m_window, &QWindow::windowStateChanged, this, [this] {
            enableNativeSnapping();
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
            updateSnappedState();
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

bool WindowStateController::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window && event->type() == QEvent::PlatformSurface
        && static_cast<QPlatformSurfaceEvent *>(event)->surfaceEventType()
               == QPlatformSurfaceEvent::SurfaceCreated)
        enableNativeSnapping();
    return QObject::eventFilter(watched, event);
}

void WindowStateController::enableNativeSnapping()
{
#ifdef Q_OS_WIN
    if (!m_window || !m_window->handle() || fullScreen()
        || !m_window->flags().testFlag(Qt::FramelessWindowHint))
        return;
    if (!findChild<QObject *>(QStringLiteral("windowsSnapFilter")))
        new WindowsSnapFilter(m_window, this, [this] { m_geometryCache.start(); });
    const HWND handle = reinterpret_cast<HWND>(m_window->winId());
    const LONG_PTR style = GetWindowLongPtr(handle, GWL_STYLE);
    // Windows needs a resizable captioned window for native Snap participation.
    // Qt's FramelessWindowHint still handles WM_NCCALCSIZE, keeping our QML frame.
    const LONG_PTR snapStyle = style | WS_THICKFRAME | WS_CAPTION;
    if (style != snapStyle) {
        SetWindowLongPtr(handle, GWL_STYLE, snapStyle);
        SetWindowPos(handle, nullptr, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    }
#endif
}

void WindowStateController::updateSnappedState()
{
    if (m_transitioning || (m_window && m_window->windowStates().testFlag(Qt::WindowMinimized)))
        return;
    bool snapped = false;
#ifdef Q_OS_WIN
    if (m_window && m_window->handle() && !maximized() && !fullScreen())
        snapped = isWindowSnapped(reinterpret_cast<HWND>(m_window->winId()));
#endif
    if (m_snapped != snapped) {
        m_snapped = snapped;
        emit snappedChanged();
    }
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
    if (!maximizeNext && maximized()) {
        if (auto *filter = static_cast<WindowsSnapFilter *>(
                findChild<QObject *>(QStringLiteral("windowsSnapFilter"))))
            filter->restoreInPlace();
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
#ifdef Q_OS_WIN
    // The live geometry animation has already reached its destination. Do not
    // let ShowWindow/SetWindowPlacement play a second system transition here.
    const ScopedNativeTransitionSuppression suppressNativeTransition(m_window);
#endif
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
