#include "recorder.h"
#include <QElapsedTimer>
#include <QDir>
#include <QDateTime>
#include <QFileInfo>
#include <QVector>
#include <cstdio>
#include <cstring>
#include <cmath>

#ifdef HAS_ALSA
#include <alsa/asoundlib.h>
#endif

CaptureWorker::CaptureWorker(QObject *parent) : QObject(parent) {}
void CaptureWorker::setOutput(const QString &p) { m_out = p; }
void CaptureWorker::requestStop() { QMutexLocker l(&m_mutex); m_stop = true; }

void CaptureWorker::doCapture() {
#ifdef HAS_ALSA
    const char *pcmName = "8c48kmic";   // 设备原厂 asound.conf 定义的 8 麦命名 PCM
    snd_pcm_t *handle = nullptr;
    snd_pcm_hw_params_t *hw = nullptr;

    int rc = snd_pcm_open(&handle, pcmName, SND_PCM_STREAM_CAPTURE, 0);
    if (rc < 0) { emit error(QString("打开声卡 %1 失败: ").arg(pcmName) + snd_strerror(rc)); return; }

    snd_pcm_hw_params_alloca(&hw);
    snd_pcm_hw_params_any(handle, hw);
    snd_pcm_hw_params_set_access(handle, hw, SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(handle, hw, SND_PCM_FORMAT_S32_LE);
    unsigned channels = 8;
    snd_pcm_hw_params_set_channels(handle, hw, channels);
    unsigned rate = 48000;
    snd_pcm_hw_params_set_rate_near(handle, hw, &rate, 0);
    snd_pcm_uframes_t period = 1024;
    snd_pcm_hw_params_set_period_size_near(handle, hw, &period, 0);
    rc = snd_pcm_hw_params(handle, hw);
    if (rc < 0) { emit error(QString("设置参数失败: ") + snd_strerror(rc)); snd_pcm_close(handle); return; }
    snd_pcm_hw_params_get_period_size(hw, &period, 0);

    // 8 通道 × 32bit 缓冲
    QVector<int> buf(static_cast<int>(period) * static_cast<int>(channels));

    FILE *f = fopen(m_out.toUtf8().constData(), "wb");
    if (!f) { emit error("无法创建输出文件"); snd_pcm_close(handle); return; }

    // 先写 44 字节占位头，结束后再回填真实大小
    unsigned char hdr[44];
    memset(hdr, 0, sizeof(hdr));
    fwrite(hdr, 1, sizeof(hdr), f);

    QElapsedTimer t; t.start();
    qint64 lastLevel = 0, lastTick = 0;
    qint64 totalBytes = 0;
    bool stop = false;

    while (true) {
        { QMutexLocker l(&m_mutex); stop = m_stop; }
        if (stop) break;

        int n = snd_pcm_readi(handle, buf.data(), period);
        if (n < 0) {
            n = snd_pcm_recover(handle, n, 0);
            if (n < 0) { emit error("读取音频失败"); break; }
            continue;
        }
        if (static_cast<snd_pcm_uframes_t>(n) != period) snd_pcm_wait(handle, 100);

        // 计算峰值 -> 电平表(0..100)，用 sqrt 拉伸更直观
        int peak = 0;
        for (int i = 0; i < n * static_cast<int>(channels); ++i) {
            int v = buf[i]; if (v < 0) v = -v; if (v > peak) peak = v;
        }
        qint64 now = t.elapsed();
        if (now - lastLevel >= 100) {
            lastLevel = now;
            double r = static_cast<double>(peak) / 2147483647.0;
            int lvl = r > 0 ? static_cast<int>(std::sqrt(r) * 100.0) : 0;
            if (lvl < 0) lvl = 0; if (lvl > 100) lvl = 100;
            emit level(lvl);
        }
        if (now - lastTick >= 200) { lastTick = now; emit tick(static_cast<int>(now / 1000)); }

        fwrite(buf.data(), sizeof(int), static_cast<size_t>(n) * channels, f);
        totalBytes += static_cast<qint64>(n) * channels * sizeof(int);
    }

    // 回填 WAV 头
    fseek(f, 0, SEEK_SET);
    unsigned dataSize = static_cast<unsigned>(totalBytes);
    unsigned byteRate = rate * channels * 4;
    unsigned blockAlign = channels * 4;
    const char *RIFF = "RIFF"; const char *WAVE = "WAVE";
    const char *fmt = "fmt "; const char *data = "data";
    unsigned sub1 = 16; unsigned fmtCode = 1; unsigned bits = 32;
    fwrite(RIFF, 1, 4, f); unsigned le = 36 + dataSize; fwrite(&le, 4, 1, f);
    fwrite(WAVE, 1, 4, f);
    fwrite(fmt, 1, 4, f);  fwrite(&sub1, 4, 1, f);
    fwrite(&fmtCode, 2, 1, f);
    fwrite(&channels, 2, 1, f);
    fwrite(&rate, 4, 1, f);  fwrite(&byteRate, 4, 1, f);
    fwrite(&blockAlign, 2, 1, f);
    fwrite(&bits, 2, 1, f);
    fwrite(data, 1, 4, f); fwrite(&dataSize, 4, 1, f);
    fclose(f);
    snd_pcm_close(handle);
    emit finished(m_out);
#else
    Q_UNUSED(m_out);
    emit error("本构建未启用 ALSA：请在使用设备 Qt5 运行库 + ALSA 的 Linux 环境下编译运行。");
#endif
}

// ---------------- Recorder (QML 桥接) ----------------
Recorder::Recorder(QObject *parent) : QObject(parent) {}
Recorder::~Recorder() {
    if (m_worker) m_worker->requestStop();
    if (m_thread) { m_thread->quit(); m_thread->wait(3000); }
}

void Recorder::setStatus(const QString &s) { if (m_status != s) { m_status = s; emit statusChanged(); } }

void Recorder::start() {
    if (m_recording) return;
    QDir d("/userdata/e1_qt_rec");
    d.mkpath(".");
    QString ts = QDateTime::currentDateTime().toString("yyyy-MM-dd_hh-mm-ss");
    m_lastFile = d.filePath(ts + ".wav");

    m_thread = new QThread(this);
    m_worker = new CaptureWorker;
    m_worker->setOutput(m_lastFile);
    m_worker->moveToThread(m_thread);
    connect(m_thread, &QThread::started, m_worker, &CaptureWorker::doCapture);
    connect(m_worker, &CaptureWorker::finished, this, &Recorder::onFinished);
    connect(m_worker, &CaptureWorker::error, this, &Recorder::onError);
    connect(m_worker, &CaptureWorker::level, this, &Recorder::onLevel);
    connect(m_worker, &CaptureWorker::tick, this, &Recorder::onTick);
    connect(m_worker, &CaptureWorker::finished, m_thread, &QThread::quit);
    connect(m_thread, &QThread::finished, m_thread, &QThread::deleteLater);
    connect(m_thread, &QThread::finished, m_worker, &QObject::deleteLater);

    m_recording = true; m_elapsed = 0; m_level = 0;
    emit recordingChanged(); emit levelChanged(); emit elapsedChanged();
    setStatus("录音中…");
    m_thread->start();
}

void Recorder::stop() {
    if (!m_recording || !m_worker) return;
    m_worker->requestStop();
    setStatus("停止中…");
}

QStringList Recorder::recordings() const {
    QString dir = "/userdata/e1_qt_rec";
    QDir d(dir);
    QStringList r;
    for (const QFileInfo &fi : d.entryInfoList(QStringList() << "*.wav", QDir::Files, QDir::Time))
        r << fi.fileName();
    return r;
}

void Recorder::onLevel(int v) { if (m_level != v) { m_level = v; emit levelChanged(); } }
void Recorder::onTick(int s)  { if (m_elapsed != s) { m_elapsed = s; emit elapsedChanged(); } }
void Recorder::onError(const QString &e) { setStatus("错误: " + e); emit error(e); }
void Recorder::onFinished(const QString &f) {
    m_recording = false; m_level = 0;
    emit recordingChanged(); emit levelChanged();
    setStatus("已保存: " + QFileInfo(f).fileName());
}
