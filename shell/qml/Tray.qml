// The tray icons in the bar, native (TrayHost = StatusNotifierItem host). Left click activates the app's item, right
// click (or left click on a menu-only item) asks the bar to open the item's menu as a glass popup, middle click is the
// secondary action, the wheel scrolls (volume-style items use it). Passive items stay out of the bar.
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import SircaShell

Item {
    id: tray
    signal menuRequested(var item, real centerX)
    property var openItem: null                       // the item whose menu is open (its pill stays lit)
    implicitWidth: row.implicitWidth; implicitHeight: 27
    width: implicitWidth; height: implicitHeight
    TrayHost { id: host }
    // For the bar's colour haze: the same row, but only the COLOURED icons (app pictures), none of the monochrome symbols.
    // A blurred copy of a monochrome glyph is a grey (on light glass: dark) smudge, not colour.
    property alias hazeSource: hz
    Item { id: hz; visible: false; width: tray.width; height: tray.height; layer.enabled: true
        Row { anchors.verticalCenter: parent.verticalCenter; spacing: 2
            Repeater { model: host
                delegate: Item { required property var item
                    readonly property bool shownHere: item.status !== "Passive" && item.icon !== "" && !tray.isHidden(item)
                    readonly property bool coloured: item.iconIsFile || !/-symbolic$/.test(String(item.icon))
                    visible: shownHere; width: shownHere ? 30 : 0; height: 27
                    Image { anchors.centerIn: parent; width: 18; height: 18; visible: parent.coloured && parent.item.iconIsFile; source: parent.item.iconIsFile ? parent.item.icon : ""; sourceSize: Qt.size(36, 36) }
                    Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; visible: parent.coloured && !parent.item.iconIsFile; source: parent.item.iconIsFile ? "" : parent.item.icon; roundToIconSize: false } } } } }
    function isHidden(item) { const l = Config.get("trayHidden", []), a = (item.itemId || "").toLowerCase(), b = (item.title || "").toLowerCase()
        for (let i = 0; i < l.length; ++i) { const h = String(l[i]).toLowerCase(); if (h !== "" && (h === a || h === b)) return true } return false }
    function requestMenuAt(n) { let k = 0; for (let i = 0; i < row.children.length; ++i) { const c = row.children[i]; if (!c.item || !c.shown) continue; if (k === n) { tray.menuRequested(c.item, c.center()); return } ++k } }
    Row { id: row; anchors.verticalCenter: parent.verticalCenter; spacing: 2
        Repeater { model: host
            delegate: Item { id: cell
                required property var item
                // "trayHidden" in the config: item ids (or titles) the user does not want in the bar, compared without case
                readonly property bool hiddenByUser: { const l = Config.get("trayHidden", []), a = (item.itemId || "").toLowerCase(), b = (item.title || "").toLowerCase()
                    for (let i = 0; i < l.length; ++i) { const h = String(l[i]).toLowerCase(); if (h !== "" && (h === a || h === b)) return true } return false }
                readonly property bool shown: item.status !== "Passive" && item.icon !== "" && !hiddenByUser
                visible: shown; width: shown ? 30 : 0; height: 27
                Rectangle { anchors.centerIn: parent; width: 28; height: 27; radius: 13.5
                    color: Config.fg(tray.openItem === cell.item ? 0.12 : (hh.hovered ? 0.07 : 0)); Behavior on color { ColorAnimation { duration: Config.quick } } }
                // files and pixmaps are pictures; theme names go through the icon theme (symbolic ones get tinted white)
                Image { anchors.centerIn: parent; width: 18; height: 18; visible: cell.item.iconIsFile; source: cell.item.iconIsFile ? cell.item.icon : ""; sourceSize: Qt.size(36, 36); smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
                    opacity: hh.hovered ? 1 : 0.9 }
                Kirigami.Icon { id: themed; anchors.centerIn: parent; width: 18; height: 18; visible: !cell.item.iconIsFile; source: cell.item.iconIsFile ? "" : cell.item.icon; roundToIconSize: false
                    // light mode: monochrome symbols are white like the rest of the bar's icons, over a soft dark shadow
                    readonly property bool symbolic: /-symbolic$/.test(String(cell.item.icon))
                    isMask: symbolic && !Config.dark; color: "white"   // literal-ok: white glyphs on light glass, by design
                    layer.enabled: !Config.dark; layer.effect: MultiEffect { autoPaddingEnabled: true; shadowEnabled: true; shadowColor: Config.ink; shadowOpacity: 0.6; shadowBlur: 0.5; shadowVerticalOffset: 1 }
                    opacity: hh.hovered ? 1 : 0.9 }
                Rectangle { visible: cell.item.status === "NeedsAttention"; x: parent.width - 9; y: 3; width: 7; height: 7; radius: 3.5; color: Config.attention; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.4) }
                HoverHandler { id: hh }
                function center() { return cell.mapToItem(tray, cell.width / 2, 0).x }
                function globalPos() { const p = cell.mapToGlobal(cell.width / 2, cell.height); return [Math.round(p.x), Math.round(p.y)] }
                TapHandler { acceptedButtons: Qt.LeftButton
                    onTapped: { if (cell.item.itemIsMenu) tray.menuRequested(cell.item, cell.center()); else { const g = cell.globalPos(); cell.item.activate(g[0], g[1]) } } }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: tray.menuRequested(cell.item, cell.center()) }
                TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: { const g = cell.globalPos(); cell.item.secondaryActivate(g[0], g[1]) } }
                WheelHandler { onWheel: e => cell.item.scroll(e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x, e.angleDelta.y === 0) }
                // name tip under the bar, after a short rest
                Timer { id: tipDelay; interval: 600; running: hh.hovered && tray.openItem === null }
                Rectangle { visible: hh.hovered && !tipDelay.running && tray.openItem === null; anchors.top: parent.bottom; anchors.topMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; z: 50
                    width: tipText.implicitWidth + 18; height: 26; radius: 8; color: Config.popSurface; border.width: 1; border.color: Config.fg(0.14)
                    Text { id: tipText; anchors.centerIn: parent; text: cell.item.title; color: Config.ink; font.pixelSize: 12 } } } } }
}
