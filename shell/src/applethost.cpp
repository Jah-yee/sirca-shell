#include "applethost.h"
#include <QTimer>
#include "shellcorona.h"
#include <QDebug>

AppletHost::AppletHost(QQuickItem *parent) : QQuickItem(parent) {}

void AppletHost::setPlugin(const QString &p)
{
    if (m_plugin == p) return;
    m_plugin = p;
    Q_EMIT pluginChanged();
    if (isComponentComplete()) attach();
}

void AppletHost::setZone(const QString &z)
{
    if (m_zone == z) return;
    m_zone = z;
    Q_EMIT zoneChanged();
}

void AppletHost::componentComplete()
{
    QQuickItem::componentComplete();
    attach();
}

void AppletHost::attach()
{
    if (m_plugin.isEmpty() || m_item) return;
    m_item = ShellCorona::self()->itemFor(m_plugin, m_zone);
    if (!m_item) return;
    m_item->setParentItem(this);
    m_item->setProperty("hideOnWindowDeactivate", false);
    m_item->setSize(size());
    connect(m_item, SIGNAL(expandedChanged(bool)), this, SLOT(onAppletExpandedChanged()));
    if (m_zone == QLatin1String("lobe")) {
        // In a lobe the applet IS the popup. Most applets prefer their compact form and create the full one only
        // when expanded, so: keep the compact item hidden, expand on demand, and adopt the full representation.
        m_item->setVisible(false);
        m_item->setProperty("preloadFullRepresentation", true);   // build the popup content at startup, not inside the first opening animation
        connect(m_item, SIGNAL(fullRepresentationItemChanged(QObject *)), this, SLOT(adoptFullRepresentation()));
        if (m_wantExpanded) m_item->setProperty("expanded", true);
        else {
            // warm-up: applets do their expensive first-time work (models, views) when first expanded; do that now,
            // unseen (the lobe has no height), so the first real opening animates smoothly
            m_warming = true;
            m_item->setProperty("expanded", true);
            QTimer::singleShot(1500, this, [this] { if (!m_wantExpanded && m_item) m_item->setProperty("expanded", false); m_warming = false; });
        }
        adoptFullRepresentation();
    } else {
        m_item->setVisible(true);
    }
    Q_EMIT appletItemChanged();
}

void AppletHost::adoptFullRepresentation()
{
    if (!m_item) return;
    auto *full = qobject_cast<QQuickItem *>(m_item->property("fullRepresentationItem").value<QObject *>());
    if (!full) return;
    if (full != m_full) {
        m_full = full;
        // libplasma parents the full representation back under the applet item whenever the expanded state
        // settles; take it again each time (queued, so we do not fight it inside its own handler)
        connect(full, &QQuickItem::parentChanged, this, [this] {
            if (m_full && m_full->parentItem() != this) QMetaObject::invokeMethod(this, "adoptFullRepresentation", Qt::QueuedConnection);
        });
    }
    if (full->parentItem() != this) full->setParentItem(this);
    full->setPosition(QPointF(0, 0));
    full->setSize(size());
    full->setVisible(true);
    Q_EMIT appletItemChanged();   // lobe size bindings read the full item's Layout hints
}

void AppletHost::onAppletExpandedChanged()
{
    if (m_warming) return;
    Q_EMIT expandedChanged();
}

void AppletHost::geometryChange(const QRectF &n, const QRectF &o)
{
    QQuickItem::geometryChange(n, o);
    if (m_item) m_item->setSize(n.size());
    if (m_full) m_full->setSize(n.size());
}

bool AppletHost::expanded() const
{
    if (m_warming) return m_wantExpanded;
    return m_item ? m_item->property("expanded").toBool() : m_wantExpanded;
}

void AppletHost::setExpanded(bool e)
{
    m_wantExpanded = e;
    if (m_warming && m_item) { m_item->setProperty("expanded", e); return; }
    if (m_item && m_item->property("expanded").toBool() != e) m_item->setProperty("expanded", e);
}
