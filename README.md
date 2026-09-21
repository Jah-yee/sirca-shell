# Sirca Shell

The name comes from *sırça*, an old Turkish word for fine glass. This is a liquid-glass desktop shell for **KDE Plasma 6 on
Wayland**: a top bar and a dock whose popups grow out of them, with its own launcher, search, quick settings,
notifications, clipboard history, screenshots and recording, tile picker and edit mode. KWin stays the compositor;
only Plasma's panels are replaced, and one command gives them back.

It comes with the look that goes with it: a KWin effect for real glass (blur, refraction, a lit edge), KDE and GTK
themes generated from one token file, a light / dark switch that cross-fades the whole desktop, seven colour themes
with matching wallpapers, a lock screen, and optional extras (Spotify, Firefox, Ghostty).

## Install

```
git clone https://github.com/onuroluc/sirca-shell.git
cd sirca-shell
./install.sh
```

The installer is interactive. It checks your system, tells you what will and will not work on it, explains the risks of
each part in plain words, and lets you choose: the shell only (no root), the shell with the matching look, or the author's
full setup. `./install.sh --dry-run` shows every command it would run and changes nothing. `./uninstall.sh` removes what
it installed, part by part.

Then: `sirca-shell-switch on` (your Plasma panels are saved) and `sirca-shell-switch off` (they come back exactly).

## What works, what does not (yet)

| | |
|---|---|
| KDE Plasma 6.6, Wayland, KWin | yes: this is what it is built and used on, every day |
| X11, other compositors (Hyprland, Sway, GNOME) | no |
| One screen | yes |
| Several screens | not yet: the bar and dock are on the primary screen only |
| Without the KWin effect | works, but flat: translucent surfaces, no blur or lit edge |
| NVIDIA | developed on it. AMD and Intel: untested by the author, reports welcome |
| After a Plasma upgrade | the shell keeps working; the KWin effect must be rebuilt (`./install.sh` again) |

It is young software by one person, used daily on one machine. Expect rough edges elsewhere, and please report them.

## What is in this repository

| folder | what |
|---|---|
| `shell/` | the shell itself (C++ / QML). Its README has the features, settings, scripting and build dependencies |
| `kwin-effects/` | the glass KWin effect: a fork of kwin-effects-glass with shapes described by the shell ("lobes"), Plasma 6.6 fixes, and **Glass Key** (glass inside apps that paint opaque windows) |
| `desktop/` | the look for everything else: KDE colour scheme, GTK 3 / 4, Qt style + window decoration, `glass-mode` (light / dark and colour themes), lock screen, Plasma OSD, app extras |
| `wallpapers/` | one original picture in seven colours, dark and light (made by `desktop/tools/make_default_wallpaper.py` and `desktop/tools/wallpaper_variants.py`; free to use with the project) |
| `setups/` | the colour themes and the author's bar / dock layout as a setup file (`sirca-shell-setup import …`) |

## Licence and credits

GPL-3.0-or-later for everything written for this project, see `LICENSE`. Each folder keeps the notices of what it builds on:

- `kwin-effects/` is a fork of **kwin-effects-glass** by 4v3ngR, itself a fork of KWin's blur effect (KDE) by way of Better Blur; GPL-3.0.
- `desktop/qt/darkly-fork/` is a fork of **Darkly** (itself a fork of Lightly / Breeze), GPL-2.0-or-later; see its `COPYING`.
- `desktop/third_party/adw-gtk3/` is **adw-gtk3** by lassekongo83, LGPL-2.1.
- `shell/qml/control/` derives from **Plasma Control Hub** by zayronxio; `shell/applets/` holds forks of KDE Plasma applets (their headers are kept).
- Fonts: **Outfit** and **Inter**, SIL Open Font License. Icons are not bundled; the look assumes Papirus.

Thank you to all of them.
