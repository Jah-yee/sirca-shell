// Colour haze under a dock icon: an enlarged, heavily blurred, slightly saturated copy of the icon, drawn beneath it.
// It reads as if the icon's light were caught inside the dock's glass. Parent it into a layer that is masked to the
// dock's outline so the haze never spills past the glass.
import QtQuick
import QtQuick.Effects
import SircaShell
import org.kde.kirigami as Kirigami

Item {
    id: root
    property var source                 // icon name or QIcon (same thing the visible icon gets)
    property real iconSize: 46
    property real strength: 0.5          // 0 = off
    property real spread: 2.0            // haze size relative to the icon
    visible: strength > 0.01
    width: iconSize * spread; height: width
    Kirigami.Icon { id: src; width: root.iconSize; height: width; source: root.source; roundToIconSize: false; visible: false }
    MultiEffect {
        anchors.fill: parent
        source: src                       // stretched to the haze size, then blurred: no detail survives, only colour
        autoPaddingEnabled: true
        blurEnabled: true; blur: 1.0; blurMax: 64
        saturation: Config.hazeSaturation; brightness: Config.hazeLift
        opacity: Math.min(1, root.strength * Config.hazeFactor)
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }
}
