/*
 *    One audio device in the Sound module's picker: icon, name, check mark when default.
 *    SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    id: row
    required property var model
    property string icon: "audio-speakers-symbolic"
    readonly property bool isDefault: model.PulseObject ? (model.PulseObject.default ?? false) : false
    readonly property string deviceName: {
        var o = model.PulseObject;
        if (!o) return model.Description ?? model.Name ?? "";
        var nick = o.pulseProperties ? o.pulseProperties["node.nick"] : undefined;
        return nick || o.description || o.name || "";
    }
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouse.containsMouse ? root.toggleOffColor : "transparent"
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8
        Kirigami.Icon { source: row.icon; Layout.preferredWidth: 16; Layout.preferredHeight: 16; opacity: row.isDefault ? 1 : 0.7 }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: row.deviceName
            font.pixelSize: root.subLabelSize + 1
            font.weight: row.isDefault ? Font.DemiBold : Font.Normal
            elide: Text.ElideMiddle
        }
        Kirigami.Icon { source: "checkmark-symbolic"; Layout.preferredWidth: 16; Layout.preferredHeight: 16; visible: row.isDefault; color: Kirigami.Theme.textColor }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: { if (row.model.PulseObject) row.model.PulseObject.default = true }
    }
}
