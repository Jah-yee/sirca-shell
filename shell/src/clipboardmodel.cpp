#include "clipboardmodel.h"
#include <KSystemClipboard>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeData>
#include <QStandardPaths>
#include <QUrl>

QString ClipboardModel::dir() { return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/sirca-shell/clipboard"); }

ClipboardModel::ClipboardModel(QObject *parent) : QAbstractListModel(parent)
{
    QDir().mkpath(dir());
    QFile::setPermissions(dir(), QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);      // what you copy is nobody else's business
    load();
    m_saveLater.setSingleShot(true); m_saveLater.setInterval(800);
    connect(&m_saveLater, &QTimer::timeout, this, &ClipboardModel::save);
    m_restoreLater.setSingleShot(true); m_restoreLater.setInterval(250);
    connect(&m_restoreLater, &QTimer::timeout, this, &ClipboardModel::restoreIfEmpty);
    if (auto *c = KSystemClipboard::instance())
        connect(c, &KSystemClipboard::changed, this, [this](QClipboard::Mode mode) { if (mode == QClipboard::Clipboard) onClipboardChanged(); });
    refilter();
}

QHash<int, QByteArray> ClipboardModel::roleNames() const
{
    return {{KindRole, "kind"}, {TextRole, "text"}, {PreviewRole, "preview"}, {ImageRole, "image"}, {TimeRole, "time"}, {SizeRole, "note"}, {PinnedRole, "pinned"}};
}

QVariant ClipboardModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) return {};
    const Entry &e = m_entries.at(m_rows.at(index.row()));
    switch (role) {
    case KindRole: return e.kind;
    case TextRole: return e.text;
    case PreviewRole: return e.text.left(400).simplified();
    case ImageRole: return e.imagePath.isEmpty() ? QString() : QStringLiteral("file://") + e.imagePath;
    case TimeRole: return e.time;
    case SizeRole: return e.note;
    case PinnedRole: return e.pinned;
    }
    return {};
}

void ClipboardModel::onClipboardChanged()
{
    auto *c = KSystemClipboard::instance();
    const QMimeData *m = c ? c->mimeData(QClipboard::Clipboard) : nullptr;
    const bool empty = !m || m->formats().isEmpty();
    if (empty) { if (!m_settingOurselves) m_restoreLater.start(); return; }      // the owner went away: put the newest entry back
    m_restoreLater.stop();
    if (m_settingOurselves) { m_settingOurselves = false; return; }              // that was select() / restore: already in the list
    if (m->data(QStringLiteral("x-kde-passwordManagerHint")) == "secret") return; // password managers ask not to be remembered

    Entry e; e.time = QDateTime::currentDateTime();
    if (m->hasUrls() && !m->urls().isEmpty() && m->urls().first().isLocalFile()) {
        e.kind = QStringLiteral("files");
        QStringList l; for (const QUrl &u : m->urls()) l << u.toString();
        e.text = l.join(QLatin1Char('\n'));
        e.note = m->urls().size() == 1 ? QStringLiteral("1 file") : QStringLiteral("%1 files").arg(m->urls().size());
    } else if (m->hasText() && !m->text().trimmed().isEmpty()) {
        e.kind = QStringLiteral("text");
        e.text = m->text();
        if (e.text.size() > 200000) return;                                        // not a clipboard entry, a file
        e.note = e.text.size() > 400 ? QStringLiteral("%1 characters").arg(e.text.size()) : QString();
    } else if (m->hasImage()) {
        const QImage img = qvariant_cast<QImage>(m->imageData());
        if (img.isNull() || qint64(img.width()) * img.height() > 40000000) return;
        const QByteArray id = QCryptographicHash::hash(QByteArray::fromRawData(reinterpret_cast<const char *>(img.constBits()), int(qMin<qsizetype>(img.sizeInBytes(), 4000000))), QCryptographicHash::Sha1).toHex().left(16);
        e.kind = QStringLiteral("image");
        e.imagePath = dir() + QLatin1Char('/') + QString::fromLatin1(id) + QStringLiteral(".png");
        if (!QFile::exists(e.imagePath)) img.save(e.imagePath, "PNG");
        e.note = QStringLiteral("%1 × %2").arg(img.width()).arg(img.height());
    } else return;
    push(e);
}

void ClipboardModel::push(const Entry &in)
{
    Entry e = in;
    for (int i = 0; i < m_entries.size(); ++i)                                     // the same thing again moves to the top (and stays pinned)
        if (m_entries.at(i).kind == e.kind && m_entries.at(i).text == e.text && m_entries.at(i).imagePath == e.imagePath) { e.pinned = e.pinned || m_entries.at(i).pinned; m_entries.removeAt(i); break; }
    m_entries.prepend(e);
    // only what is NOT pinned counts towards the limit, and only that is ever pushed out
    auto loose = [this] { int n = 0; for (const Entry &x : std::as_const(m_entries)) if (!x.pinned) ++n; return n; };
    while (loose() > kMax) {
        int last = -1; for (int i = m_entries.size() - 1; i >= 0; --i) if (!m_entries.at(i).pinned) { last = i; break; }
        if (last < 0) break;
        const Entry old = m_entries.takeAt(last);
        if (!old.imagePath.isEmpty()) { bool used = false; for (const Entry &x : std::as_const(m_entries)) if (x.imagePath == old.imagePath) used = true; if (!used) QFile::remove(old.imagePath); }
    }
    refilter();
    m_saveLater.start();
}

QMimeData *ClipboardModel::toMime(const Entry &e) const
{
    auto *mime = new QMimeData;
    if (e.kind == QLatin1String("image")) { const QImage img(e.imagePath); if (!img.isNull()) mime->setImageData(img); }
    else if (e.kind == QLatin1String("files")) { QList<QUrl> urls; for (const QString &s : e.text.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) urls << QUrl(s); mime->setUrls(urls); mime->setText(e.text); }
    else mime->setText(e.text);
    return mime;
}

void ClipboardModel::restoreIfEmpty()
{
    auto *c = KSystemClipboard::instance();
    if (!c || m_entries.isEmpty()) return;
    const QMimeData *m = c->mimeData(QClipboard::Clipboard);
    if (m && !m->formats().isEmpty()) return;
    m_settingOurselves = true;
    c->setMimeData(toMime(m_entries.first()), QClipboard::Clipboard);
}

void ClipboardModel::select(int row)
{
    if (row < 0 || row >= m_rows.size()) return;
    const Entry e = m_entries.at(m_rows.at(row));
    auto *c = KSystemClipboard::instance();
    if (!c) return;
    m_settingOurselves = true;
    c->setMimeData(toMime(e), QClipboard::Clipboard);
    Entry top = e; top.time = QDateTime::currentDateTime();
    push(top);
}

void ClipboardModel::remove(int row)
{
    if (row < 0 || row >= m_rows.size()) return;
    const Entry e = m_entries.takeAt(m_rows.at(row));
    if (!e.imagePath.isEmpty()) { bool used = false; for (const Entry &x : std::as_const(m_entries)) if (x.imagePath == e.imagePath) used = true; if (!used) QFile::remove(e.imagePath); }
    refilter(); m_saveLater.start();
}

void ClipboardModel::clear()
{
    QList<Entry> keep;
    for (const Entry &e : std::as_const(m_entries)) { if (e.pinned) keep << e; else if (!e.imagePath.isEmpty()) QFile::remove(e.imagePath); }
    m_entries = keep; refilter(); m_saveLater.start();
}

void ClipboardModel::togglePin(int row)
{
    if (row < 0 || row >= m_rows.size()) return;
    Entry &e = m_entries[m_rows.at(row)];
    e.pinned = !e.pinned;
    refilter(); m_saveLater.start();
}

void ClipboardModel::setFilter(const QString &f) { if (f == m_filter) return; m_filter = f; Q_EMIT filterChanged(); refilter(); }

void ClipboardModel::refilter()
{
    beginResetModel();
    m_rows.clear();
    const QString needle = m_filter.trimmed().toLower();
    for (int pass = 0; pass < 2; ++pass)                                           // pinned first, each group newest first
        for (int i = 0; i < m_entries.size(); ++i)
            if (m_entries.at(i).pinned == (pass == 0) && (needle.isEmpty() || m_entries.at(i).text.toLower().contains(needle))) m_rows << i;
    endResetModel();
    Q_EMIT countChanged();
}

void ClipboardModel::load()
{
    QFile f(dir() + QStringLiteral("/history.json"));
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonArray a = QJsonDocument::fromJson(f.readAll()).array();
    for (const QJsonValue &v : a) {
        const QJsonObject o = v.toObject();
        Entry e{o.value(QStringLiteral("kind")).toString(), o.value(QStringLiteral("text")).toString(), o.value(QStringLiteral("image")).toString(),
                QDateTime::fromString(o.value(QStringLiteral("time")).toString(), Qt::ISODate), o.value(QStringLiteral("note")).toString(), o.value(QStringLiteral("pinned")).toBool()};
        if (e.kind == QLatin1String("image") && !QFile::exists(e.imagePath)) continue;
        if (!e.kind.isEmpty()) m_entries << e;
    }
}

void ClipboardModel::save()
{
    QJsonArray a;
    for (const Entry &e : std::as_const(m_entries))
        a.append(QJsonObject{{QStringLiteral("kind"), e.kind}, {QStringLiteral("text"), e.text}, {QStringLiteral("image"), e.imagePath}, {QStringLiteral("time"), e.time.toString(Qt::ISODate)}, {QStringLiteral("note"), e.note}, {QStringLiteral("pinned"), e.pinned}});
    QFile f(dir() + QStringLiteral("/history.json"));
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) { f.write(QJsonDocument(a).toJson(QJsonDocument::Compact)); f.setPermissions(QFile::ReadOwner | QFile::WriteOwner); }
}
