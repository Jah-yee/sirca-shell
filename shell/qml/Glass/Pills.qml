// Window-count pill cluster (ported from the dock fork): 1..5 pills, the focused window's pill bright.
import QtQuick
import SircaShell

Row {
    id: pills
    property int count: 0
    property int activeIndex: -1       // which pill is the focused window
    property bool groupActive: false   // any window of the group focused
    property bool minimized: false
    property bool attention: false
    readonly property int shown: Math.min(count, 5)
    readonly property bool overflow: count > 5
    readonly property real thick: 2
    readonly property real span: 30
    readonly property real single: 14
    readonly property real each: shown <= 1 ? single : Math.max(4, Math.min(9, (span - spacing * (shown - 1)) / shown))
    readonly property int hit: activeIndex < 0 ? -1 : Math.min(activeIndex, shown - 1)
    spacing: 3
    visible: shown > 0
    function level(i) {
        if (minimized) return 0.32;
        if (i === hit) return 0.95;
        return groupActive ? 0.42 : 0.55;
    }
    Repeater {
        model: pills.shown
        Rectangle {
            required property int index
            width: (pills.overflow && index === pills.shown - 1) ? pills.each * 1.7 : pills.each
            height: pills.thick
            radius: pills.thick / 2
            color: pills.attention ? Config.attention : Config.fgSolid
            opacity: pills.level(index)
            Behavior on width { NumberAnimation { duration: Config.normal; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Config.quick } }
        }
    }
}
