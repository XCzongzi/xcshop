#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>
#include <QLoggingCategory>
#include <QQmlContext>
#include <QQuickStyle>
#include "XCFile.h"
#include "BuildKitManager.h"
#include "BuildManager.h"
#include "UpdateChecker.h"
#include <QTimer>
#ifdef XCSHOP_UI_TESTS
#include "../tests/UiTestInput.h"
#include "../tests/UpdateFeedFixture.h"
#include <QDesktopServices>
#include <QTemporaryDir>
#include <QWindow>
#include <QFontDatabase>
#include <memory>
int runWindowFrameTests(QQmlApplicationEngine &engine);
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationVersion(QStringLiteral(XCSHOP_VERSION));
    // This application customizes control backgrounds; native Windows style does not support that.
    QQuickStyle::setStyle("Basic");
    BuildKitManager buildKits;
    BuildManager builder;
    UpdateChecker updates;
    UpdateChecker *activeUpdates = &updates;
#ifdef XCSHOP_UI_TESTS
    std::unique_ptr<QTemporaryDir> updateTestDirectory;
    std::unique_ptr<UpdateFeedFixture> updateFeed;
    std::unique_ptr<UpdateChecker> testUpdates;
    if (app.arguments().contains("--update-ui-smoke") || app.arguments().contains("--initialization-ui-smoke")) {
        updateTestDirectory = std::make_unique<QTemporaryDir>();
        updateFeed = std::make_unique<UpdateFeedFixture>();
        const auto initializationMode = qEnvironmentVariable("XCSHOP_INITIALIZATION_TEST_MODE");
        if (initializationMode == "current") updateFeed->setVersion(app.applicationVersion());
        if (initializationMode == "offline") updateFeed->stall = true;
        testUpdates = std::make_unique<UpdateChecker>(updateFeed->url(), updateTestDirectory->filePath("state.ini"), 300);
        activeUpdates = testUpdates.get();
        QDesktopServices::setUrlHandler("https", updateFeed.get(), "recordOpenedUrl");
    }
#endif
    QObject::connect(&builder, &BuildManager::runningChanged, &buildKits, &BuildKitManager::setBusy);
    QQmlApplicationEngine engine;


    //文件路径初始化
    QString appDir = QCoreApplication::applicationDirPath();    //取运行目录
    QString desktopDir = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);

    XCFile xcfile;
    xcfile.folder(appDir + "/projects");


    engine.rootContext()->setContextProperty("APP_DIRPATH", appDir);
    engine.rootContext()->setContextProperty("DESKTOP_DIRPATH", desktopDir);
    engine.rootContext()->setContextProperty("BuildKits", &buildKits);
    engine.rootContext()->setContextProperty("Builder", &builder);
    engine.rootContext()->setContextProperty("Updates", activeUpdates);
#ifdef XCSHOP_UI_TESTS
    if (updateFeed) engine.rootContext()->setContextProperty("UpdateFixture", updateFeed.get());
#endif


    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
#ifdef XCSHOP_UI_TESTS
    std::unique_ptr<QTemporaryDir> smokeDirectory;
    UiTestInput uiTestInput;
    engine.rootContext()->setContextProperty("UiInput", &uiTestInput);
    if (app.arguments().contains("--window-frame-tests"))
        return runWindowFrameTests(engine);
    if (app.arguments().contains("--initialization-ui-smoke") || app.arguments().contains("--update-ui-smoke") || app.arguments().contains("--ui-smoke") || app.arguments().contains("--minecraft-ui-smoke")
        || app.arguments().contains("--operations-ui-smoke") || app.arguments().contains("--shared-ui-smoke")
        || app.arguments().contains("--dropdown-ui-smoke") || app.arguments().contains("--light-theme-ui-smoke")
        || app.arguments().contains("--themed-icon-ui-smoke") || app.arguments().contains("--explorer-ui-smoke")
        || app.arguments().contains("--editor-fonts-ui-smoke")) {
#ifdef Q_OS_WIN
        // The offscreen platform does not enumerate Windows system fonts.
        for (const auto &name : {"msyh.ttc", "segoeui.ttf", "consola.ttf", "simsun.ttc"})
            QFontDatabase::addApplicationFont(qEnvironmentVariable("WINDIR", "C:/Windows") + "/Fonts/" + name);
#endif
        smokeDirectory = std::make_unique<QTemporaryDir>(appDir + "/ui-smoke-XXXXXX");
        engine.rootContext()->setContextProperty("SMOKE_DIR", smokeDirectory->path());
        engine.rootContext()->setContextProperty("SMOKE_OUTPUT_DIR", appDir);
        if (app.arguments().contains("--initialization-ui-smoke")) {
            engine.rootContext()->setContextProperty("APP_DIRPATH", smokeDirectory->path());
            engine.rootContext()->setContextProperty("INITIALIZATION_TEST_MODE", qEnvironmentVariable("XCSHOP_INITIALIZATION_TEST_MODE"));
            engine.load(QUrl("qrc:/tests/InitializationUiSmoke.qml"));
        } else if (app.arguments().contains("--update-ui-smoke")) {
            xcfile.writeAtomic(smokeDirectory->filePath("settings.json"), "{\"initializationCompleted\":true}");
            engine.rootContext()->setContextProperty("APP_DIRPATH", smokeDirectory->path());
            engine.load(QUrl("qrc:/tests/UpdateUiSmoke.qml"));
        } else if (app.arguments().contains("--editor-fonts-ui-smoke")) {
            engine.rootContext()->setContextProperty("APP_DIRPATH", smokeDirectory->path());
            engine.load(QUrl("qrc:/tests/EditorFontsUiSmoke.qml"));
        } else if (app.arguments().contains("--explorer-ui-smoke")) {
            engine.load(QUrl("qrc:/tests/ExplorerUiSmoke.qml"));
        } else if (app.arguments().contains("--themed-icon-ui-smoke")) {
            engine.load(QUrl("qrc:/tests/ThemedIconUiSmoke.qml"));
        } else if (app.arguments().contains("--light-theme-ui-smoke")) {
            const auto testFile = qEnvironmentVariable("XCSHOP_THEME_TEST_FILE");
            if (testFile.endsWith("WorkspaceTransitionUiSmoke.qml") || testFile.endsWith("AboutUiSmoke.qml")) {
                engine.rootContext()->setContextProperty("APP_DIRPATH", smokeDirectory->path());
                xcfile.writeAtomic(smokeDirectory->filePath("settings.json"), "{\"initializationCompleted\":true}");
            }
            engine.load(testFile.isEmpty() ? QUrl("qrc:/tests/LightThemeUiSmoke.qml")
                                          : QUrl::fromLocalFile(testFile));
        } else if (app.arguments().contains("--dropdown-ui-smoke")) {
            engine.load(QUrl("qrc:/tests/DropdownUiSmoke.qml"));
        } else if (app.arguments().contains("--shared-ui-smoke")) {
            engine.load(QUrl("qrc:/tests/SharedUiSmoke.qml"));
        } else if (app.arguments().contains("--operations-ui-smoke")) {
            engine.load(QUrl("qrc:/tests/OperationsUiSmoke.qml"));
        } else if (app.arguments().contains("--minecraft-ui-smoke")) {
            engine.rootContext()->setContextProperty("APP_DIRPATH", smokeDirectory->path());
            engine.load(QUrl("qrc:/tests/MinecraftItemsSmoke.qml"));
        } else engine.load(QUrl("qrc:/tests/EditorUiSmoke.qml"));
    } else
#endif
    engine.loadFromModule("xcshop", "Main");

    // Test entry points use isolated local fixtures instead of the public feed.
#ifdef XCSHOP_UI_TESTS
    if (app.arguments().size() == 1)
#endif
        if (!engine.rootObjects().isEmpty()
            && !engine.rootObjects().first()->property("initializing").toBool())
            QTimer::singleShot(1500, &updates, &UpdateChecker::check);

#ifdef XCSHOP_UI_TESTS
    if (app.arguments().contains("--startup-smoke")) {
        QTimer::singleShot(1500, &app, [&] {
            if (engine.rootObjects().isEmpty()) { app.exit(2); return; }
            auto *window = qobject_cast<QWindow *>(engine.rootObjects().first());
            if (!window) { app.exit(3); return; }
            qInfo("EDITOR_STARTUP_SMOKE_PASSED");
            window->close();
        });
    }
#endif

    


    return app.exec();
}
