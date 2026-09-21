// Now playing, on the lock screen: cover, title, artist, previous / play-pause / next. The same pill language as the bar's
// media widget. Loaded through a Loader: if the media module is missing, the lock screen simply has no pill.
import QtQuick
import QtQml
import QtQuick.Effects
import org.kde.plasma.private.mpris as Mpris

Item {
    id: pill
    property color ink: "white"
    property color inkDim: "white"
    property color tint: Qt.rgba(0.1, 0.1, 0.12, 0.5)
    property color line: Qt.rgba(1, 1, 1, 0.16)
    property real u: 1
    property bool tintIcons: false       // the icons are white drawings; on light glass they take the ink (GPU only)
    // Which source: the one that is PLAYING. Plasma's model keeps pointing at the source it chose last (a paused browser tab)
    // while another app plays, so every source is watched here: a playing one wins (the model's own choice first, if that is
    // playing), and with nothing playing it is the model's choice as before.
    property var sources: []
    Instantiator { model: mpris
        delegate: QtObject { required property var container }
        onObjectAdded: (i, o) => { const l = pill.sources.slice(); l.push(o); pill.sources = l }
        onObjectRemoved: (i, o) => { pill.sources = pill.sources.filter(x => x !== o) } }
    readonly property var player: { const cur = mpris.currentPlayer
        if (cur && cur.playbackStatus === Mpris.PlaybackStatus.Playing) return cur
        for (let i = 0; i < sources.length; ++i) { const c = sources[i].container; if (c && c.playbackStatus === Mpris.PlaybackStatus.Playing) return c }
        return cur }
    readonly property bool hasTrack: !!player && (player.track ?? "") !== ""
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    visible: hasTrack; width: row.implicitWidth + 28 * u; height: 56 * u
    Mpris.Mpris2Model { id: mpris }
    Rectangle { anchors.fill: parent; radius: height / 2; color: pill.tint; border.width: 1; border.color: pill.line }
    Row { id: row; anchors.centerIn: parent; spacing: 12 * pill.u
        Item { width: 38 * pill.u; height: width; anchors.verticalCenter: parent.verticalCenter
            Rectangle { id: cm; anchors.fill: parent; radius: 9 * pill.u; visible: false; layer.enabled: true }
            Image { id: cover; anchors.fill: parent; source: pill.player ? (pill.player.artUrl ?? "") : ""; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true; asynchronous: true; sourceSize: Qt.size(128, 128); smooth: true; mipmap: true }
            Rectangle { anchors.fill: parent; radius: 9 * pill.u; color: Qt.rgba(pill.ink.r, pill.ink.g, pill.ink.b, 0.10); visible: cover.status !== Image.Ready
                Image { anchors.centerIn: parent; width: 18 * pill.u; height: width; source: "icons/note.svg"; sourceSize: Qt.size(48, 48); opacity: 0.75
                    layer.enabled: pill.tintIcons; layer.effect: MultiEffect { colorization: 1; colorizationColor: pill.ink } } }
            MultiEffect { anchors.fill: parent; source: cover; maskEnabled: true; maskSource: cm; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0; visible: cover.status === Image.Ready } }
        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 1
            Text { width: Math.min(implicitWidth, 300 * pill.u); elide: Text.ElideRight; text: pill.player ? (pill.player.track ?? "") : ""; color: pill.ink; font.pixelSize: Math.round(14 * pill.u); font.weight: Font.Medium }
            Text { width: Math.min(implicitWidth, 300 * pill.u); elide: Text.ElideRight; visible: text !== ""; text: pill.player ? (pill.player.artist ?? "") : ""; color: pill.inkDim; font.pixelSize: Math.round(12 * pill.u) } }
        Row { anchors.verticalCenter: parent.verticalCenter; spacing: 2 * pill.u
            Repeater { model: [ { a: "prev" }, { a: "toggle" }, { a: "next" } ]
                Item { id: b; required property var modelData; width: 34 * pill.u; height: width
                    readonly property bool can: !pill.player ? false : (modelData.a === "prev" ? pill.player.canGoPrevious : (modelData.a === "next" ? pill.player.canGoNext : true))
                    opacity: can ? 1 : 0.35
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(pill.ink.r, pill.ink.g, pill.ink.b, ma.pressed ? 0.22 : (ma.containsMouse ? 0.13 : 0)) }
                    Image { anchors.centerIn: parent; width: (b.modelData.a === "toggle" ? 18 : 16) * pill.u; height: width; sourceSize: Qt.size(48, 48)
                        source: "icons/" + (b.modelData.a === "toggle" ? (pill.playing ? "pause" : "play") : b.modelData.a) + ".svg"
                        layer.enabled: pill.tintIcons; layer.effect: MultiEffect { colorization: 1; colorizationColor: pill.ink } }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: b.can
                        onClicked: { if (b.modelData.a === "prev") pill.player.Previous(); else if (b.modelData.a === "next") pill.player.Next(); else pill.player.PlayPause() } } } } } }
}
