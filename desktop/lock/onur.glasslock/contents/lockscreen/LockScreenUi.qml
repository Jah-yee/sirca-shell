// Glass — lock screen. Same picture and the same glass card as the Glass login screen, so locking, unlocking and logging
// in all look like one thing.
//   rest   sharp wallpaper, slow drifting light, a large clock. The picture leans a little with the pointer.
//   unlock any key or click: the picture blurs (live GPU blur) and the glass card comes up. The password field owns the
//          keyboard the whole time, so you can simply start typing.
// Talks to the locker through `authenticator` (startAuthenticating / respond / succeeded / failed), like Plasma's own.
// If this file ever failed to load, kscreenlocker falls back to the default lock screen: it cannot lock you out.
import QtQuick
import QtQuick.Effects
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import "state.js" as State

Item {
    id: ui
    // the desktop's colour theme, light / dark and wallpaper (state.js is rewritten by glass-mode on every switch)
    readonly property color accent: State.accent
    readonly property bool dark: State.dark
    readonly property color ink: dark ? "#eff0f1" : "#23252e"
    readonly property color inkDim: dark ? Qt.rgba(239/255, 240/255, 241/255, 0.66) : Qt.rgba(0.14, 0.15, 0.19, 0.70)
    function fgc(a) { return dark ? Qt.rgba(1, 1, 1, a) : Qt.rgba(0.16, 0.17, 0.22, Math.min(1, a * 1.25)) }   // overlays: light on dark glass, slate on milk
    readonly property color glassTint: dark ? Qt.rgba(24/255, 25/255, 27/255, fx ? 0.40 : 0.74) : Qt.rgba(0.975, 0.98, 0.99, fx ? 0.58 : 0.86)
    readonly property string wallpaper: State.wallpaper !== "" ? State.wallpaper : "assets/background.jpg"
    readonly property real u: Math.max(1, Math.min(1.6, height / 1080))
    readonly property bool fx: GraphicsInfo.api !== GraphicsInfo.Software

    FontLoader { id: fRegular; source: "fonts/Inter-Regular.ttf" }
    FontLoader { source: "fonts/Inter-Medium.ttf" }
    FontLoader { source: "fonts/Inter-SemiBold.ttf" }
    FontLoader { id: dLight; source: "fonts/Outfit-ExtraLight.ttf" }
    FontLoader { source: "fonts/Outfit-Regular.ttf" }
    FontLoader { source: "fonts/Outfit-Medium.ttf" }
    readonly property string family: fRegular.status === FontLoader.Ready ? fRegular.name : "sans-serif"
    readonly property string displayFamily: dLight.status === FontLoader.Ready ? dLight.name : family

    // ---- state ----
    property bool shown: false                   // the card is up
    property bool busy: false                    // waiting for PAM
    property bool locked: false                  // short pause after a wrong password
    property bool noPassword: false              // authenticated without a prompt: just offer "Unlock"
    property string message: ""
    property real blurAmt: shown ? 1 : 0
    Behavior on blurAmt { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    function wake() { if (!shown) { shown = true; authenticator.startAuthenticating() } idle.restart(); password.forceActiveFocus() }
    function submit() { if (busy || locked) return; if (noPassword) { Qt.quit(); return } busy = true; message = ""; authenticator.respond(password.text) }
    Timer { id: idle; interval: 30000; onTriggered: if (password.text === "" && !ui.busy) ui.shown = false; else restart() }
    Timer { id: grace; interval: 1500; onTriggered: { ui.locked = false; authenticator.startAuthenticating(); password.forceActiveFocus() } }

    Connections { target: authenticator
        function onFailed(kind) { if (kind !== 0) return;          // non-interactive authenticators (fingerprint …) fail quietly
            ui.busy = false; ui.locked = true; ui.message = "That password did not work"; password.text = ""; shake.restart(); grace.restart() }
        function onSucceeded() { if (authenticator.hadPrompt) Qt.quit(); else { ui.busy = false; ui.noPassword = true; ui.shown = true } }
        function onInfoMessageChanged() { if (authenticator.infoMessage) ui.message = authenticator.infoMessage }
        function onErrorMessageChanged() { if (authenticator.errorMessage) ui.message = authenticator.errorMessage }
        function onPromptForSecretChanged() { password.forceActiveFocus() } }
    Connections { target: root
        function onClearPassword() { password.text = ""; ui.busy = false }
        function onNotificationRepeated() { ui.wake() } }
    KeyboardIndicator.KeyState { id: caps; key: Qt.Key_CapsLock }

    // ---- the picture ----
    property real lookX: 0
    property real lookY: 0
    Item { id: picture; anchors.fill: parent; visible: !ui.fx; layer.enabled: ui.fx
        readonly property real room: 28 * ui.u
        Rectangle { anchors.fill: parent; color: ui.dark ? "#05060f" : "#f1f2f6" }
        Image { id: bg; x: -picture.room + picture.room * -ui.lookX * 0.6; y: -picture.room + picture.room * -ui.lookY * 0.6
            width: parent.width + 2 * picture.room; height: parent.height + 2 * picture.room
            Behavior on x { SmoothedAnimation { velocity: 26 } } Behavior on y { SmoothedAnimation { velocity: 26 } }
            source: ui.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: false; smooth: true; mipmap: true
            onStatusChanged: if (status === Image.Error && source != "assets/background.jpg") source = "assets/background.jpg" } }   // a wallpaper that has gone: the bundled one
    MultiEffect { anchors.fill: parent; visible: ui.fx; source: picture
        blurEnabled: ui.blurAmt > 0.002; blur: ui.blurAmt; blurMax: 64; blurMultiplier: 1.5
        saturation: 0.12 * ui.blurAmt; brightness: -0.04 * ui.blurAmt; scale: 1 + 0.02 * ui.blurAmt }
    Rectangle { anchors.fill: parent; color: ui.dark ? "#02030a" : "#f4f5f9"; opacity: ui.shown ? (ui.fx ? (ui.dark ? 0.26 : 0.22) : 0.55) : (ui.dark ? 0.10 : 0.04)
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } } }
    Rectangle { anchors.fill: parent
        opacity: ui.dark ? 1 : 0.25
        gradient: Gradient { GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) } GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.0) } GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.20) } } }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: ui.wake()
        onPositionChanged: m => { ui.lookX = (m.x / width) * 2 - 1; ui.lookY = (m.y / height) * 2 - 1; if (ui.shown) idle.restart() } }

    // ---- clock ----
    Column { id: clock; anchors.horizontalCenter: parent.horizontalCenter
        y: ui.shown ? ui.height * 0.105 : ui.height * 0.30
        Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }
        scale: ui.shown ? 0.62 : 1; transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }
        spacing: 2 * ui.u
        property date now: new Date()
        Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: clock.now = new Date() }
        Text { anchors.horizontalCenter: parent.horizontalCenter; color: ui.inkDim; font.family: ui.displayFamily; font.pixelSize: Math.round(23 * ui.u); font.letterSpacing: 0.6; text: Qt.formatDate(clock.now, "dddd, d MMMM") }
        Text { anchors.horizontalCenter: parent.horizontalCenter; color: ui.ink; font.family: ui.displayFamily; font.weight: Font.ExtraLight; font.pixelSize: Math.round(138 * ui.u); font.letterSpacing: -1
            text: Qt.formatTime(clock.now, "h:mm AP").replace(/\s?[AP]M$/i, "") } }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: ui.height * 0.30 + 214 * ui.u; color: ui.inkDim; font.family: ui.family; font.pixelSize: Math.round(14 * ui.u); text: "Press any key to unlock"
        property real pulse: 1; opacity: ui.shown ? 0 : 0.8 * pulse; Behavior on opacity { NumberAnimation { duration: 300 } }
        SequentialAnimation on pulse { loops: Animation.Infinite; NumberAnimation { to: 0.45; duration: 1800; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: 1800; easing.type: Easing.InOutSine } } }

    // ---- the glass card ----
    Item { id: card; width: Math.round(380 * ui.u); height: Math.round(cardCol.implicitHeight + 48 * ui.u)
        x: Math.round((parent.width - width) / 2); y: Math.round(ui.height * 0.5 - height / 2 + 30 * ui.u) + lift
        property real lift: ui.shown ? 0 : 34 * ui.u
        property real show: ui.shown ? 1 : 0
        opacity: show; scale: 0.94 + 0.06 * show; visible: opacity > 0.01
        Behavior on show { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Behavior on lift { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
        transform: Translate { id: shakeX }
        SequentialAnimation { id: shake
            NumberAnimation { target: shakeX; property: "x"; to: -12; duration: 50 } NumberAnimation { target: shakeX; property: "x"; to: 10; duration: 70 }
            NumberAnimation { target: shakeX; property: "x"; to: -6; duration: 70 } NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 80 } }
        Item { anchors.fill: parent; visible: ui.fx
            ShaderEffectSource { id: under; sourceItem: picture; sourceRect: Qt.rect(card.x, card.y, card.width, card.height); live: true; visible: false; width: card.width; height: card.height }
            Rectangle { id: cardMask; anchors.fill: parent; radius: 22 * ui.u; visible: false; layer.enabled: true; layer.smooth: true }
            MultiEffect { anchors.fill: parent; source: under; blurEnabled: true; blur: 1.0; blurMax: 64; blurMultiplier: 3.0; autoPaddingEnabled: false; saturation: 0.45; brightness: ui.dark ? 0.05 : 0.10
                maskEnabled: true; maskSource: cardMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 } }
        Rectangle { z: -2; anchors.fill: parent; anchors.margins: -1; anchors.topMargin: 10 * ui.u; anchors.bottomMargin: -16 * ui.u; radius: 30 * ui.u; color: Qt.rgba(0, 0, 0, ui.dark ? 0.30 : 0.10)
            layer.enabled: ui.fx; layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 40 } }                 // a soft shadow: the card floats
        Rectangle { anchors.fill: parent; radius: 22 * ui.u; color: ui.glassTint }
        Rectangle { anchors.fill: parent; radius: 22 * ui.u; gradient: Gradient { GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, ui.dark ? 0.11 : 0.55) } GradientStop { position: 0.22; color: Qt.rgba(1, 1, 1, 0.0) } } }
        // the rim: bright along the top like light catching the edge, fading down the sides (the shell's glass does the same)
        Rectangle { anchors.fill: parent; radius: 22 * ui.u; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, ui.dark ? 0.10 : 0.55) }
        Item { anchors.fill: parent
            Rectangle { width: parent.width; height: card.height; radius: 22 * ui.u; color: "transparent"; border.width: 1.2; border.color: Qt.rgba(1, 1, 1, ui.dark ? 0.30 : 0.95) }
            layer.enabled: true; layer.effect: MultiEffect { maskEnabled: true; maskSource: rimFade; maskThresholdMin: 0.0; maskSpreadAtMin: 1.0 }
        }
        Rectangle { id: rimFade; anchors.fill: parent; visible: false; layer.enabled: true
            gradient: Gradient { GradientStop { position: 0.0; color: "white" } GradientStop { position: 0.5; color: "transparent" } } }
        Column { id: cardCol; anchors.horizontalCenter: parent.horizontalCenter; y: 30 * ui.u; width: parent.width - 56 * ui.u; spacing: 14 * ui.u
            Item { width: 92 * ui.u; height: width; anchors.horizontalCenter: parent.horizontalCenter
                Rectangle { anchors.fill: parent; radius: width / 2; color: ui.fgc(0.08); border.width: 1; border.color: ui.fgc(0.2) }
                Image { anchors.centerIn: parent; width: parent.width * 0.5; height: width; source: "icons/user.svg"; sourceSize: Qt.size(96, 96); opacity: 0.8; visible: !face.ok; layer.enabled: ui.fx && !ui.dark; layer.effect: MultiEffect { colorization: 1; colorizationColor: ui.ink } }
                Canvas { id: face; anchors.fill: parent; anchors.margins: 3 * ui.u
                    property string src: kscreenlocker_userImage !== "" ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""
                    property bool ok: false; visible: ok
                    onSrcChanged: { ok = false; if (src !== "") { if (isImageLoaded(src)) { ok = true; requestPaint() } else loadImage(src) } }
                    Component.onCompleted: if (src !== "") loadImage(src)
                    onImageLoaded: if (isImageLoaded(src)) { ok = true; requestPaint() }
                    onPaint: { const c = getContext("2d"); c.reset(); if (!ok) return; c.beginPath(); c.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI); c.closePath(); c.clip(); c.drawImage(src, 0, 0, width, height) } } }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; color: ui.ink; font.family: ui.displayFamily; font.weight: Font.Medium; font.pixelSize: Math.round(22 * ui.u); elide: Text.ElideRight
                text: kscreenlocker_userName.charAt(0).toUpperCase() + kscreenlocker_userName.slice(1) }
            Rectangle { id: field; width: parent.width; height: 46 * ui.u; radius: height / 2
                color: ui.fgc(password.activeFocus ? 0.10 : 0.07); border.width: password.activeFocus ? 1.5 : 1
                border.color: password.activeFocus ? Qt.rgba(ui.accent.r, ui.accent.g, ui.accent.b, 0.95) : ui.fgc(0.14)
                Repeater { model: 4
                    Rectangle { required property int index; z: -1; anchors.fill: parent; anchors.margins: -(index + 1) * 2 * ui.u; radius: height / 2; color: "transparent"
                        border.width: 2 * ui.u; border.color: Qt.rgba(ui.accent.r, ui.accent.g, ui.accent.b, (password.activeFocus ? 0.16 : 0) * (1 - index / 4)) } }
                Text { anchors.verticalCenter: parent.verticalCenter; x: 20 * ui.u; color: ui.inkDim; font.family: ui.family; font.pixelSize: Math.round(15 * ui.u); visible: password.text === ""
                    text: ui.noPassword ? "Press Enter to unlock" : (ui.busy ? "Checking…" : (ui.locked ? "Wait a moment…" : "Password")) }
                TextInput { id: password; anchors.left: parent.left; anchors.right: go.left; anchors.leftMargin: 20 * ui.u; anchors.rightMargin: 8 * ui.u; anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password; passwordCharacter: "●"; passwordMaskDelay: 0; color: ui.ink; font.family: ui.family; font.pixelSize: Math.round(15 * ui.u); font.letterSpacing: 2
                    clip: true; focus: true; readOnly: ui.busy || ui.locked || ui.noPassword
                    cursorDelegate: Rectangle { width: 1.5; color: ui.accent; visible: password.activeFocus && password.text !== "" }
                    onTextChanged: { if (text !== "") { ui.message = ""; if (!ui.shown) ui.wake() } idle.restart() }
                    onAccepted: ui.submit()
                    Keys.onEscapePressed: { text = ""; ui.shown = false }
                    Keys.onPressed: e => { if (!ui.shown) { ui.wake(); if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) e.accepted = true } } }
                Rectangle { id: go; width: 34 * ui.u; height: width; radius: width / 2; anchors.right: parent.right; anchors.rightMargin: 6 * ui.u; anchors.verticalCenter: parent.verticalCenter
                    color: goArea.pressed ? ui.fgc(0.30) : (goArea.containsMouse ? ui.fgc(0.22) : ui.fgc(0.14)); opacity: (password.text !== "" || ui.noPassword) && !ui.busy ? 1 : 0.35
                    Image { anchors.centerIn: parent; width: 17 * ui.u; height: width; source: "icons/arrow.svg"; sourceSize: Qt.size(48, 48); layer.enabled: ui.fx && !ui.dark; layer.effect: MultiEffect { colorization: 1; colorizationColor: ui.ink } }
                    MouseArea { id: goArea; anchors.fill: parent; hoverEnabled: true; onClicked: ui.submit() } } }
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 6 * ui.u; height: 18 * ui.u
                readonly property string note: ui.message !== "" ? ui.message : (root.notification ? root.notification : (caps.locked ? "Caps Lock is on" : ""))
                Image { anchors.verticalCenter: parent.verticalCenter; width: 14 * ui.u; height: width; source: "icons/caps.svg"; sourceSize: Qt.size(32, 32); visible: caps.locked && ui.message === ""; opacity: 0.8; layer.enabled: ui.fx && !ui.dark; layer.effect: MultiEffect { colorization: 1; colorizationColor: ui.ink } }
                Text { anchors.verticalCenter: parent.verticalCenter; font.family: ui.family; font.pixelSize: Math.round(12.5 * ui.u); color: ui.message !== "" ? (ui.dark ? "#f0676c" : "#c9353a") : ui.inkDim; text: parent.note !== "" ? parent.note : " " } } } }

    // now playing, bottom centre (a Loader: without the media module there is simply no pill)
    Loader { id: media; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 34 * ui.u; source: "MediaPill.qml"
        onLoaded: { item.u = Qt.binding(() => ui.u); item.ink = Qt.binding(() => ui.ink); item.inkDim = Qt.binding(() => ui.inkDim); item.tint = Qt.binding(() => ui.glassTint); item.line = Qt.binding(() => ui.fgc(0.16)); item.tintIcons = Qt.binding(() => ui.fx && !ui.dark) } }

    // sleep, bottom right (only if the system can)
    Rectangle { visible: root.suspendToRamSupported; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 28 * ui.u; width: 36 * ui.u; height: width; radius: width / 2
        color: sa.pressed ? ui.fgc(0.20) : (sa.containsMouse ? ui.fgc(0.13) : ui.glassTint); border.width: 1; border.color: ui.fgc(0.13)
        Image { anchors.centerIn: parent; width: 16 * ui.u; height: width; source: "icons/sleep.svg"; sourceSize: Qt.size(48, 48); opacity: 0.9; layer.enabled: ui.fx && !ui.dark; layer.effect: MultiEffect { colorization: 1; colorizationColor: ui.ink } }
        MouseArea { id: sa; anchors.fill: parent; hoverEnabled: true; onClicked: root.suspendToRam() } }

    Keys.onPressed: e => ui.wake()
    Component.onCompleted: password.forceActiveFocus()
}
