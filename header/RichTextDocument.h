#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QTextCursor;
class QTextDocument;

// Bridge the editor's native document and Minecraft components. Formatting is
// applied to its cursor, so IME, selections and undo use the same text control.
class RichTextDocument : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject *target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(QVariantMap currentStyle READ currentStyle NOTIFY currentStyleChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool singleLine READ singleLine WRITE setSingleLine NOTIFY singleLineChanged)
public:
    using QObject::QObject;
    QObject *target() const { return m_target; }
    void setTarget(QObject *target);
    QVariantMap currentStyle() const;
    QString error() const { return m_error; }
    bool singleLine() const { return m_singleLine; }
    void setSingleLine(bool singleLine);
    Q_INVOKABLE void load(const QString &source);
    Q_INVOKABLE QString serialize() const;
    Q_INVOKABLE void apply(const QString &property, const QVariant &value);
    Q_INVOKABLE void resetStyle();
signals:
    void targetChanged();
    void currentStyleChanged();
    void errorChanged();
    void singleLineChanged();
    void edited();
private:
    QTextCursor *cursor() const;
    QTextDocument *document() const;
    bool normalizeSingleLine();
    QPointer<QObject> m_target;
    QString m_error;
    QString m_source;
    bool m_loading = false;
    bool m_singleLine = false;
    bool m_normalizing = false;
};
