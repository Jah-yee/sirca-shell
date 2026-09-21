#!/usr/bin/env python3
# ~/.config/fastfetch/render-galaxy.py
# Decode the braille spiral-galaxy in galaxy.txt into a real pixel bitmap and
# color every "lit" dot by a RADIAL gradient from the galaxy core outward.
# Output: galaxy.png (transparent background, so Ghostty's frosted glass shows
# through). greet.sh rebuilds this only when galaxy.txt is newer.
#
# Radial palette (core -> rim) is sampled from the "Blue Nebula" waywallen
# wallpaper: a hot white-cyan core, fading cyan -> blue -> violet -> magenta.
# To recolor, edit STOPS below. To change the picture, edit galaxy.txt.

from PIL import Image, ImageDraw
import os

CFG = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(CFG, "galaxy.txt")
OUT = os.path.join(CFG, "galaxy.png")

SCALE = 6          # pixels per braille dot
DOT_R = 2.6        # dot radius in px (slightly < SCALE/2 for tiny gaps)
RADIUS_PCT = 90    # percentile of dot-distances mapped to the rim color

# Radial color stops, core (t=0) -> rim (t=1).
STOPS = [                     # Glass theme + accent: a pale blue core, the light-navy accent, then violet into the dark glass (wallpaper colours)
    (0.00, (196, 210, 250)),
    (0.18, ( 76, 110, 214)),
    (0.42, ( 70,  82, 176)),
    (0.70, ( 72,  62, 130)),
    (1.00, ( 50,  52,  70)),
]

# Braille dot bit -> (subcol, subrow) in the 2-wide x 4-tall cell.
BITS = {0x01:(0,0),0x02:(0,1),0x04:(0,2),0x40:(0,3),
        0x08:(1,0),0x10:(1,1),0x20:(1,2),0x80:(1,3)}


def lerp(a, b, f):
    return tuple(round(a[i] + (b[i] - a[i]) * f) for i in range(3))


def color_at(t):
    t = max(0.0, min(1.0, t))
    for i in range(len(STOPS) - 1):
        t0, c0 = STOPS[i]
        t1, c1 = STOPS[i + 1]
        if t <= t1:
            f = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            return lerp(c0, c1, f)
    return STOPS[-1][1]


def main():
    lines = open(SRC, encoding="utf-8").read().split("\n")
    while lines and lines[-1] == "":
        lines.pop()

    dots = []
    for cy, line in enumerate(lines):
        for cx, ch in enumerate(line):
            o = ord(ch)
            if 0x2800 <= o <= 0x28FF:
                bits = o - 0x2800
                for bit, (sc, sr) in BITS.items():
                    if bits & bit:
                        dots.append((cx * 2 + sc, cy * 4 + sr))
    if not dots:
        return

    # core = centroid of lit dots
    mx = sum(d[0] for d in dots) / len(dots)
    my = sum(d[1] for d in dots) / len(dots)
    dists = sorted(((dx - mx) ** 2 + (dy - my) ** 2) ** 0.5 for dx, dy in dots)
    rim = dists[min(len(dists) - 1, int(len(dists) * RADIUS_PCT / 100))] or 1.0

    W = (max(d[0] for d in dots) + 1) * SCALE
    H = (max(d[1] for d in dots) + 1) * SCALE
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for dx, dy in dots:
        d = ((dx - mx) ** 2 + (dy - my) ** 2) ** 0.5
        col = color_at(d / rim)
        px = dx * SCALE + SCALE / 2
        py = dy * SCALE + SCALE / 2
        dr.ellipse([px - DOT_R, py - DOT_R, px + DOT_R, py + DOT_R],
                   fill=col + (255,))
    img.save(OUT)
    print(f"wrote {OUT} ({W}x{H}, {len(dots)} dots)")


if __name__ == "__main__":
    main()
