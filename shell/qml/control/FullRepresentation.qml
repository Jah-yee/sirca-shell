/*
 *    Glass Control — Control Center style layout on a strict grid.
 *    Backends: upstream Plasma Control Hub pieces (network model, Bluetooth via BluezQt,
 *    MPRIS, notification inhibition, session management) + Plasma's brightness/night-light plugin.
 *
 *    SPDX-FileCopyrightText: zayronxio (upstream), onur (layout + glass)
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.sessions as Sessions
import org.kde.notificationmanager as NotificationManager
import org.kde.bluezqt 1.0 as BluezQt
import org.kde.kcmutils // KCMLauncher
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.private.volume

import "js/funcs.js" as Funcs
import "lib" as Lib
import "components" as Components

Item {
    id: menu

    // ---------- backends ----------
    property QtObject btManager: BluezQt.Manager
    property var network: network
    property var notificationSettings: notificationSettings
    property var monitor: null
    property var inhibitor: null

    NotificationManager.Settings { id: notificationSettings }
    Sessions.SessionManagement { id: sm }
    UserInfo { id: userInfo }
    NightLight { id: nightLight }
    Battery { id: battery; visible: false }
    Components.Network { id: network }
    Components.SectionNetworks { id: sectionNetworks }

    // volume
    readonly property var sink: PreferredDevice.sink
    readonly property bool sinkAvailable: sink && sink.name !== "auto_null"

    // brightness (same approach as Plasma's applet)
    ScreenBrightnessControl { id: screenBrightnessControl; isSilent: false }
    Connections {
        id: displays
        target: screenBrightnessControl.displays
        property var info: []
        function update() {
            const [labelRole, brightnessRole, maxBrightnessRole, displayNameRole] =
                ["label", "brightness", "maxBrightness", "displayName"].map(r => target.KItemModels.KRoleNames.role(r));
            info = [...Array(target.rowCount()).keys()].map(i => {
                const idx = target.index(i, 0);
                return { displayName: target.data(idx, displayNameRole), label: target.data(idx, labelRole),
                         brightness: target.data(idx, brightnessRole), maxBrightness: target.data(idx, maxBrightnessRole) };
            });
        }
        function onDataChanged() { update(); }
        function onModelReset() { update(); }
        function onRowsInserted() { update(); }
        function onRowsRemoved() { update(); }
        Component.onCompleted: update()
    }
    readonly property var mainScreen: displays.info.length > 0 ? displays.info[0] : null
    readonly property bool brightnessAvailable: screenBrightnessControl.isBrightnessAvailable && mainScreen !== null

    // derived states
    readonly property bool wifiAvailable: network.availableDevices.wirelessDeviceAvailable
    readonly property bool wifiOn: wifiAvailable && network.enabledConnections.wirelessHwEnabled && network.enabledConnections.wirelessEnabled
    readonly property bool netConnected: network.netStatusText !== undefined && network.netStatusText !== ""
    // "Wired Ethernet: Connected to X\nWi-Fi: Connected to Y" -> "X · Y"
    readonly property string primaryConnection: {
        if (!netConnected) return "";
        return String(network.netStatusText).split("\n").map(function (l) {
            var m = l.match(/Connected to (.*)$/); return m ? m[1] : l;
        }).filter(function (x) { return x !== ""; }).join(" · ");
    }
    readonly property bool btOn: btManager.bluetoothOperational
    readonly property bool dndOn: notificationSettings.notificationsInhibitedByApplication
                                  || (notificationSettings.notificationsInhibitedUntil instanceof Date
                                      && !isNaN(notificationSettings.notificationsInhibitedUntil.getTime())
                                      && Date.now() < notificationSettings.notificationsInhibitedUntil.getTime())

    property color iconsSettingsColor: root.onIconColor
    property bool showSound: false
    Connections { target: root; function onExpandedChanged() { if (!root.expanded) menu.showSound = false } }
    readonly property bool isVertical: false
    property int marginSeperator: root.gap

    // ---------- sizing ----------
    readonly property int contentWidth: 340
    readonly property int rowH: 58
    readonly property int tallH: rowH * 3
    readonly property int headerH: 40

    Layout.preferredWidth: contentWidth + root.pad * 2
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    Layout.preferredHeight: wrapper.implicitHeight + root.pad * 2
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight
    clip: true

    ColumnLayout {
        id: wrapper
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap
        opacity: menu.showSound ? 0 : 1
        visible: opacity > 0
        transform: Translate { x: menu.showSound ? -24 : 0; Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        // ---------- header: user · battery · power ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: headerH
            Layout.maximumHeight: headerH
            spacing: 10

            Item {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                Rectangle { id: avatarMask; anchors.fill: parent; radius: width / 2; visible: false }
                Image {
                    anchors.fill: parent
                    source: userInfo.urlAvatar
                    visible: userInfo.urlAvatar != ""
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: avatarMask }
                }
                Lib.Bubble { anchors.fill: parent; on: false; visible: userInfo.urlAvatar == ""
                    Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; source: "user-identity" } }
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: userInfo.name
                font.pixelSize: root.labelSize + 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                visible: battery.hasBattery
                text: battery.percent + "%"
                font.pixelSize: root.subLabelSize
                opacity: 0.7
            }
            Lib.Bubble {
                id: powerBubble
                on: false
                Layout.preferredWidth: root.bubbleSize; Layout.preferredHeight: root.bubbleSize
                Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; source: "system-shutdown-symbolic" }
                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: powerBubble.hovered = true; onExited: powerBubble.hovered = false; onClicked: sm.requestLogoutPrompt() }
                PlasmaComponents3.ToolTip { text: i18n("Power") }
            }
        }

        // ---------- row 1: connectivity module + focus/toggles ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: tallH
            Layout.maximumHeight: tallH
            spacing: root.gap

            Lib.Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    Lib.RowItem {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: network.activeConnectionIcon
                        label: i18n("Network")
                        sublabel: netConnected ? menu.primaryConnection : (wifiAvailable && !wifiOn ? i18n("Wi-Fi Off") : i18n("Not Connected"))
                        on: netConnected || wifiOn
                        showArrow: true
                        onToggled: wifiAvailable ? network.handler.enableWireless(!wifiOn) : sectionNetworks.toggleNetworkSection()
                        onActivated: sectionNetworks.toggleNetworkSection()
                    }
                    Lib.RowItem {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: btOn ? "network-bluetooth-activated-symbolic" : "network-bluetooth-inactive-symbolic"
                        label: i18n("Bluetooth")
                        sublabel: Funcs.getBtDevice()
                        on: btOn
                        onToggled: Funcs.toggleBluetooth()
                        onActivated: KCMLauncher.openSystemSettings("kcm_bluetooth")
                    }
                    Lib.RowItem {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "configure"
                        label: i18n("Settings")
                        sublabel: i18n("System Settings")
                        on: true
                        onToggled: KCMLauncher.openSystemSettings("")
                        onActivated: KCMLauncher.openSystemSettings("")
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: (contentWidth - root.gap) / 2
                Layout.maximumWidth: Layout.preferredWidth
                Layout.fillHeight: true
                spacing: root.gap

                // Focus-style long tile: Do Not Disturb
                Lib.Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rowH + 14
                    Lib.RowItem {
                        anchors.fill: parent
                        icon: dndOn ? "notifications-disabled-symbolic" : "notifications-symbolic"
                        label: i18n("Do Not Disturb")
                        sublabel: dndOn ? i18n("On") : i18n("Off")
                        on: dndOn
                        onToggled: Funcs.toggleDnd()
                        onActivated: Funcs.toggleDnd()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: root.gap
                    Lib.Tile {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "redshift-status-on"
                        label: i18n("Night Light")
                        on: nightLight.on
                        onClicked: nightLight.toggle()
                    }
                    Lib.Tile {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "video-display-symbolic"
                        label: i18n("Displays")
                        on: false
                        onClicked: KCMLauncher.openSystemSettings("kcm_kscreen")
                    }
                }
            }
        }

        // ---------- row 2: Display ----------
        Lib.Card {
            Layout.fillWidth: true
            Layout.preferredHeight: displayContent.implicitHeight + 24
            Layout.maximumHeight: Layout.preferredHeight
            visible: brightnessAvailable
            ColumnLayout {
                id: displayContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 6
                PlasmaComponents3.Label { text: i18n("Display"); font.pixelSize: root.labelSize; font.weight: Font.DemiBold }
                Lib.PillSlider {
                    Layout.fillWidth: true
                    icon: "brightness-high-symbolic"
                    from: mainScreen ? (mainScreen.maxBrightness > 100 ? 1 : 0) : 0
                    to: mainScreen ? mainScreen.maxBrightness : 100
                    value: mainScreen ? mainScreen.brightness : 0
                    onMoved: v => { if (mainScreen) screenBrightnessControl.setBrightness(mainScreen.displayName, Math.round(v)) }
                }
            }
        }

        // ---------- row 3: Sound (chevron opens the Sound page) ----------
        Lib.Card {
            id: soundCard
            Layout.fillWidth: true
            Layout.preferredHeight: soundContent.implicitHeight + 24
            Layout.maximumHeight: Layout.preferredHeight
            visible: sinkAvailable

            ColumnLayout {
                id: soundContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    PlasmaComponents3.Label { text: i18n("Sound"); font.pixelSize: root.labelSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    PlasmaComponents3.Label {
                        text: sink ? Math.round(sink.volume / PulseAudio.NormalVolume * 100) + "%" : ""
                        font.pixelSize: root.subLabelSize; opacity: 0.68
                    }
                    Lib.IconButton { icon: "arrow-right"; onClicked: menu.showSound = true; tooltip: i18n("Output and input devices") }
                }
                Lib.PillSlider {
                    Layout.fillWidth: true
                    icon: sink ? Funcs.volIconName(sink.volume, sink.muted) : "audio-volume-high-symbolic"
                    from: 0; to: 100
                    value: sink ? sink.volume / PulseAudio.NormalVolume * 100 : 0
                    onMoved: v => { if (sink) sink.volume = Math.round(v) * PulseAudio.NormalVolume / 100 }
                }
            }
        }

        // (Now Playing moved out: the top bar's media widget has its own lobe in Sirca Shell)
    }

    // ---------- Sound page: slider + output / input device pickers, same popup size ----------
    ColumnLayout {
        id: soundPage
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap
        opacity: menu.showSound ? 1 : 0
        visible: opacity > 0
        transform: Translate { x: menu.showSound ? 0 : 24; Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: headerH
            spacing: 10
            Lib.Bubble {
                id: backBubble
                on: false
                Layout.preferredWidth: root.bubbleSize; Layout.preferredHeight: root.bubbleSize
                Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; source: "arrow-left" }
                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: backBubble.hovered = true; onExited: backBubble.hovered = false; onClicked: menu.showSound = false }
            }
            PlasmaComponents3.Label { Layout.fillWidth: true; text: i18n("Sound"); font.pixelSize: root.labelSize + 2; font.weight: Font.DemiBold }
            Lib.IconButton { icon: "configure"; tooltip: i18n("Audio settings"); onClicked: { KCMLauncher.openSystemSettings("kcm_pulseaudio"); root.expanded = false } }
        }

        Lib.Card {
            Layout.fillWidth: true
            Layout.preferredHeight: pageSlider.implicitHeight + 24
            ColumnLayout {
                id: pageSlider
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 12
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents3.Label { text: i18n("Volume"); font.pixelSize: root.labelSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    PlasmaComponents3.Label { text: sink ? Math.round(sink.volume / PulseAudio.NormalVolume * 100) + "%" : ""; font.pixelSize: root.subLabelSize; opacity: 0.68 }
                }
                Lib.PillSlider {
                    Layout.fillWidth: true
                    icon: sink ? Funcs.volIconName(sink.volume, sink.muted) : "audio-volume-high-symbolic"
                    from: 0; to: 100
                    value: sink ? sink.volume / PulseAudio.NormalVolume * 100 : 0
                    onMoved: v => { if (sink) sink.volume = Math.round(v) * PulseAudio.NormalVolume / 100 }
                }
            }
        }

        Lib.Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentHeight: deviceLists.implicitHeight
                clip: true
                interactive: contentHeight > height
                ColumnLayout {
                    id: deviceLists
                    width: parent.width
                    spacing: 2
                    PlasmaComponents3.Label { text: i18n("Output"); font.pixelSize: root.subLabelSize; font.weight: Font.DemiBold; opacity: 0.6; Layout.leftMargin: 8; Layout.topMargin: 4 }
                    Repeater {
                        model: PulseObjectFilterModel { filterOutInactiveDevices: true; sourceModel: SinkModel {} }
                        delegate: Lib.DeviceRow { Layout.fillWidth: true; icon: "audio-speakers-symbolic" }
                    }
                    PlasmaComponents3.Label { text: i18n("Input"); font.pixelSize: root.subLabelSize; font.weight: Font.DemiBold; opacity: 0.6; Layout.leftMargin: 8; Layout.topMargin: 10 }
                    Repeater {
                        model: PulseObjectFilterModel { filterOutInactiveDevices: true; sourceModel: SourceModel {} }
                        delegate: Lib.DeviceRow { Layout.fillWidth: true; icon: "audio-input-microphone-symbolic" }
                    }
                }
            }
        }
    }
}
