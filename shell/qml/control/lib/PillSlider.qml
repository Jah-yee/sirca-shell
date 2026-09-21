/*
 *    Apple-style pill slider: thick rounded track, bright fill, no handle,
 *    icon riding inside the fill at the left.
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import SircaShell
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: pill
    property real from: 0
    property real to: 100
    property real value: 0
    property string icon: ""
    property bool enabled: true
    signal moved(real newValue)

    implicitHeight: 28
    readonly property real fraction: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property int iconZone: height

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.isDarkTheme ? Config.fg(0.12) : Qt.rgba(0, 0, 0, 0.10)
        border.width: 1
        border.color: root.cardRimColor
        clip: true

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(pill.iconZone, pill.fraction * track.width)
            radius: height / 2
            color: root.isDarkTheme ? Config.fg(0.92) : Config.fg(1.0)
            Behavior on width { enabled: !mouse.pressed; NumberAnimation { duration: 90 } }
        }
    }

    Kirigami.Icon {
        id: glyph
        source: pill.icon
        width: pill.height * 0.58
        height: width
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: (pill.iconZone - width) / 2
        color: "#1e1e1e"
        isMask: true
        visible: pill.icon !== ""
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: pill.enabled
        function set(x) {
            var f = Math.max(0, Math.min(1, x / width));
            var v = pill.from + f * (pill.to - pill.from);
            pill.value = v;
            pill.moved(v);
        }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x) }
        onWheel: wheel => {
            var step = (pill.to - pill.from) / 20;
            var v = Math.max(pill.from, Math.min(pill.to, pill.value + (wheel.angleDelta.y > 0 ? step : -step)));
            pill.value = v; pill.moved(v);
        }
    }
}
