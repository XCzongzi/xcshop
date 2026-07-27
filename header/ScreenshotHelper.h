#pragma once
#include <QObject>
#include <QImage>
#include <QQuickWindow>

class ScreenshotHelper : public QObject {
    Q_OBJECT
public:
    explicit ScreenshotHelper(QObject *parent = nullptr);
    
public slots:
    Q_INVOKABLE QImage captureWindow(QQuickWindow *window, const QRect &region);
};