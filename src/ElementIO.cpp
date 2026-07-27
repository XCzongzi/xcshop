#include "ElementIO.h"
#include <regex>

QFile file;

QString elementPath = "";



ElementIO::ElementIO(){

}

ElementIO::~ElementIO(){
    file.close();
}

bool ElementIO::open(const QString& filePath){
    elementPath = filePath;
    file.setFileName(filePath);
    if (file.open(QIODevice::ReadWrite | QIODevice::Text))return true;
    return false;
}
void ElementIO::close(const QString& filePath){
    file.close();
}

void ElementIO::write(const QString& content){
    // 先清空文件内容再写入
    file.seek(0);       // 移动到文件开头
    file.resize(0);     // 清空文件内容

    QTextStream out(&file);
    out << content;
    out.flush();
}

QString ElementIO::read(){
    file.seek(0);
    QTextStream in(&file);
    return in.readAll();
}