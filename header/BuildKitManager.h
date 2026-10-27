#pragma once

#include <QObject>
#include <QVariantList>

// A catalog of templates in one builder-compatible kits/ root. Never executes kit scripts.
class BuildKitManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString kitsPath READ kitsPath WRITE setKitsPath NOTIFY kitsPathChanged)
    Q_PROPERTY(QString defaultKitsPath READ defaultKitsPath CONSTANT)
    Q_PROPERTY(QString preferredTemplateId READ preferredTemplateId WRITE setPreferredTemplateId NOTIFY preferredTemplateIdChanged)
    Q_PROPERTY(QVariantList templates READ templates NOTIFY catalogChanged)
    Q_PROPERTY(QStringList issues READ issues NOTIFY catalogChanged)
    Q_PROPERTY(bool identityValid READ identityValid NOTIFY catalogChanged)
    Q_PROPERTY(bool busy READ busy WRITE setBusy NOTIFY busyChanged)
    Q_PROPERTY(int dataVersion READ dataVersion CONSTANT)
public:
    explicit BuildKitManager(QObject *parent = nullptr);
    QString kitsPath() const { return m_kitsPath; }
    QString defaultKitsPath() const;
    void setKitsPath(const QString &path);
    QString preferredTemplateId() const { return m_preferredTemplateId; }
    void setPreferredTemplateId(const QString &id);
    QVariantList templates() const { return m_templates; }
    QStringList issues() const { return m_issues; }
    bool identityValid() const { return m_identityValid; }
    bool busy() const { return m_busy; }
    void setBusy(bool value);
    int dataVersion() const { return 0; } // 操作组工作区格式。
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QVariantMap findTemplate(const QString &id) const;
    Q_INVOKABLE QVariantList options(int requiredDataVersion = 0) const;
    // -1 unsupported, 0 explicitly supported, 1 newer and only tentatively supported.
    Q_INVOKABLE int versionSupport(const QString &id, const QString &version) const;
    Q_INVOKABLE QString importKit(const QString &sourceRoot);
    // Removes only the template descriptor, preserving potentially shared dependencies.
    Q_INVOKABLE QString removeTemplate(const QString &id);
    Q_INVOKABLE QString localPath(const QString &path) const;
signals:
    void kitsPathChanged();
    void preferredTemplateIdChanged();
    void catalogChanged();
    void busyChanged();
private:
    QString m_kitsPath, m_preferredTemplateId;
    QVariantList m_templates;
    QStringList m_issues;
    bool m_identityValid = false, m_busy = false;
};
