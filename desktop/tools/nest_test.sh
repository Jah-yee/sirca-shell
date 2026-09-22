#!/bin/bash
# nest_test.sh <plugin .so> <out.png> [app] — load a decoration build in a NESTED KWin (no root, no touching the session),
# screenshot it, quit. How decoration changes get looked at before anyone is asked to install them.
set -euo pipefail
# qdbus is "qdbus6" on Ubuntu / Arch and "qdbus-qt6" on Fedora
qdbus6() { if command -v qdbus6 >/dev/null 2>&1; then command qdbus6 "$@"; else qdbus-qt6 "$@"; fi; }
SO="$1"; OUT="$2"; APP="${3:-kwrite}"; R="$(mktemp -d)"; ID="$(basename "$SO" .so)"
mkdir -p "$R/plugins/org.kde.kdecoration3" "$R/config"; cp "$SO" "$R/plugins/org.kde.kdecoration3/"
cp ~/.config/kwinrc ~/.config/darklyrc ~/.config/kdeglobals "$R/config/" 2>/dev/null || true
kwriteconfig6 --file "$R/config/kwinrc" --group org.kde.kdecoration2 --key library "$ID"
( XDG_CONFIG_HOME="$R/config" QT_PLUGIN_PATH="$R/plugins" setsid kwin_wayland --wayland-display "$WAYLAND_DISPLAY" --socket "wayland-glassnest-$$" --width 1100 --height 760 --no-lockscreen --no-global-shortcuts -- $APP >"$R/nest.log" 2>&1 & echo $! > "$R/pid" )
sleep 9
JS="$R/place.js"; echo 'for (const w of workspace.windowList()) if (w.normalWindow && String(w.caption).indexOf("Wayland Compositor") >= 0) w.frameGeometry = { x: 300, y: 200, width: w.frameGeometry.width, height: w.frameGeometry.height };' > "$JS"
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$JS" "gsnest$$"); qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >/dev/null; sleep 0.5; qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "gsnest$$" >/dev/null; sleep 1.5
F="$R/full.png"; timeout 20 spectacle -b -n -f -o "$F" >/dev/null 2>&1; magick "$F" -crop 1100x800+300+200 +repage "$OUT"; rm -f "$F"
kill "$(cat "$R/pid")" 2>/dev/null || true; sleep 1; rm -rf "$R"
