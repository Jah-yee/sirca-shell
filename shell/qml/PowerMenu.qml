// Power menu (Ctrl+Alt+Del, and the power buttons in the launcher and quick settings): Lock, Sleep, Log out, Restart,
// Shut down, in our look instead of Plasma's full-screen logout screen. Lock and Sleep act at once. The three that end
// the session need a second press within ten seconds ("Press again"); nothing ever runs by itself when the time is up.
// They go through the session manager (org.kde.Shutdown), so apps are asked to save and close as usual.
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
    readonly property var actions: [
        { id: "lock", label: "Lock", icon: "system-lock-screen-symbolic", confirm: false, key: Qt.Key_L },
        { id: "sleep", label: "Sleep", icon: "system-suspend-symbolic", confirm: false, key: Qt.Key_S },
        { id: "logout", label: "Log out", icon: "system-log-out-symbolic", confirm: true, key: Qt.Key_O },
        { id: "restart", label: "Restart", icon: "system-reboot-symbolic", confirm: true, key: Qt.Key_R },
        { id: "shutdown", label: "Shut down", icon: "system-shutdown-symbolic", confirm: true, key: Qt.Key_U } ]
    property int current: 0
    property string armed: ""                         // id of the action waiting for its second press
    property int secondsLeft: 0
    readonly property int tileW: 112
    readonly property int panelW: actions.length * tileW + 32
    readonly property int panelH: 168
    readonly property rect panel: Qt.rect(Math.round((width - panelW) / 2), Math.round(height * 0.34), panelW, panelH)
    property bool setupDone: false
    property real show: 0
    Behavior on show { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    function toggle() { visible ? close_() : open() }
    function open() {
        if (!setupDone) { Shell.setupSearch(sw); setupDone = true }
        current = 0; armed = ""; visible = true; show = 1; keys.forceActiveFocus(); shapeLater.restart(); sw.opened()
        focusArmed = false; Shell.setKeyboardMode(sw, "exclusive"); relax.restart()
    }
    function close_() { if (!visible) return; visible = false; show = 0; armed = ""; countdown.stop(); focusArmed = false; relax.stop(); arm.stop()
        Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "clearLobes", "sii", ["sirca-shell", sw.width, sw.height]) }
    function activate(i) {
        const a = actions[i]; if (!a) return; current = i
        if (a.confirm && armed !== a.id) { armed = a.id; secondsLeft = 10; countdown.restart(); return }
        run(a.id) }
    // dryRun: the self-test and D-Bus preview must never end the session
    property bool dryRun: false
    function run(id) {
        armed = ""; countdown.stop(); close_()
        if (dryRun) { console.log("power menu (dry run):", id); return }
        if (id === "lock") Shell.dbusSend("org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "Lock")
        else if (id === "sleep") Shell.runDetached("systemctl", ["suspend"])
        else if (id === "logout") Shell.dbusSend("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logout")
        else if (id === "restart") Shell.dbusSend("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndReboot")
        else if (id === "shutdown") Shell.dbusSend("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndShutdown") }
    Timer { id: countdown; interval: 1000; repeat: true; onTriggered: { sw.secondsLeft -= 1; if (sw.secondsLeft <= 0) { stop(); sw.armed = "" } } }   // time up = disarm, never execute

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
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { if (sw.armed !== "") { sw.armed = ""; countdown.stop() } else sw.close_(); e.accepted = true }
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) { sw.current = (sw.current + 1) % sw.actions.length; sw.armed = ""; e.accepted = true }
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) { sw.current = (sw.current + sw.actions.length - 1) % sw.actions.length; sw.armed = ""; e.accepted = true }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { sw.activate(sw.current); e.accepted = true }
            else { for (let i = 0; i < sw.actions.length; ++i) if (e.key === sw.actions[i].key) { sw.activate(i); e.accepted = true } } }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Row { x: 16; y: 18
            Repeater { model: sw.actions
                Item { id: tile; required property int index; required property var modelData
                    readonly property bool sel: index === sw.current
                    readonly property bool waiting: sw.armed === modelData.id
                    width: sw.tileW; height: 118
                    Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 18
                        color: tile.waiting ? Qt.rgba(229/255, 72/255, 77/255, 0.22) : Config.fg(tile.sel ? 0.12 : (th.hovered ? 0.07 : 0))
                        border.width: 1; border.color: tile.waiting ? Qt.rgba(229/255, 72/255, 77/255, 0.55) : Config.fg(tile.sel ? 0.16 : 0)
                        Behavior on color { ColorAnimation { duration: Config.quick } } }
                    Rectangle { id: disc; anchors.horizontalCenter: parent.horizontalCenter; y: 16; width: 54; height: 54; radius: 27
                        color: tile.waiting ? Qt.rgba(229/255, 72/255, 77/255, 0.9) : Config.fg(0.10); border.width: 1; border.color: Config.fg(0.16)
                        scale: tt.pressed ? 0.93 : 1; Behavior on scale { NumberAnimation { duration: Config.quick } }
                        Kirigami.Icon { anchors.centerIn: parent; width: 24; height: 24; source: tile.modelData.icon; isMask: true; color: tile.waiting ? "white" : Config.fgSolid; roundToIconSize: false } }   // literal-ok: white on the red armed disc
                    Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: disc.bottom; anchors.topMargin: 10; color: Config.ink; font.pixelSize: 13; font.weight: tile.waiting ? Font.DemiBold : Font.Medium
                        text: tile.waiting ? "Press again" : tile.modelData.label }
                    HoverHandler { id: th; onHoveredChanged: if (hovered && sw.armed === "") sw.current = tile.index }
                    TapHandler { id: tt; onTapped: sw.activate(tile.index) } } } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 30; color: Config.inkDim; font.pixelSize: 12
            text: sw.armed !== "" ? "Press again to " + sw.actions[sw.current].label.toLowerCase() + "  ·  " + sw.secondsLeft + " s  ·  Esc cancels" : "Arrows and Enter, or L  S  O  R  U" }
    }
}
