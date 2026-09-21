/*
 *    Night Light state + toggle, the way Plasma's own brightness applet does it:
 *    KWin's NightLight D-Bus properties for the state, NightLightInhibitor to toggle.
 *    (Replaces upstream's sensor-based Plasma-version sniffing and dynamic component.)
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.workspace.dbus as DBus

Item {
    id: nightLight

    readonly property bool available: Boolean(control.properties.available)
    readonly property bool enabled: Boolean(control.properties.enabled)
    readonly property bool running: Boolean(control.properties.running)
    readonly property bool inhibited: Boolean(control.properties.inhibited)
    readonly property bool on: available && enabled && running && !inhibited
    readonly property string statusText: !available ? i18n("Unavailable")
                                       : !enabled ? i18n("Off")
                                       : inhibited ? i18n("Paused")
                                       : running ? i18n("On") : i18n("Scheduled")

    DBus.Properties {
        id: control
        busType: DBus.BusType.Session
        service: "org.kde.KWin.NightLight"
        path: "/org/kde/KWin/NightLight"
        iface: "org.kde.KWin.NightLight"
    }

    function toggle() {
        NightLightInhibitor.toggleInhibition()
    }
}
