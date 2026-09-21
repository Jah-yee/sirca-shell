/*
 *    Small round icon button with a hover glow (media controls, chevrons, back).
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import SircaShell
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    id: btn
    property string icon: ""
    property int size: 26
    property int iconSize: Math.round(size * 0.6)
    property string tooltip: ""
    signal clicked
    Layout.preferredWidth: size
    Layout.preferredHeight: size
    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.pressed ? Config.fg(0.18) : mouse.containsMouse ? root.toggleOffColor : "transparent"
        border.width: mouse.containsMouse ? 1 : 0
        border.color: root.cardRimColor
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: btn.iconSize; height: width
        source: btn.icon
        opacity: mouse.containsMouse ? 1 : 0.8
        scale: mouse.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 80 } }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    PlasmaComponents3.ToolTip { visible: btn.tooltip !== "" && mouse.containsMouse; text: btn.tooltip }
}
