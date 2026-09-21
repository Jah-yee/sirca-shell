// A tray item's menu as a glass popup. The entries come from the app over com.canonical.dbusmenu (TrayItem.fetchMenu);
// submenus are pages inside the same popup, with a back row. Same rows as every other list in the shell.
import QtQuick
import org.kde.kirigami as Kirigami
import SircaShell

Item {
    id: menu
    property var item: null
    signal closeRequested()
    property var stack: []                           // [{label, entries}], the last one is shown
    readonly property var entries: stack.length > 0 ? stack[stack.length - 1].entries : []
    property bool loading: false
    implicitWidth: 264
    implicitHeight: Math.max(44, col.implicitHeight + 8)
    function show(it) { item = it; stack = []; loading = true; if (it) it.fetchMenu() }
    Connections { target: menu.item; ignoreUnknownSignals: true
        function onMenuReady(entries) { menu.loading = false; menu.stack = [{ label: menu.item ? menu.item.title : "", entries: entries }] } }

    Column { id: col; x: 4; y: 4; width: parent.width - 8
        // heading: the app, or "back" inside a submenu
        Item { width: parent.width; height: 34
            readonly property bool deep: menu.stack.length > 1
            Rectangle { anchors.fill: parent; radius: 10; color: Config.fg(parent.deep && bh.hovered ? 0.08 : 0) }
            Kirigami.Icon { id: backIcon; x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; source: "go-previous-symbolic"; isMask: true; color: Config.fgSolid; opacity: 0.8; visible: parent.deep; roundToIconSize: false }
            Text { x: parent.deep ? 30 : 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - 10; elide: Text.ElideRight
                text: menu.stack.length > 0 ? menu.stack[menu.stack.length - 1].label : (menu.item ? menu.item.title : ""); color: Config.inkDim
                font.pixelSize: 11; font.weight: Font.Medium; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.6 }
            HoverHandler { id: bh } TapHandler { enabled: parent.deep; onTapped: { const s = menu.stack.slice(); s.pop(); menu.stack = s } } }
        Text { visible: menu.loading; x: 10; height: 30; verticalAlignment: Text.AlignVCenter; text: "Loading…"; color: Config.inkDim; font.pixelSize: 13 }
        Text { visible: !menu.loading && menu.entries.length === 0; x: 10; height: 30; verticalAlignment: Text.AlignVCenter; text: "No menu"; color: Config.inkDim; font.pixelSize: 13 }
        Repeater { model: menu.entries
            delegate: Item { id: row
                required property var modelData
                width: col.width; height: modelData.separator ? 9 : 34
                Rectangle { visible: row.modelData.separator; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Config.fg(0.08) }
                Item { anchors.fill: parent; visible: !row.modelData.separator; opacity: row.modelData.enabled ? 1 : 0.4
                    Rectangle { anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: 1; radius: 10
                        color: Config.fg(rt.pressed ? 0.16 : (rh.hovered && row.modelData.enabled ? 0.10 : 0)); border.width: 1; border.color: Config.fg(rh.hovered && row.modelData.enabled ? 0.12 : 0)
                        Behavior on color { ColorAnimation { duration: Config.quick } } }
                    // check / radio mark, else the entry's own icon
                    Item { id: lead; x: 8; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter
                        Rectangle { anchors.centerIn: parent; visible: row.modelData.toggle !== ""; width: 14; height: 14; radius: row.modelData.toggle === "radio" ? 7 : 4; color: Config.fg(row.modelData.checked ? 0.9 : 0.08); border.width: 1; border.color: Config.fg(0.3)
                            Rectangle { anchors.centerIn: parent; visible: row.modelData.checked; width: 6; height: 6; radius: row.modelData.toggle === "radio" ? 3 : 1.5; color: Config.onFg } }
                        Kirigami.Icon { anchors.fill: parent; visible: row.modelData.toggle === "" && row.modelData.icon !== ""; source: row.modelData.icon; roundToIconSize: false } }
                    Text { anchors.left: lead.right; anchors.leftMargin: 8; anchors.right: next.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label; color: Config.ink; font.pixelSize: 13; elide: Text.ElideRight; textFormat: Text.PlainText }
                    Kirigami.Icon { id: next; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: row.modelData.children.length > 0 ? 13 : 0; height: 13
                        source: "go-next-symbolic"; isMask: true; color: Config.fgSolid; opacity: 0.7; visible: row.modelData.children.length > 0; roundToIconSize: false }
                    HoverHandler { id: rh }
                    TapHandler { id: rt; enabled: row.modelData.enabled
                        onTapped: { if (row.modelData.children.length > 0) menu.stack = menu.stack.concat([{ label: row.modelData.label, entries: row.modelData.children }]);
                                    else { menu.item.menuEvent(row.modelData.id); menu.closeRequested() } } } } } }
    }
}
