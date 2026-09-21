/*
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kquickcontrolsaddons as KQuickAddons
import org.kde.kirigami as Kirigami

import org.kde.notificationmanager as NotificationManager
import plasma.applet.org.kde.plasma.notifications as NotificationsApplet


Item {
    id: notificationPopup

    // no accent blue inside cards (timeout line, links' hover, progress): the glass theme is monochrome
    Kirigami.Theme.inherit: false
    Kirigami.Theme.highlightColor: "#f2f3f4"
    Kirigami.Theme.textColor: "#eff0f1"
    Kirigami.Theme.backgroundColor: "#202326"
    Kirigami.Theme.highlightedTextColor: "#202326"
    Kirigami.Theme.disabledTextColor: "#9a9b9c"
    Kirigami.Theme.linkColor: "#cfd3d6"

    // stand-ins for what the window type provided
    property bool isCritical: false
    property bool takeFocus: false
    readonly property bool active: false
    readonly property int leftPadding: 12
    readonly property int rightPadding: 12
    readonly property int topPadding: 10
    readonly property int bottomPadding: 10
    property alias mainItem: holder.mainItem
    Rectangle { anchors.fill: parent; radius: 14; color: Qt.rgba(1, 1, 1, focusListener.containsMouse ? 0.09 : 0.055); border.width: 1; border.color: Qt.rgba(1, 1, 1, focusListener.containsMouse ? 0.16 : 0.09)
        Behavior on color { ColorAnimation { duration: 120 } } }
    // our own layout for ordinary notifications; jobs, inline replies and file previews keep Plasma's delegate (it carries
    // their logic), everything else must look like it belongs to this desktop, not like a Plasma popup inside our frame
    readonly property bool plainCard: notificationItem.modelInterface.notificationType === NotificationManager.Notifications.NotificationType
                                   && !notificationItem.modelInterface.hasReplyAction && notificationItem.modelInterface.urls.length === 0
    Item { id: holder; x: notificationPopup.leftPadding; y: notificationPopup.topPadding
        property Item mainItem
        onMainItemChanged: if (mainItem) mainItem.parent = holder
        width: mainItem ? mainItem.implicitWidth : 0; height: mainItem ? mainItem.implicitHeight : 0 }
    opacity: visible ? 1 : 0

    property int popupWidth
    property bool showPopupTimeout

    // Maximum width the popup can take to not break out of the screen geometry.
    readonly property int availableWidth: popupWidth

    readonly property int minimumContentWidth: popupWidth
    readonly property int maximumContentWidth: Math.min((availableWidth > 0 ? availableWidth : Number.MAX_VALUE), popupWidth * 3)

    property alias modelInterface: notificationItem.modelInterface

    property int modelTimeout
    property int dismissTimeout

    property var defaultActionFallbackWindowIdx

    signal expired
    signal hoverEntered
    signal hoverExited

    property int defaultTimeout: 5000
    readonly property int effectiveTimeout: {
        if (modelTimeout === -1) {
            return defaultTimeout;
        }
        if (dismissTimeout) {
            return dismissTimeout;
        }
        return modelTimeout;
    }

    // On wayland we need focus to copy to the clipboard, we change on mouse interaction until the cursor leaves
    visible: false

    height: mainItem.implicitHeight + topPadding + bottomPadding
    width: mainItem.implicitWidth + leftPadding + rightPadding

    mainItem: KQuickAddons.MouseEventListener {
        id: focusListener
        property bool wantsFocus: false

        implicitWidth: Math.min(Math.max(notificationPopup.minimumContentWidth, notificationItem.Layout.preferredWidth), Math.max(notificationPopup.minimumContentWidth, notificationPopup.maximumContentWidth))
        implicitHeight: notificationPopup.plainCard ? nativeCard.implicitHeight : notificationItem.implicitHeight

        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: wantsFocus = true
        onContainsMouseChanged: {
            wantsFocus = wantsFocus && containsMouse
            if (containsMouse) {
                onEntered: notificationPopup.hoverEntered()
            } else {
                onExited: notificationPopup.hoverExited()
            }
        }

        // Activate default action when dragging a file over the notification.
        DropArea {
            id: activateDefaultActionDropArea
            anchors.fill: parent

            property bool containsAcceptableDrag: false
            property point lastPosition: Qt.point(-1, -1)

            onEntered: (event) => {
                if (notificationItem.modelInterface.hasDefaultAction && !notificationItem.dragging) {
                    dragActivationTimer.restart();
                    containsAcceptableDrag = true;
                    lastPosition = Qt.point(drag.x, drag.y);
                } else {
                    drag.accepted = false;
                }
            }
            onPositionChanged: {
                if (containsAcceptableDrag) {
                    const manhattanLength = Math.abs((drag.x - lastPosition.x) + (drag.y - lastPosition.y));
                    if (manhattanLength > Application.styleHints.startDragDistance) {
                        dragActivationTimer.restart();
                        lastPosition = Qt.point(drag.x, drag.y);
                    }
                }
            }
            onDropped: {
                containsAcceptableDrag = false;
            }
            onExited: {
                containsAcceptableDrag = false;
                dragActivationTimer.stop();
            }
        }

        Timer {
            id: dragActivationTimer
            interval: 250 // same as Task Manager
            repeat: false
            onTriggered: notificationItem.modelInterface.defaultActionInvoked()
        }

        // ---- native card -----------------------------------------------------------------------------------------
        Item {
            id: nativeCard
            readonly property var mi: notificationItem.modelInterface
            visible: notificationPopup.plainCard
            z: 5
            anchors.left: parent.left; anchors.right: parent.right
            implicitHeight: Math.max(col.implicitHeight, 40) + (actions.visible ? actions.height + 10 : 0) + 2
            Kirigami.Icon { id: pic; x: 0; y: 2; width: 36; height: 36
                source: nativeCard.mi.icon || nativeCard.mi.applicationIconSource || "preferences-desktop-notification"; roundToIconSize: false }
            Column { id: col; x: 48; width: parent.width - 48 - 4; spacing: 2
                Row { width: parent.width; spacing: 6
                    Text { text: nativeCard.mi.applicationName || ""; color: Qt.rgba(1, 1, 1, 0.55); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.3
                        elide: Text.ElideRight; width: Math.min(implicitWidth, parent.width - 30) }
                    Text { visible: (nativeCard.mi.originName || "") !== ""; text: "· " + (nativeCard.mi.originName || ""); color: Qt.rgba(1, 1, 1, 0.38); font.pixelSize: 11; elide: Text.ElideRight } }
                Text { width: parent.width - 18; text: nativeCard.mi.summary || ""; color: "#f2f3f4"; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; visible: text !== "" }
                Text { width: parent.width; text: nativeCard.mi.body || ""; color: Qt.rgba(1, 1, 1, 0.72); font.pixelSize: 13; textFormat: Text.StyledText; wrapMode: Text.Wrap; maximumLineCount: 5; elide: Text.ElideRight
                    visible: text !== ""; linkColor: "#cfd3d6"; onLinkActivated: link => nativeCard.mi.openUrl(link) } }
            // actions: glass pills
            Row { id: actions; x: 48; y: Math.max(col.implicitHeight, 40) + 8; spacing: 6; visible: rep.count > 0
                Repeater { id: rep; model: nativeCard.mi.actionLabels
                    Rectangle { required property int index; required property string modelData
                        height: 26; width: lab.implicitWidth + 24; radius: 13
                        color: Qt.rgba(1, 1, 1, ah.hovered ? 0.18 : 0.10); border.width: 1; border.color: Qt.rgba(1, 1, 1, ah.hovered ? 0.24 : 0.14)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { id: lab; anchors.centerIn: parent; text: parent.modelData; color: "#f2f3f4"; font.pixelSize: 12; font.weight: Font.Medium }
                        HoverHandler { id: ah }
                        TapHandler { onTapped: nativeCard.mi.actionInvoked(nativeCard.mi.actionNames[parent.index]) } } } }
            // whole card = default action
            TapHandler { enabled: nativeCard.mi.hasDefaultAction; onTapped: nativeCard.mi.defaultActionInvoked() }
            TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: if (nativeCard.mi.closable) nativeCard.mi.closeClicked() }
            // close: appears under the pointer
            Rectangle { anchors.right: parent.right; y: 0; width: 20; height: 20; radius: 10; opacity: focusListener.containsMouse ? 1 : 0
                color: Qt.rgba(1, 1, 1, xh.hovered ? 0.22 : 0.10); Behavior on opacity { NumberAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "\u2715"; color: "#f2f3f4"; font.pixelSize: 10 }
                HoverHandler { id: xh }
                TapHandler { onTapped: nativeCard.mi.closeClicked() } }
        }
        // time left: a hairline along the card's bottom edge (only while the timer runs)
        Rectangle { visible: notificationPopup.plainCard && notificationPopup.showPopupTimeout && notificationItem.modelInterface.timeout > 0; z: 6
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: -6; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.45)
            width: parent.width * Math.max(0, Math.min(1, notificationItem.modelInterface.remainingTime / Math.max(1, notificationItem.modelInterface.timeout))) }

        NotificationsApplet.DraggableDelegate {
            opacity: notificationPopup.plainCard ? 0 : 1
            enabled: !notificationPopup.plainCard
            anchors {
                fill: parent
                topMargin: notificationPopup.modelInterface.closable || notificationPopup.modelInterface.dismissable || notificationPopup.modelInterface.configurable ? -notificationPopup.topPadding : 0
            }
            leftPadding: 0
            rightPadding: 0
            hoverEnabled: true
            draggable: notificationItem.modelInterface.notificationType != NotificationManager.Notifications.JobType
            onDismissRequested: GlassGlobals.popupNotificationsModel.close(GlassGlobals.popupNotificationsModel.index(notificationItem.modelInterface.index, 0))

            TapHandler {
                id: tapHandler
                acceptedButtons: {
                    let buttons = Qt.MiddleButton;
                    if (notificationPopup.modelInterface.hasDefaultAction) {
                        buttons |= Qt.LeftButton;
                    }
                    return buttons;
                }
                onTapped: (_eventPoint, button) => {
                    if (button === Qt.MiddleButton) {
                        if (notificationItem.modelInterface.closable) {
                            notificationItem.modelInterface.closeClicked();
                        }
                    } else if (notificationPopup.modelInterface.hasDefaultAction) {
                        notificationItem.modelInterface.defaultActionInvoked();
                    }
                }
            }

            LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
            LayoutMirroring.childrenInherit: true

            Timer {
                id: timer
                interval: notificationPopup.effectiveTimeout
                running: {
                    if (!notificationPopup.visible) {
                        return false;
                    }
                    if (focusListener.containsMouse) {
                        return false;
                    }
                    if (interval <= 0) {
                        return false;
                    }
                    if (notificationItem.dragging || notificationItem.menuOpen || activateDefaultActionDropArea.containsAcceptableDrag) {
                        return false;
                    }
                    if (notificationItem.modelInterface.replying
                            && (notificationPopup.active || notificationItem.modelInterface.hasPendingReply)) {
                        return false;
                    }
                    return true;
                }
                onTriggered: {
                    if (notificationPopup.dismissTimeout) {
                        notificationPopup.modelInterface.dismissClicked();
                    } else {
                        notificationPopup.expired();
                    }
                }
            }

            NumberAnimation {
                target: notificationItem.modelInterface
                property: "remainingTime"
                from: timer.interval
                to: 0
                duration: timer.interval
                running: timer.running && Kirigami.Units.longDuration > 1 && notificationPopup.showPopupTimeout
            }

            contentItem: NotificationsApplet.DelegatePopup {
                id: notificationItem

                Layout.preferredHeight: implicitHeight // Why is this necessary?

                modelInterface {
                    maximumLineCount: 8
                    bodyCursorShape: modelInterface.hasDefaultAction ? Qt.PointingHandCursor : 0

                    popupLeftPadding: notificationPopup.leftPadding
                    popupTopPadding: notificationPopup.topPadding
                    popupRightPadding: notificationPopup.rightPadding
                    popupBottomPadding: notificationPopup.bottomPadding

                    // When notification is updated, restart hide timer
                    onTimeChanged: {
                        if (timer.running) {
                            timer.restart();
                        }
                    }
                    timeout: timer.running ? timer.interval : 0

                    closable: true

                    onBodyClicked: {
                        if (modelInterface.hasDefaultAction) {
                            notificationItem.modelInterface.defaultActionInvoked();
                        }
                    }
                }
            }
        }
    }
}
