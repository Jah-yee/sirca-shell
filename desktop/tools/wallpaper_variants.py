#!/usr/bin/python3
"""Colour variants of ONE wallpaper: the picture itself never moves, only its colours change.
  dark  : hue rotation of the original
  light : the same hue, lightness mirrored (dark background -> near white, glowing sheets -> pastel), with the darkest
          results lifted so the fine edge lines become saturated colour instead of black
usage: variants.py SOURCE OUTDIR [--preview WIDTH]"""
import sys, os, numpy as np
from PIL import Image
src, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
img = Image.open(src).convert("RGB")
if "--preview" in sys.argv: w = int(sys.argv[sys.argv.index("--preview") + 1]); img = img.resize((w, round(w * img.height / img.width)), Image.LANCZOS)
rgb = np.asarray(img, dtype=np.float32) / 255.0

def rgb2hls(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]; mx, mn = a.max(-1), a.min(-1); l = (mx + mn) / 2; d = mx - mn
    s = np.where(d == 0, 0, d / np.where(l > 0.5, 2 - mx - mn, mx + mn + 1e-9))
    h = np.zeros_like(l); m = d > 0
    rc = np.where(m, (((g - b) / (d + 1e-9)) % 6), 0); gc = (b - r) / (d + 1e-9) + 2; bc = (r - g) / (d + 1e-9) + 4
    h = np.where(mx == r, rc, np.where(mx == g, gc, bc)); h = np.where(m, h / 6.0 % 1.0, 0)
    return h, l, s
def hls2rgb(h, l, s):
    c = (1 - np.abs(2 * l - 1)) * s; hp = h * 6; x = c * (1 - np.abs(hp % 2 - 1)); z = np.zeros_like(h)
    i = np.floor(hp).astype(int) % 6
    r = np.choose(i, [c, x, z, z, x, c]); g = np.choose(i, [x, c, c, x, z, z]); b = np.choose(i, [z, z, x, c, c, x])
    m = l - c / 2; return np.stack([r + m, g + m, b + m], -1)

h, l, s = rgb2hls(rgb)
# ---- where the object is. Its outline is drawn by thin bright lines; the glow AROUND it is smooth. So: find fine structure
# (difference to a blurred copy), thicken it until the outline is closed, flood the background in from the top corners, and
# what the flood cannot reach is the object. Worked out at a quarter of the size, then scaled back up.
from PIL import ImageFilter, ImageDraw, ImageChops
q = 4 if img.width > 2000 else 2 if img.width > 1200 else 1
mx = Image.fromarray((rgb.max(-1) * 255).astype(np.uint8)).resize((img.width // q, img.height // q), Image.LANCZOS)
k = lambda px: max(3, (px // q) | 1)                                      # a size in source pixels -> odd size at mask scale
detail = ImageChops.difference(mx, mx.filter(ImageFilter.GaussianBlur(k(24) / 2)))
lines = detail.point(lambda v: 255 if v > 9 else 0)
bright = mx.point(lambda v: 255 if v > 95 else 0)                         # the lit sheets themselves
wall = ImageChops.lighter(lines, bright).filter(ImageFilter.MaxFilter(k(29)))     # thick enough to close gaps in the outline
flood = wall.copy()
for seed in [(0, 0), (flood.width - 1, 0), (0, flood.height // 2), (flood.width - 1, flood.height // 2), (0, flood.height - 1), (flood.width - 1, flood.height - 1)]:
    if flood.getpixel(seed) == 0: ImageDraw.floodfill(flood, seed, 128)
objm = flood.point(lambda v: 0 if v == 128 else 255)                       # everything the flood did not reach
objm = objm.filter(ImageFilter.MinFilter(k(29)))                           # take the thickening back off the outside
objm = objm.filter(ImageFilter.MaxFilter(k(9))).filter(ImageFilter.MinFilter(k(9)))
objm = objm.filter(ImageFilter.MinFilter(k(7)))                           # a hair inside the outline: no dark fringe of the old background
bw = objm
MASK = np.asarray(bw.filter(ImageFilter.GaussianBlur(k(44) / 2)).resize(img.size, Image.BICUBIC), dtype=np.float32) / 255.0
_g = img.resize((img.width // 16, img.height // 16), Image.BILINEAR).filter(ImageFilter.GaussianBlur(max(2, img.width / 16 / 28)))
GLOWRGB = np.asarray(_g.resize(img.size, Image.BICUBIC), dtype=np.float32) / 255.0
_w = (s * l).ravel(); _ang = h.ravel() * 2 * np.pi
DOM = float((np.arctan2((np.sin(_ang) * _w).sum(), (np.cos(_ang) * _w).sum()) / (2 * np.pi)) % 1.0)      # the picture's dominant hue
if "--mask" in sys.argv: Image.fromarray((MASK * 255).astype(np.uint8)).save(os.path.join(out, "mask.png"))
GLOW = np.asarray(bw.filter(ImageFilter.GaussianBlur(k(260) / 2)).resize(img.size, Image.BICUBIC), dtype=np.float32) / 255.0
# hue shift (degrees) from the original's blue; every picture below is computed from the ONE source, never from another variant
THEMES = {"blue": 0, "violet": 45, "rose": 100, "red": 128, "amber": 165, "green": -92, "teal": -42}
THEMES = {k: v / 360.0 for k, v in THEMES.items()}
for name, dh in THEMES.items():
    hh = (h + dh) % 1.0
    Image.fromarray((np.clip(hls2rgb(hh, l, s), 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(out, f"bloom-{name}-dark.png"))
    # ---- light: a REGRADE, worked like an adjustment-layer stack (onur's brief, 2026-09-19). No inversion, no exposure
    # push, no white overlay; the artwork (shapes, folds, gradients, rims, layering) is untouched, the tonal ORDER is kept.
    ss_ = lambda e0, e1, x: (lambda t: t * t * (3 - 2 * t))(np.clip((x - e0) / (e1 - e0), 0, 1))
    # 1+2. Curves + Levels on the object: shadows and lower mid-tones lifted hard, black point raised a lot, white point
    #      left where it is. Monotonic, so what was darker stays darker: overlaps and folds keep their depth.
    BLACK, P = 0.60, 1.45
    lifted = BLACK + (1.0 - BLACK) * (1.0 - (1.0 - l) ** P)
    # 5. highlight protection (luminosity mask): rims and speculars take less of the lift's flattening and stay the
    #    brightest things in the picture; they may go to white
    hi = ss_(0.55, 0.92, l)
    #    (white-ish highlights go up to white; COLOURED bright reflections, like the glowing core, are held at a lightness
    #    where their colour still shows instead of washing out)
    white_hi = np.maximum(lifted, 0.93 + 0.07 * l); colour_hi = np.minimum(lifted, 0.70 + 0.08 * l)
    keep = np.clip(s * 1.15, 0, 1) * 0.85
    L2 = lifted * (1 - hi) + (white_hi * (1 - keep) + colour_hi * keep) * hi
    # bright AND saturated areas (the glowing core, coloured reflections) are held below the point where a colour washes out
    L2 = L2 - np.maximum(0, L2 - 0.76) * 0.85 * np.clip(s * 1.1, 0, 1) * ss_(0.30, 0.55, l) * (1 - ss_(0.90, 0.99, l))
    # 3+4. colour: hues and their relationships kept (only the theme's rotation `dh`); dark saturated colours become
    #      luminous pastels, denser / overlapping glass keeps more saturation, bright coloured reflections stay saturated
    S2 = np.clip(s * (0.82 + 0.16 * ss_(0.06, 0.45, l)) + 0.10 * hi * s, 0, 1)      # lifted shadows must stay COLOUR (luminous pastel), not turn dusty grey
    # 8. final curves: a touch of contrast back around the object's new mid-tones
    L2 = np.clip(L2 + 0.035 * np.sin((L2 - 0.74) * np.pi / 0.26) * (1 - hi) * ss_(0.5, 0.6, L2), 0, 1)
    graded = hls2rgb(hh, L2, S2)
    # 0+6. background: a fill, not a lifted black. Paper = a very pale tint of the picture's own dominant hue; on it the
    #      original's coloured illumination as a large, extremely soft pastel glow (GLOWRGB: the source blurred very wide)
    paper = hls2rgb(np.full((1, 1), (DOM + dh) % 1.0, np.float32), np.full((1, 1), 0.968, np.float32), np.full((1, 1), 0.55, np.float32))[0, 0]
    gh, gl, gs = rgb2hls(GLOWRGB)
    glow = hls2rgb((gh + dh) % 1.0, np.full_like(gl, 0.86), np.clip(gs * 0.9, 0, 1))
    ga = np.clip(gl * 3.2, 0, 0.55)[..., None]
    bg = paper[None, None, :] * (1 - ga) + glow * ga
    # 7. the heavily feathered mask: the solid object (MASK) plus whatever is lit enough to be glass rather than empty
    #    background (the faint outer sheets), so translucency survives instead of being cut out
    A = np.maximum(MASK, ss_(0.045, 0.22, l) * 0.97)[..., None]
    res = bg * (1 - A) + graded * A
    Image.fromarray((np.clip(res, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(out, f"bloom-{name}-light.png"))
print("done", out)
