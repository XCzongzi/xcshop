#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QProcess>
#include <QTimer>
#include <QVariantMap>

// Application-lifetime asynchronous process owner. State survives changing QML pages.
class BuildManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString executablePath READ executablePath WRITE setExecutablePath NOTIFY executablePathChanged)
    Q_PROPERTY(QString defaultExecutablePath READ defaultExecutablePath CONSTANT)
    Q_PROPERTY(bool available READ available NOTIFY executablePathChanged)
    Q_PROPERTY(QString versionInfo READ versionInfo NOTIFY versionInfoChanged)
    Q_PROPERTY(QString displayVersionInfo READ displayVersionInfo NOTIFY versionInfoChanged)
    Q_PROPERTY(bool versionValid READ versionValid NOTIFY versionInfoChanged)
    Q_PROPERTY(bool queryingVersion READ queryingVersion NOTIFY versionInfoChanged)
    Q_PROPERTY(QString startupArguments READ startupArguments WRITE setStartupArguments NOTIFY startupArgumentsChanged)
    Q_PROPERTY(bool running READ running NOTIFY changed)
    Q_PROPERTY(QString projectPath READ projectPath NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString summary READ summary NOTIFY changed)
    Q_PROPERTY(QString outputPath READ outputPath NOTIFY changed)
    Q_PROPERTY(QString consoleText READ consoleText NOTIFY changed)
    Q_PROPERTY(qint64 elapsedMs READ elapsedMs NOTIFY changed)
    Q_PROPERTY(QVariantList problems READ problems NOTIFY changed)
    Q_PROPERTY(QVariantMap result READ result NOTIFY changed)
public:
    explicit BuildManager(QObject *parent = nullptr);
    ~BuildManager() override;
    QString executablePath() const { return m_executablePath; }
    void setExecutablePath(const QString &path);
    QString defaultExecutablePath() const;
    bool available() const;
    QString versionInfo() const { return m_versionInfo; }
    QString displayVersionInfo() const;
    bool versionValid() const;
    bool queryingVersion() const { return m_queryingVersion; }
    QString startupArguments() const { return m_startupArguments; }
    void setStartupArguments(const QString &arguments);
    bool running() const { return m_running; }
    QString projectPath() const { return m_projectPath; }
    QString state() const { return m_state; }
    QString summary() const { return m_summary; }
    QString outputPath() const { return m_outputPath; }
    QString consoleText() const { return m_console; }
    qint64 elapsedMs() const { return m_running && m_clock.isValid() ? m_clock.elapsed() : m_elapsed; }
    QVariantList problems() const { return m_problems; }
    QVariantMap result() const { return m_result; }
    Q_INVOKABLE bool start(const QString &project, const QString &kits);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void recheckExecutable();
    Q_INVOKABLE void fetchVersion();
    Q_INVOKABLE void restoreVersionInfo(const QString &path, const QString &info);
    Q_INVOKABLE QString resolveOutputPath(const QString &project, const QString &parentPath,
                                         const QString &folderName) const;
signals:
    void versionInfoChanged();
    void versionInfoFetched();
    void startupArgumentsChanged();
    void executablePathChanged();
    void changed();
    void runningChanged(bool running);
    void completed(bool success);
private:
    QProcess m_process;
    QProcess m_versionProcess;
    QTimer m_versionTimer;
    QByteArray m_versionOutput;
    QString m_versionInfo, m_startupArguments;
    bool m_queryingVersion = false;
    QTimer m_tick, m_killTimer;
    QElapsedTimer m_clock;
    QString m_executablePath, m_projectPath, m_state = "未构建", m_summary, m_outputPath, m_console;
    QByteArray m_stdout, m_stderr;
    QVariantList m_problems;
    QVariantMap m_result;
    qint64 m_elapsed = 0;
    bool m_running = false, m_cancelled = false, m_receivedResult = false;
    bool m_discardStdout = false, m_discardStderr = false;
    QString m_protocolError;
    void readChannel(bool standardError, bool flush = false);
    void line(const QByteArray &bytes, bool standardError);
    void appendLog(const QString &text);
    void integrationError(const QString &reason, const QString &solution);
    void finish(int exitCode, QProcess::ExitStatus status);
    void setRunning(bool value);
};
