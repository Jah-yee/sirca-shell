// Preview of the Glass lock screen with a mock authenticator (never the real locker).
//   sirca-shell --qml-test harness.qml -- <W> <H> <rest|unlock|failed> <out.png> [ms]
// Without QT_QPA_PLATFORM=offscreen it opens a focus-free window for a moment and saves its own image (GPU effects on).
import QtQuick
import QtQuick.Window
Window { id: win
    readonly property var a: { const i = Qt.application.arguments.indexOf("--"); return i >= 0 ? Qt.application.arguments.slice(i + 1) : [] }
    width: parseInt(a[0] || "1700"); height: parseInt(a[1] || "760"); visible: true; color: "black"
    flags: Qt.Tool | Qt.WindowDoesNotAcceptFocus | Qt.FramelessWindowHint; title: "Glass lock preview"
    property string kscreenlocker_userName: "onur"
    property string kscreenlocker_userImage: "/var/lib/AccountsService/icons/onur"
    QtObject { id: authenticator; property bool hadPrompt: true; property string infoMessage: ""; property string errorMessage: ""; property string prompt: ""; property bool busy: false
        signal failed(int kind); signal succeeded(); signal promptForSecretChanged()
        function startAuthenticating() { console.log("mock: startAuthenticating") }
        function respond(p) { console.log("mock: respond, length", p.length); failed(0) } }
    Loader { id: l; anchors.fill: parent; source: "../onur.glasslock/contents/lockscreen/LockScreen.qml" }
    function ui() { return l.item.children[0] }
    Timer { interval: 300; running: true; onTriggered: { const st = win.a[2] || "rest"; if (st !== "rest") win.ui().wake(); if (st === "failed") { win.ui().submit() } } }
    Timer { interval: parseInt(win.a[4] || "3200"); running: true; onTriggered: { console.log("state shown", win.ui().shown, "fx", win.ui().fx, "msg", win.ui().message); l.item.grabToImage(r => { console.log("saved", r.saveToFile(win.a[3] || "out.png")); Qt.quit() }) } } }
