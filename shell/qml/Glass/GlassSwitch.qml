// Glass switch: a pill track, a white knob; on = brighter track (no accent colour, like the rest of the desktop).
import QtQuick
import SircaShell

Item {
    id: sw
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: 44; implicitHeight: 26
    Rectangle { anchors.fill: parent; radius: height / 2
        color: sw.checked && !Config.dark ? Config.accent : Config.fg(sw.checked ? 0.34 : 0.10); border.width: 1; border.color: Config.fg(sw.checked ? 0.30 : 0.14)
        Behavior on color { ColorAnimation { duration: Config.quick } } }
    Rectangle { y: 3; x: sw.checked ? parent.width - width - 3 : 3; width: 20; height: 20; radius: 10; color: sw.checked ? "white" : Config.fg(0.75)   // literal-ok: the knob is white on any track
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
    TapHandler { onTapped: sw.toggled(!sw.checked) }
}
