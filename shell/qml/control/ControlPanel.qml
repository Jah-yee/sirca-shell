// Quick settings, native: the Glass Control panel without the Plasma applet around it. This wrapper supplies what the
// applet's main.qml used to (the `root` tokens the pages read, and `expanded`); the pages themselves are the same files,
// talking to the same backends (NetworkManager, BlueZ, PulseAudio/PipeWire, brightness, night light, do-not-disturb,
// session management), which are plain QML modules and do not need plasmashell.
import SircaShell
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root
    property bool expanded: false                      // set by the bar; the pages set it to false to close themselves
    signal closeRequested()
    onExpandedChanged: if (!expanded) closeRequested()

    readonly property color themeBgColor: "#18191b"
    readonly property bool isDarkTheme: true
    property int cardRadius: 18
    property real cardAlpha: 0.14
    property real cardHoverBoost: 0.06
    property color cardRimColor: Config.fg(0.13)
    property color cardInnerRimColor: Config.fg(0.05)
    property color cardSheenColor: Config.fg(0.075)
    property color cardFootColor: "transparent"
    property color toggleOffColor: Config.fg(0.10)
    property color toggleOnColor: Config.fg(0.90)
    property color cardRimHoverColor: Config.fg(0.24)
    property color rowHoverColor: Config.fg(0.06)
    readonly property int smallSpacing: Kirigami.Units.smallSpacing
    readonly property int mediumSpacing: Kirigami.Units.mediumSpacing
    readonly property int largeSpacing: Kirigami.Units.largeSpacing
    readonly property int buttonMargin: 4
    readonly property int largeFontSize: Kirigami.Theme.defaultFont.pixelSize + 2
    readonly property int mediumFontSize: Kirigami.Theme.defaultFont.pixelSize
    readonly property bool isVertical: false
    readonly property bool iconPositionRight: false
    readonly property real scale: 1
    readonly property int pad: 12
    readonly property int gap: 10
    readonly property int bubbleSize: 34
    readonly property int labelSize: 13
    readonly property int subLabelSize: 11
    readonly property color onIconColor: Qt.rgba(0.11, 0.13, 0.18, 1)

    implicitWidth: panel.Layout.preferredWidth > 0 ? panel.Layout.preferredWidth : 364
    implicitHeight: panel.Layout.preferredHeight > 0 ? panel.Layout.preferredHeight : 420
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    FullRepresentation { id: panel; anchors.fill: parent }
}
