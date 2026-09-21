// Tile picker (Meta+A): the layouts that make sense on a 32:9 screen, drawn as small screens. Click a zone and the
// focused window goes there; each zone also shows its own key, so the panel doubles as the cheat sheet for them.
// With the Mudeer KWin script installed, its actions do the moving (it knows about gaps); without it the shell places the
// window itself through a one-off KWin script (Shell.tileActiveWindow).
import QtQuick
import SircaShell
import "Glass"

Window {
    id: tw
    color: "transparent"
    flags: Qt.FramelessWindowHint
    visible: false
    width: Screen.width; height: Screen.height
    signal opened()
    // zones: [x, width] in fractions of the screen, a = Mudeer action name
    readonly property var layouts: [
        { name: "Halves", zones: [ { x: 0, w: 1/2, a: "Mudeer Half Left" }, { x: 1/2, w: 1/2, a: "Mudeer Half Right" } ] },
        { name: "Thirds", zones: [ { x: 0, w: 1/3, a: "Mudeer Third Left" }, { x: 1/3, w: 1/3, a: "Mudeer Third Middle" }, { x: 2/3, w: 1/3, a: "Mudeer Third Right" } ] },
        { name: "Quarters", zones: [ { x: 0, w: 1/4, a: "Mudeer Quarter Far-Left" }, { x: 1/4, w: 1/4, a: "Mudeer Quarter Middle-Left" }, { x: 1/2, w: 1/4, a: "Mudeer Quarter Middle-Right" }, { x: 3/4, w: 1/4, a: "Mudeer Quarter Far-Right" } ] },
        { name: "Wide middle", zones: [ { x: 0, w: 1/4, a: "Mudeer Quarter Far-Left" }, { x: 1/4, w: 1/2, a: "Mudeer Half Middle" }, { x: 3/4, w: 1/4, a: "Mudeer Quarter Far-Right" } ] },
        { name: "Two thirds + third", zones: [ { x: 0, w: 2/3, a: "Mudeer Two-Thirds Left" }, { x: 2/3, w: 1/3, a: "Mudeer Third Right" } ] },
        { name: "Third + two thirds", zones: [ { x: 0, w: 1/3, a: "Mudeer Third Left" }, { x: 1/3, w: 2/3, a: "Mudeer Two-Thirds Right" } ] },
        { name: "Three quarters + quarter", zones: [ { x: 0, w: 3/4, a: "Mudeer Three-Quarters Left" }, { x: 3/4, w: 1/4, a: "Mudeer Quarter Far-Right" } ] },
        { name: "Quarter + three quarters", zones: [ { x: 0, w: 1/4, a: "Mudeer Quarter Far-Left" }, { x: 1/4, w: 3/4, a: "Mudeer Three-Quarters Right" } ] },
        { name: "Centred two thirds", zones: [ { x: 1/6, w: 2/3, a: "Mudeer Two-Thirds Middle" } ] },
        { name: "Whole screen", zones: [ { x: 0, w: 1, a: "Mudeer Whole" } ] } ]
    property bool mudeer: true                         // the Mudeer KWin script is installed (checked when the panel opens); without it the shell places the window itself
    property var pendingZone: null
    property var keys: ({})                            // action -> key text, read when the panel opens
    readonly property int miniW: 288
    readonly property int miniH: 81
    readonly property int cellH: miniH + 30
    readonly property int panelW: 2 * miniW + 3 * 22
    readonly property int panelH: 54 + Math.ceil(layouts.length / 2) * cellH + 14
    readonly property rect panel: Qt.rect(Math.round((width - panelW) / 2), Math.round((height - panelH) * 0.42), panelW, panelH)
    property bool setupDone: false
    property bool dryRun: false
    property real show: 0
    Behavior on show { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    function toggle() { visible ? close_() : open() }
    function open() {
        if (!setupDone) { Shell.setupSearch(tw); setupDone = true }
        mudeer = Shell.kwinHasAction("Mudeer Half Left")
        const k = {}; for (const l of layouts) for (const z of l.zones) if (k[z.a] === undefined) k[z.a] = Shell.kwinShortcutKey(z.a); keys = k
        visible = true; show = 1; keyItem.forceActiveFocus(); shapeLater.restart(); tw.opened()
        focusArmed = false; Shell.setKeyboardMode(tw, "exclusive"); relax.restart()
    }
    function close_() { if (!visible) return; visible = false; show = 0; focusArmed = false; relax.stop(); arm.stop()
        Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "clearLobes", "sii", ["sirca-shell", tw.width, tw.height]) }
    // the window manager moves its ACTIVE window: close first, let the focus go back to the window, then ask
    property string pendingAction: ""
    function apply(action, zone) { pendingAction = action; pendingZone = zone || null; close_(); later.restart() }
    Timer { id: later; interval: 140; onTriggered: { const a = tw.pendingAction; tw.pendingAction = ""; if (a === "") return
        if (tw.dryRun) { console.log("tiles (dry run):", a); return }
        if (tw.mudeer) Shell.dbusSend("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component", "invokeShortcut", [a])
        else if (tw.pendingZone) Shell.tileActiveWindow(tw.pendingZone.x, tw.pendingZone.w) } }

    property bool focusArmed: false
    Timer { id: relax; interval: 160; onTriggered: { Shell.setKeyboardMode(tw, "ondemand"); arm.restart() } }
    Timer { id: arm; interval: 220; onTriggered: tw.focusArmed = true }
    onActiveChanged: if (visible && focusArmed && !active) lost.restart(); else lost.stop()
    Timer { id: lost; interval: 80; onTriggered: if (tw.visible && !tw.active) tw.close_() }
    Timer { id: shapeLater; interval: 16; onTriggered: tw.pushShape() }
    function pushShape() { if (!visible) return
        Shell.setShape(tw, [{ x: panel.x, y: panel.y, w: panel.width, h: panel.height, r: Config.cornerRadius }])
        Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "setLobes", "siivdd", ["sirca-shell", tw.width, tw.height, [panel.x, panel.y, panel.width, panel.height], Config.cornerRadius, 1])
        tw.requestUpdate() }

    LobeShape { anchors.fill: parent; bar: tw.panel }
    Item { id: keyItem; x: tw.panel.x; y: tw.panel.y; width: tw.panel.width; height: tw.panel.height; focus: true
        opacity: tw.show; transform: Translate { y: (1 - tw.show) * 10 }
        Keys.onPressed: e => { if (e.key === Qt.Key_Escape) { tw.close_(); e.accepted = true } }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Text { x: 24; y: 18; text: "Place the focused window"; color: Config.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
        Text { anchors.right: parent.right; anchors.rightMargin: 24; y: 20; text: "Esc closes"; color: Config.inkDim; font.pixelSize: 12 }
        Grid { x: 22; y: 54; columns: 2; columnSpacing: 22; rowSpacing: 0
            Repeater { model: tw.layouts
                Item { id: cell; required property var modelData; width: tw.miniW; height: tw.cellH
                    Rectangle { id: mini; width: tw.miniW; height: tw.miniH; radius: 10; color: Qt.rgba(0, 0, 0, 0.22); border.width: 1; border.color: Config.fg(0.10)
                        Repeater { model: cell.modelData.zones
                            Rectangle { id: zone; required property var modelData
                                x: 3 + modelData.x * (mini.width - 6) + 1.5; y: 4.5; width: modelData.w * (mini.width - 6) - 3; height: mini.height - 9; radius: 7
                                color: Config.fg(zt.pressed ? 0.34 : (zh.hovered ? 0.26 : 0.09)); border.width: 1; border.color: Config.fg(zh.hovered ? 0.55 : 0.16)
                                Behavior on color { ColorAnimation { duration: Config.quick } }
                                Text { anchors.centerIn: parent; text: tw.keys[zone.modelData.a] || ""; visible: width < parent.width - 6
                                    color: Config.fg(zh.hovered ? 0.95 : 0.55); font.pixelSize: 10; font.weight: Font.Medium }
                                HoverHandler { id: zh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { id: zt; onTapped: tw.apply(zone.modelData.a, zone.modelData) } } } }
                    Text { x: 2; y: tw.miniH + 7; text: cell.modelData.name; color: Config.inkDim; font.pixelSize: 11 } } } }
    }
}
