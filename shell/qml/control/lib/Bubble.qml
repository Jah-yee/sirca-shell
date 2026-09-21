/*
 *    Round toggle "bubble": solid frosted white with a sheen when on, frosted glass when off (no accent colour).
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import SircaShell
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: bubble
    property bool on: true
    property bool hovered: false
    radius: height / 2
    color: on ? root.toggleOnColor : root.toggleOffColor
    border.width: 1
    border.color: hovered ? Config.fg(on ? 0.95 : 0.30) : (on ? Config.fg(0.55) : root.cardRimColor)
    scale: hovered ? 1.07 : 1.0
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    // hover wash
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Config.fg(bubble.hovered ? 0.10 : 0.0)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0;  color: Config.fg(bubble.on ? 0.35 : 0.10) }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }
}
