// The one material: frosted dark glass (blur + rim + refraction come from the KWin Glass effect on dock-typed
// surfaces), scheme tint, hairline rim and a top sheen drawn here so the surface reads the same everywhere.
import QtQuick
import SircaShell

Item {
    id: glass
    property real radius: Config.cornerRadius
    property real topRadius: radius
    property real bottomRadius: radius
    property color tint: Config.tint
    property color rim: Config.rim
    property real sheen: Config.sheen
    property bool drawRim: true

    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        topLeftRadius: glass.topRadius; topRightRadius: glass.topRadius
        bottomLeftRadius: glass.bottomRadius; bottomRightRadius: glass.bottomRadius
        color: glass.tint
        border.width: glass.drawRim ? 1 : 0
        border.color: glass.rim
        Rectangle {
            anchors.fill: parent; anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            topLeftRadius: Math.max(0, glass.topRadius - 1); topRightRadius: Math.max(0, glass.topRadius - 1)
            bottomLeftRadius: Math.max(0, glass.bottomRadius - 1); bottomRightRadius: Math.max(0, glass.bottomRadius - 1)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Config.fg(glass.sheen) }
                GradientStop { position: 0.45; color: "transparent" }
            }
        }
    }
}
