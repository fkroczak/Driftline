"""Zweite Runde Logo-Vorschläge (andere Ansätze: Embleme, Symbole, illustrierte Lettern).

Aufruf: python3 tools/logos2.py  ->  art/logos/runde2/logo_11..20.png und uebersicht.png
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import logos as L
from logos import C, Mask, FONTS
from PIL import Image, ImageDraw, ImageFont

L.W, L.H = 256, 96
W, H = L.W, L.H
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "logos", "runde2")
L.OUT = OUT

FONTS["bold"] = {
    "H": ["XX....XX"] * 4 + ["XXXXXXXX"] * 2 + ["XX....XX"] * 5,
    "U": ["XX....XX"] * 9 + ["XXXXXXXX", ".XXXXXX."],
    "L": ["XX......"] * 9 + ["XXXXXXXX"] * 2,
    "B": ["XXXXXXX.", "XXXXXXXX", "XX....XX", "XX....XX", "XXXXXXX.", "XXXXXXX.",
          "XX....XX", "XX....XX", "XX....XX", "XXXXXXXX", "XXXXXXX."],
    "O": [".XXXXXX.", "XXXXXXXX"] + ["XX....XX"] * 7 + ["XXXXXXXX", ".XXXXXX."],
    "N": ["XX....XX", "XXX...XX", "XXXX..XX", "XXXX..XX", "XX.XX.XX", "XX.XX.XX",
          "XX..XXXX", "XX..XXXX", "XX...XXX", "XX....XX", "XX....XX"],
    "D": ["XXXXXX..", "XXXXXXX.", "XX...XXX"] + ["XX....XX"] * 5 + ["XX...XXX", "XXXXXXX.", "XXXXXX.."],
    " ": ["...."] * 11,
}
for d, g in {"0": ["XXX", "X.X", "X.X", "X.X", "XXX"], "1": [".X.", "XX.", ".X.", ".X.", "XXX"],
             "7": ["XXX", "..X", ".X.", ".X.", ".X."], "4": ["X.X", "X.X", "XXX", "..X", "..X"], "2": ["XXX", "..X", "XXX", "X..", "XXX"], "3": ["XXX", "..X", ".XX", "..X", "XXX"]}.items():
    FONTS["mini"][d] = g
FONTS["mini"]["X"] = ["X.X", "X.X", ".X.", "X.X", "X.X"]
FONTS["mini"]["J"] = ["..X", "..X", "..X", "X.X", "XXX"]
FONTS["mini"]["Q"] = ["XXX", "X.X", "X.X", "XXX", "..X"]

WORD = "HULLBOUND"


def letters(word, x, y, font="bold", scale=2, gap=2, offsets=None):
    """Liefert je Buchstabe eine Maske (für Effekte pro Buchstabe)."""
    out = []
    for i, ch in enumerate(word):
        m = Mask()
        oy = offsets[i] if offsets else 0
        m.text(ch, x, y + oy, font, scale, 0)
        out.append((ch, m, x))
        x += (len(FONTS[font][ch][0]) + gap) * scale
    return out


def union(ms):
    u = Mask()
    for m in ms:
        u.p |= m.p
    return u


def line(cv_or_mask, x0, y0, x1, y1, c=None, dash=0):
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy; x0 += sx
        if e2 <= dx:
            err += dx; y0 += sy
    if c is not None:
        for i, (x, y) in enumerate(pts):
            if not dash or (i // dash) % 2 == 0:
                cv_or_mask.set(x, y, c)
    return pts


def circle(cx, cy, r, filled=True):
    m = Mask()
    for j in range(-r - 1, r + 2):
        for i in range(-r - 1, r + 2):
            d = i * i + j * j
            if (d <= r * r + r) if filled else (r * r - r <= d <= r * r + r):
                m.p.add((cx + i, cy + j))
    return m


def mtext(cv, s, x, y, color, center=False):
    m = Mask()
    if center:
        x = x - L.text_w(s, "mini") // 2
    m.text(s, x, y, "mini")
    cv.fill(m, C[color])


LOGOS = []


def logo(title, idea):
    def deco(fn):
        LOGOS.append((fn, title, idea))
        return fn
    return deco


@logo("Missionsabzeichen", "Runder Crew-Aufnäher mit Planet, Schiff und Banderole")
def a1():
    cv = L.Canvas(seed=1)
    cx, cy, r = 128, 48, 42
    outer = circle(cx, cy, r)
    cv.fill(outer.dilate(1), C["outline"])
    cv.fill(outer, C["g6"])
    inner = circle(cx, cy, r - 4)
    cv.fill_bands(inner, [C["v4"], C["navy2"], C["navy"], C["space"]])
    for k in range(64):
        t = k / 64 * 2 * math.pi
        cv.set(cx + round((r - 2) * math.cos(t)), cy + round((r - 2) * math.sin(t)), C["g3"])
    rnd = random.Random(3)
    for _ in range(40):
        x, y = cx + rnd.randint(-34, 34), cy + rnd.randint(-34, 34)
        if (x, y) in inner.p:
            cv.set(x, y, rnd.choice([C["g4"], C["g2"], C["v1"]]))
    # Planet unten
    pl = circle(cx + 14, cy + 52, 30)
    pl.p &= inner.p
    cv.fill_bands(pl, [C["o1"], C["e2"], C["e3"], C["r3"]], y0=cy + 22, y1=cy + 38)
    for x, y in pl.p:
        if (y - cy) % 4 == 0 and (x + y) % 5:
            cv.set(x, y, C["e3"])
    # Schiff oben
    L.ship(cv, cx - 4, cy - 30, k=1)
    for i in range(cx - 30, cx - 8):
        if i % 3:
            cv.set(i, cy - 26, C["b3"])
    # Banderole
    bx0, bx1, by, bh = cx - 66, cx + 66, cy - 7, 18
    for side in (-1, 1):
        ex = bx0 - 8 if side < 0 else bx1 + 1
        for j in range(bh):
            cut = abs(j - bh // 2) < 3
            for i in range(8):
                xx = ex + i
                if side < 0 and cut and i < 4 - abs(j - bh // 2):
                    continue
                if side > 0 and cut and i > 3 + abs(j - bh // 2):
                    continue
                cv.set(xx, by + 3 + j, C["r3"])
    band = Mask().rect(bx0, by, bx1 - bx0, bh)
    cv.outline(band, C["outline"])
    cv.fill_bands(band, [C["r1"], C["r1"], C["r2"], C["r2"], C["r3"]])
    cv.rectf(bx0, by + 1, bx1 - bx0, 1, C["r0"])
    m = L.centered(WORD, by + 3, "std", 2, 1)
    cv.fill(m.shift(0, 1), C["r3"])
    cv.fill(m, C["g1"])
    for x, y in m.p:
        if (x, y + 1) not in m.p:
            cv.set(x, y, C["g3"])
    mtext(cv, "CREW 01", cx, cy + 30, "o0", center=True)
    return cv


@logo("Isometrisch", "Dicke Blocklettern mit tiefer 3D-Extrusion, Stahl und Schildblau")
def a2():
    cv = L.Canvas(seed=2)
    ls = letters(WORD, 32, 22, "bold", 2, 2)
    front = union(m for _, m, _ in ls)
    depth = 9
    allm = Mask()
    for k in range(depth, 0, -1):
        allm.p |= front.shift(k, k).p
    cv.fill(union([allm, front]).dilate(1), C["outline"])
    for k in range(depth, 0, -1):
        lay = front.shift(k, k)
        for x, y in lay.p:
            side = (x - 1, y) not in lay.p
            cv.set(x, y, C["b4"] if k > 5 else C["b3"])
        # Kante
    for x, y in allm.p:
        if (x + 1, y + 1) not in allm.p and (x, y) not in front.p:
            cv.set(x, y, C["outline"])
    cv.fill_bands(front, [C["g0"], C["g1"], C["g2"], C["g3"], C["g4"]])
    cv.bevel(front, C["g0"], C["g5"])
    mtext(cv, "EIN RAUMSCHIFF-ROGUELIKE", 128, 72, "b1", center=True)
    return cv


STENCIL_CUTS = {"O": [(3, 0), (4, 0), (3, 1), (4, 1), (3, 9), (4, 9), (3, 10), (4, 10)],
                "D": [(2, 0), (2, 1), (2, 9), (2, 10)],
                "B": [(2, 0), (2, 1), (2, 4), (2, 5), (2, 9), (2, 10)],
                "U": [(3, 9), (4, 9), (3, 10), (4, 10)],
                "H": [(2, 4), (2, 5)], "L": [(2, 9), (2, 10)], "N": []}


@logo("Frachtstempel", "Schablonenschrift auf Containerblech, Warnstreifen und abgenutzte Farbe")
def a3():
    cv = L.Canvas(stars=False)
    cv.rectf(0, 0, W, H, C["g8"])
    for x in range(0, W, 12):
        cv.rectf(x, 0, 1, H, C["g9"]); cv.rectf(x + 1, 0, 1, H, C["g7"])
    for y0 in (0, H - 8):
        for x in range(W):
            for y in range(y0, y0 + 8):
                cv.set(x, y, C["o2"] if ((x + y) // 5) % 2 else C["g9"])
        cv.rectf(0, y0 + (8 if y0 == 0 else -1), W, 1, C["outline"])
    for x in (6, W - 8):
        for y in (14, H - 16):
            cv.rectf(x, y, 2, 2, C["g5"]); cv.set(x, y, C["g3"])
    sc = 2
    x = (W - (9 * 10 - 2) * sc) // 2
    paint = Mask()
    for ch, m, lx in letters(WORD, x, 24, "bold", sc, 2):
        for cx_, cy_ in STENCIL_CUTS.get(ch, []):
            for dy in range(sc):
                for dx in range(sc):
                    m.p.discard((lx + cx_ * sc + dx, 24 + cy_ * sc + dy))
        paint.p |= m.p
    rnd = random.Random(9)
    for x_, y_ in paint.p:
        if rnd.random() < 0.025:
            continue
        cv.set(x_, y_, C["o1"] if rnd.random() > 0.05 else C["o3"])
    mtext(cv, "FRACHTMODUL 07", 128, 56, "g3", center=True)
    mtext(cv, "MAX 40 T", 128, 63, "g5", center=True)
    return cv


@logo("H-Schiff", "Symbol: Draufsicht eines Zwillingsrumpf-Schiffs, das ein H bildet")
def a4():
    cv = L.Canvas(seed=4)
    ox, oy = 14, 16
    pods = []
    for px in (ox, ox + 26):
        pod = Mask().rect(px, oy + 4, 12, 52)
        for k in range(4):
            pod.p |= Mask().rect(px + 4 - k, oy + k, 4 + 2 * k, 1).p
        pods.append((px, pod))
    bar = Mask().rect(ox + 12, oy + 22, 14, 14)
    ship = union([p for _, p in pods] + [bar])
    cv.outline(ship, C["outline"])
    for px, pod in pods:
        for x, y in pod.p:
            col = x - px
            cv.set(x, y, C["g1"] if col < 2 else C["g2"] if col < 5 else C["g3"] if col < 9 else C["g5"])
        for y in range(oy + 12, oy + 50, 6):
            cv.rectf(px + 4, y, 4, 3, C["navy2"]); cv.set(px + 5, y + 1, C["b1"])
        cv.rectf(px + 2, oy + 56, 8, 2, C["g6"])
        for i, c in enumerate(("b0", "b1", "b1", "b2", "b2", "b3", "b4")):
            cv.rectf(px + 3 + (1 if i > 3 else 0), oy + 58 + i, 6 - (2 if i > 3 else 0), 1, C[c])
    cv.fill_bands(bar, [C["g2"], C["g3"], C["g4"]])
    cv.rectf(ox + 15, oy + 25, 8, 4, C["b2"]); cv.rectf(ox + 15, oy + 25, 8, 1, C["b0"])
    cv.rectf(ox + 14, oy + 32, 10, 1, C["o2"])
    cv.set(ox + 5, oy + 1, C["r1"]); cv.set(ox + 31, oy + 1, C["t2"])
    ls = letters("ULLBOUND", 70, 30, "bold", 2, 2)
    word = union(m for _, m, _ in ls)
    # erstes H der Wortmarke ist das Schiff -> Wortmarke beginnt mit U
    cv.outline(word, C["outline"])
    cv.fill_bands(word, [C["g1"], C["g2"], C["g3"], C["g4"]])
    cv.bevel(word, C["g0"], C["g5"])
    mtext(cv, "EIN RAUMSCHIFF-ROGUELIKE", 70, 60, "b1")
    return cv


@logo("Hüllenbruch", "Zerschossene Stahllettern mit Rissen, Brandspuren und Funken")
def a5():
    cv = L.Canvas(seed=5)
    x = (W - 88 * 2) // 2
    ls = letters(WORD, x, 24, "bold", 2, 2)
    word = union(m for _, m, _ in ls)
    cv.fill(word.shift(2, 2).dilate(1), C["g9"])
    cv.outline(word, C["outline"])
    cv.fill_bands(word, [C["g2"], C["g3"], C["g4"], C["g5"], C["g6"]])
    cv.bevel(word, C["g1"], C["g7"])
    rnd = random.Random(12)
    # Risse
    for sx in (x + 14, x + 58, x + 104, x + 150):
        px, py = sx, 24
        for _ in range(26):
            if (px, py) in word.p:
                cv.set(px, py, C["outline"])
                for d in ((1, 0), (-1, 0)):
                    q = (px + d[0], py)
                    if q in word.p and rnd.random() < 0.3:
                        cv.set(*q, C["g7"])
            px += rnd.choice((-1, 0, 1)); py += 1
    # Einschussloch im zweiten L
    hx_, hy_ = x + 3 * 20 + 3, 38
    burn = circle(hx_, hy_, 5)
    for x_, y_ in burn.p:
        if (x_, y_) in word.p:
            cv.set(x_, y_, C["g8"])
    hole = circle(hx_, hy_, 2)
    for x_, y_ in hole.dilate(1).p:
        cv.set(x_, y_, C["e2"])
    cv.fill(hole, C["outline"])
    for x_, y_ in ((hx_ - 1, hy_ - 4), (hx_ + 3, hy_ - 3)):
        cv.set(x_, y_, C["o1"])
    # Funken
    for _ in range(26):
        a = rnd.uniform(-2.6, -0.4); d = rnd.uniform(4, 22)
        sx_, sy_ = hx_ + round(math.cos(a) * d), hy_ + round(math.sin(a) * d * 0.8)
        cv.set(sx_, sy_, rnd.choice([C["o0"], C["o1"], C["o2"], C["e2"]]))
    # Rauch
    for _ in range(30):
        cv.set(hx_ + rnd.randint(-6, 10), hy_ - rnd.randint(8, 20), C["g7"])
    mtext(cv, "HUELLE 23 PROZENT", 128, 58, "r1", center=True)
    return cv


@logo("Chrom-Kursiv", "80er-Chromschrift, kursiv, Himmel-Boden-Spiegelung mit Glanzstern")
def a6():
    cv = L.Canvas(seed=6)
    x0 = (W - 88 * 2) // 2 - 6
    ls = letters(WORD, x0, 26, "bold", 2, 2)
    base = union(m for _, m, _ in ls)
    word = Mask(); word.p = {(x + (48 - y) // 3, y) for x, y in base.p}
    cv.fill(word.dilate(2), C["v4"])
    cv.outline(word, C["outline"])
    mid = 37
    for x, y in word.p:
        if y < mid:
            cv.set(x, y, [C["b0"], C["b1"], C["b1"], C["b2"], C["b2"], C["b3"]][min(5, max(0, (y - 26) * 6 // 11))])
        elif y == mid:
            cv.set(x, y, C["g0"])
        else:
            cv.set(x, y, [C["o3"], C["o2"], C["o1"], C["o0"]][min(3, (y - mid - 1) * 4 // 11)])
    for x, y in word.p:
        if (x - 1, y) not in word.p:
            cv.set(x, y, C["g0"] if y < mid else C["o0"])
    # Unterstrich-Swoosh
    for i in range(150):
        y = 56 + round(2 * math.sin(i / 25))
        cv.set(56 + i, y, C["p2"]); cv.set(56 + i, y + 1, C["p3"])
    # Glanzstern
    sx, sy = x0 + 170, 27
    for d in range(-4, 5):
        cv.set(sx + d, sy, C["g0"] if abs(d) < 3 else C["b1"])
        cv.set(sx, sy + d, C["g0"] if abs(d) < 3 else C["b1"])
    mtext(cv, "RAUMSCHIFF-ROGUELIKE", 128, 62, "p1", center=True)
    return cv


@logo("Bullauge", "Genietete Stahllettern, das O ist ein Bullauge mit Blick ins All")
def a7():
    cv = L.Canvas(seed=7, stars=False)
    cv.rectf(0, 0, W, H, C["navy"])
    for y in range(0, H, 16):
        cv.rectf(0, y, W, 1, C["outline"]); cv.rectf(0, y + 1, W, 1, C["navy2"])
    for y in range(8, H, 16):
        for x in range(4, W, 24):
            cv.set(x, y, C["navy3"])
    x = (W - 88 * 2) // 2
    ls = letters(WORD, x, 28, "bold", 2, 2)
    others = union(m for ch, m, _ in ls if ch != "O")
    cv.fill(others.shift(1, 2).dilate(1), C["outline"])
    cv.outline(others, C["outline"])
    cv.fill_bands(others, [C["g2"], C["g3"], C["g4"], C["g5"]])
    cv.bevel(others, C["g1"], C["g6"])
    for x_, y_ in others.p:
        if (x_ % 4 == 1 and y_ % 6 == 2) and all(q in others.p for q in ((x_ + 1, y_), (x_ - 1, y_), (x_, y_ + 1), (x_, y_ - 1))):
            cv.set(x_, y_, C["g6"]); cv.set(x_ - 1, y_ - 1, C["g1"])
    ox = [lx for ch, _, lx in ls if ch == "O"][0] + 8
    oy = 39
    ring = circle(ox, oy, 13)
    cv.fill(ring.dilate(1), C["outline"])
    cv.fill_bands(ring, [C["o1"], C["o2"], C["o3"]])
    glass = circle(ox, oy, 9)
    cv.fill(glass.dilate(1), C["outline"])
    cv.fill_bands(glass, [C["v4"], C["navy"], C["space"]])
    pl = circle(ox + 4, oy + 5, 5); pl.p &= glass.p
    cv.fill_bands(pl, [C["t1"], C["t2"], C["t3"]])
    for (a, b) in ((-4, -2), (-1, 3), (3, -5), (-5, 3)):
        cv.set(ox + a, oy + b, C["g1"])
    for k in range(5):
        cv.set(ox - 6 + k, oy - 2 - k, C["b0"])
    for k in range(12):
        t = k / 12 * 2 * math.pi
        rx, ry = ox + round(11 * math.cos(t)), oy + round(11 * math.sin(t))
        cv.set(rx, ry, C["o3"]); cv.set(rx - 1, ry - 1, C["o0"])
    mtext(cv, "EIN RAUMSCHIFF-ROGUELIKE", 128, 66, "g3", center=True)
    return cv


STROKES = {
    "H": [[(0, 0), (0, 6)], [(4, 0), (4, 6)], [(0, 3), (4, 3)]],
    "U": [[(0, 0), (0, 5), (1, 6), (3, 6), (4, 5), (4, 0)]],
    "L": [[(0, 0), (0, 6), (4, 6)]],
    "B": [[(0, 3), (0, 0), (3, 0), (4, 1), (4, 2), (3, 3), (0, 3), (0, 6), (3, 6), (4, 5), (4, 4), (3, 3)]],
    "O": [[(1, 0), (3, 0), (4, 1), (4, 5), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0)]],
    "N": [[(0, 6), (0, 0), (4, 6), (4, 0)]],
    "D": [[(0, 0), (3, 0), (4, 1), (4, 5), (3, 6), (0, 6), (0, 0)]],
}


@logo("Sternenkarte", "Buchstaben als Sprungrouten: Knoten und Linien wie auf der Sektorkarte")
def a8():
    cv = L.Canvas(seed=8)
    u = 4
    lw, gap = 4 * u, 8
    x = (W - (9 * lw + 8 * gap)) // 2
    y = 22
    nodes = []
    rnd = random.Random(4)
    for i, ch in enumerate(WORD):
        lx = x + i * (lw + gap)
        for st in STROKES[ch]:
            for (a, b), (c, d) in zip(st, st[1:]):
                line(cv, lx + a * u, y + b * u, lx + c * u, y + d * u, C["b3"])
            for (a, b) in st:
                nodes.append((lx + a * u, y + b * u))
    # Sprungpfad zwischen Buchstaben
    for i in range(8):
        a = x + i * (lw + gap) + lw
        line(cv, a, y + 30, a + gap, y + 30, C["navy4"], dash=1)
    seen = set()
    special = {3: "r1", 9: "o2", 17: "t2", 28: "v2", 40: "gr2"}
    for k, (nx, ny) in enumerate(nodes):
        if (nx, ny) in seen:
            continue
        seen.add((nx, ny))
        col = special.get(len(seen), "b1")
        for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            cv.set(nx + dx, ny + dy, C[col])
        cv.set(nx, ny, C["g0"])
    # Ziel-Markierung am Ende
    mtext(cv, "KURS SETZEN", 128, 62, "b1", center=True)
    return cv


@logo("Arcade-Bogen", "Klassischer Automaten-Titel: Lettern im Bogen, dicke Doppelkontur")
def a9():
    cv = L.Canvas(seed=9)
    offs = [round(-9 * (1 - ((i - 4) / 4.6) ** 2)) for i in range(9)]
    x = (W - 88 * 2) // 2
    ls = letters(WORD, x, 30, "bold", 2, 2, offs)
    word = union(m for _, m, _ in ls)
    cv.fill(word.dilate(3).shift(0, 2), C["outline"])
    cv.fill(word.dilate(2), C["o1"])
    cv.fill(word.dilate(2) - word.dilate(1), C["o2"])
    cv.fill(word.dilate(1), C["outline"])
    for ch, m, lx in ls:
        cv.fill_bands(m, [C["g0"], C["r0"], C["r1"], C["r1"], C["r2"]])
        for x_, y_ in m.p:
            if (x_, y_ - 1) not in m.p:
                cv.set(x_, y_, C["g0"])
    L.ship(cv, 118, 62, k=1)
    mtext(cv, "TIPPEN ZUM STARTEN", 128, 78, "o1", center=True)
    return cv


@logo("Monochrom", "Einfarbig und reduziert: Silhouette des Startschiffs plus gesperrte Wortmarke")
def a10():
    cv = L.Canvas(stars=False)
    cv.rectf(0, 0, W, H, C["space"])
    wc = C["g1"]
    ox, oy = 24, 26
    sil = Mask()
    sil.p |= Mask().rect(ox, oy, 40, 10).p
    sil.p |= Mask().rect(ox, oy + 30, 40, 10).p
    sil.p |= Mask().rect(ox, oy, 12, 40).p
    for k in range(6):
        sil.p |= Mask().rect(ox + 40, oy + k, 6 - k, 1).p
        sil.p |= Mask().rect(ox + 40, oy + 9 - k, 6 - k, 1).p
        sil.p |= Mask().rect(ox + 40, oy + 30 + k, 6 - k, 1).p
        sil.p |= Mask().rect(ox + 40, oy + 39 - k, 6 - k, 1).p
    sil.p |= Mask().rect(ox + 20, oy + 18, 16, 4).p
    sil.p |= Mask().rect(ox + 36, oy + 19, 3, 2).p
    cv.fill(sil, wc)
    for yy in (oy + 4, oy + 20, oy + 34):
        cv.rectf(ox - 6, yy, 4, 2, wc)
    cut = Mask()
    for i in range(ox + 14, ox + 40, 6):
        cut.p |= Mask().rect(i, oy + 4, 3, 2).p
        cut.p |= Mask().rect(i, oy + 34, 3, 2).p
    cv.fill(cut, C["space"])
    m = Mask(); m.text(WORD, 84, 34, "std", 2, 3)
    cv.fill(m, wc)
    mtext(cv, "EIN RAUMSCHIFF-ROGUELIKE", 84, 56, "g5")
    return cv


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for i, (fn, title, idea) in enumerate(LOGOS, 11):
        im = fn().save(f"logo_{i:02d}.png", scale=4)
        tiles.append((im, f"{i:02d}  {title}", idea))
    tw, th = W * 3, H * 3
    pad, lab = 24, 54
    sheet = Image.new("RGB", (pad + 2 * (tw + pad), pad + 5 * (th + lab + pad)), (18, 20, 30))
    d = ImageDraw.Draw(sheet)
    f1 = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
    f2 = ImageFont.truetype("DejaVuSans.ttf", 16)
    for k, (im, t, idea) in enumerate(tiles):
        x = pad + (k % 2) * (tw + pad)
        y = pad + (k // 2) * (th + lab + pad)
        sheet.paste(im.resize((tw, th), Image.NEAREST), (x, y))
        d.text((x, y + th + 6), t, fill=(230, 234, 240), font=f1)
        d.text((x, y + th + 32), idea, fill=(142, 151, 164), font=f2)
    sheet.save(os.path.join(OUT, "uebersicht.png"))


if __name__ == "__main__":
    main()
