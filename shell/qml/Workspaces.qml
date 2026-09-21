// Workspace indicator for the bar: one dot per virtual desktop, the current one stretched into a short pill. Click a
// dot to go there, scroll over it to walk through them. With a single desktop there is nothing to indicate: width 0.
import QtQuick
import org.kde.taskmanager as TaskManager
import SircaShell

Item {
    id: ws
    readonly property int count: info.numberOfDesktops
    property bool allowed: true
    readonly property bool shown: count > 1 && allowed
    visible: shown
    width: shown ? row.implicitWidth + 16 : 0; height: 27
    TaskManager.VirtualDesktopInfo { id: info }
    function go(step) { const ids = info.desktopIds; const i = ids.indexOf(info.currentDesktop); if (i < 0) return
        info.requestActivate(ids[(i + step + ids.length) % ids.length]) }
    Rectangle { anchors.fill: parent; radius: height / 2; color: Config.fg(hh.hovered ? 0.07 : 0); Behavior on color { ColorAnimation { duration: Config.quick } } }
    HoverHandler { id: hh }
    WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: e => { acc += e.angleDelta.y; if (Math.abs(acc) >= 120) { ws.go(acc > 0 ? -1 : 1); acc = 0 } } }
    Row { id: row; anchors.centerIn: parent; spacing: 6
        Repeater { model: ws.shown ? info.desktopIds : []
            Item { id: dot; required property var modelData; required property int index
                readonly property bool current: modelData === info.currentDesktop
                width: current ? 18 : 7; height: 27; Behavior on width { NumberAnimation { duration: Config.normal; easing.type: Easing.OutCubic } }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 7; radius: 3.5
                    color: Config.fg(dot.current ? 0.95 : (dh.hovered ? 0.6 : 0.32)); Behavior on color { ColorAnimation { duration: Config.quick } } }
                HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: info.requestActivate(dot.modelData) } } } }
}
