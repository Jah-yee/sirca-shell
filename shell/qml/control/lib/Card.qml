/*
 *    Glass Control card. Upstream drew each card with the Plasma theme's
 *    dialog-background SVG tiles plus a second shadow copy; this draws a
 *    frosted-glass tile instead (scheme-tinted translucent face, thin rim,
 *    top sheen) so the cards speak the same language as the Glass KWin
 *    effect on the panels. Children are placed directly on the card.
 *
 *    SPDX-FileCopyrightText: zayronxio (original), onur (glass re-skin)
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: card
    property bool globalBool: true
    property bool hovered: false
    property real radius: root.cardRadius

    Rectangle {
        id: face
        anchors.fill: parent
        radius: card.radius
        z: -1
        visible: card.globalBool

        color: Qt.rgba(root.themeBgColor.r, root.themeBgColor.g, root.themeBgColor.b,
                       Math.min(1.0, root.cardAlpha + (card.hovered ? root.cardHoverBoost : 0)))
        Behavior on color { ColorAnimation { duration: 120 } }

        border.width: 1
        border.color: card.hovered ? root.cardRimHoverColor : root.cardRimColor
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // Top sheen: light catching the upper edge of the glass
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0;  color: root.cardSheenColor }
                GradientStop { position: 0.42; color: "transparent" }
                GradientStop { position: 1.0;  color: root.cardFootColor }
            }
        }

        // Inner hairline just inside the rim, like the bars' outline
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.width: 1
            border.color: root.cardInnerRimColor
        }
    }
}
