#!/usr/bin/env bash
# demo-notifications.sh — a handful of made-up notifications for screenshots and videos of the shell: two apps with
# several entries each (they stack up in the history behind the bell) and a few single ones. Nothing here is real.
# Each one pops up as a card for a moment and then sits in the history.  --fast: no pauses between them.
# Clear them again with the "Clear" button in the history.
set -euo pipefail
pause=1.6; [ "${1:-}" = "--fast" ] && pause=0.15
say() {  # app-name  desktop-entry  icon  title  text
  notify-send -a "$1" -h "string:desktop-entry:$2" -i "$3" -t 4000 "$4" "$5"; sleep "$pause"; }
# (one app never twice in a row: the notification library folds two quick ones from the same app into a single card)
say "Discord"  discord            discord                    "Mira"                 "are we still on for the raid tonight?"
say "Steam"    steam              steam                      "Juno is now playing"  "Hollow Knight: Silksong"
say "Discord"  discord            discord                    "Mira"                 "bring the good snacks this time"
say "Firefox"  firefox            firefox                    "Download finished"    "wallpaper-pack-32x9.zip"
say "Steam"    steam              steam                      "Download complete"    "Hades II is ready to play"
say "Calendar" org.gnome.Calendar org.gnome.Calendar         "Design review"        "Starts in 15 minutes  ·  Room 2"
say "Discord"  discord            discord                    "#showcase"            "Theo: that glass dock is unreal, dotfiles when?"
say "Discover" org.kde.discover   system-software-update     "Updates available"    "12 packages can be updated"
say "Dolphin"  org.kde.dolphin    system-file-manager        "Copy finished"        "248 photos copied to Pictures/Trip"
echo "done: 9 notifications (Discord x3 and Steam x2 stack up; Firefox, Calendar, Discover, Dolphin stand alone)"
