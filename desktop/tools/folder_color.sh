#!/usr/bin/env bash
# Switch the folder colour of the personal Papirus copy (~/.local/share/icons/Papirus-Dark, and Papirus / Papirus-Light
# if they are there too).   tools/folder_color.sh <colour>      e.g. blue, indigo, black, grey, nordic, darkcyan, violet
# Papirus ships every colour; the plain names (folder.svg, folder-documents.svg, user-home.svg, …) are symlinks to one
# colour's files. This relinks them, like upstream's papirus-folders does, but without root and only in your home copy.
# Each run writes the previous links to ~/.local/state/glass-desktop/folder-color.prev (restore: run with that colour).
set -euo pipefail
NEW="${1:?colour, e.g. blue}"; STATE="$HOME/.local/state/glass-desktop"; mkdir -p "$STATE"
changed=0; prev=""
for theme in "$HOME/.local/share/icons/Papirus-Dark" "$HOME/.local/share/icons/Papirus" "$HOME/.local/share/icons/Papirus-Light"; do
    [ -d "$theme" ] || continue
    for places in "$theme"/*/places; do
        [ -d "$places" ] || continue
        [ -e "$places/folder-$NEW.svg" ] || continue
        cur="$(readlink "$places/folder.svg" || true)"; cur="${cur#folder-}"; cur="${cur%.svg}"        # colour in use now
        [ -n "$cur" ] && [ "$cur" != "$NEW" ] || continue
        prev="$cur"
        for link in "$places"/*; do
            [ -L "$link" ] || continue
            t="$(readlink "$link")"
            case "$t" in *-"$cur".svg|*-"$cur"-*) ;; *) continue ;; esac
            n="${t/-$cur/-$NEW}"
            [ -e "$places/$n" ] || continue
            ln -sfn "$n" "$link"; changed=$((changed + 1))
        done
    done
    rm -f "$theme/icon-theme.cache"; command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -f "$theme" 2>/dev/null || true
done
[ -n "$prev" ] && echo "$prev" > "$STATE/folder-color.prev"
echo "relinked $changed icons to '$NEW'${prev:+ (was '$prev')}"
