// Thin glass slider: a line, a bright fill, a knob that shows up with the pointer. `moved` fires while dragging,
// `committed` on release (and on wheel).
import QtQuick
import SircaShell

Item {
    id: sl
    property real from: 0
    property real to: 1
    property real step: 0                     // 0 = continuous
    property real value: 0
    readonly property bool dragging: ma.pressed
    property real dragValue: value
    readonly property real shown: dragging ? dragValue : value
    signal moved(real v)
    signal committed(real v)
    implicitHeight: 22; implicitWidth: 220
    function snap(v) { v = Math.max(from, Math.min(to, v)); return step > 0 ? Math.round((v - from) / step) * step + from : v }
    readonly property real frac: to > from ? (shown - from) / (to - from) : 0
    Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Config.fg(0.14) }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(height, track.width * sl.frac); height: 4; radius: 2; color: Config.fg(0.92) }
    Rectangle { x: (track.width - width) * sl.frac; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: Config.fgSolid
        scale: ma.pressed ? 1.15 : (ma.containsMouse ? 1 : 0.85)
        Behavior on scale { NumberAnimation { duration: Config.quick } } }
    MouseArea { id: ma; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
        function at(mx) { return sl.snap(sl.from + (sl.to - sl.from) * Math.max(0, Math.min(1, (mx - 4) / sl.width))) }
        onPressed: e => { sl.dragValue = at(e.x); sl.moved(sl.dragValue) }
        onPositionChanged: e => { if (pressed) { const v = at(e.x); if (v !== sl.dragValue) { sl.dragValue = v; sl.moved(v) } } }
        onReleased: sl.committed(sl.dragValue)
        onWheel: w => { const d = (sl.step > 0 ? sl.step : (sl.to - sl.from) / 40) * (w.angleDelta.y > 0 ? 1 : -1); sl.committed(sl.snap(sl.value + d)) } }
}
