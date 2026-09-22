#!/usr/bin/env bash
# Sirca Shell — remove what ./install.sh installed. Asks before each part; your own config and wallpapers are kept unless
# you say otherwise.      ./uninstall.sh [--dry-run]
set -uo pipefail
# qdbus is "qdbus6" on Ubuntu / Arch and "qdbus-qt6" on Fedora (exported: the steps run through bash -c)
qdbus6() { if type -P qdbus6 >/dev/null 2>&1; then command qdbus6 "$@"; else qdbus-qt6 "$@"; fi; }
export -f qdbus6
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"; STATE="$HOME/.local/state/sirca-shell"; DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
ask() { local a; read -r -p "$1 [y/N] " a </dev/tty || a=""; case "$a" in y|Y|yes) return 0 ;; *) return 1 ;; esac; }
run() { local what="$1"; shift; if [ $DRY = 1 ]; then echo "  [dry run] $what:  $*"; else echo "  … $what"; "$@" || echo "    (that step reported a problem; continuing)"; fi; }
echo "This gives Plasma's panels back first, then removes the parts you confirm."
command -v sirca-shell-switch >/dev/null && run "switch the shell off (Plasma's panels come back)" sirca-shell-switch off
if [ -f "$STATE/effect-manifest.txt" ] && ask "Remove the glass KWin effect (sudo) and switch KWin's own blur back on?"; then
    run "unload the effect" bash -c 'for e in glasskey glass; do qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect $e >/dev/null; kwriteconfig6 --file kwinrc --group Plugins --key ${e}Enabled false; done; kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true; qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect blur >/dev/null; true'
    run "delete the installed plugin files (sudo)" sudo xargs -a "$STATE/effect-manifest.txt" rm -f
fi
[ -x "$ROOT/desktop/tools/install_qt.sh" ] && [ -f /usr/lib/*/qt6/plugins/styles/darkly6.so.orig-glass ] 2>/dev/null && ask "Restore the stock Darkly style and remove the glass decoration (sudo)?" && {
    run "back to the Darkly decoration" "$ROOT/desktop/tools/use_decoration.sh" darkly; run "restore the plugins (sudo)" sudo "$ROOT/desktop/tools/install_qt.sh" --undo; }
ask "Revert the KDE colour scheme and GTK look to what you had before?" && run "revert the look" "$ROOT/desktop/tools/apply_all.sh" revert
ask "Remove the lock screen (Plasma's own from the next login)?" && run "remove the lock screen" "$ROOT/desktop/tools/install_lock.sh" --undo
[ -f "$STATE/icon-theme.txt" ] && ask "Icon theme back to what you had ($(cat "$STATE/icon-theme.txt"))?" && run "restore the icon theme" bash -c 't=$(cat "$0/icon-theme.txt"); for h in /usr/lib/x86_64-linux-gnu/libexec/plasma-changeicons /usr/lib/libexec/plasma-changeicons /usr/libexec/plasma-changeicons /usr/lib64/libexec/plasma-changeicons; do [ -x "$h" ] && { "$h" "$t" >/dev/null 2>&1 && exit 0; }; done; kwriteconfig6 --file kdeglobals --group Icons --key Theme "$t"' "$STATE"
ask "Remove glass-mode and its helper links from ~/.local/bin?" && run "remove the links" rm -f "$HOME/.local/bin/glass-mode" "$HOME/.local/bin/glass-lock-sync" "$HOME/.local/bin/glass-folder-color"
run "remove the shell itself" "$ROOT/shell/uninstall.sh"
ask "Also delete your shell config (~/.config/sirca-shell) and the bundled wallpapers?" && run "delete config and wallpapers" rm -rf "$HOME/.config/sirca-shell" "$HOME/.local/share/wallpapers/sirca"
echo "Done. Log out and in once so every app forgets the old look."
