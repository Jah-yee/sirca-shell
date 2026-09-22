#!/bin/bash
# sudo tools/install_qt.sh — installs the Glass window decoration and the forked widget style system-wide.
# The stock Darkly style is kept as darkly6.so.orig-glass (first run only). Undo: sudo tools/install_qt.sh --undo
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)/build"; P=/usr/lib/x86_64-linux-gnu/qt6/plugins
if [ "${1:-}" = "--undo" ]; then
  [ -f "$P/styles/darkly6.so.orig-glass" ] && mv "$P/styles/darkly6.so.orig-glass" "$P/styles/darkly6.so"
  rm -f "$P/org.kde.kdecoration3/"org.kde.glass*.so; echo "undone (switch the decoration back with tools/use_decoration.sh darkly)"; exit 0
fi
[ -f "$P/styles/darkly6.so.orig-glass" ] || cp "$P/styles/darkly6.so" "$P/styles/darkly6.so.orig-glass"
install -m 755 "$SRC/darkly6.so" "$P/styles/darkly6.so"
install -m 755 "$SRC/org.kde.glass18.so" "$P/org.kde.kdecoration3/org.kde.glass18.so"
# older builds stay until KWin is restarted (the running KWin may still have one loaded); harmless files
echo "installed. Now run (as yourself):  $(dirname "$0")/use_decoration.sh glass"
