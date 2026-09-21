#include "trayhost.h"
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QMutex>
#include <QtEndian>

static const QString kWatcher = QStringLiteral("org.kde.StatusNotifierWatcher");
static const QString kWatcherPath = QStringLiteral("/StatusNotifierWatcher");
static const QString kItemIface = QStringLiteral("org.kde.StatusNotifierItem");
static const QString kMenuIface = QStringLiteral("com.canonical.dbusmenu");

// ---- wire types ---------------------------------------------------------------------------------------------------
struct SniImage { int width = 0, height = 0; QByteArray data; };
using SniImageList = QList<SniImage>;
Q_DECLARE_METATYPE(SniImage)
Q_DECLARE_METATYPE(SniImageList)
static QDBusArgument &operator<<(QDBusArgument &a, const SniImage &i) { a.beginStructure(); a << i.width << i.height << i.data; a.endStructure(); return a; }
static const QDBusArgument &operator>>(const QDBusArgument &a, SniImage &i) { a.beginStructure(); a >> i.width >> i.height >> i.data; a.endStructure(); return a; }

struct MenuNode { int id = 0; QVariantMap props; QList<MenuNode> children; };
static const QDBusArgument &operator>>(const QDBusArgument &a, MenuNode &n)
{
    a.beginStructure();
    a >> n.id >> n.props;
    a.beginArray();
    while (!a.atEnd()) {
        QDBusVariant v; a >> v;
        MenuNode child; v.variant().value<QDBusArgument>() >> child;
        n.children.append(child);
    }
    a.endArray();
    a.endStructure();
    return a;
}

static QVariantList toEntries(const QList<MenuNode> &nodes)
{
    QVariantList out;
    for (const MenuNode &n : nodes) {
        if (!n.props.value(QStringLiteral("visible"), true).toBool()) continue;
        QString label = n.props.value(QStringLiteral("label")).toString();
        label.replace(QStringLiteral("__"), QStringLiteral("\x01")).remove(QLatin1Char('_')).replace(QStringLiteral("\x01"), QStringLiteral("_"));   // mnemonics
        const bool separator = n.props.value(QStringLiteral("type")).toString() == QLatin1String("separator");
        if (separator && (out.isEmpty() || out.last().toMap().value(QStringLiteral("separator")).toBool())) continue;   // no leading / double lines
        out.append(QVariantMap{{QStringLiteral("id"), n.id}, {QStringLiteral("label"), label}, {QStringLiteral("separator"), separator},
            {QStringLiteral("enabled"), n.props.value(QStringLiteral("enabled"), true).toBool()},
            {QStringLiteral("toggle"), n.props.value(QStringLiteral("toggle-type")).toString()},
            {QStringLiteral("checked"), n.props.value(QStringLiteral("toggle-state"), 0).toInt() == 1},
            {QStringLiteral("icon"), n.props.value(QStringLiteral("icon-name")).toString()},
            {QStringLiteral("children"), toEntries(n.children)}});
    }
    while (!out.isEmpty() && out.last().toMap().value(QStringLiteral("separator")).toBool()) out.removeLast();
    return out;
}

// ---- pixmap icons -------------------------------------------------------------------------------------------------
static QMutex s_imgLock;
static QHash<QString, QImage> s_images;
void TrayImageProvider::store(const QString &key, const QImage &image) { QMutexLocker l(&s_imgLock); s_images.insert(key, image); }
void TrayImageProvider::drop(const QString &key) { QMutexLocker l(&s_imgLock); s_images.remove(key); }
QImage TrayImageProvider::requestImage(const QString &id, QSize *size, const QSize &)
{
    const QString key = id.section(QLatin1Char('?'), 0, 0);             // "?rev" only busts the Image cache
    QMutexLocker l(&s_imgLock);
    const QImage img = s_images.value(key);
    if (size) *size = img.size();
    return img;
}

static QImage bestPixmap(const SniImageList &list)
{
    const SniImage *best = nullptr;
    for (const SniImage &i : list) if (i.width > 0 && i.height > 0 && i.data.size() >= i.width * i.height * 4 && (!best || i.width > best->width)) best = &i;
    if (!best) return {};
    QImage img(best->width, best->height, QImage::Format_ARGB32);      // wire format: ARGB32, network byte order
    const auto *src = reinterpret_cast<const quint32 *>(best->data.constData());
    auto *dst = reinterpret_cast<quint32 *>(img.bits());
    for (int p = 0; p < best->width * best->height; ++p) dst[p] = qFromBigEndian(src[p]);
    return img;
}

// ---- one item -----------------------------------------------------------------------------------------------------
TrayItem::TrayItem(const QString &service, const QString &path, QObject *parent) : QObject(parent), m_service(service), m_path(path)
{
    auto bus = QDBusConnection::sessionBus();
    for (const char *sig : {"NewIcon", "NewAttentionIcon", "NewOverlayIcon", "NewTitle", "NewToolTip", "NewStatus", "NewMenu"})
        bus.connect(service, path, kItemIface, QLatin1String(sig), this, SLOT(refresh()));
    refresh();
}

void TrayItem::refresh()
{
    QDBusMessage m = QDBusMessage::createMethodCall(m_service, m_path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("GetAll"));
    m << kItemIface;
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QVariantMap> r = *w;
        if (r.isError()) return;
        const QVariantMap p = r.value();
        m_id = p.value(QStringLiteral("Id")).toString();
        m_status = p.value(QStringLiteral("Status"), QStringLiteral("Active")).toString();
        m_itemIsMenu = p.value(QStringLiteral("ItemIsMenu")).toBool();
        m_menuPath = p.value(QStringLiteral("Menu")).value<QDBusObjectPath>().path();
        m_title = p.value(QStringLiteral("Title")).toString();
        if (m_title.isEmpty()) {                                       // Discord: no Title, but a ToolTip (sa(iiay)ss)
            const QDBusArgument tip = p.value(QStringLiteral("ToolTip")).value<QDBusArgument>();
            if (tip.currentType() == QDBusArgument::StructureType) { QString ic, t, sub; SniImageList im; tip.beginStructure(); tip >> ic >> im >> t >> sub; tip.endStructure(); m_title = t; }
        }
        if (m_title.isEmpty()) m_title = m_id;

        const bool attention = m_status == QLatin1String("NeedsAttention");
        QString name = attention ? p.value(QStringLiteral("AttentionIconName")).toString() : QString();
        if (name.isEmpty()) name = p.value(QStringLiteral("IconName")).toString();
        const QString themePath = p.value(QStringLiteral("IconThemePath")).toString();
        m_iconIsFile = false;
        QString icon;
        if (name.startsWith(QLatin1Char('/')) && QFileInfo::exists(name)) { icon = QStringLiteral("file://") + name; m_iconIsFile = true; }
        else if (!name.isEmpty() && !themePath.isEmpty()) {             // an app's private icon folder (Steam)
            for (const QString &rel : {QStringLiteral("%1.svg"), QStringLiteral("%1.png"), QStringLiteral("hicolor/scalable/apps/%1.svg"), QStringLiteral("hicolor/48x48/apps/%1.png"),
                                       QStringLiteral("hicolor/32x32/apps/%1.png"), QStringLiteral("hicolor/24x24/apps/%1.png"), QStringLiteral("hicolor/22x22/apps/%1.png")}) {
                const QString f = QDir(themePath).filePath(rel.arg(name));
                if (QFileInfo::exists(f)) { icon = QStringLiteral("file://") + f; m_iconIsFile = true; break; }
            }
        }
        if (icon.isEmpty() && !name.isEmpty()) icon = name;
        if (icon.isEmpty()) {
            const QString field = attention ? QStringLiteral("AttentionIconPixmap") : QStringLiteral("IconPixmap");
            QImage img = bestPixmap(qdbus_cast<SniImageList>(p.value(field).value<QDBusArgument>()));
            if (img.isNull() && attention) img = bestPixmap(qdbus_cast<SniImageList>(p.value(QStringLiteral("IconPixmap")).value<QDBusArgument>()));
            if (!img.isNull()) { TrayImageProvider::store(key(), img); icon = QStringLiteral("image://tray/%1?%2").arg(key()).arg(++m_rev); m_iconIsFile = true; }
        }
        m_icon = icon;
        Q_EMIT changed();
    });
}

static void callItem(const QString &service, const QString &path, const QString &method, const QVariantList &args)
{
    QDBusMessage m = QDBusMessage::createMethodCall(service, path, kItemIface, method);
    m.setArguments(args);
    QDBusConnection::sessionBus().asyncCall(m);
}
void TrayItem::activate(int x, int y) { callItem(m_service, m_path, QStringLiteral("Activate"), {x, y}); }
void TrayItem::secondaryActivate(int x, int y) { callItem(m_service, m_path, QStringLiteral("SecondaryActivate"), {x, y}); }
void TrayItem::scroll(int delta, bool horizontal) { callItem(m_service, m_path, QStringLiteral("Scroll"), {delta, horizontal ? QStringLiteral("horizontal") : QStringLiteral("vertical")}); }

void TrayItem::fetchMenu()
{
    if (!hasMenu()) { Q_EMIT menuReady({}); return; }
    auto bus = QDBusConnection::sessionBus();
    QDBusMessage about = QDBusMessage::createMethodCall(m_service, m_menuPath, kMenuIface, QStringLiteral("AboutToShow"));   // some apps build the menu now
    about << 0;
    auto *aw = new QDBusPendingCallWatcher(bus.asyncCall(about, 1500), this);
    connect(aw, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *aw) {
        aw->deleteLater();
        QDBusMessage m = QDBusMessage::createMethodCall(m_service, m_menuPath, kMenuIface, QStringLiteral("GetLayout"));
        m << 0 << -1 << QStringList();
        auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m, 3000), this);
        connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
            w->deleteLater();
            const QDBusMessage reply = w->reply();
            if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() < 2) { Q_EMIT menuReady({}); return; }
            MenuNode root; reply.arguments().at(1).value<QDBusArgument>() >> root;
            Q_EMIT menuReady(toEntries(root.children));
        });
    });
}

void TrayItem::menuEvent(int id)
{
    QDBusMessage m = QDBusMessage::createMethodCall(m_service, m_menuPath, kMenuIface, QStringLiteral("Event"));
    m << id << QStringLiteral("clicked") << QVariant::fromValue(QDBusVariant(QVariant(0))) << uint(QDateTime::currentSecsSinceEpoch());
    QDBusConnection::sessionBus().asyncCall(m);
}

// ---- the host -----------------------------------------------------------------------------------------------------
TrayHost::TrayHost(QObject *parent) : QAbstractListModel(parent)
{
    qDBusRegisterMetaType<SniImage>();
    qDBusRegisterMetaType<SniImageList>();
    auto bus = QDBusConnection::sessionBus();
    m_hostName = QStringLiteral("org.kde.StatusNotifierHost-%1-glass").arg(QCoreApplication::applicationPid());
    bus.registerService(m_hostName);
    m_gone.setConnection(bus);
    m_gone.setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(&m_gone, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &s) { removeWhere([&s](TrayItem *i) { return i->service() == s; }); });
    // the watcher may start after us (or restart): follow its name
    auto *w = new QDBusServiceWatcher(kWatcher, bus, QDBusServiceWatcher::WatchForRegistration, this);
    connect(w, &QDBusServiceWatcher::serviceRegistered, this, [this] { connectToWatcher(); });
    connectToWatcher();
}

void TrayHost::connectToWatcher()
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.interface()->isServiceRegistered(kWatcher)) return;
    bus.connect(kWatcher, kWatcherPath, kWatcher, QStringLiteral("StatusNotifierItemRegistered"), this, SLOT(onRegistered(QString)));
    bus.connect(kWatcher, kWatcherPath, kWatcher, QStringLiteral("StatusNotifierItemUnregistered"), this, SLOT(onUnregistered(QString)));
    QDBusMessage reg = QDBusMessage::createMethodCall(kWatcher, kWatcherPath, kWatcher, QStringLiteral("RegisterStatusNotifierHost"));
    reg << m_hostName;
    bus.asyncCall(reg);
    QDBusMessage get = QDBusMessage::createMethodCall(kWatcher, kWatcherPath, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << kWatcher << QStringLiteral("RegisteredStatusNotifierItems");
    auto *pw = new QDBusPendingCallWatcher(bus.asyncCall(get), this);
    connect(pw, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *pw) {
        pw->deleteLater();
        QDBusPendingReply<QVariant> r = *pw;
        if (r.isError()) return;
        const QStringList items = r.value().toStringList();
        for (const QString &i : items) add(i);
    });
}

void TrayHost::add(const QString &serviceAndPath)
{
    const int slash = serviceAndPath.indexOf(QLatin1Char('/'));
    const QString service = slash < 0 ? serviceAndPath : serviceAndPath.left(slash);
    const QString path = slash < 0 ? QStringLiteral("/StatusNotifierItem") : serviceAndPath.mid(slash);
    for (TrayItem *i : std::as_const(m_items)) if (i->key() == service + path) return;
    beginInsertRows({}, m_items.size(), m_items.size());
    m_items.append(new TrayItem(service, path, this));
    endInsertRows();
    m_gone.addWatchedService(service);
    Q_EMIT countChanged();
}

void TrayHost::removeWhere(const std::function<bool(TrayItem *)> &match)
{
    for (int i = m_items.size() - 1; i >= 0; --i) {
        if (!match(m_items.at(i))) continue;
        beginRemoveRows({}, i, i);
        TrayItem *it = m_items.takeAt(i);
        endRemoveRows();
        TrayImageProvider::drop(it->key());
        it->deleteLater();
    }
    Q_EMIT countChanged();
}

void TrayHost::onRegistered(const QString &serviceAndPath) { add(serviceAndPath); }
void TrayHost::onUnregistered(const QString &serviceAndPath)
{
    const int slash = serviceAndPath.indexOf(QLatin1Char('/'));
    const QString key = slash < 0 ? serviceAndPath + QStringLiteral("/StatusNotifierItem") : serviceAndPath;
    removeWhere([&key](TrayItem *i) { return i->key() == key; });
}

QVariant TrayHost::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size() || role != Qt::UserRole + 1) return {};
    return QVariant::fromValue(m_items.at(index.row()));
}
