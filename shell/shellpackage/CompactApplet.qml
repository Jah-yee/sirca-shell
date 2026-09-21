/*
    Sirca Shell's compact-applet wrapper (replaces the stock one from org.kde.plasma.desktop).
    The stock wrapper puts an applet's full representation into a PlasmaCore popup dialog. Sirca Shell never wants a
    separate window: its AppletHost takes `fullRepresentation` and parents it into a lobe of the bar. So this wrapper
    only shows the compact representation (for bar-zone applets) and leaves the full one alone.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: root
    objectName: "onur.sircashell-CompactApplet"
    anchors.fill: parent

    mainText: plasmoidItem ? plasmoidItem.toolTipMainText : ""
    subText: plasmoidItem ? plasmoidItem.toolTipSubText : ""
    location: Plasmoid.location
    active: plasmoidItem ? !plasmoidItem.expanded : false
    textFormat: plasmoidItem ? plasmoidItem.toolTipTextFormat : Text.AutoText
    mainItem: plasmoidItem && plasmoidItem.toolTipItem ? plasmoidItem.toolTipItem : null

    property Item fullRepresentation
    property Item compactRepresentation
    property Item expandedFeedback: null     // no "expanded" tile: open state is a glow, drawn by the shell
    property PlasmoidItem plasmoidItem

    onCompactRepresentationChanged: {
        if (compactRepresentation) {
            compactRepresentation.anchors.fill = null;
            compactRepresentation.parent = root;
            compactRepresentation.anchors.fill = root;
            compactRepresentation.visible = true;
        }
        root.visible = true;
    }
}
