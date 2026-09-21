// Now playing, in the bar. No container at rest: a round cover wrapped by a thin progress ring, the title with the
// artist dimmed after it, and a small level meter. Static: hovering only lays a faint glass tile under it, clicking opens the
// now-playing lobe, which has the controls. Data: Plasma's MPRIS model.
import QtQuick
import QtQml
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume
import org.kde.kirigami as Kirigami
import SircaShell

Item {
    id: island
    signal clicked()                // the bar opens the now-playing lobe
    property bool lobeOpen: false
    readonly property alias model: mpris
    property bool quiet: false      // a fullscreen window has focus: stop the perpetual animations, nobody can see them
    // Which source: the one that is PLAYING. Plasma's model keeps pointing at the source it chose last (a paused browser tab)
    // while another app plays, so every source is watched here: a playing one wins (the model's own choice first, if that is
    // playing), and with nothing playing it is the model's choice as before.
    property var sources: []
    Instantiator { model: mpris
        delegate: QtObject { required property var container }
        onObjectAdded: (i, o) => { const l = island.sources.slice(); l.push(o); island.sources = l }
        onObjectRemoved: (i, o) => { island.sources = island.sources.filter(x => x !== o) } }
    readonly property var player: { const cur = mpris.currentPlayer
        if (cur && cur.playbackStatus === Mpris.PlaybackStatus.Playing) return cur
        for (let i = 0; i < sources.length; ++i) { const c = sources[i].container; if (c && c.playbackStatus === Mpris.PlaybackStatus.Playing) return c }
        return cur }
    readonly property bool hasTrack: !!player && (player.track ?? "") !== ""
    property alias coverItem: disc                 // the bar builds its colour haze from the cover only
    readonly property string coverUrl: cover.status === Image.Ready ? String(cover.source) : ""
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool hovered: hover.hovered
    readonly property real progress: (player && player.length > 0) ? Math.max(0, Math.min(1, player.position / player.length)) : 0
    readonly property string artist: player ? (player.artist ?? "") : ""

    Mpris.Mpris2Model { id: mpris }
    Timer { interval: 1000; repeat: true; running: island.playing && island.visible && !island.quiet; onTriggered: island.player.updatePosition() }

    visible: opacity > 0.01
    property bool allowed: true                 // placed in the bar at all (layout) and not in edit mode
    opacity: hasTrack && allowed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Config.normal } }
    height: 29
    width: hasTrack ? row.implicitWidth + 18 : 0
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }   // track changes only; nothing resizes on hover
    clip: true

    // hover pill: the very same one as the clock and the gear (27 px, fill only, no rim); a bit brighter while the lobe is open
    Rectangle { anchors.centerIn: parent; width: parent.width; height: 27; radius: 13.5
        color: Config.fg(island.lobeOpen ? 0.12 : (island.hovered ? 0.07 : 0))
        Behavior on color { ColorAnimation { duration: Config.quick } } }

    Row {
        id: row
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        // cover in a progress ring
        Item { width: 25; height: 25; anchors.verticalCenter: parent.verticalCenter
            Shape {   // track + progress arc
                anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: Config.fg(0.14); strokeWidth: 1.5; fillColor: "transparent"
                    PathAngleArc { centerX: 12.5; centerY: 12.5; radiusX: 11.5; radiusY: 11.5; startAngle: 0; sweepAngle: 360 } }
                ShapePath { strokeColor: Config.fg(island.playing ? 0.92 : 0.5); strokeWidth: 1.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 12.5; centerY: 12.5; radiusX: 11.5; radiusY: 11.5; startAngle: -90; sweepAngle: Math.max(0.01, 360 * island.progress) } }
            }
            Item { id: disc; anchors.centerIn: parent; width: 19; height: 19
                opacity: island.playing ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: Config.normal } }
                Rectangle { id: coverMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true; layer.smooth: true }
                Image { id: cover; anchors.fill: parent; source: island.player ? (island.player.artUrl ?? "") : ""; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true; asynchronous: true; sourceSize: Qt.size(76, 76); smooth: true; mipmap: true }
                MultiEffect { anchors.fill: parent; source: cover; maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0; visible: cover.status === Image.Ready }
                Kirigami.Icon { anchors.centerIn: parent; width: 13; height: 13; source: "emblem-music-symbolic"; isMask: true; color: Config.fgSolid; opacity: 0.8; visible: cover.status !== Image.Ready; roundToIconSize: false }
            }
        }

        // title, then the artist dimmed; one line, fading out at the end instead of "…"
        Item { id: label; anchors.verticalCenter: parent.verticalCenter
            width: Math.min(line.implicitWidth, 300); height: line.implicitHeight
            Text { id: line; textFormat: Text.StyledText; font.pixelSize: 13; font.weight: Font.Medium; color: Config.ink
                opacity: island.playing ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: Config.normal } }
                text: {
                    const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                    const t = island.player ? esc(island.player.track ?? "") : ""
                    return island.artist !== "" ? t + "<font color=\"" + Config.hex(Config.inkDim) + "\">&nbsp;&nbsp;" + esc(island.artist) + "</font>" : t
                }
                layer.enabled: line.implicitWidth > 300
                layer.effect: MultiEffect { maskEnabled: true; maskSource: fadeMask }
            }
            Rectangle { id: fadeMask; width: 300; height: line.implicitHeight; visible: false; layer.enabled: true
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "white" } GradientStop { position: 0.86; color: "white" } GradientStop { position: 1.0; color: "transparent" } } }
            clip: true
        }

        // Level meter: four slim rounded bars driven by the REAL output level (PulseAudio/PipeWire peak of the default
        // sink, ~25 readings a second, only while something plays and the bar is not in quiet mode). One level, four bars:
        // each bar shows the level a few readings later than its left neighbour, so loud moments travel across as a small
        // wave. Rise at once, fall slowly, like a meter.
        Row { id: levels; spacing: 2.5; anchors.verticalCenter: parent.verticalCenter; height: 14; visible: island.playing
            readonly property bool live: island.playing && island.visible && !island.quiet && Config.levelMeter
            property var history: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            property var shown: [0, 0, 0, 0]
            VolumeMonitor { id: meter; target: levels.live ? PreferredDevice.sink : null
                // Auto-ranging: the bars show the level RELATIVE to how loud it has been lately, not the absolute peak. An app with
                // its own volume turned down (measured: Spotify peaking at 0.013 of full scale) left the bars flat. `ref` follows
                // the loudest recent reading: up at once, down by half in about 8 s; below the floor it is silence, not music.
                property real ref: 0.05
                onVolumeChanged: { ref = Math.max(0.004, volume, ref * 0.9965)
                    const rel = volume < 0.0006 ? 0 : volume / ref
                    const h = levels.history.slice(1); h.push(Math.min(1, Math.pow(rel, 1.6))); levels.history = h;   // pow > 1: peaks near the recent maximum are the norm, spread them out
                    const out = []; for (let i = 0; i < 4; ++i) { const v = h[h.length - 1 - i * 2]; out.push(v > levels.shown[i] ? v : Math.max(v, levels.shown[i] * 0.80)) }
                    // a bar is 3..14 px tall: a change of less than a pixel is invisible, but assigning it would still repaint the
                    // whole 5120-wide bar surface. Only whole-pixel changes go through (steady or quiet passages then cost nothing).
                    let same = true; for (let i = 0; i < 4; ++i) if (Math.round(11 * out[i]) !== Math.round(11 * (levels.shown[i] || 0))) { same = false; break }
                    if (!same) levels.shown = out } }
            onLiveChanged: if (!live) shown = [0, 0, 0, 0]
            Repeater { model: 4
                Rectangle { required property int index
                    readonly property real level: levels.shown[index] || 0
                    width: 2; radius: 1; anchors.verticalCenter: parent.verticalCenter
                    height: 3 + 11 * level
                    color: Config.fg(0.5 + 0.45 * level) } }      // no Behavior: easing a value that changes 25x a second repaints this wide surface at the full 240 Hz
        }
    }
    HoverHandler { id: hover }
    TapHandler { onTapped: island.clicked() }
}
