#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml>

// Maps a Minecraft storage-container choice to one of the container-screen
// assets bundled with the application.
class ContainerCatalog : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    // The two lists keep block inventories and entity inventories distinct.
    // Their boolean parameters are the independent visibility controls used
    // by the in-workspace container selector.
    Q_INVOKABLE QVariantList blockContainers(bool includeLargeChests) const;
    Q_INVOKABLE QVariantList entityContainers(bool includeEntities) const;
    Q_INVOKABLE int interfaceForContainer(const QString &containerId) const;
};
