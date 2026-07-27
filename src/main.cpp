#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>
#include <QLoggingCategory>
#include <QQmlContext>
#include "XCFile.h"
#include "ScreenshotHelper.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;


    //文件路径初始化
    QString appDir = QCoreApplication::applicationDirPath();    //取运行目录
    QString desktopDir = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);

    XCFile xcfile;
    xcfile.folder(appDir + "/templates");
    xcfile.folder(appDir + "/projects");
    //delete &xcfile;


    engine.rootContext()->setContextProperty("APP_DIRPATH", appDir);
    engine.rootContext()->setContextProperty("DESKTOP_DIRPATH", desktopDir);


    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("xcshop", "Main");

    


    return app.exec();
}
