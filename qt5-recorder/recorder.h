#pragma once
#include <QObject>
#include <QThread>
#include <QString>
#include <QMutex>

// 在设备端（Linux + ALSA）的线程里执行 8 麦采集；在缺 ALSA 的平台（如 Windows 测试编译）会给出提示。
class CaptureWorker : public QObject {
    Q_OBJECT
public:
    explicit CaptureWorker(QObject *parent = nullptr);
    void setOutput(const QString &path);
public slots:
    void doCapture();
    void requestStop();
signals:
    void level(int);      // 0..100 电平表
    void error(const QString &);
    void finished(const QString &); // 产出文件路径
    void tick(int);       // 已录制秒数
private:
    QString m_out;
    bool m_stop = false;
    QMutex m_mutex;
};

class Recorder : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(int elapsed   READ elapsed   NOTIFY elapsedChanged)
    Q_PROPERTY(int level     READ level     NOTIFY levelChanged)
    Q_PROPERTY(QString status READ status   NOTIFY statusChanged)
public:
    explicit Recorder(QObject *parent = nullptr);
    ~Recorder();
    bool recording() const { return m_recording; }
    int elapsed()   const { return m_elapsed; }
    int level()     const { return m_level; }
    QString status() const { return m_status; }

    Q_INVOKABLE QStringList recordings() const;
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
signals:
    void recordingChanged();
    void elapsedChanged();
    void levelChanged();
    void statusChanged();
    void error(const QString &);
private slots:
    void onLevel(int);
    void onError(const QString &);
    void onFinished(const QString &);
    void onTick(int);
private:
    void setStatus(const QString &s);
    QThread *m_thread = nullptr;
    CaptureWorker *m_worker = nullptr;
    bool m_recording = false;
    int m_elapsed = 0;
    int m_level = 0;
    QString m_status = "就绪";
    QString m_lastFile;
};
