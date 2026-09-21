#!/usr/bin/env bash
# Tell the Glass lock screen what the desktop looks like right now: accent, light or dark, wallpaper.   glass-lock-sync
# It reads the shell's config and rewrites state.js inside the INSTALLED lock screen package (the locker cannot read the
# config itself). Called by glass-mode and by Sirca Shell whenever one of the three changes. Without the package: nothing.
set -euo pipefail
CFG="$HOME/.config/sirca-shell/config.json"; DST="$HOME/.local/share/plasma/shells/onur.glasslock/contents/lockscreen"
[ -d "$DST" ] || exit 0
/usr/bin/python3 - "$CFG" "$DST/state.js" <<'P'
import json, os, re, sys, urllib.parse
try: c = json.load(open(sys.argv[1]))
except Exception: c = {}
acc = str(c.get("accent", "#4c6ed6")); acc = acc if re.fullmatch(r"#[0-9a-fA-F]{6}", acc) else "#4c6ed6"
dark = c.get("mode", "dark") != "light"
w = str(c.get("wallpaper", "")); w = w[7:] if w.startswith("file://") else w
url = "file://" + urllib.parse.quote(w) if w and os.path.isfile(w) else ""
out = (".pragma library\n// written by glass-lock-sync: the desktop's look, for the lock screen\n"
       "var accent = %s;\nvar dark = %s;\nvar wallpaper = %s;\n" % (json.dumps(acc), "true" if dark else "false", json.dumps(url)))
dst = sys.argv[2]
if os.path.isfile(dst) and open(dst).read() == out: sys.exit(0)
tmp = dst + ".tmp"; open(tmp, "w").write(out); os.replace(tmp, dst)          # whole file or nothing: the locker never sees half of it
P
