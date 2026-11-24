"""Finales Logo (Hüllenbruch) und App-Icon.

Aufruf: python3 tools/app_icon.py
  -> art/logos/final/logo.png, logo_transparent.png, app_icon_*.png und game/icon.png (1024 px)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import logos as L
import logos2 as L2
from logos import C, Mask
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "art", "logos", "final")


def damaged(cv, m, rnd, cracks, hole, scorch_r=5):
    cv.fill(m.shift(2, 2).dilate(1), C["g9"])
    cv.outline(m, C["outline"])
    cv.fill_bands(m, [C["g2"], C["g3"], C["g4"], C["g5"], C["g6"]])
    cv.bevel(m, C["g1"], C["g7"])
    for px, py, n in cracks:
        for _ in range(n):
            if (px, py) in m.p:
                cv.set(px, py, C["outline"])
                q = (px + 1, py)
                if q in m.p and rnd.random() < 0.35:
                    cv.set(*q, C["g7"])
            px += rnd.choice((-1, 0, 1)); py += 1
    hx, hy = hole
    for p in L2.circle(hx, hy, scorch_r).p:
        if p in m.p:
            cv.set(*p, C["g8"])
    h = L2.circle(hx, hy, 2)
    cv.fill(h.dilate(1), C["e2"])
    cv.fill(h, C["outline"])
    cv.set(hx - 1, hy - 4, C["o1"]); cv.set(hx + 3, hy - 3, C["o1"]); cv.set(hx - 3, hy + 1, C["o2"])
    for _ in range(26):
        a = rnd.uniform(-2.6, -0.4); d = rnd.uniform(4, 20)
        cv.set(hx + round(math.cos(a) * d), hy + round(math.sin(a) * d * 0.8),
               rnd.choice([C["o0"], C["o1"], C["o2"], C["e2"]]))
    for _ in range(24):
        cv.set(hx + rnd.randint(-5, 9), hy - rnd.randint(8, 18), rnd.choice([C["g7"], C["g8"]]))


def logo(transparent=False):
    L.W, L.H = 256, 72
    cv = L.Canvas(seed=5, stars=not transparent)
    if transparent:
        cv.img.paste((0, 0, 0, 0), (0, 0, L.W, L.H))
    x = (L.W - 88 * 2) // 2
    ls = L2.letters("HULLBOUND", x, 16, "bold", 2, 2)
    word = L2.union(m for _, m, _ in ls)
    rnd = random.Random(12)
    damaged(cv, word, rnd, [(x + 14, 16, 26), (x + 104, 16, 26), (x + 150, 16, 26)], (x + 63, 30))
    s = Mask(); s.text("EIN RAUMSCHIFF-ROGUELIKE", (L.W - L.text_w("EIN RAUMSCHIFF-ROGUELIKE", "mini")) // 2, 52, "mini")
    cv.fill(s, C["r1"])
    return cv


def icon():
    L.W, L.H = 64, 64
    cv = L.Canvas(stars=False)
    ramp = [C["navy2"], C["navy"], C["space"]]
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - 30, y - 26) / 44 * (len(ramp) - 1)
            i = int(d); f = d - i
            g = min(1.0, max(0.0, (f - 0.4) * 5))
            i2 = i + (1 if g * 16 > bayer[y % 4][x % 4] else 0)
            cv.set(x, y, ramp[min(len(ramp) - 1, i2)])
    rnd = random.Random(21)
    for _ in range(22):
        cv.set(rnd.randrange(64), rnd.randrange(64), rnd.choice([C["g5"], C["g4"], C["navy4"], C["g2"]]))
    # Planetenrand unten rechts für Farbe
    pl = L2.circle(70, 78, 30)
    cv.fill_bands(pl, [C["e2"], C["e3"], C["r3"], C["r3"]], y0=48, y1=64)
    for x, y in pl.p:
        if (x - 70) ** 2 + (y - 78) ** 2 > 27 ** 2:
            cv.set(x, y, C["o2"])
    m = Mask(); m.text("H", 20, 15, "bold", 3, 0)
    damaged(cv, m, random.Random(4), [(23, 17, 30), (31, 27, 6)], (40, 22), scorch_r=4)
    return cv


def save(cv, path, size):
    cv.img.resize(size, Image.NEAREST).save(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    save(logo(), os.path.join(OUT, "logo.png"), (256 * 6, 72 * 6))
    save(logo(True), os.path.join(OUT, "logo_transparent.png"), (256 * 6, 72 * 6))
    ic = icon()
    for n in (1024, 512, 192, 180, 128):
        save(ic, os.path.join(OUT, f"app_icon_{n}.png"), (n, n))
    ic.img.convert("RGB").resize((1024, 1024), Image.NEAREST).save(os.path.join(ROOT, "game", "icon.png"))


if __name__ == "__main__":
    main()
