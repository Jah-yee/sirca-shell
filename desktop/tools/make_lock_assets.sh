#!/usr/bin/env bash
# The lock screen shows one picture: copy yours in (default: the bundled wallpaper).   tools/make_lock_assets.sh [wallpaper]
# Then run tools/install_lock.sh again.
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"; WALL="${1:-$R/design/wallpaper/glass-default.jpg}"
LOCK="$R/lock/onur.glasslock/contents/lockscreen"; mkdir -p "$LOCK/assets"
magick "$WALL" -quality 93 "$LOCK/assets/background.jpg"
echo "lock screen picture: $WALL"
