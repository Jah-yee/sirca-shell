#!/usr/bin/python3
"""Draws the default wallpaper that ships with Glass Desktop. It is an original picture (made by this script), so it
may be redistributed with the themes: nested domes of violet, blue, teal and mint light on deep navy.
    tools/make_default_wallpaper.py [WIDTH HEIGHT]        -> design/wallpaper/glass-default.jpg"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import random
W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (5120, 1440)
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, "design", "wallpaper", "glass-default.jpg"); os.makedirs(os.path.dirname(out), exist_ok=True)
S = 2                                                    # draw at half size, blur there, scale up: soft shapes do not need more
w, h = W // S, H // S
def layer(): return Image.new("RGB", (w, h), (0, 0, 0))
# base: navy glow in the middle falling off to near black
base = Image.new("RGB", (w, h), (2, 3, 10)); glow = layer(); d = ImageDraw.Draw(glow)
d.ellipse((w * 0.22, -h * 0.35, w * 0.78, h * 1.35), fill=(14, 24, 84)); base = ImageChops.screen(base, glow.filter(ImageFilter.GaussianBlur(h * 0.22)))
cx, cy = w / 2, h * 1.12                                # the shapes rise from below the bottom edge: no arc ends in sight
arcs = [((122, 61, 240), 0.300, 1.02, -0.030), ((47, 124, 240), 0.235, 0.80, 0.022), ((34, 195, 200), 0.170, 0.58, -0.012), ((56, 224, 176), 0.105, 0.36, 0.018)]
for colour, rx, ry, dx in arcs:
    box = (cx + w * dx - w * rx, cy - h * ry, cx + w * dx + w * rx, cy + h * ry)
    body = layer(); ImageDraw.Draw(body).ellipse(box, fill=tuple(int(c * 0.34) for c in colour))          # the translucent sheet
    inner = (box[0] + w * 0.012, box[1] + h * 0.05, box[2] - w * 0.012, box[3] + h * 0.05)
    ImageDraw.Draw(body).ellipse(inner, fill=(0, 0, 0))                                                    # …hollow below its rim
    base = ImageChops.screen(base, body.filter(ImageFilter.GaussianBlur(h * 0.035)))
    halo = layer(); ImageDraw.Draw(halo).ellipse(box, outline=colour, width=max(2, int(h * 0.012)))
    base = ImageChops.screen(base, halo.filter(ImageFilter.GaussianBlur(h * 0.02)))
    line = layer(); ImageDraw.Draw(line).ellipse(box, outline=tuple(min(255, int(c * 0.55 + 130)) for c in colour), width=max(1, int(h * 0.0028)))
    base = ImageChops.screen(base, line.filter(ImageFilter.GaussianBlur(0.8)))
img = base.resize((W, H), Image.LANCZOS)
# vignette + a little grain so the gradients do not band
vig = Image.new("L", (W // 8, H // 8), 0); ImageDraw.Draw(vig).ellipse((-W // 40, -H // 16, W // 8 + W // 40, H // 8 + H // 16), fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(H // 40)).resize((W, H), Image.BILINEAR).point(lambda v: 95 + v * 160 // 255)
img = ImageChops.multiply(img, Image.merge("RGB", (vig, vig, vig)))
random.seed(7); noise = Image.effect_noise((W // 2, H // 2), 9).resize((W, H), Image.BILINEAR).point(lambda v: 122 + (v - 128) // 6)
img = ImageChops.overlay(img, Image.merge("RGB", (noise, noise, noise)))
img.save(out, quality=93); print(out)
