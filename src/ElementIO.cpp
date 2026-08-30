#include "ElementIO.h"
#include <QFile>
#include <QSaveFile>

ElementIO::ElementIO() = default;

bool ElementIO::open(const QString& filePath){
    m_filePath = filePath;

    QFile input(m_filePath);
    return input.open(QIODevice::ReadOnly | QIODevice::Text);
}

void ElementIO::close(){
    m_filePath.clear();
}

bool ElementIO::write(const QString& content){
    if (m_filePath.isEmpty())
        return false;

    QSaveFile output(m_filePath);
    if (!output.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;

    const QByteArray encoded = content.toUtf8();
    if (output.write(encoded) != encoded.size()) {
        output.cancelWriting();
        return false;
    }

    return output.commit();
}

QString ElementIO::read(){
    if (m_filePath.isEmpty())
        return "";

    QFile input(m_filePath);
    if (!input.open(QIODevice::ReadOnly | QIODevice::Text))
        return "";

    return QString::fromUtf8(input.readAll());
}
