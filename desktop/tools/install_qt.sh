#!/bin/bash
# sudo tools/install_qt.sh — installs the Glass window decoration and the forked widget style system-wide.
# The stock Darkly style is kept as darkly6.so.orig-glass (first run only). Undo: sudo tools/install_qt.sh --undo
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)/build"
# Qt's plugin folder differs per distro (Ubuntu /usr/lib/x86_64-linux-gnu/qt6/plugins, Fedora /usr/lib64/qt6/plugins, Arch /usr/lib/qt6/plugins): ask Qt
P="$(qtpaths6 --plugin-dir 2>/dev/null || qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null || true)"
[ -d "$P" ] || P=/usr/lib/x86_64-linux-gnu/qt6/plugins
[ -d "$P" ] || { echo "Qt 6 plugin folder not found (qtpaths6 / qmake6 missing?)"; exit 1; }
if [ "${1:-}" = "--undo" ]; then
  [ -f "$P/styles/darkly6.so.orig-glass" ] && mv "$P/styles/darkly6.so.orig-glass" "$P/styles/darkly6.so"
  rm -f "$P/org.kde.kdecoration3/"org.kde.glass*.so; echo "undone (switch the decoration back with tools/use_decoration.sh darkly)"; exit 0
fi
# the stock Darkly style is kept if it is there; without it there is nothing to keep (Fedora, Arch: Darkly is not a default package)
[ -f "$P/styles/darkly6.so.orig-glass" ] || { [ -f "$P/styles/darkly6.so" ] && cp "$P/styles/darkly6.so" "$P/styles/darkly6.so.orig-glass"; } || true
mkdir -p "$P/styles" "$P/org.kde.kdecoration3"
install -m 755 "$SRC/darkly6.so" "$P/styles/darkly6.so"
install -m 755 "$SRC/org.kde.glass18.so" "$P/org.kde.kdecoration3/org.kde.glass18.so"
# older builds stay until KWin is restarted (the running KWin may still have one loaded); harmless files
echo "installed. Now run (as yourself):  $(dirname "$0")/use_decoration.sh glass"
