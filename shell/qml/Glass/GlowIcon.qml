// Theme icon that glows while `active` — the "this is open" language shared by launcher, tray and gear.
import SircaShell
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: root
    property string source: ""
    property bool active: false
    property bool hovered: false
    property real size: 18
    property color color: Config.fgSolid
    width: size; height: size
    MultiEffect { z: -1; anchors.fill: icon; source: icon; autoPaddingEnabled: true; blurEnabled: true; blur: 1.0; blurMax: 32; brightness: Config.dark ? 0.5 : 0.1; saturation: Config.dark ? -0.2 : 0.4; colorization: Config.dark ? 0 : 1; colorizationColor: Config.glow; scale: 1.5; transformOrigin: Item.Center
        // light mode: a faint halo even at rest (a flat dark glyph on milk looked dead next to the glowing white one of dark mode)
        opacity: root.active ? (Config.dark ? 0.75 : 0.95) : (Config.dark ? 0 : (root.hovered ? 0.45 : 0.20)); Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
    MultiEffect { z: -1; anchors.fill: icon; source: icon; autoPaddingEnabled: true; blurEnabled: true; blur: 0.8; blurMax: 10; brightness: Config.dark ? 0.5 : 0.1; colorization: Config.dark ? 0 : 1; colorizationColor: Config.glow; scale: 1.12; transformOrigin: Item.Center
        opacity: root.active ? (Config.dark ? 0.6 : 0.85) : 0; Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
    Kirigami.Icon { id: icon; anchors.fill: parent; source: root.source; color: root.color; isMask: true; roundToIconSize: false
        opacity: root.hovered || root.active ? 1 : 0.85; Behavior on opacity { NumberAnimation { duration: 120 } } }
}
