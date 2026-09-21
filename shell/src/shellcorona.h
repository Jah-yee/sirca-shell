// Hosts real Plasma applets inside Sirca Shell surfaces (same technique as plasmawindowed): a private corona with two
// containments — "bar" (horizontal, top edge: applets show their compact form, e.g. the system tray) and "lobe"
// (planar: applets show their full form, e.g. Glass Control inside the gear lobe). Layout persists in
// ~/.config/sirca-shell-appletsrc so hosted applets keep their own settings.
#pragma once
#include <Plasma/Containment>
#include <Plasma/Corona>
#include <QHash>
#include <QQuickItem>

class ShellCorona : public Plasma::Corona
{
    Q_OBJECT
public:
    static ShellCorona *self();
    explicit ShellCorona(QObject *parent = nullptr);
    // One screen, id 0. Without these the containments report screen -1 and hosted applets that place their own
    // windows (notification popups, tooltips) get an empty rect and end up at 0,0.
    int numScreens() const override { return 1; }
    int screenForContainment(const Plasma::Containment *) const override { return 0; }
    QRect screenGeometry(int id) const override;
    QRect availableScreenRect(int id) const override;
    QRegion availableScreenRegion(int id) const override { return availableScreenRect(id); }
    void setStrut(bool bottom, int px);   // space our own surfaces reserve; popups stay clear of it
    // The corona (Plasma's applet hosting: shell package, containments, applet scan) is only needed for the fallback
    // switches. It is created on first use; struts set before that are remembered and applied then.
    static bool exists();
    static void rememberStrut(bool bottom, int px);
    QQuickItem *itemFor(const QString &plugin, const QString &zone);
    Plasma::Applet *appletFor(const QString &plugin, const QString &zone);
    // any loaded applet by plugin id, including the ones nested inside the tray (its inner containment is ours too)
    Q_INVOKABLE QQuickItem *findItem(const QString &plugin);

private Q_SLOTS:
    void showConfig(Plasma::Applet *applet);   // a hosted applet asked for its settings window (tray gear, right-click → Configure…)

private:
    void watchConfigRequests(Plasma::Containment *c);
    Plasma::Containment *zoneContainment(const QString &zone);
    QHash<QString, Plasma::Containment *> m_zones;
    int m_top = 0, m_bottom = 0;
};
