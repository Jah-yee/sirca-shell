#include "osdservice.h"
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMetaType>

static const QString kName = QStringLiteral("org.kde.plasmashell");
static const QString kPath = QStringLiteral("/org/kde/osdService");

QDBusArgument &operator<<(QDBusArgument &a, const OsdRect &r) { a.beginStructure(); a << r.x << r.y << r.w << r.h; a.endStructure(); return a; }
const QDBusArgument &operator>>(const QDBusArgument &a, OsdRect &r) { a.beginStructure(); a >> r.x >> r.y >> r.w >> r.h; a.endStructure(); return a; }

OsdService::OsdService(QObject *parent) : QObject(parent) { qDBusRegisterMetaType<OsdRect>(); }

bool OsdService::claim()
{
    if (m_claimed) return true;
    auto bus = QDBusConnection::sessionBus();
    if (bus.interface()->isServiceRegistered(kName)) return false;            // plasmashell (or anyone) has it: hands off
    if (!bus.registerService(kName)) return false;
    bus.registerObject(kPath, this, QDBusConnection::ExportAllSlots | QDBusConnection::ExportScriptableSignals);
    m_claimed = true;
    return true;
}

void OsdService::release()
{
    if (!m_claimed) return;
    auto bus = QDBusConnection::sessionBus();
    bus.unregisterObject(kPath);
    bus.unregisterService(kName);
    m_claimed = false;
}

static QString volumeIcon(int percent) { return percent <= 0 ? QStringLiteral("audio-volume-muted") : percent < 34 ? QStringLiteral("audio-volume-low") : percent < 67 ? QStringLiteral("audio-volume-medium") : QStringLiteral("audio-volume-high"); }

void OsdService::brightnessChanged(int percent) { Q_EMIT osdProgress(QStringLiteral("video-display-brightness"), percent, 100, {}); }
void OsdService::screenBrightnessChanged(int percent, const QString &, const QString &displayLabel, int, const OsdRect &) { Q_EMIT osdProgress(QStringLiteral("video-display-brightness"), percent, 100, displayLabel); }
void OsdService::keyboardBrightnessChanged(int percent) { Q_EMIT osdProgress(QStringLiteral("input-keyboard-brightness"), percent, 100, {}); }
void OsdService::volumeChanged(int percent) { volumeChanged(percent, 100); }
void OsdService::volumeChanged(int percent, int maximumPercent) { Q_EMIT osdProgress(volumeIcon(percent), percent, maximumPercent, {}); }
void OsdService::microphoneVolumeChanged(int percent) { Q_EMIT osdProgress(percent <= 0 ? QStringLiteral("microphone-sensitivity-muted") : QStringLiteral("microphone-sensitivity-high"), percent, 100, {}); }
void OsdService::mediaPlayerVolumeChanged(int percent, const QString &playerName, const QString &playerIconName) { Q_EMIT osdProgress(playerIconName.isEmpty() ? volumeIcon(percent) : playerIconName, percent, 100, playerName); }
void OsdService::kbdLayoutChanged(const QString &layoutName) { Q_EMIT osdText(QStringLiteral("input-keyboard"), layoutName); }
void OsdService::virtualKeyboardEnabledChanged(bool on) { Q_EMIT osdText(on ? QStringLiteral("input-keyboard-virtual-on") : QStringLiteral("input-keyboard-virtual-off"), on ? QStringLiteral("Virtual keyboard on") : QStringLiteral("Virtual keyboard off")); }
void OsdService::touchpadEnabledChanged(bool on) { Q_EMIT osdText(on ? QStringLiteral("input-touchpad-on") : QStringLiteral("input-touchpad-off"), on ? QStringLiteral("Touchpad on") : QStringLiteral("Touchpad off")); }
void OsdService::wifiEnabledChanged(bool on) { Q_EMIT osdText(on ? QStringLiteral("network-wireless-on") : QStringLiteral("network-wireless-off"), on ? QStringLiteral("Wi-Fi on") : QStringLiteral("Wi-Fi off")); }
void OsdService::bluetoothEnabledChanged(bool on) { Q_EMIT osdText(on ? QStringLiteral("preferences-system-bluetooth") : QStringLiteral("preferences-system-bluetooth-inactive"), on ? QStringLiteral("Bluetooth on") : QStringLiteral("Bluetooth off")); }
void OsdService::wwanEnabledChanged(bool on) { Q_EMIT osdText(on ? QStringLiteral("network-mobile-on") : QStringLiteral("network-mobile-off"), on ? QStringLiteral("Mobile network on") : QStringLiteral("Mobile network off")); }
void OsdService::virtualDesktopChanged(const QString &name) { Q_EMIT osdText(QStringLiteral("user-desktop"), name); }
void OsdService::powerManagementInhibitedChanged(bool inhibited) { Q_EMIT osdText(QStringLiteral("system-suspend-inhibited"), inhibited ? QStringLiteral("Sleep and screen locking blocked") : QStringLiteral("Sleep and screen locking unblocked")); }
void OsdService::powerProfileChanged(const QString &profile) { Q_EMIT osdText(QStringLiteral("speedometer"), profile == QLatin1String("power-saver") ? QStringLiteral("Power Save") : profile == QLatin1String("performance") ? QStringLiteral("Performance") : QStringLiteral("Balanced")); }
void OsdService::showText(const QString &icon, const QString &text) { Q_EMIT osdText(icon, text); }
