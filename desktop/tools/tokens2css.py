#!/usr/bin/env python3
"""tokens.json -> CSS custom properties. First consumer: the HTML mocks. The GTK3/GTK4 generators will reuse flatten()."""
import json, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
t = json.loads((root / "design" / "tokens.json").read_text())
def flatten(d, prefix=""):
    for k, v in d.items():
        if k.startswith("_"): continue
        if isinstance(v, dict): yield from flatten(v, f"{prefix}{k}-")
        else: yield f"{prefix}{k}", v
px = ("radius-", "spacing-")
lines = [":root {"]
for k, v in flatten(t):
    unit = "px" if k.startswith(px) and isinstance(v, (int, float)) and "unit" not in k or k in ("glass-blur", "decoration-buttonSize", "decoration-buttonGap") else ""
    if k.startswith("motion-") and k != "motion-bounce": unit = "ms"
    if k in ("font-size", "font-sizeSmall", "font-sizeTitle"): unit = "pt"
    lines.append(f"  --{k}: {v}{unit};")
lines.append("}")
out = root / "design" / "mock" / "tokens.css"
out.write_text("\n".join(lines) + "\n"); print("wrote", out)
