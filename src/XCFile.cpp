#include "XCFile.h"
#include <regex>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

XCFile::XCFile(){

}


bool XCFile::write(const QString& filePath,const QString& content){
    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)){
        QTextStream out(&file);
        out << content;
        file.close();
        return true;
    }else{
        return false;
    }
    return false;
}

QString XCFile::read(const QString& filePath){
    QFile file(filePath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)){
        QTextStream in(&file);
        QString content = in.readAll();
        file.close();
        return content;
    }else{
        return "";
    }
    return "";
}

bool XCFile::exists(const QString& filePath){
    QFileInfo info(filePath);
    return info.exists() && info.isFile();
}

bool XCFile::folder(const QString& folderPath){
    QDir dir(folderPath);
    if (!dir.exists()){
        return dir.mkpath(folderPath);
    }
    return true;
}


bool XCFile::rename(const QString& oldPath, const QString& newPath){
    return QFile::rename(oldPath, newPath);
}

bool XCFile::copy(const QString& sourcePath, const QString& destinationPath){
    const QUrl sourceUrl(sourcePath);
    const QString localSource = sourceUrl.isLocalFile() ? sourceUrl.toLocalFile() : sourcePath;
    QFileInfo destinationInfo(destinationPath);
    if (!QDir().mkpath(destinationInfo.absolutePath()))
        return false;
    if (QFile::exists(destinationPath) && !QFile::remove(destinationPath))
        return false;
    return QFile::copy(localSource, destinationPath);
}

bool XCFile::remove_file(const QString& filePath){
    return QFile::remove(filePath);
}

bool XCFile::remove_folder(const QString& folderPath){return 0;}

bool XCFile::clone(const QString& filePath){
    QString prefix = filePath.section('.', 0, -2);  //把文件名跟后缀分开，以便于为克隆的文件编号（用 -0这样的数字编号）
    QString suffix = filePath.section('.', -1);

    std::regex pattern("^[0-9]*$");  //检测如果分离后的文件名有被编号，就把编号去掉，回归编号前的文件名，以防止二次编号（选择编号后的文件复制时）
    if(std::regex_match(prefix.section(" -",-1).toStdString(),pattern)){
        prefix = prefix.section(" -", 0, -2);
    }
    prefix += " -";//为文件名加上编号的前缀
    for(int i = 1; true; i++){
        if(!QFile::exists(prefix + QString::number(i) + "." + suffix)){
            return QFile::copy(filePath, prefix + QString::number(i) + "." + suffix);
        }
    }
    
    
}

QString XCFile::appDataPath(){
    const QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(path);
    return path;
}
