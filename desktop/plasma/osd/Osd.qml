/*
    Onyr-Dark on-screen display (volume / brightness / keyboard layout …).
    Compact frosted pill in the style of the Glass Control popup: icon, a
    14 px pill bar with rounded ends, a small percentage. The window frame
    (frost, blur, rounded corners) comes from the desktop theme's dialog
    background, so it matches the panels and popups automatically.

    Same properties as plasma-workspace's stock Osd.qml, which the shell sets.

    SPDX-FileCopyrightText: 2014 Martin Klapetek <mklapetek@kde.org>
    SPDX-FileCopyrightText: 2026 onur
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.workspace.osd

OsdWindow {
    id: window

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property alias timeout: osd.timeout
    property alias osdValue: osd.osdValue
    property alias osdMaxValue: osd.osdMaxValue
    property alias osdAdditionalText: osd.osdAdditionalText
    property alias icon: osd.icon
    property alias showingProgress: osd.showingProgress

    width: mainItem.implicitWidth + leftPadding + rightPadding
    height: mainItem.implicitHeight + topPadding + bottomPadding

    mainItem: Item {
        id: osd

        property int timeout: 1800
        property var osdValue
        property int osdMaxValue: 100
        property string osdAdditionalText: ""
        property string icon
        property bool showingProgress: false

        readonly property real fraction: showingProgress && osdMaxValue > 0
            ? Math.max(0, Math.min(1, Number(osdValue) / osdMaxValue)) : 0
        readonly property string labelText: (showingProgress ? osdAdditionalText : osdValue) ?? ""
        readonly property bool overdrive: showingProgress && Number(osdValue) > 100

        implicitWidth: 300
        implicitHeight: 48

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 12

            // Text-only OSDs (keyboard layout, media player names, …): icon + centred text
            Kirigami.Icon {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                source: osd.icon + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : "")
                visible: !osd.showingProgress && valid
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: !osd.showingProgress
                text: osd.labelText
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Progress OSDs: the Glass Control pill - thick track, bright fill, icon riding inside the fill
            Item {
                id: bar
                visible: osd.showingProgress
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                readonly property int iconZone: height

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    clip: true

                    Rectangle {
                        id: fill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(bar.iconZone, osd.fraction * parent.width)
                        radius: height / 2
                        color: osd.overdrive ? Kirigami.Theme.neutralTextColor : Qt.rgba(1, 1, 1, 0.92)
                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }
                }
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: (bar.iconZone - width) / 2
                    width: bar.height * 0.6
                    height: width
                    source: osd.icon + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : "")
                    isMask: true
                    color: "#1e1e1e"
                    visible: valid
                }
            }

            PlasmaComponents3.Label {
                id: percentLabel
                visible: osd.showingProgress
                Layout.preferredWidth: metrics.advanceWidth
                horizontalAlignment: Text.AlignRight
                text: i18nc("Percentage value", "%1%", Number(osd.osdValue))
                font.pixelSize: 13
                font.weight: Font.DemiBold
                opacity: 0.85
                color: osd.overdrive ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                TextMetrics { id: metrics; font: percentLabel.font; text: "150%" }
            }
        }
    }
}
