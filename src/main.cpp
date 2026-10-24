#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>
#include <QLoggingCategory>
#include <QQmlContext>
#include <QQuickStyle>
#include "XCFile.h"
#include "BuildKitManager.h"
#include "BuildManager.h"
#ifdef XCSHOP_UI_TESTS
#include <QTemporaryDir>
#include <QWindow>
#include <QFontDatabase>
#include <memory>
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    // This application customizes control backgrounds; native Windows style does not support that.
    QQuickStyle::setStyle("Basic");
    BuildKitManager buildKits;
    BuildManager builder;
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


    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
#ifdef XCSHOP_UI_TESTS
    std::unique_ptr<QTemporaryDir> smokeDirectory;
    if (app.arguments().contains("--ui-smoke") || app.arguments().contains("--minecraft-ui-smoke")
        || app.arguments().contains("--operations-ui-smoke")) {
#ifdef Q_OS_WIN
        // The offscreen platform does not enumerate Windows system fonts.
        for (const auto &name : {"msyh.ttc", "segoeui.ttf", "consola.ttf"})
            QFontDatabase::addApplicationFont(qEnvironmentVariable("WINDIR", "C:/Windows") + "/Fonts/" + name);
#endif
        smokeDirectory = std::make_unique<QTemporaryDir>(appDir + "/ui-smoke-XXXXXX");
        engine.rootContext()->setContextProperty("SMOKE_DIR", smokeDirectory->path());
        engine.rootContext()->setContextProperty("SMOKE_OUTPUT_DIR", appDir);
        if (app.arguments().contains("--operations-ui-smoke")) {
            engine.load(QUrl("qrc:/tests/OperationsUiSmoke.qml"));
        } else if (app.arguments().contains("--minecraft-ui-smoke")) {
            engine.rootContext()->setContextProperty("APP_DIRPATH", smokeDirectory->path());
            engine.load(QUrl("qrc:/tests/MinecraftItemsSmoke.qml"));
        } else engine.load(QUrl("qrc:/tests/EditorUiSmoke.qml"));
    } else
#endif
    engine.loadFromModule("xcshop", "Main");

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
