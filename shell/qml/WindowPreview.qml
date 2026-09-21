// One window of the hovered app: live PipeWire thumbnail, title, close button. Tap activates the window.
import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire
import org.kde.kirigami as Kirigami
import SircaShell

Item {
    id: root
    property string title: ""
    property var uuid: ""
    property var icon
    property bool isActive: false
    signal activate()
    signal close()
    signal peek(bool on)
    TaskManager.ScreencastingRequest { id: cast; uuid: root.visible ? root.uuid : "" }

    Rectangle { anchors.fill: parent; radius: 12; color: Config.fg(hh.hovered ? 0.10 : (root.isActive ? 0.06 : 0)); border.width: 1; border.color: Config.fg(hh.hovered || root.isActive ? 0.14 : 0)
        Behavior on color { ColorAnimation { duration: Config.quick } } }
    Row { x: 8; y: 6; height: 18; spacing: 6; width: parent.width - 16 - 20
        Kirigami.Icon { width: 16; height: 16; source: root.icon; anchors.verticalCenter: parent.verticalCenter }
        Text { width: parent.width - 22; text: root.title; color: Config.ink; elide: Text.ElideRight; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter } }
    Item { x: 8; y: 28; width: parent.width - 16; height: parent.height - 36
        PipeWire.PipeWireSourceItem { id: pw; anchors.fill: parent; nodeId: cast.nodeId; visible: cast.nodeId > 0 }
        Kirigami.Icon { anchors.centerIn: parent; width: 48; height: 48; source: root.icon; visible: !pw.visible; opacity: 0.8 } }
    HoverHandler { id: hh; onHoveredChanged: root.peek(hovered) }
    TapHandler { onTapped: root.activate() }
    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: root.close() }
    Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 5; width: 18; height: 18; radius: 9; opacity: hh.hovered ? 1 : 0
        color: Config.fg(xh.hovered ? 0.22 : 0.10); Behavior on opacity { NumberAnimation { duration: Config.quick } }
        Text { anchors.centerIn: parent; text: "✕"; color: Config.ink; font.pixelSize: 10 }
        HoverHandler { id: xh }
        TapHandler { onTapped: root.close() } }
}
