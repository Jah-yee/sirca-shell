#!/usr/bin/env bash
# Spotify's Miniplayer as a desktop widget: window rule + decoration exception. No root.   tools/install_spotify_widget.sh [--undo]
#  - KWin rule "spotify-miniplayer" (class chromium-browser, title contains "Spotify - Web Player"): keep above, skip task bar.
#  - Darkly decoration exception: the title bar is hidden and there is no border, but the DECORATION stays, because it casts
#    the window shadow and draws the desktop's one window edge line (a borderless window has neither).
#  - Glass Key + the Glass effect's ForceBlurClasses get the Miniplayer's window class.
# The look itself is apps/spotify/user.css ("html.glass-pip"), injected by apps/spotify/glass-live.js.
set -euo pipefail
# qdbus is "qdbus6" on Ubuntu / Arch and "qdbus-qt6" on Fedora
qdbus6() { if type -P qdbus6 >/dev/null 2>&1; then command qdbus6 "$@"; else qdbus-qt6 "$@"; fi; }
R="$HOME/.config/kwinrulesrc"; G="Windeco Exception 0"
rules() { /usr/bin/python3 - "$R" "$1" <<'P'
import os, re, sys
p, add = sys.argv[1], sys.argv[2] == "add"; s = open(p).read() if os.path.isfile(p) else "[General]\ncount=0\nrules=\n"
s = re.sub(r'\n\[spotify-miniplayer\]\n(?:[^\[\n].*\n?)*', '\n', s)
m = re.search(r'(?m)^rules=(.*)$', s); names = [r for r in (m.group(1) if m else "").split(',') if r and r != 'spotify-miniplayer']
if add:
    names.append('spotify-miniplayer')
    s = s.rstrip('\n') + '\n\n[spotify-miniplayer]\nDescription=Spotify Miniplayer: a widget (stays on top, not in the task bar; its title bar is hidden by a decoration exception)\nabove=true\naboverule=2\nskiptaskbar=true\nskiptaskbarrule=2\ntitle=Spotify - Web Player\ntitlematch=2\ntypes=1\nwmclass=chromium-browser\nwmclasscomplete=false\nwmclassmatch=1\n'
s = re.sub(r'(?m)^rules=.*$', 'rules=' + ','.join(names), s); s = re.sub(r'(?m)^count=.*$', 'count=%d' % len(names), s)
open(p + '.tmp', 'w').write(s.rstrip('\n') + '\n'); os.replace(p + '.tmp', p)
P
}
[ -f "$R" ] && cp "$R" "$R.bak-$(date +%Y%m%d%H%M)"
if [ "${1:-}" = "--undo" ]; then
    rules remove; for k in Enabled ExceptionPattern ExceptionType HideTitleBar Mask BorderSize; do kwriteconfig6 --file darklyrc --group "$G" --key $k --delete; done
    kwriteconfig6 --file kwinrc --group Effect-glasskey --key Classes spotify; kwriteconfig6 --file kwinrc --group Effect-blurplus --key ForceBlurClasses spotify
else
    rules add
    kwriteconfig6 --file darklyrc --group "$G" --key Enabled true; kwriteconfig6 --file darklyrc --group "$G" --key ExceptionPattern "Spotify - Web Player.*"
    kwriteconfig6 --file darklyrc --group "$G" --key ExceptionType 1; kwriteconfig6 --file darklyrc --group "$G" --key HideTitleBar true
    kwriteconfig6 --file darklyrc --group "$G" --key Mask 16; kwriteconfig6 --file darklyrc --group "$G" --key BorderSize 0
    kwriteconfig6 --file kwinrc --group Effect-glasskey --key Classes "spotify,chromium-browser"; kwriteconfig6 --file kwinrc --group Effect-blurplus --key ForceBlurClasses "spotify,chromium-browser"
fi
dbus-send --session --type=signal /DarklyDecoration org.kde.Darkly.Style.reparseConfiguration 2>/dev/null || true
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
echo "done (reopen the Miniplayer)"
