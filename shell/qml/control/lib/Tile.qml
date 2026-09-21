/*
 *    Square toggle tile: bubble on top, label underneath (Control Center style).
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Card {
    id: tile
    property string icon: ""
    property string label: ""
    property bool on: false
    property bool iconMask: false
    signal clicked

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 6

        Bubble {
            id: bubble
            on: tile.on
            hovered: tile.hovered
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.bubbleSize
            Layout.preferredHeight: root.bubbleSize
            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width * 0.56
                height: width
                source: tile.icon
                isMask: tile.iconMask
                color: tile.on ? root.onIconColor : Kirigami.Theme.textColor
            }
        }
        PlasmaComponents3.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: tile.width - 12
            text: tile.label
            font.pixelSize: root.labelSize - 1
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tile.hovered = true
        onExited: tile.hovered = false
        onClicked: tile.clicked()
    }
}
