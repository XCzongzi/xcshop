#pragma once

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QTextLayout>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QSyntaxHighlighter;

// Apply foreground colours to the editor's own layout. Never render a second
// copy of the text or change its contents, font or undo history.
class EditorHighlighter : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject *target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(QVariantList ranges READ ranges WRITE setRanges NOTIFY rangesChanged)
    Q_PROPERTY(bool highlightMacros READ highlightMacros WRITE setHighlightMacros NOTIFY highlightMacrosChanged)
    Q_PROPERTY(QColor macroColor READ macroColor WRITE setMacroColor NOTIFY macroColorChanged)
public:
    explicit EditorHighlighter(QObject *parent = nullptr);
    ~EditorHighlighter() override;
    QObject *target() const { return m_target; }
    void setTarget(QObject *target);
    QVariantList ranges() const { return m_ranges; }
    void setRanges(const QVariantList &ranges);
    bool highlightMacros() const { return m_highlightMacros; }
    void setHighlightMacros(bool enabled);
    QColor macroColor() const { return m_macroColor; }
    void setMacroColor(const QColor &color);
signals:
    void targetChanged();
    void rangesChanged();
    void highlightMacrosChanged();
    void macroColorChanged();
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
private slots:
    void scheduleApply();
private:
    void apply();
    QPointer<QObject> m_target;
    QVariantList m_ranges;
    QList<QMetaObject::Connection> m_connections;
    QList<QTextLayout::FormatRange> m_inputFormats;
    QPointer<QSyntaxHighlighter> m_documentHighlighter;
    QColor m_macroColor;
    bool m_highlightMacros = false;
    bool m_applyPending = false;
    bool m_pointerSelecting = false;
    int m_pointerAnchor = 0;
};
