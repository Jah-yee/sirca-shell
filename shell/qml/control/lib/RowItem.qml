/*
 *    One row of the connectivity module / a long tile: bubble at the left,
 *    label + sublabel at the right. Clicking the bubble toggles, clicking the
 *    text opens the detail action.
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    id: row
    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool on: false
    property bool iconMask: false
    property bool showArrow: false
    signal toggled
    signal activated

    implicitHeight: 56

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 12
        color: textArea.containsMouse ? root.rowHoverColor : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Bubble {
            id: bubble
            on: row.on
            Layout.preferredWidth: root.bubbleSize
            Layout.preferredHeight: root.bubbleSize
            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width * 0.56
                height: width
                source: row.icon
                isMask: row.iconMask
                color: row.on ? root.onIconColor : Kirigami.Theme.textColor
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: bubble.hovered = true
                onExited: bubble.hovered = false
                onClicked: row.toggled()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.label
                font.pixelSize: root.labelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.sublabel
                visible: text !== ""
                font.pixelSize: root.subLabelSize
                opacity: 0.68
                elide: Text.ElideRight
            }
            MouseArea {
                id: textArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: row.activated()
            }
        }

        Kirigami.Icon {
            visible: row.showArrow
            source: "arrow-right"
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            opacity: 0.5
        }
    }
}
