#!/bin/bash
# use_decoration.sh glass|darkly — switch KWin's window decoration plugin (the plugin file must already be installed).
set -euo pipefail
D=/usr/lib/x86_64-linux-gnu/qt6/plugins/org.kde.kdecoration3
case "${1:-}" in
  glass) [ -f "$D/org.kde.glass18.so" ] || { echo "install first:  sudo $(cd "$(dirname "$0")" && pwd)/install_qt.sh"; exit 1; }
         kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.glass18; kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Glass ;;
  darkly) kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.darkly; kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Darkly ;;
  *) echo "usage: $0 glass|darkly"; exit 2 ;;
esac
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null; echo "decoration: $(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)"
