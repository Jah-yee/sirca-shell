#!/usr/bin/python3
"""galaxy.txt (braille art) -> galaxy.ansi: the same galaxy as TEXT, sized for the greeting, each character coloured with
one of ten PALETTE SLOTS (176..185, core -> rim) instead of fixed colours. glass-mode defines those ten slots in Ghostty's
theme from the desktop's colour theme; a terminal re-colours every cell that refers to a palette slot, so a greeting that is
already on screen changes colour with the theme. (The PNG logo it replaces was baked pixels.)
    render-galaxy-ansi.py [COLUMNS]      default 46"""
import os, sys, math
CFG = os.path.dirname(os.path.abspath(__file__)); COLS = int(sys.argv[1]) if len(sys.argv) > 1 else 46
FIRST, N = 176, 10
BITS = {0x01: (0, 0), 0x02: (0, 1), 0x04: (0, 2), 0x40: (0, 3), 0x08: (1, 0), 0x10: (1, 1), 0x20: (1, 2), 0x80: (1, 3)}
rows = open(os.path.join(CFG, "galaxy.txt"), encoding="utf-8").read().split("\n")
while rows and not rows[-1].strip(): rows.pop()
W, H = max(len(r) for r in rows) * 2, len(rows) * 4
src = [[0] * W for _ in range(H)]
for ry, line in enumerate(rows):
    for cx, ch in enumerate(line):
        o = ord(ch) - 0x2800
        if 0 < o < 256:
            for bit, (dx, dy) in BITS.items():
                if o & bit: src[ry * 4 + dy][cx * 2 + dx] = 1
# downsample the dot grid to the target width (area coverage), keep the aspect
tw = COLS * 2; k = W / tw; th = int(math.ceil(H / k / 4) * 4)
dst = [[0] * tw for _ in range(th)]
for y in range(th):
    for x in range(tw):
        x0, x1, y0, y1 = int(x * k), max(int(x * k) + 1, int((x + 1) * k)), int(y * k), max(int(y * k) + 1, int((y + 1) * k))
        cells = [src[yy][xx] for yy in range(y0, min(y1, H)) for xx in range(x0, min(x1, W))]
        dst[y][x] = 1 if cells and sum(cells) / len(cells) >= 0.34 else 0
# radial colour: distance from the centre of mass, the 90th percentile of lit dots = the rim
lit = [(x, y) for y in range(th) for x in range(tw) if dst[y][x]]
cx = sum(p[0] for p in lit) / len(lit); cy = sum(p[1] for p in lit) / len(lit)
dist = sorted(math.hypot(x - cx, (y - cy)) for x, y in lit); rim = dist[int(len(dist) * 0.9)] or 1
inv = {v: b for b, v in BITS.items()}
out = []
for ry in range(th // 4):
    line, last = "", None
    for c in range(COLS):
        o = 0
        for (dx, dy), bit in inv.items():
            if dst[ry * 4 + dy][c * 2 + dx]: o |= bit
        if not o: line += " "; continue
        t = min(1.0, math.hypot(c * 2 + 0.5 - cx, ry * 4 + 1.5 - cy) / rim)
        slot = FIRST + min(N - 1, int(t * N))
        if slot != last: line += f"\x1b[38;5;{slot}m"; last = slot
        line += chr(0x2800 + o)
    out.append(line.rstrip() + "\x1b[0m")
open(os.path.join(CFG, "galaxy.ansi"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print(f"{COLS}x{len(out)}")
