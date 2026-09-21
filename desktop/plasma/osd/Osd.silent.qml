/*
    Silent on-screen display: installed by `sirca-shell-switch on`. Sirca Shell shows volume / brightness inside its top
    bar (it listens to plasmashell's osdService signals, which are only emitted while the OSD is enabled), so the popup
    itself must exist but never appear. Same properties as Osd.qml, which plasmashell sets.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.workspace.osd

OsdWindow {
    id: window
    property int timeout: 1
    property var osdValue
    property int osdMaxValue: 100
    property string osdAdditionalText: ""
    property string icon
    property bool showingProgress: false
    width: 1; height: 1
    // NOT hidden in the same instant: a window that maps and unmaps at once is announced to task managers before its
    // on-screen-display role (skip taskbar) has arrived, and Sirca Shell's dock grew by one cell for a moment on every
    // volume / brightness change. A short life lets the role apply; 1x1 px and empty, it is not seen.
    // ... and it stays up while updates keep coming (a held key, a dragged slider): hiding and re-showing in a burst made
    // the phantom task come back on every re-show. One appearance per burst; gone 1.2 s after the last update.
    Timer { id: hideSoon; interval: 1200; onTriggered: window.visible = false }
    onVisibleChanged: if (visible) hideSoon.restart()
    onOsdValueChanged: hideSoon.restart()
    onOsdAdditionalTextChanged: hideSoon.restart()
    onIconChanged: hideSoon.restart()
    mainItem: Item { implicitWidth: 1; implicitHeight: 1 }
}
