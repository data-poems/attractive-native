#!/usr/bin/env python3
"""Export the Android launcher icon from the iOS strange-attractor icon.

The adaptive foreground is Attractive/Assets.xcassets/AppIcon.appiconset/
icon-strange-attractor-1024.png on its own black, scaled so the attractor's
wings (99% of its bright strands) sit within 32dp of the centre and padded
with black to the 108dp layer. The monochrome layer draws the same Lorenz
attractor from its equations (sigma 10, rho 28, beta 8/3, the x-z view) as a
1dp line fitted within 31dp of the centre.

Requires Pillow and numpy. Run from the repository root:

    python3 android/scripts/export-launcher-icon.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "Attractive/Assets.xcassets/AppIcon.appiconset/icon-strange-attractor-1024.png"
RES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

CENTRE = (499, 489)        # centroid of the attractor's bright strands, master px
WING_R = 425               # radius holding 99% of the bright strands, master px
WING_R_DP = 32
LAYER = 432                # 108dp at xxxhdpi


def place(img, fill):
    """Scale the master so WING_R maps to WING_R_DP and centre CENTRE in the layer."""
    k = (WING_R_DP / WING_R) * (LAYER / 108)          # layer px per master px
    size = round(img.size[0] * k)
    scaled = img.resize((size, size), Image.LANCZOS)
    out = Image.new(img.mode, (LAYER, LAYER), fill)
    out.paste(scaled, (round(LAYER / 2 - CENTRE[0] * k), round(LAYER / 2 - CENTRE[1] * k)))
    return out


def lorenz(steps=4000, dt=0.005, settle=2000):
    sigma, rho, beta = 10.0, 28.0, 8 / 3
    p = np.array([0.1, 0.0, 0.0])
    f = lambda q: np.array([sigma * (q[1] - q[0]), q[0] * (rho - q[2]) - q[1], q[0] * q[1] - beta * q[2]])
    points = []
    for i in range(steps + settle):
        k1 = f(p); k2 = f(p + dt / 2 * k1); k3 = f(p + dt / 2 * k2); k4 = f(p + dt * k3)
        p = p + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
        if i >= settle:
            points.append((p[0], p[2]))
    return np.array(points)


def attractor_glyph(radius_dp=31, line_dp=1.0, ss=4):
    pts = lorenz()
    centre = (pts.max(axis=0) + pts.min(axis=0)) / 2
    rel = (pts - centre) * np.array([1, -1])           # z up
    scale = radius_dp / np.hypot(rel[:, 0], rel[:, 1]).max()
    k = LAYER * ss / 108
    xy = [((54 + x * scale) * k, (54 + y * scale) * k) for x, y in rel]
    big = Image.new("L", (LAYER * ss, LAYER * ss), 0)
    ImageDraw.Draw(big).line(xy, fill=255, width=round(line_dp * k), joint="curve")
    return big.resize((LAYER, LAYER), Image.LANCZOS)


def main():
    master = Image.open(MASTER).convert("RGB")
    fg = place(master, (0, 0, 0)).convert("RGBA")
    alpha = attractor_glyph()
    mono = Image.new("RGBA", (LAYER, LAYER), (255, 255, 255, 0))
    mono.putalpha(alpha)
    for name, scale in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        px = round(108 * scale)
        fg.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher_foreground.webp", "WEBP", quality=94, method=6)
        mono.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher_monochrome.png", optimize=True)
    print(f"wrote launcher layers to {RES.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
