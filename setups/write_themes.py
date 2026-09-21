#!/usr/bin/env python3
"""Put the seven bundled colour themes into the shell's config.   write_themes.py WALLPAPER_DIR
Each theme = an accent + a dark and a light wallpaper (sirca-<name>-dark.jpg / -light.jpg, all made from the one bundled
picture). An existing "themes" key is left alone: your own themes win."""
import json, os, sys
walls = os.path.abspath(sys.argv[1]); here = os.path.dirname(os.path.abspath(__file__))
cfg_path = os.path.expanduser("~/.config/sirca-shell/config.json")
try: cfg = json.load(open(cfg_path))
except Exception: cfg = {}
if isinstance(cfg.get("themes"), dict) and cfg["themes"]:
    print("you already have colour themes: left alone"); sys.exit(0)
accents = json.load(open(os.path.join(here, "themes.json")))
themes = {}
for name, accent in accents.items():
    t = {"accent": accent}
    for mode in ("dark", "light"):
        p = os.path.join(walls, "sirca-%s-%s.jpg" % (name, mode))
        if os.path.isfile(p): t[mode] = p
    themes[name] = t
first = "blue" if "blue" in themes else next(iter(themes))
cfg["themes"] = themes; cfg.setdefault("theme", first); cfg.setdefault("accent", themes[cfg["theme"]]["accent"] if cfg["theme"] in themes else themes[first]["accent"])
mode = cfg.get("mode", "dark")
for m, key in (("dark", "wallpaperDark"), ("light", "wallpaperLight")):
    if m in themes.get(cfg["theme"], {}): cfg.setdefault(key, themes[cfg["theme"]][m])
os.makedirs(os.path.dirname(cfg_path), exist_ok=True)
tmp = cfg_path + ".tmp"; json.dump(cfg, open(tmp, "w"), indent=4); os.replace(tmp, cfg_path)
print("wrote %d colour themes" % len(themes))
