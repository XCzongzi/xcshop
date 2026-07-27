#include "ScreenshotHelper.h"
#include <QPainter>

ScreenshotHelper::ScreenshotHelper(QObject *parent) : QObject(parent) {}

QImage ScreenshotHelper::captureWindow(QQuickWindow *window, const QRect &region) {
    if (!window) return QImage();
    
    QImage screenshot = window->grabWindow();
    if (region.isValid()) {
        return screenshot.copy(region);
    }
    return screenshot;
}