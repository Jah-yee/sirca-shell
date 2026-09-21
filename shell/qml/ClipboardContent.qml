// The inside of the clipboard panel, separate from the surface so it can be rendered in a test with made-up entries
// (never capture the real clipboard history).
import QtQuick
import org.kde.kirigami as Kirigami
import SircaShell

Item {
    id: root
    property var entries
    property int fieldH: 58
    property alias field: field
    property alias list: list
    signal picked(int row)
    signal closeRequested()
    clip: true
    function ago(date) { if (!date) return ""; const s = Math.max(0, (Date.now() - new Date(date).getTime()) / 1000);
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + " min" : s < 86400 ? Math.floor(s / 3600) + " h" : Math.floor(s / 86400) + " d" }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Item { width: parent.width; height: root.fieldH
        Kirigami.Icon { id: clipIcon; x: 22; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; source: "edit-paste-symbolic"; isMask: true; color: Config.fgSolid; opacity: 0.75; roundToIconSize: false }
        Text { anchors.left: field.left; anchors.verticalCenter: parent.verticalCenter; visible: field.text === ""; color: Config.inkDim; font.pixelSize: 18; text: "Clipboard history" }
        TextInput { id: field; anchors.left: clipIcon.right; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 22; anchors.verticalCenter: parent.verticalCenter
            color: Config.ink; font.pixelSize: 18; clip: true; focus: true; selectByMouse: true; selectionColor: Config.fg(0.25); selectedTextColor: Config.fgSolid
            onTextChanged: { if (root.entries && root.entries.filter !== undefined) root.entries.filter = text; list.currentIndex = 0 }
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { if (text !== "") text = ""; else root.closeRequested(); e.accepted = true }
                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) { list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1); e.accepted = true }
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { list.currentIndex = Math.max(0, list.currentIndex - 1); e.accepted = true }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.picked(list.currentIndex); e.accepted = true }
                else if (e.key === Qt.Key_Delete && text === "" && root.entries) { root.entries.remove(list.currentIndex); e.accepted = true }
                else if (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier) && root.entries) { root.entries.togglePin(list.currentIndex); e.accepted = true } } } }
    Rectangle { y: root.fieldH - 1; x: 16; width: parent.width - 32; height: 1; color: Config.fg(0.08) }

    ListView { id: list; x: 8; y: root.fieldH + 6; width: parent.width - 16; height: parent.height - root.fieldH - 46; model: root.entries; clip: true; spacing: 2
        boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height; highlightMoveDuration: 0; keyNavigationEnabled: false
        delegate: Item { id: row
            required property int index
            required property var model
            readonly property bool sel: index === list.currentIndex
            readonly property bool isImage: model.kind === "image"
            width: list.width; height: isImage ? 84 : (body.lineCount > 1 ? 58 : 44)
            Rectangle { anchors.fill: parent; radius: 12; color: Config.fg(row.sel ? 0.13 : (rh.hovered ? 0.06 : 0)); border.width: 1; border.color: Config.fg(row.sel ? 0.16 : 0)
                Behavior on color { ColorAnimation { duration: Config.quick } } }
            Kirigami.Icon { id: kindIcon; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; isMask: true; color: Config.fgSolid; opacity: 0.7; roundToIconSize: false
                source: row.model.kind === "image" ? "image-x-generic-symbolic" : row.model.kind === "files" ? "folder-symbolic" : "edit-copy-symbolic" }
            Image { visible: row.isImage; x: 40; anchors.verticalCenter: parent.verticalCenter; width: 120; height: 68; source: row.isImage ? row.model.image : ""; sourceSize: Qt.size(240, 136); fillMode: Image.PreserveAspectCrop; asynchronous: true
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Config.fg(0.12); radius: 6 } }
            Text { id: body; visible: !row.isImage; anchors.left: kindIcon.right; anchors.leftMargin: 12; anchors.right: meta.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: row.model.kind === "files" ? String(row.model.text).split("\n").map(u => decodeURIComponent(u.replace(/^file:\/\//, ""))).join("   ") : row.model.preview
                color: Config.ink; font.pixelSize: 13; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText }
            // pin: stays at the top, survives "Clear history", is never pushed out. Shown while hovering, and always on a pinned entry
            Item { id: pin; anchors.right: del.left; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; opacity: row.model.pinned ? 1 : (rh.hovered || row.sel ? 1 : 0)
                Behavior on opacity { NumberAnimation { duration: Config.quick } }
                Rectangle { anchors.fill: parent; radius: 11; color: row.model.pinned ? Config.onFill : Config.fg(ph.hovered ? 0.18 : 0.07) }
                Kirigami.Icon { anchors.centerIn: parent; width: 11; height: 11; source: "window-pin-symbolic"; isMask: true; color: row.model.pinned ? Config.onFg : Config.fgSolid; roundToIconSize: false }
                HoverHandler { id: ph } TapHandler { onTapped: if (root.entries) root.entries.togglePin(row.index) } }
            Column { id: meta; anchors.right: pin.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                Text { anchors.right: parent.right; text: root.ago(row.model.time); color: Config.inkDim; font.pixelSize: 11 }
                Text { anchors.right: parent.right; text: row.model.note || ""; visible: text !== ""; color: Config.inkDim; font.pixelSize: 11; opacity: 0.8 } }
            Item { id: del; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; opacity: rh.hovered || row.sel ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Config.quick } }
                Rectangle { anchors.fill: parent; radius: 11; color: Config.fg(dh.hovered ? 0.18 : 0.07) }
                Kirigami.Icon { anchors.centerIn: parent; width: 10; height: 10; source: "window-close-symbolic"; isMask: true; color: Config.fgSolid; roundToIconSize: false }
                HoverHandler { id: dh } TapHandler { onTapped: if (root.entries) root.entries.remove(row.index) } }
            HoverHandler { id: rh }
            TapHandler { enabled: !dh.hovered && !ph.hovered; onTapped: { list.currentIndex = row.index; root.picked(row.index) } } } }   // a tap on pin / remove is not a pick (handlers all see the same tap)
    Text { visible: list.count === 0; x: 24; y: root.fieldH + 22; text: field.text !== "" ? "Nothing matches" : "Nothing copied yet"; color: Config.inkDim; font.pixelSize: 14 }

    // footer
    Item { y: parent.height - 38; width: parent.width; height: 38
        Rectangle { x: 16; width: parent.width - 32; height: 1; color: Config.fg(0.08) }
        Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: "Enter copies  ·  Delete removes  ·  Ctrl+P pins"; color: Config.inkDim; font.pixelSize: 11 }
        Rectangle { visible: list.count > 0; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; height: 26; width: cl.implicitWidth + 20; radius: 13
            color: Config.fg(clh.hovered ? 0.13 : 0.06); border.width: 1; border.color: Config.fg(0.10)
            Text { id: cl; anchors.centerIn: parent; text: "Clear unpinned"; color: Config.ink; font.pixelSize: 11; font.weight: Font.Medium }
            HoverHandler { id: clh } TapHandler { onTapped: if (root.entries) root.entries.clear() } } }
}
