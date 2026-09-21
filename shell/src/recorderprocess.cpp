#include "recorderprocess.h"
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <signal.h>

RecorderProcess::RecorderProcess(QObject *parent) : QObject(parent)
{
    for (QProcess *p : {&m_rec, &m_conv}) {
        p->setProcessChannelMode(QProcess::MergedChannels);
        p->setStandardOutputFile(QProcess::nullDevice());                // gsr prints a line every second
        connect(p, &QProcess::stateChanged, this, &RecorderProcess::runningChanged);
    }
    connect(&m_rec, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) { if (e == QProcess::FailedToStart) Q_EMIT finished(-2); });
    connect(&m_rec, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
        if (!QFileInfo::exists(m_master) || QFileInfo(m_master).size() < 1024) { QFile::remove(m_master); Q_EMIT finished(code ? code : 1); return; }
        if (!m_hdr) { Q_EMIT finished(0); return; }                      // SDR: the recording already is the final file
        m_triedGpu = true; convert(true);
    });
    connect(&m_conv, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        const bool ok = status == QProcess::NormalExit && code == 0 && QFileInfo(m_file).size() > 1024;
        if (!ok && m_triedGpu) { m_triedGpu = false; QFile::remove(m_file); convert(false); return; }   // CPU path as the fallback
        if (ok) QFile::remove(m_master); else qWarning("recording: tonemapping failed, the HDR master is kept: %s", qPrintable(m_master));
        Q_EMIT finished(ok ? 0 : 5);
    });
}

RecorderProcess::~RecorderProcess()
{
    if (m_rec.state() != QProcess::NotRunning) { ::kill(pid_t(m_rec.processId()), SIGINT); if (!m_rec.waitForFinished(4000)) m_rec.kill(); }
}

bool RecorderProcess::hdrOn()
{
    QProcess p; p.start(QStringLiteral("kscreen-doctor"), {QStringLiteral("-o")});
    if (!p.waitForFinished(1500)) return false;
    const QByteArray out = p.readAllStandardOutput();
    const int i = out.indexOf("HDR:");
    return i >= 0 && out.mid(i, 40).contains("enabled");
}

bool RecorderProcess::start(int x, int y, int w, int h, const QString &file, bool sound)
{
    if (running()) return false;
    if (QStandardPaths::findExecutable(QStringLiteral("gpu-screen-recorder")).isEmpty()) { Q_EMIT finished(-2); return false; }
    m_file = file; m_hdr = hdrOn(); m_width = w;
    // the HDR master sits next to the final file under a hidden name until it has been converted
    m_master = m_hdr ? QFileInfo(file).absolutePath() + QStringLiteral("/.") + QFileInfo(file).completeBaseName() + QStringLiteral(".hdr.mkv") : file;
    QStringList args{QStringLiteral("-w"), QStringLiteral("region"), QStringLiteral("-region"), QStringLiteral("%1x%2+%3+%4").arg(w).arg(h).arg(x).arg(y),
                     QStringLiteral("-f"), QStringLiteral("60"), QStringLiteral("-fm"), QStringLiteral("cfr"), QStringLiteral("-q"), QStringLiteral("very_high"),
                     QStringLiteral("-k"), m_hdr ? QStringLiteral("hevc_hdr") : (w <= 4096 ? QStringLiteral("h264") : QStringLiteral("hevc")), QStringLiteral("-cursor"), QStringLiteral("yes")};
    if (sound) args << QStringLiteral("-a") << QStringLiteral("default_output");
    args << QStringLiteral("-o") << m_master;
    m_rec.start(QStringLiteral("gpu-screen-recorder"), args);
    return true;
}

void RecorderProcess::stop()
{
    if (m_rec.state() != QProcess::NotRunning) ::kill(pid_t(m_rec.processId()), SIGINT);   // gsr finishes the file on SIGINT
}

void RecorderProcess::convert(bool gpu)
{
    // same two tonemapping chains as the Vice fork uses on this machine (BT.2390 on the GPU through libplacebo; hable on the CPU)
    QStringList a{QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"), QStringLiteral("error"), QStringLiteral("-y")};
    if (gpu) a << QStringLiteral("-init_hw_device") << QStringLiteral("vulkan=vk:0") << QStringLiteral("-filter_hw_device") << QStringLiteral("vk");
    a << QStringLiteral("-i") << m_master << QStringLiteral("-vf")
      << (gpu ? QStringLiteral("format=p010,hwupload,libplacebo=tonemapping=bt.2390:colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv:format=yuv420p,hwdownload,format=yuv420p")
              : QStringLiteral("zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"))
      ;
    // NVENC's H.264 stops at 4096 px wide; the full 5120-wide screen goes through x264 (slower, same quality target)
    if (m_width <= 4096) a << QStringLiteral("-c:v") << QStringLiteral("h264_nvenc") << QStringLiteral("-preset") << QStringLiteral("p6") << QStringLiteral("-cq") << QStringLiteral("19");
    else a << QStringLiteral("-c:v") << QStringLiteral("libx264") << QStringLiteral("-preset") << QStringLiteral("fast") << QStringLiteral("-crf") << QStringLiteral("18");
    a
      << QStringLiteral("-pix_fmt") << QStringLiteral("yuv420p") << QStringLiteral("-c:a") << QStringLiteral("aac") << QStringLiteral("-b:a") << QStringLiteral("192k")
      << QStringLiteral("-movflags") << QStringLiteral("+faststart") << m_file;
    m_conv.start(QStringLiteral("ffmpeg"), a);
}
