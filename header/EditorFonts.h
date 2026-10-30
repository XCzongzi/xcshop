#pragma once

#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QObject>
#include <QQmlEngine>

class EditorFonts : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QStringList chineseFamilies READ chineseFamilies CONSTANT)
    Q_PROPERTY(QStringList latinFamilies READ latinFamilies CONSTANT)

public:
    using QObject::QObject;

    QStringList chineseFamilies() const
    {
        return QFontDatabase::families(QFontDatabase::SimplifiedChinese);
    }

    QStringList latinFamilies() const
    {
        auto families = QFontDatabase::families(QFontDatabase::Latin);
        // A Latin font with Han glyphs would take priority over the Chinese font.
        const auto chinese = QFontDatabase::families(QFontDatabase::Any);
        for (const auto &family : chinese) {
            const auto systems = QFontDatabase::writingSystems(family);
            if (systems.contains(QFontDatabase::SimplifiedChinese)
                    || systems.contains(QFontDatabase::TraditionalChinese)
                    || systems.contains(QFontDatabase::Japanese))
                families.removeAll(family);
        }
        return families;
    }

    Q_INVOKABLE QFont mixedFont(const QString &chinese, const QString &latin, int pixelSize) const
    {
        // Qt caches merged font engines by the primary family. Register the Han
        // fallback too, so changing only the Chinese family invalidates that
        // cache and updates controls which already rendered Chinese text.
        const QStringList fallback{chinese};
        if (QFontDatabase::applicationFallbackFontFamilies(QChar::Script_Han) != fallback) {
            QFontDatabase::setApplicationFallbackFontFamilies(QChar::Script_Han, fallback);
            // Unlike addApplicationFont(), changing fallbacks does not emit
            // this signal. Notify Qt Quick so existing glyph caches refresh.
            QMetaObject::invokeMethod(qGuiApp, "fontDatabaseChanged", Qt::QueuedConnection);
        }
        QFont font;
        // QML's font.family exposes only one family. Keep the ordered fallback
        // list in a QFont so editing, selection and IME use the same text layout.
        font.setFamilies({latin, chinese});
        font.setPixelSize(pixelSize);
        return font;
    }
};
