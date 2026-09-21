// Search (Meta+Space): one field for everything. Apps, settings, files, maths, unit conversion, windows, shell commands …
// The results come from KRunner's engine (Milou.ResultsModel), so every runner the system has works; the panel is ours.
// An overlay surface that takes the keyboard while it is up. Only the panel takes input (the rest of the surface is
// click-through), and the search closes when it loses keyboard focus, i.e. as soon as anything else is clicked: that
// click, or a window drag, goes to its window untouched.
import QtQuick
import org.kde.milou as Milou
import org.kde.kirigami as Kirigami
import SircaShell
import "Glass"

Window {
    id: sw
    color: "transparent"
    flags: Qt.FramelessWindowHint
    visible: false
    width: Screen.width; height: Screen.height
    signal opened()

    readonly property int panelW: 700
    readonly property int fieldH: 62
    readonly property int rowH: 46
    readonly property int maxListH: 9 * rowH + 40
    readonly property real listH: list.count > 0 ? Math.min(list.contentHeight + 14, maxListH) : (field.text !== "" && !results.querying ? 54 : 0)
    property real panelH: fieldH + listH
    Behavior on panelH { Spring {} }
    readonly property rect panel: Qt.rect(Math.round((width - panelW) / 2), Math.round(height * 0.20), panelW, Math.round(panelH))
    property bool setupDone: false
    property real show: 0                                     // content fade / rise
    Behavior on show { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    function toggle() { visible ? close_() : open() }
    function open() {
        if (!setupDone) { Shell.setupSearch(sw); setupDone = true }
        field.text = ""; list.currentIndex = 0
        visible = true; show = 1; field.forceActiveFocus(); shapeLater.restart(); sw.opened()
        armed = false; Shell.setKeyboardMode(sw, "exclusive"); relax.restart()
    }
    // same focus hand-over as the bar's popups (Surface.popupFocus): grab, relax, then close on loss
    property bool armed: false
    Timer { id: relax; interval: 160; onTriggered: { Shell.setKeyboardMode(sw, "ondemand"); arm.restart() } }
    Timer { id: arm; interval: 220; onTriggered: sw.armed = true }
    onActiveChanged: if (visible && armed && !previewing && !active) lost.restart(); else lost.stop()
    Timer { id: lost; interval: 80; onTriggered: if (sw.visible && !sw.active) sw.close_() }
    // for looking at it (screenshots, tests): opens with a query, WITHOUT taking the keyboard, and closes by itself
    function preview(q) {
        if (!setupDone) { Shell.setupSearch(sw); setupDone = true }
        Shell.setKeyboardMode(sw, "none"); previewing = true
        field.text = q; list.currentIndex = 0; visible = true; show = 1; shapeLater.restart(); previewEnd.restart()
    }
    property bool previewing: false
    Timer { id: previewEnd; interval: 3500; onTriggered: sw.close_() }
    function close_() {
        if (previewing) { previewing = false; Shell.setKeyboardMode(sw, "exclusive") }
        if (!visible) return;
        visible = false; show = 0; field.text = ""; armed = false; relax.stop(); arm.stop()
        Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "clearLobes", "sii", ["sirca-shell", sw.width, sw.height])
    }
    function runCurrent() {
        if (list.count < 1) return;
        const i = Math.max(0, Math.min(list.currentIndex, list.count - 1));
        if (results.run(results.index(i, 0))) close_();
    }
    Timer { id: shapeLater; interval: 16; onTriggered: sw.pushShape() }
    function pushShape() {
        if (!visible) return;
        Shell.setShape(sw, [{ x: panel.x, y: panel.y, w: panel.width, h: panel.height, r: Config.cornerRadius }]);   // blur AND input: only the panel
        Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "setLobes", "siivdd", ["sirca-shell", sw.width, sw.height, [panel.x, panel.y, panel.width, panel.height], Config.cornerRadius, 1]);
        sw.requestUpdate();
    }
    onPanelChanged: if (visible) shapeLater.restart()
    onWidthChanged: if (visible) shapeLater.restart()
    onHeightChanged: if (visible) shapeLater.restart()

    Milou.ResultsModel { id: results; queryString: sw.visible ? field.text : ""; limit: 14 }

    LobeShape { anchors.fill: parent; bar: sw.panel }

    Item { x: sw.panel.x; y: sw.panel.y; width: sw.panel.width; height: sw.panel.height; clip: true
        opacity: sw.show; transform: Translate { y: (1 - sw.show) * 10 }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }                                  // clicks on the panel stay here

        // ---- the field ----
        Item { id: fieldRow; width: parent.width; height: sw.fieldH
            Kirigami.Icon { id: glass; x: 22; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; source: "search-symbolic"; isMask: true; color: Config.fgSolid; opacity: 0.75; roundToIconSize: false }
            Text { anchors.left: field.left; anchors.verticalCenter: parent.verticalCenter; visible: field.text === ""; color: Config.inkDim; font.pixelSize: 20
                text: "Search apps, files, settings, or type a sum" }
            TextInput { id: field
                anchors.left: glass.right; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 22; anchors.verticalCenter: parent.verticalCenter
                color: Config.ink; font.pixelSize: 20; clip: true; focus: true; selectByMouse: true
                selectionColor: Config.fg(0.25); selectedTextColor: Config.fgSolid
                cursorDelegate: Rectangle { width: 1.5; color: Config.fgSolid; visible: field.activeFocus
                    SequentialAnimation on opacity { running: field.activeFocus; loops: Animation.Infinite
                        PauseAnimation { duration: 500 } NumberAnimation { to: 0; duration: 120 } PauseAnimation { duration: 380 } NumberAnimation { to: 1; duration: 120 } } }
                onTextChanged: list.currentIndex = 0
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape) { if (text !== "") text = ""; else sw.close_(); e.accepted = true }
                    else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) { list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1); e.accepted = true }
                    else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { list.currentIndex = Math.max(0, list.currentIndex - 1); e.accepted = true }
                    else if (e.key === Qt.Key_PageDown) { list.currentIndex = Math.min(list.count - 1, list.currentIndex + 6); e.accepted = true }
                    else if (e.key === Qt.Key_PageUp) { list.currentIndex = Math.max(0, list.currentIndex - 6); e.accepted = true }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { sw.runCurrent(); e.accepted = true }
                }
            }
        }
        Rectangle { y: sw.fieldH - 1; x: 16; width: parent.width - 32; height: 1; color: Config.fg(0.08); visible: sw.listH > 1 }

        // ---- results ----
        ListView { id: list
            x: 8; y: sw.fieldH + 6; width: parent.width - 16; height: Math.max(0, sw.maxListH - 14)
            model: results; clip: true; interactive: contentHeight > height; boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0; keyNavigationEnabled: false
            section.property: "category"; section.criteria: ViewSection.FullString
            section.delegate: Item { required property string section; width: list.width; height: 26
                Text { x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: parent.section; color: Config.inkDim; opacity: 0.8
                    font.pixelSize: 11; font.weight: Font.Medium; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.6 } }
            delegate: Item { id: row
                required property int index
                required property var model
                width: list.width; height: sw.rowH
                readonly property bool sel: index === list.currentIndex
                // the same glass tile as menu rows: faint fill + rim when selected
                Rectangle { anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: 1; radius: 12
                    color: Config.fg(row.sel ? 0.13 : (rh.hovered ? 0.06 : 0)); border.width: 1; border.color: Config.fg(row.sel ? 0.16 : 0)
                    Behavior on color { ColorAnimation { duration: Config.quick } } }
                Kirigami.Icon { id: ic; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; source: row.model.decoration; roundToIconSize: false }
                Column { anchors.left: ic.right; anchors.leftMargin: 12; anchors.right: hint.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Text { width: parent.width; text: row.model.display ?? ""; color: Config.ink; font.pixelSize: 14; font.weight: Font.Medium; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText }
                    Text { width: parent.width; text: row.model.subtext ?? ""; visible: text !== ""; color: Config.inkDim; font.pixelSize: 12; elide: Text.ElideMiddle; maximumLineCount: 1; textFormat: Text.PlainText } }
                Text { id: hint; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "↵"; color: Config.inkDim; font.pixelSize: 15; opacity: row.sel ? 0.9 : 0 }
                HoverHandler { id: rh }
                TapHandler { onTapped: { list.currentIndex = row.index; sw.runCurrent() } } }
        }
        Text { x: 24; y: sw.fieldH + 18; visible: list.count === 0 && field.text !== "" && !results.querying; text: "Nothing found"; color: Config.inkDim; font.pixelSize: 14 }
    }
}
