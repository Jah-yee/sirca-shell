#!/usr/bin/env bash
# Give the Plasma panels back and remove what install.sh installed (reads build/install_manifest.txt).
set -euo pipefail
cd "$(dirname "$0")"
command -v sirca-shell-switch >/dev/null && sirca-shell-switch off || true
[ -f build/install_manifest.txt ] || { echo "no build/install_manifest.txt: nothing recorded to remove"; exit 1; }
xargs -a build/install_manifest.txt -d '\n' rm -f --
rm -f "$HOME/.config/systemd/user/sirca-shell.service" "$HOME/.config/systemd/user/sirca-shell-fallback.service"
systemctl --user daemon-reload || true; kbuildsycoca6 >/dev/null 2>&1 || true
echo "Removed. Your settings stay in ~/.config/sirca-shell (delete that folder to forget them)."
