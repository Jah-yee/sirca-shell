// Dock highlight: a pool of light thrown up from below the cell. It fades out in every direction — upward and to the
// sides — so there is no edge anywhere (hover = dim, focused = bright). Drawn as a circle, stretched vertically.
import SircaShell
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property real strength: 0          // peak white alpha at the bottom centre
    // always LIGHT: on light glass the text colour (dark slate) made hover and focus a dark smudge under the icon. White on
    // milky glass needs more of it to show at all.
    readonly property real k: Config.dark ? 1.0 : 2.4
    function lit(a) { return Qt.rgba(1, 1, 1, Math.min(1, a * k)) }   // literal-ok: light, by design
    property real spread: 40           // horizontal reach in px (a little past the cell; it is nearly zero by then)
    Behavior on strength { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    visible: strength > 0.004
    Shape {
        x: root.width / 2 - root.spread; y: root.height - root.spread; width: 2 * root.spread; height: root.spread
        transform: Scale { origin.y: root.spread; yScale: (root.height * 1.05) / root.spread }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.spread; centerY: root.spread + 2; focalX: centerX; focalY: centerY; centerRadius: root.spread; focalRadius: 0
                GradientStop { position: 0.0; color: root.lit(root.strength) }
                GradientStop { position: 0.35; color: root.lit(root.strength * 0.5) }
                GradientStop { position: 0.7; color: root.lit(root.strength * 0.12) }
                GradientStop { position: 1.0; color: root.lit(0) }
            }
            PathRectangle { x: 0; y: 0; width: 2 * root.spread; height: root.spread }
        }
    }
}
