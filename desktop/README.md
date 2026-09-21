# Glass Desktop

The themes that go with [Sirca Shell](../sirca-shell): one design, generated from one file (`design/tokens.json`) into
every toolkit, plus a matching lock screen. KWin stays the window manager; nothing here replaces it.

> **Status: alpha, tested on one machine** (Plasma 6.6 on Wayland, Ubuntu 26.04, NVIDIA, 5120×1440). Every installer
> has an undo.

## Pieces

| folder | what | install | needs root |
| --- | --- | --- | --- |
| `design/` | tokens, HTML mocks, the default wallpaper (`tools/make_default_wallpaper.py` draws it) | – | – |
| `tools/gen_kde.py`, `apply_kde.sh` | KDE colour scheme **Glass** and settings | `tools/apply_kde.sh` | no |
| `tools/gen_gtk.py`, `apply_gtk.sh` | GTK 4 / libadwaita stylesheet, GTK 3 on the bundled adw-gtk3, Flatpak overrides | `tools/apply_gtk.sh apply` (`revert`) | no |
| `qt/darkly-fork/` | Qt widget style and the **Glass** window decoration (lit outline, rounded corners) | build, then `sudo tools/install_qt.sh` and `tools/use_decoration.sh glass` | yes |
| `tools/mode.sh` | **light / dark for the whole desktop**: colour scheme `Glass` / `GlassLight`, GTK 3 / 4, the portal's colour-scheme (Firefox, Electron, Ghostty follow it), Papirus / Papirus-Dark, a wallpaper per mode, Sirca Shell's `mode` | link it as `glass-mode` on your PATH; `glass-mode light\|dark\|toggle`, `glass-mode wallpaper light FILE` | no |
| `lock/onur.glasslock/` | lock screen | `tools/install_lock.sh` (`--undo`), then log out and in | no |
| `plasma/osd/` | replaces Plasma's volume / brightness popup (Sirca Shell shows those in its clock pill) | see its README | no |
| `apps/` | Ghostty dialog styling, Firefox accent colours | copy by hand | no |
| `apps/spotify/`, `tools/gen_spotify.py` | **Spotify in the Glass look** (optional): a Spicetify theme generated from the tokens and the current accent, an in-app extension that follows light / dark and colour themes without a restart, and the Miniplayer as a glass widget | needs Spotify from its apt / rpm package (not snap or Flatpak) and [Spicetify](https://spicetify.app); then `tools/gen_spotify.py --apply`, `spicetify config extensions glass-live.js`, `spicetify backup apply -n`, `tools/install_spotify_widget.sh` | only for Spicetify's write access to Spotify's folder |
| `kwin/glasstranslucent/` | small KWin script: keeps listed apps translucent when window rules cannot (apps that name their window late) | copy to `~/.local/share/kwin/scripts/`, enable | no |

A switch of mode or colour theme is one cross-fade for the whole screen (KWin's blend-changes effect, started by
`tools/mode.sh`; off with `"modeBlend": false` in the shell config). Folder icons follow the colour theme through small
generated icon themes (`tools/folder_theme.py`: `Glass-<Papirus variant>-<colour>`). Real glass inside Spotify (surfaces
see-through, text and pictures solid) and the Miniplayer's shadow need the **Glass Key** effect from the companion KWin
effects repository; without it the theme is simply opaque.

`tools/apply_all.sh apply|revert` runs the user-level pieces together. `tools/folder_color.sh <colour>` switches the
Papirus folder colour (link it as `glass-folder-color` on your PATH and Sirca Settings shows a colour picker).

## Your own wallpaper

The lock screen shows one picture. Use yours:

```
tools/make_lock_assets.sh /path/to/wallpaper.jpg     # needs ImageMagick
tools/install_lock.sh
```

The lock screen is safe to try: if it fails to load, Plasma falls back to its own.

## Licence and credits

GPL-3.0-or-later for everything written for this project, see `LICENSE`.

- `qt/darkly-fork/` is a fork of **Darkly** (itself a fork of Lightly / Breeze), GPL-2.0-or-later; see its `COPYING`.
- `third_party/adw-gtk3/` is **adw-gtk3** by lassekongo83, LGPL-2.1.
- Fonts: **Outfit** and **Inter**, SIL Open Font License (`OFL.txt` next to the files).
- The default wallpaper is drawn by `tools/make_default_wallpaper.py` and is part of this project.
- Icons are not bundled; the look assumes Papirus-Dark.
