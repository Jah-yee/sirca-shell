#pragma once
// org.kde.osdService, the interface volume / brightness / layout … changes are announced on (by plasma-pa, PowerDevil,
// KWin, the keyboard daemon). Plasma serves it from plasmashell under the bus name org.kde.plasmashell. When Sirca Shell
// runs WITHOUT plasmashell (config "withoutPlasmashell": true) it serves the same interface itself and shows the values
// in the top bar's clock pill. It must never hold that name otherwise: plasmashell refuses to start while it is taken.
#include <QDBusArgument>
#include <QObject>

struct OsdRect { int x = 0, y = 0, w = 0, h = 0; };
Q_DECLARE_METATYPE(OsdRect)
QDBusArgument &operator<<(QDBusArgument &a, const OsdRect &r);
const QDBusArgument &operator>>(const QDBusArgument &a, OsdRect &r);

class OsdService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.osdService")
public:
    explicit OsdService(QObject *parent = nullptr);
    bool claim();                                   // take org.kde.plasmashell + /org/kde/osdService; false if someone has it
    void release();
    bool claimed() const { return m_claimed; }
public Q_SLOTS:
    void brightnessChanged(int percent);
    void screenBrightnessChanged(int percent, const QString &displayId, const QString &displayLabel, int priority, const OsdRect &screenRect);
    void keyboardBrightnessChanged(int percent);
    void volumeChanged(int percent);
    void volumeChanged(int percent, int maximumPercent);
    void microphoneVolumeChanged(int percent);
    void mediaPlayerVolumeChanged(int percent, const QString &playerName, const QString &playerIconName);
    void kbdLayoutChanged(const QString &layoutName);
    void virtualKeyboardEnabledChanged(bool virtualKeyboardEnabled);
    void touchpadEnabledChanged(bool touchpadEnabled);
    void wifiEnabledChanged(bool wifiEnabled);
    void bluetoothEnabledChanged(bool bluetoothEnabled);
    void wwanEnabledChanged(bool wwanEnabled);
    void virtualDesktopChanged(const QString &currentVirtualDesktopName);
    void powerManagementInhibitedChanged(bool inhibited);
    void powerProfileChanged(const QString &profile);
    void showText(const QString &icon, const QString &text);
Q_SIGNALS:
    // same shape as Plasma's own signals, so the bar's code is the same with and without plasmashell
    Q_SCRIPTABLE void osdProgress(const QString &icon, int percent, int maximumPercent, const QString &additionalText);
    Q_SCRIPTABLE void osdText(const QString &icon, const QString &text);
private:
    bool m_claimed = false;
};
