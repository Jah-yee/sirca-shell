#!/bin/bash
# use_decoration.sh glass|darkly — switch KWin's window decoration plugin (the plugin file must already be installed).
set -euo pipefail
# qdbus is "qdbus6" on Ubuntu / Arch and "qdbus-qt6" on Fedora
qdbus6() { if type -P qdbus6 >/dev/null 2>&1; then command qdbus6 "$@"; else qdbus-qt6 "$@"; fi; }
D="$(qtpaths6 --plugin-dir 2>/dev/null || qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null)/org.kde.kdecoration3"
[ -d "$D" ] || D=/usr/lib/x86_64-linux-gnu/qt6/plugins/org.kde.kdecoration3
case "${1:-}" in
  glass) [ -f "$D/org.kde.glass18.so" ] || { echo "install first:  sudo $(cd "$(dirname "$0")" && pwd)/install_qt.sh"; exit 1; }
         kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.glass18; kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Glass ;;
  darkly) kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.darkly; kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Darkly ;;
  *) echo "usage: $0 glass|darkly"; exit 2 ;;
esac
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null; echo "decoration: $(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)"
