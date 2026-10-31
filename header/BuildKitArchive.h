#pragma once

#include <QString>
#include <QUrl>
#include <atomic>
#include <functional>
#include <memory>

// ZIP/network details stay outside the template catalog and QML.
namespace BuildKitArchive {
using Cancellation = std::shared_ptr<std::atomic_bool>;
using Progress = std::function<void(int, const QString &)>;
// Throws std::runtime_error; all output belongs to the caller's temporary directory.
QString prepare(const QString &source, const QUrl &downloadUrl, const QString &staging,
                const Cancellation &cancel, const Progress &progress);
}
