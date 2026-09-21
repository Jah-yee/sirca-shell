// First run: one card that names the things nobody finds by themselves. Shown once (config key "welcomed"), and again on
// request:  qdbus6 onur.SircaShell /SircaShell onur.SircaShell.showWelcome
// Same popup pattern as the power menu: takes the keyboard, closes on Esc / Enter / focus loss. No input catcher.
import QtQuick
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
    readonly property var tips: [
        { icon: "document-edit-symbolic", title: "Make it yours", text: "Right-click the bar or the dock, then Edit: move widgets, width, blur, haze, per surface." },
        { icon: "color-management-symbolic", title: "Colour and light", text: "Quick settings (the gear): the palette button picks a colour theme, the sun or moon switches light and dark." },
        { icon: "search-symbolic", title: "Search does more", text: "Meta opens the launcher, Meta+Space searches: apps, files, settings, and sums like 12*7 or 5 km in mi." },
        { icon: "view-grid-symbolic", title: "Tile with the keyboard", text: "Meta+A shows the layouts for the focused window; Meta+Left, Right and Up tile and maximise." },
        { icon: "camera-photo-symbolic", title: "Capture", text: "Meta+Shift+S takes a screenshot, Meta+Shift+R records a region. Both land in a notification you can click." },
        { icon: "edit-paste-symbolic", title: "Clipboard history", text: "Meta+V. Enter copies, Ctrl+P pins an entry so it stays." } ]
    readonly property int panelW: 640
    readonly property int panelH: 96 + tips.length * 62 + 64
    readonly property rect panel: Qt.rect(Math.round((width - panelW) / 2), Math.round((height - panelH) / 2), panelW, panelH)
    property bool setupDone: false
    property real show: 0
    Behavior on show { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function open() {
        if (!setupDone) { Shell.setupSearch(sw); setupDone = true }
        visible = true; show = 1; keys.forceActiveFocus(); shapeLater.restart(); sw.opened()
        focusArmed = false; Shell.setKeyboardMode(sw, "exclusive"); relax.restart()
    }
    function close_() { if (!visible) return; visible = false; show = 0; focusArmed = false; relax.stop(); arm.stop()
        Shell.saveConfigKey("welcomed", true)
        Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "clearLobes", "sii", ["sirca-shell", sw.width, sw.height]) }

    property bool focusArmed: false
    Timer { id: relax; interval: 160; onTriggered: { Shell.setKeyboardMode(sw, "ondemand"); arm.restart() } }
    Timer { id: arm; interval: 220; onTriggered: sw.focusArmed = true }
    onActiveChanged: if (visible && focusArmed && !active) lost.restart(); else lost.stop()
    Timer { id: lost; interval: 80; onTriggered: if (sw.visible && !sw.active) sw.close_() }
    Timer { id: shapeLater; interval: 16; onTriggered: sw.pushShape() }
    function pushShape() { if (!visible) return;
        Shell.setShape(sw, [{ x: panel.x, y: panel.y, w: panel.width, h: panel.height, r: Config.cornerRadius }]);
        Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "setLobes", "siivdd", ["sirca-shell", sw.width, sw.height, [panel.x, panel.y, panel.width, panel.height], Config.cornerRadius, 1]);
        sw.requestUpdate() }

    LobeShape { anchors.fill: parent; bar: sw.panel }
    Item { id: keys; x: sw.panel.x; y: sw.panel.y; width: sw.panel.width; height: sw.panel.height; focus: true
        opacity: sw.show; transform: Translate { y: (1 - sw.show) * 10 }
        Keys.onPressed: e => { if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { sw.close_(); e.accepted = true } }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Text { x: 32; y: 28; text: "Welcome to Sirca Shell"; color: Config.ink; font.pixelSize: 24; font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
        Text { x: 32; y: 62; text: "Six things worth knowing. This card shows once."; color: Config.inkDim; font.pixelSize: 13 }
        Column { x: 20; y: 96; width: parent.width - 40
            Repeater { model: sw.tips
                Item { required property var modelData; width: parent.width; height: 62
                    Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40; radius: 20; color: Config.fg(0.08); border.width: 1; border.color: Config.fg(0.10)
                        Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; source: parent.parent.modelData.icon; fallback: "help-about-symbolic"; isMask: true; color: Config.fgSolid; roundToIconSize: false } }
                    Column { x: 68; width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        Text { text: parent.parent.modelData.title; color: Config.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { width: parent.width; text: parent.parent.modelData.text; color: Config.inkDim; font.pixelSize: 13; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight } } } } }
        Rectangle { id: ok; anchors.right: parent.right; anchors.rightMargin: 28; anchors.bottom: parent.bottom; anchors.bottomMargin: 22; width: 116; height: 36; radius: 18
            color: okh.hovered ? Qt.lighter(Config.accent, 1.12) : Config.accent; scale: okt.pressed ? 0.96 : 1; Behavior on scale { NumberAnimation { duration: Config.quick } }
            Text { anchors.centerIn: parent; text: "Got it"; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold }   // literal-ok: on the accent fill
            HoverHandler { id: okh; cursorShape: Qt.PointingHandCursor } TapHandler { id: okt; onTapped: sw.close_() } }
        Text { x: 32; anchors.verticalCenter: ok.verticalCenter; text: "Everything is a key in ~/.config/sirca-shell/config.json too."; color: Config.inkDim; font.pixelSize: 12 }
    }
}
