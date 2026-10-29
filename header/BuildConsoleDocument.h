#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QTextDocument>
#include <QtQml/qqmlregistration.h>

// Programmatic inserts in a read-only TextArea still create undo commands.
// Build output never needs those commands or the old log strings they retain.
class BuildConsoleDocument : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
public:
    explicit BuildConsoleDocument(QObject *parent = nullptr) : QObject(parent) {}
    QQuickTextDocument *document() const { return m_document.data(); }
    void setDocument(QQuickTextDocument *document) {
        if (m_document == document) return;
        m_document = document;
        if (document && document->textDocument())
            document->textDocument()->setUndoRedoEnabled(false);
        emit documentChanged();
    }
signals:
    void documentChanged();
private:
    QPointer<QQuickTextDocument> m_document;
};
