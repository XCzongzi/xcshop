#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include "WindowStateController.h"
#include <QFont>
#include <QFile>
#include <QImage>
#include <QPixmap>
#include <QScreen>
#include <QSignalSpy>
#include <QSurfaceFormat>
#include <QTest>
#include <QThread>
#include <QTemporaryDir>
#include <QSettings>
#include <atomic>

#ifdef Q_OS_WIN
#include <qt_windows.h>
#endif

class WindowFrameTests : public QObject
{
    Q_OBJECT
public:
    explicit WindowFrameTests(QQuickWindow *window) : m_window(window) {}

private:
    QQuickWindow *m_window;

    void clickAt(qreal x, qreal y)
    {
        QTest::mouseClick(m_window, Qt::LeftButton, Qt::NoModifier, QPoint(qRound(x), qRound(y)));
    }

    void nativeRestore()
    {
#ifdef Q_OS_WIN
        ShowWindow(reinterpret_cast<HWND>(m_window->winId()), SW_RESTORE);
#else
        m_window->setWindowStates(m_window->windowStates() & ~Qt::WindowMinimized);
        m_window->setVisible(true);
#endif
    }

    void verifyMaximizedCoverage()
    {
        QCOMPARE(m_window->visibility(), QWindow::Maximized);
        QCOMPARE(m_window->property("margins").toReal(), 0.0);
        QCOMPARE(m_window->property("surfaceWidth").toInt(), m_window->width());
        QCOMPARE(m_window->property("surfaceHeight").toInt(), m_window->height());
#ifdef Q_OS_WIN
        const HWND handle = reinterpret_cast<HWND>(m_window->winId());
        MONITORINFO monitor = {};
        monitor.cbSize = sizeof(monitor);
        QVERIFY(GetMonitorInfo(MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST), &monitor));
        RECT client = {};
        POINT origin = {};
        QVERIFY(GetClientRect(handle, &client));
        QVERIFY(ClientToScreen(handle, &origin));
        RECT frame = {};
        QVERIFY(GetWindowRect(handle, &frame));
        QVERIFY(frame.left <= origin.x && frame.top <= origin.y);
        QVERIFY2(frame.right >= origin.x + client.right && frame.bottom >= origin.y + client.bottom,
                 "The native frame must contain the entire maximized client area");
        QCOMPARE(origin.x, monitor.rcWork.left);
        QCOMPARE(origin.y, monitor.rcWork.top);
        QCOMPARE(client.right, monitor.rcWork.right - monitor.rcWork.left);
        QCOMPARE(client.bottom, monitor.rcWork.bottom - monitor.rcWork.top);
#endif
        // Geometry alone misses a stale scene-graph texture or transparent strip.
        QVERIFY(QTest::qWaitForWindowExposed(m_window));
        const QImage image = m_window->grabWindow();
        QVERIFY(!image.isNull());
#ifdef Q_OS_WIN
        // Qt rounds the logical window size before scaling grabWindow's image.
        const int roundingTolerance = qCeil(m_window->devicePixelRatio());
        QVERIFY(qAbs(image.width() - client.right) <= roundingTolerance);
        QVERIFY(qAbs(image.height() - client.bottom) <= roundingTolerance);
#endif
        for (const QPoint &sample : {QPoint(image.width() - 1, image.height() / 2),
                                     QPoint(image.width() / 2, image.height() - 1),
                                     QPoint(image.width() - 1, image.height() - 1)}) {
            QVERIFY2(image.pixelColor(sample).alpha() > 250,
                     qPrintable(QString("Transparent maximized edge at (%1, %2)")
                                    .arg(sample.x()).arg(sample.y())));
        }
    }

    void verifyTransparentFrame()
    {
        const QRect geometry = m_window->geometry();
        QQuickWindow backing;
        const QColor backingColor(72, 208, 168);
        backing.setFlags(Qt::Tool | Qt::FramelessWindowHint);
        backing.setColor(backingColor);
        backing.setGeometry(geometry);
        backing.show();
        QVERIFY(QTest::qWaitForWindowExposed(&backing));
        m_window->raise();
        m_window->requestActivate();
        QTest::qWait(250);
        // Capture the desktop composition, not an offscreen texture with unused alpha.
        const QPixmap composed = m_window->screen()->grabWindow(0, geometry.x(), geometry.y(),
                                                               geometry.width(), geometry.height());
        QVERIFY(!composed.isNull());
        const QImage image = composed.toImage();
        composed.save(QCoreApplication::applicationDirPath() + "/window-frame-transparency.png");
        const qreal scale = composed.devicePixelRatio();
        const QList<QPoint> samples = {
            {3, geometry.height() / 2}, {geometry.width() - 4, geometry.height() / 2},
            {geometry.width() / 2, 3}, {geometry.width() / 2, geometry.height() - 4}
        };
        for (const auto &sample : samples) {
            const QColor pixel = image.pixelColor(qRound(sample.x() * scale), qRound(sample.y() * scale));
            QVERIFY2(qAbs(pixel.red() - backingColor.red()) < 32
                         && qAbs(pixel.green() - backingColor.green()) < 32
                         && qAbs(pixel.blue() - backingColor.blue()) < 32,
                     qPrintable(QString("Opaque window margin at (%1, %2): %3")
                                    .arg(sample.x()).arg(sample.y()).arg(pixel.name())));
        }
        QVERIFY2(m_window->format().alphaBufferSize() >= 8,
                 "The native surface must request alpha before the window is shown");
    }

    void verifyNativeMove()
    {
#ifdef Q_OS_WIN
        const QPoint originalPosition = m_window->position();
        m_window->setPosition(m_window->screen()->availableGeometry().topLeft() + QPoint(60, 60));
        m_window->raise();
        m_window->requestActivate();
        QTRY_VERIFY(m_window->isActive());
        QTest::qWait(150);
        const HWND handle = reinterpret_cast<HWND>(m_window->winId());
        const LONG_PTR style = GetWindowLongPtr(handle, GWL_STYLE);
        QVERIFY2((style & (WS_THICKFRAME | WS_CAPTION | WS_MAXIMIZEBOX))
                     == (WS_THICKFRAME | WS_CAPTION | WS_MAXIMIZEBOX),
                 "Native dragging must expose the window styles required by Windows Snap");
        RECT originalRect;
        QVERIFY(GetWindowRect(handle, &originalRect));
        POINT originalCursor;
        QVERIFY(GetCursorPos(&originalCursor));
        POINT press = {0, 0};
        QVERIFY(ClientToScreen(handle, &press));
        const qreal scale = m_window->devicePixelRatio();
        const int margin = m_window->property("margins").toInt();
        press.x += qRound((margin + 200) * scale);
        press.y += qRound((margin + 18) * scale);
        std::atomic<int> maxLag{0};
        auto *drag = QThread::create([&] {
            SetCursorPos(press.x, press.y);
            INPUT button = {};
            button.type = INPUT_MOUSE;
            button.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
            SendInput(1, &button, sizeof(button));
            QThread::msleep(120);
            for (int step = 1; step <= 50; ++step) {
                const int offset = step * 4;
                SetCursorPos(press.x + offset, press.y);
                QThread::msleep(16);
                RECT currentRect;
                if (GetWindowRect(handle, &currentRect))
                    maxLag.store(qMax(maxLag.load(), qAbs(int(currentRect.left - originalRect.left) - offset)));
            }
            button.mi.dwFlags = MOUSEEVENTF_LEFTUP;
            SendInput(1, &button, sizeof(button));
            SetCursorPos(originalCursor.x, originalCursor.y);
        });
        drag->start();
        QTRY_VERIFY_WITH_TIMEOUT(drag->isFinished(), 5000);
        drag->wait();
        delete drag;
        RECT movedRect;
        QVERIFY(GetWindowRect(handle, &movedRect));
        const int distance = int(movedRect.left - originalRect.left);
        m_window->setPosition(originalPosition);
        qInfo("Native titlebar drag: distance=%d px, maximum tracking lag=%d px", distance, maxLag.load());
        QVERIFY2(qAbs(distance - 200) <= 8, "The native drag must move the window with the pointer");
        QVERIFY2(maxLag.load() < 80, "The native move loop must not stall behind the pointer");
#endif
    }

private slots:
    void persistedWindowState()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QString path = directory.filePath("window-state.ini");
        const QRect available = m_window->screen()->availableGeometry();
        const QRect normal(available.topLeft() + QPoint(40, 40), QSize(640, 400));
        QWindow source;
        WindowStateController controller;
        controller.setWindow(&source);
        source.setGeometry(normal);
        source.show();
        QTRY_COMPARE(source.visibility(), QWindow::Windowed);
        controller.saveState(path);
        {
            QWindow restored;
            WindowStateController state;
            state.setWindow(&restored);
            state.restoreState(path);
            restored.setVisible(true);
            QTRY_COMPARE(restored.geometry(), normal);
            QCOMPARE(restored.visibility(), QWindow::Windowed);
        }
        source.showMaximized();
        QTRY_COMPARE(source.visibility(), QWindow::Maximized);
        controller.minimize();
        QTRY_COMPARE(source.visibility(), QWindow::Minimized);
        controller.saveState(path);
        {
            QWindow restored;
            WindowStateController state;
            state.setWindow(&restored);
            state.restoreState(path);
            restored.setVisible(true);
            QTRY_COMPARE(restored.visibility(), QWindow::Maximized);
            restored.showNormal();
            QTRY_COMPARE(restored.geometry(), normal);
        }
        // A disconnected display must not leave the titlebar outside the desktop.
        {
            QSettings settings(path, QSettings::IniFormat);
            settings.setValue("window/normalGeometry", QRect(-100000, -100000, 640, 400));
            settings.setValue("window/maximized", false);
        }
        controller.restoreState(path);
        source.show();
        QTRY_COMPARE(source.visibility(), QWindow::Windowed);
        QVERIFY(source.screen()->availableGeometry().contains(source.geometry()));
    }

    void init()
    {
        QMetaObject::invokeMethod(m_window, "finishWindowTransition");
        m_window->showNormal();
        QTRY_COMPARE(m_window->visibility(), QWindow::Windowed);
        QVERIFY(QTest::qWaitForWindowExposed(m_window));
        QTest::qWait(150);
    }

    void maximizeButtonAndDoubleClick()
    {
        const QRect normalGeometry = m_window->geometry();
        const auto flags = m_window->flags();
        const auto handle = m_window->winId();
        QSignalSpy states(m_window, &QWindow::visibilityChanged);
        const int margin = m_window->property("margins").toInt();
        clickAt(m_window->width() - margin - 48, margin + 18);
        QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
        QTRY_VERIFY(!m_window->property("windowTransitionRunning").toBool());
        verifyMaximizedCoverage();
        QTest::mouseDClick(m_window, Qt::LeftButton, Qt::NoModifier, QPoint(220, 18));
        QTRY_COMPARE(m_window->visibility(), QWindow::Windowed);
        QTRY_VERIFY(!m_window->property("windowTransitionRunning").toBool());
        QTRY_COMPARE(m_window->geometry(), normalGeometry);
        QTest::mouseDClick(m_window, Qt::LeftButton, Qt::NoModifier, QPoint(margin + 220, margin + 18));
        QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
        QTRY_VERIFY(!m_window->property("windowTransitionRunning").toBool());
        verifyMaximizedCoverage();
        clickAt(m_window->width() - 54, 18);
        QTRY_COMPARE(m_window->visibility(), QWindow::Windowed);
        QTRY_VERIFY(!m_window->property("windowTransitionRunning").toBool());
        QTRY_COMPARE(m_window->geometry(), normalGeometry);
        QCOMPARE(m_window->flags(), flags);
        QCOMPARE(m_window->winId(), handle);
        for (const auto &state : states)
            QVERIFY2(state.first().value<QWindow::Visibility>() != QWindow::FullScreen,
                     "Maximize/restore must not pass through fullscreen");
    }

    void smoothTransitionAndInterruptions()
    {
        const QRect normalGeometry = m_window->geometry();
        auto *controller = m_window->findChild<WindowStateController *>();
        auto *button = m_window->findChild<QQuickItem *>("startCreateProjectButton");
        auto *title = m_window->findChild<QQuickItem *>("windowTitle");
        QVERIFY(controller);
        QVERIFY(button);
        QVERIFY(title);
        QVERIFY(!m_window->findChild<QQuickWindow *>("windowTransitionOverlay"));
        const QSizeF buttonSize(button->width(), button->height());
        QCOMPARE(buttonSize, QSizeF(210, 140));
        const int fontSize = title->property("font").value<QFont>().pixelSize();
        for (const auto expected : {QWindow::Maximized, QWindow::Windowed}) {
            const QRect sourceGeometry = m_window->geometry();
            const QRect targetGeometry = expected == QWindow::Maximized
                                             ? m_window->screen()->availableGeometry() : normalGeometry;
            QSignalSpy widths(m_window, &QWindow::widthChanged);
            QSignalSpy frames(m_window, &QQuickWindow::frameSwapped);
            bool sawIntermediate = false;
            bool fixedControlMetrics = true;
            bool monotonicWidth = true;
            int previousWidth = sourceGeometry.width();
            const auto monitor = connect(m_window, &QWindow::widthChanged, this, [&](int width) {
                monotonicWidth = monotonicWidth && (expected == QWindow::Maximized
                    ? width >= previousWidth : width <= previousWidth);
                previousWidth = width;
                if (width != sourceGeometry.width() && width != targetGeometry.width()) {
                    sawIntermediate = true;
                    const QPointF unit = title->mapToScene(QPointF(1, 0)) - title->mapToScene(QPointF(0, 0));
                    fixedControlMetrics = fixedControlMetrics
                        && QSizeF(button->width(), button->height()) == buttonSize
                        && title->property("font").value<QFont>().pixelSize() == fontSize
                        && qAbs(unit.x() - 1.0) < 0.001 && qAbs(unit.y()) < 0.001;
                }
            });
            QVERIFY(QMetaObject::invokeMethod(m_window, "toggleMaximized"));
            QVERIFY(controller->transitioning());
            QCOMPARE(m_window->geometry(), sourceGeometry);
            QCOMPARE(m_window->opacity(), 1.0);
            QTRY_VERIFY(!controller->transitioning());
            disconnect(monitor);
            QVERIFY2(monotonicWidth, "The window must not jump backwards during maximize/restore");
            QVERIFY2(sawIntermediate, "The real window must pass through intermediate geometry");
            QVERIFY2(fixedControlMetrics, "Controls and text must keep their real size throughout resizing");
            QCOMPARE(m_window->visibility(), expected);
            QCOMPARE(m_window->opacity(), 1.0);
            QCOMPARE(QSizeF(button->width(), button->height()), buttonSize);
            QCOMPARE(title->property("font").value<QFont>().pixelSize(), fontSize);
            qInfo("Live window transition: %lld size updates, %lld rendered frames",
                  qlonglong(widths.count()), qlonglong(frames.count()));
            QVERIFY2(widths.count() >= 4, "The real window and layout must resize through intermediate sizes");
            QVERIFY2(frames.count() >= 4, "The live layout must be rendered throughout the transition");
            m_window->grabWindow().save(QCoreApplication::applicationDirPath()
                                      + (expected == QWindow::Maximized ? "/window-maximize-live.png" : "/window-restore-live.png"));
        }
        QCOMPARE(m_window->geometry(), normalGeometry);

        QVERIFY(QMetaObject::invokeMethod(m_window, "toggleMaximized"));
        QTRY_VERIFY(m_window->width() > normalGeometry.width());
        const QRect reverseFrom = m_window->geometry();
        QVERIFY(QMetaObject::invokeMethod(m_window, "toggleMaximized"));
        QCOMPARE(m_window->geometry(), reverseFrom);
        QTRY_VERIFY(!controller->transitioning());
        QCOMPARE(m_window->visibility(), QWindow::Windowed);
        QCOMPARE(m_window->geometry(), normalGeometry);

        QVERIFY(QMetaObject::invokeMethod(m_window, "toggleMaximized"));
        QTRY_VERIFY(m_window->width() > normalGeometry.width());
        QVERIFY(QMetaObject::invokeMethod(m_window, "minimize"));
        QTRY_COMPARE(m_window->visibility(), QWindow::Minimized);
        QVERIFY(!controller->transitioning());
        nativeRestore();
        QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
#ifdef Q_OS_WIN
        SendMessage(reinterpret_cast<HWND>(m_window->winId()), WM_SYSCOMMAND, SC_RESTORE, 0);
#else
        m_window->showNormal();
#endif
        QTRY_COMPARE(m_window->visibility(), QWindow::Windowed);
        QTRY_COMPARE(m_window->geometry(), normalGeometry);
#ifdef Q_OS_WIN
        QVERIFY(QMetaObject::invokeMethod(m_window, "toggleMaximized"));
        QTRY_VERIFY(m_window->width() > normalGeometry.width());
        SendMessage(reinterpret_cast<HWND>(m_window->winId()), WM_SYSCOMMAND, SC_MINIMIZE, 0);
        QTRY_COMPARE(m_window->visibility(), QWindow::Minimized);
        QTRY_VERIFY(!controller->transitioning());
        nativeRestore();
        QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
        m_window->showNormal();
        QTRY_COMPARE(m_window->geometry(), normalGeometry);
#endif
    }

    void maximizedMinimizeRestore()
    {
        const QRect normalGeometry = m_window->geometry();
        m_window->showMaximized();
        QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
        verifyMaximizedCoverage();
        const QRect maximizedGeometry = m_window->geometry();
        const QRect workArea = m_window->screen()->availableGeometry();
        QVERIFY((maximizedGeometry.topLeft() - workArea.topLeft()).manhattanLength() <= 2);
        QVERIFY((maximizedGeometry.bottomRight() - workArea.bottomRight()).manhattanLength() <= 2);
        const auto handle = m_window->winId();
        const auto flags = m_window->flags();
        for (int cycle = 0; cycle < 3; ++cycle) {
            // The same native minimize command is sent by the taskbar/system menu.
#ifdef Q_OS_WIN
            if (cycle == 1)
                SendMessage(reinterpret_cast<HWND>(handle), WM_SYSCOMMAND, SC_MINIMIZE, 0);
            else
#endif
                clickAt(m_window->width() - 90, 18);
            QTRY_COMPARE(m_window->visibility(), QWindow::Minimized);
#ifdef Q_OS_WIN
            WINDOWPLACEMENT placement = {};
            placement.length = sizeof(placement);
            QVERIFY(GetWindowPlacement(reinterpret_cast<HWND>(handle), &placement));
            QVERIFY2(placement.flags & WPF_RESTORETOMAXIMIZED,
                     "Windows must retain the maximized restore placement");
#endif
            QCOMPARE(m_window->property("margins").toInt(), 0);
            nativeRestore();
            QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
            QTRY_COMPARE(m_window->geometry(), maximizedGeometry);
            QCOMPARE(m_window->winId(), handle);
            QCOMPARE(m_window->flags(), flags);
        }
        m_window->showNormal();
        QTRY_COMPARE(m_window->geometry(), normalGeometry);
    }

    void maximizedClientStaysInsideNativeFrame()
    {
#ifdef Q_OS_WIN
        m_window->showMaximized();
        QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
        const HWND handle = reinterpret_cast<HWND>(m_window->winId());
        MONITORINFO monitor = {};
        monitor.cbSize = sizeof(monitor);
        QVERIFY(GetMonitorInfo(MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST), &monitor));
        const RECT &work = monitor.rcWork;
        // A transient maximize/DPI placement can be smaller than the work area.
        // Asking for a larger client hides the mismatch from WM_SIZE and clips
        // the rendered surface at the native window's right and bottom edges.
        const RECT proposed = {work.left, work.top, work.right - 8, work.bottom - 8};
        WINDOWPOS position = {};
        position.hwnd = handle;
        position.x = proposed.left;
        position.y = proposed.top;
        position.cx = proposed.right - proposed.left;
        position.cy = proposed.bottom - proposed.top;
        NCCALCSIZE_PARAMS calculation = {};
        calculation.rgrc[0] = proposed;
        calculation.rgrc[1] = work;
        calculation.rgrc[2] = work;
        calculation.lppos = &position;
        SendMessage(handle, WM_NCCALCSIZE, TRUE, reinterpret_cast<LPARAM>(&calculation));
        QCOMPARE(calculation.rgrc[0].left, proposed.left);
        QCOMPARE(calculation.rgrc[0].top, proposed.top);
        QCOMPARE(calculation.rgrc[0].right, proposed.right);
        QCOMPARE(calculation.rgrc[0].bottom, proposed.bottom);
        verifyMaximizedCoverage();
#endif
    }

    void normalMinimizeRestore()
    {
        const QRect geometry = m_window->geometry();
        const int margin = m_window->property("margins").toInt();
        clickAt(m_window->width() - margin - 78, margin + 18);
        QTRY_COMPARE(m_window->visibility(), QWindow::Minimized);
        nativeRestore();
        QTRY_COMPARE(m_window->visibility(), QWindow::Windowed);
        QTRY_COMPARE(m_window->geometry(), geometry);
    }

    void transparencyAndNativeMove()
    {
        verifyTransparentFrame();
        verifyNativeMove();
    }

    void dragToTopSnapsNatively()
    {
#ifdef Q_OS_WIN
        BOOL arranging = FALSE;
        if (!SystemParametersInfo(SPI_GETWINARRANGING, 0, &arranging, 0) || !arranging)
            QSKIP("Window snapping is disabled in Windows settings");
        const QRect normal = m_window->geometry();
        m_window->raise();
        m_window->requestActivate();
        QTRY_VERIFY(m_window->isActive());
        const HWND handle = reinterpret_cast<HWND>(m_window->winId());
        MONITORINFO monitor = {};
        monitor.cbSize = sizeof(monitor);
        QVERIFY(GetMonitorInfo(MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST), &monitor));
        POINT originalCursor;
        QVERIFY(GetCursorPos(&originalCursor));
        POINT press = {};
        QVERIFY(ClientToScreen(handle, &press));
        const qreal scale = m_window->devicePixelRatio();
        const int margin = m_window->property("margins").toInt();
        press.x += qRound((margin + 200) * scale);
        press.y += qRound((margin + 18) * scale);
        const POINT target = {(monitor.rcWork.left + monitor.rcWork.right) / 2,
                              monitor.rcWork.top};
        auto *drag = QThread::create([=] {
            SetCursorPos(press.x, press.y);
            INPUT button = {};
            button.type = INPUT_MOUSE;
            button.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
            SendInput(1, &button, sizeof(button));
            QThread::msleep(150);
            for (int step = 1; step <= 30; ++step) {
                SetCursorPos(press.x + (target.x - press.x) * step / 30,
                             press.y + (target.y - press.y) * step / 30);
                QThread::msleep(20);
            }
            QThread::msleep(650);
            button.mi.dwFlags = MOUSEEVENTF_LEFTUP;
            SendInput(1, &button, sizeof(button));
            SetCursorPos(originalCursor.x, originalCursor.y);
        });
        drag->start();
        QTRY_VERIFY_WITH_TIMEOUT(drag->isFinished(), 5000);
        drag->wait();
        delete drag;
        QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
        m_window->showNormal();
        QTRY_COMPARE(m_window->geometry(), normal);
#endif
    }

    void snappedWindowHasNoShadowMargins()
    {
#ifdef Q_OS_WIN
        BOOL arranging = FALSE;
        if (!SystemParametersInfo(SPI_GETWINARRANGING, 0, &arranging, 0) || !arranging)
            QSKIP("Window snapping is disabled in Windows settings");
        const QRect normal = m_window->geometry();
        const qreal normalMargin = m_window->property("margins").toReal();
        const qreal normalRadius = m_window->property("frameRadius").toReal();
        QVERIFY(normalMargin > 0);
        m_window->raise();
        m_window->requestActivate();
        QTRY_VERIFY(m_window->isActive());
        INPUT keys[4] = {};
        for (auto &key : keys) key.type = INPUT_KEYBOARD;
        keys[0].ki.wVk = VK_LWIN;
        keys[1].ki.wVk = VK_LEFT;
        keys[1].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;
        keys[2].ki.wVk = VK_LEFT;
        keys[2].ki.dwFlags = KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP;
        keys[3].ki.wVk = VK_LWIN;
        keys[3].ki.dwFlags = KEYEVENTF_KEYUP;
        QCOMPARE(SendInput(4, keys, sizeof(INPUT)), UINT(4));
        QTRY_VERIFY(m_window->property("snapped").toBool());
        QCOMPARE(m_window->visibility(), QWindow::Windowed);
        QCOMPARE(m_window->property("margins").toReal(), 0.0);
        QCOMPARE(m_window->property("frameRadius").toReal(), 0.0);
        QCOMPARE(m_window->property("surfaceWidth").toInt(), m_window->width());
        QCOMPARE(m_window->property("surfaceHeight").toInt(), m_window->height());
        QTest::qWait(200);
        const QImage snapped = m_window->grabWindow();
        QVERIFY(!snapped.isNull());
        QVERIFY(snapped.pixelColor(2, snapped.height() / 2).alpha() > 250);
        QVERIFY(snapped.pixelColor(snapped.width() - 3, snapped.height() / 2).alpha() > 250);
        const HWND handle = reinterpret_cast<HWND>(m_window->winId());
        SendMessage(handle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
        QTRY_COMPARE(m_window->visibility(), QWindow::Minimized);
        QVERIFY(m_window->property("snapped").toBool());
        nativeRestore();
        QTRY_COMPARE(m_window->visibility(), QWindow::Windowed);
        QTRY_VERIFY(m_window->property("snapped").toBool());
        SendMessage(handle, WM_SYSCOMMAND, SC_RESTORE, 0);
        QTRY_VERIFY(!m_window->property("snapped").toBool());
        QTRY_COMPARE(m_window->property("margins").toReal(), normalMargin);
        QCOMPARE(m_window->property("frameRadius").toReal(), normalRadius);
        QTRY_COMPARE(m_window->geometry(), normal);
        // Merely moving a free window against an edge must retain its shadow.
        m_window->setPosition(m_window->screen()->availableGeometry().topLeft());
        QTest::qWait(100);
        QVERIFY(!m_window->property("snapped").toBool());
        QCOMPARE(m_window->property("margins").toReal(), normalMargin);
        m_window->setGeometry(normal);
#endif
    }

    void resizeBorderAndFullScreen()
    {
        auto *border = m_window->findChild<QQuickItem *>("windowResizeBorder");
        QVERIFY(border);
        QVERIFY(border->isVisible());
        QVERIFY(border->isEnabled());
        // Each corner must win hit testing over both adjacent edges.
        const QList<QPair<QPointF, QString>> corners = {
            {{2, 2}, "windowResizeTopLeft"},
            {{border->width() - 2, 2}, "windowResizeTopRight"},
            {{2, border->height() - 2}, "windowResizeBottomLeft"},
            {{border->width() - 2, border->height() - 2}, "windowResizeBottomRight"}
        };
        for (const auto &corner : corners) {
            auto *hit = border->childAt(corner.first.x(), corner.first.y());
            QVERIFY(hit);
            QCOMPARE(hit->objectName(), corner.second);
        }
        m_window->showMaximized();
        QTRY_COMPARE(m_window->visibility(), QWindow::Maximized);
        QVERIFY(!border->isVisible());
        QVERIFY(!border->isEnabled());
        m_window->showFullScreen();
        QTRY_COMPARE(m_window->visibility(), QWindow::FullScreen);
        QCOMPARE(m_window->property("margins").toInt(), 0);
        QVERIFY(!border->isVisible());
        QVERIFY(!border->isEnabled());
    }
};

int runWindowFrameTests(QQmlApplicationEngine &engine)
{
    QTemporaryDir directory;
    if (!directory.isValid())
        return 1;
    QFile settings(directory.filePath(QStringLiteral("settings.json")));
    if (!settings.open(QIODevice::WriteOnly))
        return 1;
    settings.write("{\"initializationCompleted\":true}");
    settings.close();
    engine.rootContext()->setContextProperty("APP_DIRPATH", directory.path());
    engine.loadFromModule("xcshop", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!window)
        return 1;
    // Keep timing checks independent of the user's saved animation speed.
    if (auto *global = engine.singletonInstance<QObject *>("xcshop", "Global"))
        global->setProperty("animationSpeed", 1.0);
    WindowFrameTests tests(window);
    // Keep the application-specific switch out of Qt Test's arguments.
    QStringList arguments = QCoreApplication::arguments();
    arguments.removeAll(QStringLiteral("--window-frame-tests"));
    arguments[0] = QStringLiteral("window_frame_tests");
    return QTest::qExec(&tests, arguments);
}

#include "WindowFrameTests.moc"
