#!/usr/bin/env bash
# Install (or remove) the Glass lock screen. No root needed.   tools/install_lock.sh [--undo]
# Plasma 6.6 takes the lock screen from a shell package. This installs one that contains ONLY a lock screen
# (~/.local/share/plasma/shells/onur.glasslock) and points the screen locker at it through PLASMA_DEFAULT_SHELL, set for
# KWin's service only (KWin starts the locker; plasmashell is a different service and keeps its normal shell package).
# Takes effect at the next login. If the package ever fails to load, kscreenlocker falls back to its default lock screen.
# Look at it without locking:  /usr/lib/x86_64-linux-gnu/libexec/kscreenlocker_greet --testing --shell onur.glasslock
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"; SRC="$R/lock/onur.glasslock"; DST="$HOME/.local/share/plasma/shells/onur.glasslock"
DROP="$HOME/.config/systemd/user/plasma-kwin_wayland.service.d/glass-lock.conf"
if [ "${1:-}" = "--undo" ]; then rm -f "$DROP" "$HOME/.local/bin/glass-lock-sync"; rmdir "$(dirname "$DROP")" 2>/dev/null || true; rm -rf "$DST"; systemctl --user daemon-reload; echo "Glass lock screen removed (Plasma's own from the next login)."; exit 0; fi
[ -f "$SRC/contents/lockscreen/LockScreenUi.qml" ] || { echo "package missing in $SRC"; exit 1; }
rm -rf "$DST"; mkdir -p "$(dirname "$DST")"; cp -r "$SRC" "$DST"
mkdir -p "$HOME/.local/bin"; ln -sfn "$R/tools/lock_state.sh" "$HOME/.local/bin/glass-lock-sync"; "$R/tools/lock_state.sh" || true   # it follows the desktop's theme, mode and wallpaper
mkdir -p "$(dirname "$DROP")"
printf '# Glass Desktop lock screen (tools/install_lock.sh --undo removes this)\n[Service]\nEnvironment=PLASMA_DEFAULT_SHELL=onur.glasslock\n' > "$DROP"
systemctl --user daemon-reload
echo "Installed. Active from the next login (KWin must start with the new setting)."
