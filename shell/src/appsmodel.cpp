#include "appsmodel.h"
#include <KService>
#include <KSycoca>
#include <QCollator>
#include <QProcess>
#include <QSet>
#include <algorithm>

AppsModel::AppsModel(QObject *parent) : QAbstractListModel(parent)
{
    reload();
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, [this] { reload(); });   // something was installed or removed
}

// freedesktop main categories, folded into the handful a launcher shows
QString AppsModel::mainCategory(const QStringList &cats)
{
    static const QList<QPair<QString, QString>> map{{QStringLiteral("Game"), QStringLiteral("Games")}, {QStringLiteral("Development"), QStringLiteral("Development")},
        {QStringLiteral("Graphics"), QStringLiteral("Graphics")}, {QStringLiteral("Network"), QStringLiteral("Internet")}, {QStringLiteral("AudioVideo"), QStringLiteral("Multimedia")},
        {QStringLiteral("Audio"), QStringLiteral("Multimedia")}, {QStringLiteral("Video"), QStringLiteral("Multimedia")}, {QStringLiteral("Office"), QStringLiteral("Office")},
        {QStringLiteral("Education"), QStringLiteral("Education")}, {QStringLiteral("Science"), QStringLiteral("Education")}, {QStringLiteral("Settings"), QStringLiteral("Settings")},
        {QStringLiteral("System"), QStringLiteral("System")}, {QStringLiteral("Utility"), QStringLiteral("Utilities")}};
    for (const auto &m : map) if (cats.contains(m.first)) return m.second;
    return QStringLiteral("Other");
}

void AppsModel::reload()
{
    beginResetModel();
    m_apps.clear();
    QSet<QString> seen, used;
    const KService::List all = KService::allServices();
    for (const KService::Ptr &s : all) {
        if (!s || !s->isApplication() || s->noDisplay() || s->exec().isEmpty() || !s->showInCurrentDesktop()) continue;
        if (seen.contains(s->storageId())) continue;
        seen.insert(s->storageId());
        App a{s->name(), s->genericName(), s->comment(), s->icon(), s->storageId(), s->entryPath(), {}, {mainCategory(s->categories())}};
        a.haystack = (a.name + QLatin1Char(' ') + a.generic + QLatin1Char(' ') + s->keywords().join(QLatin1Char(' ')) + QLatin1Char(' ') + s->desktopEntryName()).toLower();
        used.insert(a.cats.first());
        m_apps.append(a);
    }
    QCollator col; col.setCaseSensitivity(Qt::CaseInsensitive); col.setNumericMode(true);
    std::sort(m_apps.begin(), m_apps.end(), [&col](const App &x, const App &y) { return col.compare(x.name, y.name) < 0; });
    static const QStringList order{QStringLiteral("Development"), QStringLiteral("Games"), QStringLiteral("Graphics"), QStringLiteral("Internet"), QStringLiteral("Multimedia"),
        QStringLiteral("Office"), QStringLiteral("Education"), QStringLiteral("Settings"), QStringLiteral("System"), QStringLiteral("Utilities"), QStringLiteral("Other")};
    m_categories.clear();
    for (const QString &c : order) if (used.contains(c)) m_categories << c;
    endResetModel();
    refilter();
    Q_EMIT categoriesChanged();
}

void AppsModel::refilter()
{
    beginResetModel();
    m_rows.clear();
    const QStringList words = m_filter.toLower().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    QList<int> starts, rest;                                  // names that START with the text first: "fi" gives Firefox before "Office"
    for (int i = 0; i < m_apps.size(); ++i) {
        const App &a = m_apps.at(i);
        if (!m_category.isEmpty() && !a.cats.contains(m_category)) continue;
        bool ok = true;
        for (const QString &w : words) if (!a.haystack.contains(w)) { ok = false; break; }
        if (!ok) continue;
        (!words.isEmpty() && a.name.toLower().startsWith(words.first()) ? starts : rest).append(i);
    }
    m_rows = starts + rest;
    endResetModel();
    Q_EMIT countChanged();
}

void AppsModel::setFilter(const QString &f) { if (f == m_filter) return; m_filter = f; Q_EMIT filterChanged(); refilter(); }
void AppsModel::setCategory(const QString &c) { if (c == m_category) return; m_category = c; Q_EMIT categoryChanged(); refilter(); }
int AppsModel::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_rows.size(); }
QHash<int, QByteArray> AppsModel::roleNames() const { return {{NameRole, "name"}, {GenericRole, "generic"}, {IconRole, "icon"}, {StorageIdRole, "storageId"}, {CommentRole, "comment"}}; }

QVariant AppsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) return {};
    const App &a = m_apps.at(m_rows.at(index.row()));
    switch (role) {
    case NameRole: case Qt::DisplayRole: return a.name;
    case GenericRole: return a.generic;
    case IconRole: return a.icon;
    case StorageIdRole: return a.storageId;
    case CommentRole: return a.comment;
    }
    return {};
}

QString AppsModel::storageIdAt(int row) const { return (row >= 0 && row < m_rows.size()) ? m_apps.at(m_rows.at(row)).storageId : QString(); }

QVariantMap AppsModel::info(const QString &storageId) const
{
    for (const App &a : m_apps) if (a.storageId == storageId) return {{QStringLiteral("name"), a.name}, {QStringLiteral("icon"), a.icon}, {QStringLiteral("storageId"), a.storageId}};
    return {};
}

bool AppsModel::launch(const QString &storageId)
{
    for (const App &a : m_apps) if (a.storageId == storageId)
        // kioclient runs KIO's ApplicationLauncherJob: startup feedback, its own systemd scope, desktop-file field codes handled
        return QProcess::startDetached(QStringLiteral("kioclient"), {QStringLiteral("exec"), a.path});
    return false;
}
