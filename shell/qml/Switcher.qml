// Alt+Tab. A centred glass panel on the overlay layer that owns the keyboard while it is up: every further Alt+Tab (the
// global shortcut keeps firing while Alt is held) moves the selection, releasing Alt switches, Escape cancels.
// Windows come most-recently-used first, so one tap goes back to the previous window.
import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import SircaShell
import "Glass"

Window {
    id: sw
    color: "transparent"
    flags: Qt.FramelessWindowHint
    visible: false
    property int current: 0
    property var model: null
    readonly property int n: model ? model.count : 0
    readonly property int cardW: 236
    readonly property int cardH: 178
    readonly property int pad: 14
    readonly property int perRow: Math.max(1, Math.min(n, Math.floor((Screen.width * 0.8) / (cardW + 10))))
    readonly property int rows: Math.max(1, Math.ceil(n / perRow))
    readonly property int margin: 40                       // room for the shadow
    width: perRow * (cardW + 10) - 10 + 2 * pad + 2 * margin
    height: rows * (cardH + 10) - 10 + 2 * pad + 2 * margin
    readonly property rect panel: Qt.rect(margin, margin, width - 2 * margin, height - 2 * margin)

    TaskManager.VirtualDesktopInfo { id: vd }
    TaskManager.ActivityInfo { id: act }
    Component { id: modelComp
        TaskManager.TasksModel { groupMode: TaskManager.TasksModel.GroupDisabled; sortMode: TaskManager.TasksModel.SortLastActivated
            filterByVirtualDesktop: true; virtualDesktop: vd.currentDesktop; filterByActivity: true; activity: act.currentActivity } }
    Timer { interval: 1500; running: true; onTriggered: sw.model = modelComp.createObject(sw) }

    function step(reverse) {
        if (n < 1) return;
        if (!visible) { current = reverse ? n - 1 : Math.min(1, n - 1); open(); }
        else current = (current + (reverse ? n - 1 : 1)) % n;
    }
    function open() {
        if (!setupDone) { Shell.setupSwitcher(sw); setupDone = true }
        visible = true; shapeLater.restart(); openedAt = Date.now(); watch.restart();
    }
    function commit() {
        if (!visible) return;
        if (model && current >= 0 && current < n) model.requestActivate(model.makeModelIndex(current));
        close_();
    }
    function close_() { visible = false; watch.stop(); Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "clearLobes", "sii", ["sirca-shell", sw.width, sw.height]) }
    property bool setupDone: false
    // While Alt is held, the selected window itself is shown: KWin's highlight-window effect brings it forward and fades
    // the others, so you see what you are about to switch to, not only its thumbnail.
    function peek() {
        let id = "";
        if (visible && model && current >= 0 && current < n) { const ids = model.data(model.makeModelIndex(current), TaskManager.AbstractTasksModel.WinIdList); if (ids && ids.length) id = ids[0]; }
        Shell.dbusSendTyped("org.kde.KWin.HighlightWindow", "/org/kde/KWin/HighlightWindow", "org.kde.KWin.HighlightWindow", "highlightWindows", "S", [id ? [id] : []]);
    }
    onCurrentChanged: peek()
    onVisibleChanged: peek()
    property double openedAt: 0
    // Alt let go → switch. The release event is the normal path; polling covers a tap so quick that Alt was already up
    // before this surface had the keyboard (then no release event ever arrives).
    Timer { id: watch; interval: 40; repeat: true
        onTriggered: { if (sw.active ? !Shell.altHeld() : Date.now() - sw.openedAt > 450) sw.commit() } }
    Timer { id: shapeLater; interval: 30; onTriggered: sw.pushShape() }
    function pushShape() {
        Shell.setShape(sw, [{ x: panel.x, y: panel.y, w: panel.width, h: panel.height, r: Config.cornerRadius }]);
        Shell.dbusSendTyped("org.kde.KWin", "/Glass", "org.kde.KWin.Glass", "setLobes", "siivdd", ["sirca-shell", sw.width, sw.height, [panel.x, panel.y, panel.width, panel.height], Config.cornerRadius, 1]);
        sw.requestUpdate();
    }
    onWidthChanged: if (visible) shapeLater.restart()
    onHeightChanged: if (visible) shapeLater.restart()

    LobeShape { anchors.fill: parent; bar: sw.panel }
    Item { id: keys; anchors.fill: parent; focus: true
        Keys.onReleased: e => { if (e.key === Qt.Key_Alt || e.key === Qt.Key_Meta) sw.commit() }
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) sw.close_();
            else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right) sw.step(false);
            else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) sw.step(true);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) sw.commit();
        } }
    Grid { x: sw.panel.x + sw.pad; y: sw.panel.y + sw.pad; columns: sw.perRow; spacing: 10
        Repeater { model: sw.visible ? sw.model : null
            delegate: Item { id: card
                required property int index
                required property var model
                width: sw.cardW; height: sw.cardH
                readonly property bool sel: index === sw.current
                Rectangle { anchors.fill: parent; radius: 14; color: Config.fg(card.sel ? 0.16 : (hh.hovered ? 0.07 : 0)); border.width: 1; border.color: Config.fg(card.sel ? 0.22 : 0)
                    Behavior on color { ColorAnimation { duration: Config.quick } } }
                WindowPreview { x: 0; y: 0; width: parent.width; height: parent.height
                    title: card.model.display || ""; icon: card.model.decoration
                    uuid: (card.model.WinIdList && card.model.WinIdList.length) ? card.model.WinIdList[0] : ""
                    onActivate: { sw.current = card.index; sw.commit() }
                    onClose: sw.model.requestClose(sw.model.makeModelIndex(card.index)) }
                HoverHandler { id: hh } } } }
}
