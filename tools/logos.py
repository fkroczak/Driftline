"""Erzeugt 10 Logo-Vorschläge für Hullbound als Pixel-Art (Palette aus tools/artgen/pipeline.py).

Aufruf: python3 tools/logos.py  ->  art/logos/logo_01..10.png und art/logos/uebersicht.png
"""
import os
import random
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "logos")
W, H, S = 192, 80, 5  # Logo-Raster in Pixeln, Hochskalierung

def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

C = {k: hx(v) for k, v in dict(
    outline="#0A0B16", space="#07080F", navy="#161B2B", navy2="#20263A", navy3="#2B3249", navy4="#363E58",
    g0="#FFFFFF", g1="#E6EAF0", g2="#C4CAD3", g3="#A9B0BB", g4="#8E97A4", g5="#747D8A", g6="#5A6370",
    g7="#424A56", g8="#2A2F3A", g9="#1A1E27",
    b0="#D3E6F8", b1="#85B7EB", b2="#378ADD", b3="#185FA5", b4="#0E3A66",
    t0="#DDF5EC", t1="#9FE1CB", t2="#5DCAA5", t3="#0F6E56", t4="#08402F",
    gr0="#E4F0D0", gr1="#C0DD97", gr2="#639922", gr3="#3B6D11", gr4="#22400A",
    o0="#FDE6BF", o1="#FAC775", o2="#EF9F27", o3="#854F0B", o4="#4F2E05",
    r0="#F7C1C1", r1="#E24B4A", r2="#A32D2D", r3="#5E1919",
    e0="#F9C9B6", e1="#F0997B", e2="#D85A30", e3="#8A3519",
    v0="#CECBF6", v1="#A6A0EA", v2="#7F77DD", v3="#534AB7", v4="#26215C",
    p0="#FBE3EB", p1="#F4C0D1", p2="#D4537E", p3="#8A2E4F",
).items()}

FONTS = {
    "std": {
        "H": ["X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
        "U": ["X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
        "L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
        "B": ["XXXX.", "X...X", "X...X", "XXXX.", "X...X", "X...X", "XXXX."],
        "O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
        "N": ["X...X", "XX..X", "X.X.X", "X..XX", "X...X", "X...X", "X...X"],
        "D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
        ">": ["X....", ".X...", "..X..", "...X.", "..X..", ".X...", "X...."],
        "_": [".....", ".....", ".....", ".....", ".....", ".....", "XXXXX"],
        " ": ["...", "...", "...", "...", "...", "...", "..."],
    },
    "tech": {
        "H": ["X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
        "U": ["X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXXX"],
        "L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
        "B": ["XXXX.", "X..X.", "X..X.", "XXXXX", "X...X", "X...X", "XXXXX"],
        "O": [".XXXX", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
        "N": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "X...X"],
        "D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
        " ": ["...", "...", "...", "...", "...", "...", "..."],
    },
    # schmal und hoch fuer Untertitel
    "mini": {
        "S": ["XXX", "X..", "XXX", "..X", "XXX"], "P": ["XXX", "X.X", "XXX", "X..", "X.."],
        "A": ["XXX", "X.X", "XXX", "X.X", "X.X"], "C": ["XXX", "X..", "X..", "X..", "XXX"],
        "E": ["XXX", "X..", "XX.", "X..", "XXX"], "R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
        "O": ["XXX", "X.X", "X.X", "X.X", "XXX"], "G": ["XXX", "X..", "X.X", "X.X", "XXX"],
        "U": ["X.X", "X.X", "X.X", "X.X", "XXX"], "L": ["X..", "X..", "X..", "X..", "XXX"],
        "I": ["XXX", ".X.", ".X.", ".X.", "XXX"], "K": ["X.X", "X.X", "XX.", "X.X", "X.X"],
        "T": ["XXX", ".X.", ".X.", ".X.", ".X."], "N": ["XXX", "X.X", "X.X", "X.X", "X.X"],
        "Y": ["X.X", "X.X", ".X.", ".X.", ".X."], "D": ["XX.", "X.X", "X.X", "X.X", "XX."],
        "H": ["X.X", "X.X", "XXX", "X.X", "X.X"], "V": ["X.X", "X.X", "X.X", "X.X", ".X."],
        "W": ["X.X", "X.X", "X.X", "XXX", "X.X"], "B": ["XX.", "X.X", "XX.", "X.X", "XX."],
        "F": ["XXX", "X..", "XX.", "X..", "X.."], "M": ["XXX", "XXX", "X.X", "X.X", "X.X"],
        "-": ["...", "...", "XXX", "...", "..."], "Z": ["XXX", "..X", ".X.", "X..", "XXX"], " ": ["..", "..", "..", "..", ".."],
        "·": ["...", "...", ".X.", "...", "..."],
    },
}


class Mask:
    def __init__(self):
        self.p = set()

    def text(self, s, x, y, font="std", scale=1, gap=1):
        f = FONTS[font]
        for ch in s:
            g = f[ch]
            for gy, row in enumerate(g):
                for gx, c in enumerate(row):
                    if c == "X":
                        for dy in range(scale):
                            for dx in range(scale):
                                self.p.add((x + gx * scale + dx, y + gy * scale + dy))
            x += (len(g[0]) + gap) * scale
        return x

    def rect(self, x, y, w, h):
        for j in range(h):
            for i in range(w):
                self.p.add((x + i, y + j))
        return self

    def bbox(self):
        xs = [a for a, _ in self.p]
        ys = [b for _, b in self.p]
        return min(xs), min(ys), max(xs), max(ys)

    def dilate(self, r=1, diag=True):
        m = Mask()
        for (x, y) in self.p:
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if diag or abs(dx) + abs(dy) <= r:
                        m.p.add((x + dx, y + dy))
        return m

    def shift(self, dx, dy):
        m = Mask()
        m.p = {(x + dx, y + dy) for x, y in self.p}
        return m

    def __sub__(self, o):
        m = Mask()
        m.p = self.p - o.p
        return m


def text_w(s, font="std", scale=1, gap=1):
    return sum((len(FONTS[font][c][0]) + gap) * scale for c in s) - gap * scale


class Canvas:
    def __init__(self, bg="space", stars=True, seed=1):
        self.img = Image.new("RGBA", (W, H), C[bg])
        self.px = self.img.load()
        if stars:
            rnd = random.Random(seed)
            for _ in range(70):
                x, y = rnd.randrange(W), rnd.randrange(H)
                self.set(x, y, rnd.choice([C["g7"], C["g6"], C["navy4"], C["g4"]]))
            for _ in range(8):
                x, y = rnd.randrange(W), rnd.randrange(H)
                self.set(x, y, C["g2"])

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y]

    def fill(self, m, c):
        for x, y in m.p:
            self.set(x, y, c)

    def fill_bands(self, m, colors, y0=None, y1=None):
        """Vertikaler Verlauf in harten Pixel-Bändern."""
        bx0, by0, bx1, by1 = m.bbox()
        y0 = by0 if y0 is None else y0
        y1 = by1 if y1 is None else y1
        n = len(colors)
        for x, y in m.p:
            t = (y - y0) / max(1, (y1 - y0 + 1))
            self.set(x, y, colors[min(n - 1, max(0, int(t * n)))])

    def bevel(self, m, light, dark):
        for x, y in m.p:
            if (x, y - 1) not in m.p or (x - 1, y) not in m.p:
                self.set(x, y, light)
            elif (x, y + 1) not in m.p or (x + 1, y) not in m.p:
                self.set(x, y, dark)

    def outline(self, m, c, r=1, diag=True):
        self.fill(m.dilate(r, diag) - m, c)

    def rectf(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.set(x + i, y + j, c)

    def save(self, name, scale=S):
        im = self.img.resize((W * scale, H * scale), Image.NEAREST)
        im.save(os.path.join(OUT, name))
        return im


def centered(s, y, font="std", scale=1, gap=1, dx=0):
    m = Mask()
    m.text(s, (W - text_w(s, font, scale, gap)) // 2 + dx, y, font, scale, gap)
    return m


def metal_word(cv, m, bands=("g1", "g2", "g3", "g4", "g5"), light="g0", dark="g6", out="outline", shadow=True):
    if shadow:
        cv.fill(m.shift(1, 2).dilate(1), C["g9"])
    cv.outline(m, C[out])
    cv.fill_bands(m, [C[b] for b in bands])
    cv.bevel(m, C[light], C[dark])


def ship(cv, x, y, flip=False, hull=("g1", "g2", "g4", "g6"), flame=True, k=1):
    """Kleiner Frachter in Draufsicht, Bug nach rechts (21x9)."""
    rows = [
        "....oooooooooooo.....",
        "...o11111111111oo....",
        "..o1222222222222oo...",
        "oo12bbbbbbbbbb222wwo.",
        "oo12223322332223wwwwo",
        "oo12bbbbbbbbbb222wwo.",
        "..o3333333333333oo...",
        "...o33333333333oo....",
        "....oooooooooooo.....",
    ]
    pal = {"o": C["outline"], "1": C[hull[0]], "2": C[hull[1]], "3": C[hull[2]], "b": C["b2"],
           "w": C["b1"]}
    pal_dark = C[hull[3]]
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            cv.rectf(x + i * k, y + j * k, k, k, pal.get(ch, pal_dark))
    cv.rectf(x + 6 * k, y + 4 * k, k, k, C["o2"])
    cv.rectf(x + 10 * k, y + 4 * k, k, k, C["r1"])
    if flame and k > 1:
        for yy in (3, 4, 5):
            for i, c in enumerate(("b1", "b1", "b2", "b2", "b3", "b3", "b4", "b4")[: 8 - abs(yy - 4) * 3]):
                cv.rectf(x - (i + 1) * k // 2 - 1, y + yy * k, k // 2 + 1, k, C["b0"] if (yy == 4 and i < 2) else C[c])
        return
    if flame:
        for k, yy in enumerate((y + 3, y + 5)):
            cv.set(x - 1, yy, C["b1"]); cv.set(x - 2, yy, C["b2"]); cv.set(x - 3, yy, C["b3"])
            cv.set(x - 4, yy, C["b4"])
        cv.set(x - 1, y + 4, C["b0"]); cv.set(x - 2, y + 4, C["b1"]); cv.set(x - 3, y + 4, C["b2"])
        cv.set(x - 4, y + 4, C["b3"]); cv.set(x - 5, y + 4, C["b4"])


def subtitle(cv, s, y, color, dx=0):
    m = centered(s, y, "mini", 1, 1, dx)
    cv.fill(m, C[color])
    return m


# ---------------------------------------------------------------------------
LOGOS = []


def logo(title, idea):
    def deco(fn):
        LOGOS.append((fn, title, idea))
        return fn
    return deco


@logo("Rumpfplatte", "Gebürstetes Metall mit Fase, blauer Rumpfstreifen wie am Frachter")
def l1():
    cv = Canvas(seed=11)
    m = centered("HULLBOUND", 20, "std", 3, 1)
    x0, y0, x1, y1 = m.bbox()
    cv.rectf(x0 - 6, y1 + 5, x1 - x0 + 13, 2, C["b2"])
    cv.rectf(x0 - 6, y1 + 7, x1 - x0 + 13, 1, C["b3"])
    for x in range(x0 - 4, x1 + 6, 6):
        cv.set(x, y1 + 5, C["b0"])
    metal_word(cv, m)
    # Nieten an den Enden
    for xx in (x0 - 9, x1 + 8):
        cv.rectf(xx, y1 + 5, 2, 3, C["g4"]); cv.set(xx, y1 + 5, C["g1"])
    subtitle(cv, "EIN RAUMSCHIFF-ROGUELIKE", y1 + 12, "g5")
    return cv


@logo("Frachter", "Das Startschiff fliegt über den Schriftzug, Triebwerke in Schildblau")
def l2():
    cv = Canvas(seed=22)
    m = centered("HULLBOUND", 34, "std", 2, 1)
    x0, y0, x1, y1 = m.bbox()
    # Antriebsspur
    for i in range(x0 - 4, 70):
        c = C["b4"] if i < 46 else C["b3"] if i < 60 else C["b2"]
        if (i * 7) % 5:
            cv.set(i, 13, c)
        if (i * 3) % 4:
            cv.set(i, 17, c)
    ship(cv, 76, 6, k=2)
    metal_word(cv, m)
    subtitle(cv, "EIN RAUMSCHIFF-ROGUELIKE", y1 + 8, "b1")
    return cv


@logo("Abzeichen", "Sechseckiges Crew-Abzeichen mit H-Monogramm, Reaktor-Orange")
def l3():
    cv = Canvas(seed=33)
    # Sechseck
    cx, cy, r = 32, 40, 22
    hexm = Mask()
    for y in range(cy - r, cy + r + 1):
        dy = abs(y - cy)
        half = r if dy <= r // 2 else r - (dy - r // 2) * 2 + 0
        half = max(0, int(r - max(0, dy - r * 0.5) * 1.0))
        for x in range(cx - half, cx + half + 1):
            hexm.p.add((x, y))
    cv.outline(hexm, C["outline"])
    cv.fill_bands(hexm, [C["g6"], C["g7"], C["g8"]])
    inner = Mask(); inner.p = {p for p in hexm.p if p in hexm.shift(0, 3).p and p in hexm.shift(0, -3).p
                               and p in hexm.shift(3, 0).p and p in hexm.shift(-3, 0).p}
    cv.fill(hexm - inner, C["o2"])
    cv.bevel(hexm, C["o1"], C["o3"])
    cv.fill_bands(inner, [C["navy3"], C["navy2"], C["navy"]])
    hm = Mask(); hm.text("H", cx - 7, cy - 10, "std", 3)
    cv.outline(hm, C["outline"])
    cv.fill_bands(hm, [C["o0"], C["o1"], C["o2"], C["o3"]])
    cv.bevel(hm, C["o0"], C["o3"])
    # Wortmarke
    m = Mask(); m.text("HULLBOUND", 64, 28, "tech", 2, 1)
    metal_word(cv, m)
    x0, y0, x1, y1 = m.bbox()
    cv.rectf(64, y1 + 5, x1 - 63, 1, C["o2"])
    s = Mask(); s.text("SPACE ROGUELIKE", 64, y1 + 9, "mini"); cv.fill(s, C["o1"])
    return cv


@logo("Retro-Sonnenuntergang", "Gestapelt, Arcade-Verlauf von Gold nach Rot über einem Gitterhorizont")
def l4():
    cv = Canvas(seed=44)
    # Horizontgitter
    for y, c in ((60, "e3"), (64, "e3"), (69, "r2"), (75, "r2")):
        cv.rectf(0, y, W, 1, C[c])
    for k in range(-12, 13):
        for y in range(58, H):
            x = W // 2 + int(k * 8 * (y - 50) / 10)
            cv.set(x, y, C["e3"])
    cv.rectf(0, 57, W, 1, C["o2"])
    a = centered("HULL", 4, "std", 3, 1)
    b = centered("BOUND", 29, "std", 3, 1)
    for m in (a, b):
        cv.fill(m.shift(2, 2).dilate(1), C["v4"])
        cv.outline(m, C["outline"])
    cv.fill_bands(a, [C["o0"], C["o1"], C["o2"], C["e2"]])
    cv.fill_bands(b, [C["o2"], C["e2"], C["r1"], C["r2"]])
    cv.bevel(a, C["o0"], C["o3"])
    cv.bevel(b, C["e1"], C["r3"])
    return cv


@logo("Terminal", "Bordcomputer: grüner Monochrom-Bildschirm mit Scanlines und Cursor")
def l5():
    cv = Canvas(bg="t4", stars=False)
    cv.rectf(0, 0, W, H, C["space"])
    cv.rectf(6, 6, W - 12, H - 12, C["g8"])
    cv.rectf(8, 8, W - 16, H - 16, C["outline"])
    m = Mask(); end = m.text(">HULLBOUND", 20, 26, "std", 2, 1)
    cur = Mask().rect(end + 2, 26, 10, 14)
    glow = m.dilate(1)
    cv.fill(glow, C["t4"])
    cv.fill(m, C["t2"])
    cv.fill(cur, C["t2"])
    # Lichtkante oben
    for x, y in m.p:
        if (x, y - 1) not in m.p:
            cv.set(x, y, C["t0"])
    s = Mask(); s.text("SYSTEM BEREIT - SPRUNG FREI", 20, 48, "mini"); cv.fill(s, C["t3"])
    # Scanlines
    for y in range(8, H - 8, 2):
        for x in range(8, W - 8):
            r, g, b, a = cv.get(x, y)
            cv.set(x, y, (r * 3 // 5, g * 3 // 5, b * 3 // 5, 255))
    # Ecken
    for (x, y) in ((6, 6), (W - 7, 6), (6, H - 7), (W - 7, H - 7)):
        cv.set(x, y, C["space"])
    cv.rectf(W - 22, H - 6, 8, 2, C["t3"])
    return cv


@logo("Raummodule", "Jeder Buchstabe ist ein Raum im Schiffsgrundriss, mit Systemfarben")
def l6():
    cv = Canvas(seed=66)
    word = "HULLBOUND"
    colors = ["b1", "gr2", "o2", "v2", "t2", "r1", "b2", "e2", "p2"]
    tile = 18
    total = len(word) * tile + 2
    x = (W - total) // 2
    y = 22
    # Rumpf
    hull = Mask().rect(x - 4, y - 4, total + 8, tile + 10)
    cv.outline(hull, C["outline"])
    cv.fill_bands(hull, [C["g2"], C["g3"], C["g4"], C["g5"], C["g6"]])
    cv.bevel(hull, C["g1"], C["g7"])
    # Nase
    nx, top, bot = x + total + 4, y - 4, y + tile + 5
    for i in range(12):
        cut = i * (tile + 10) // 26
        for j in range(top + cut, bot - cut + 1):
            cv.set(nx + i, j, C["g2"] if j < (top + bot) // 2 - 2 else C["g4"] if j < (top + bot) // 2 + 3 else C["g5"])
        cv.set(nx + i, top + cut - 1, C["outline"]); cv.set(nx + i, bot - cut + 1, C["outline"])
    cv.rectf(nx + 1, y + 6, 6, 3, C["b1"]); cv.rectf(nx + 1, y + 6, 6, 1, C["b0"])
    cv.set(nx + 11, (top + bot) // 2, C["r1"])
    for k, j in enumerate((y + 2, y + tile)):
        cv.rectf(x - 9, j, 5, 2, C["b2"]); cv.rectf(x - 12, j, 3, 2, C["b3"]); cv.set(x - 13, j, C["b4"])
        cv.set(x - 5, j, C["b0"])
    for i, ch in enumerate(word):
        tx = x + 1 + i * tile
        room = Mask().rect(tx, y, tile - 1, tile + 2)
        cv.fill(room, C["navy"])
        for gx in range(tx, tx + tile - 1, 4):
            for gy in range(y, y + tile + 2):
                cv.set(gx, gy, C["navy2"])
        for gy in range(y, y + tile + 2, 4):
            cv.rectf(tx, gy, tile - 1, 1, C["navy2"])
        cv.rectf(tx - 1, y, 1, tile + 2, C["outline"])
        lm = Mask(); lm.text(ch, tx + 4, y + 3, "std", 2, 0)
        lm2 = Mask(); lm2.p = {(px - (lm.bbox()[0] - (tx + (tile - 1 - (lm.bbox()[2] - lm.bbox()[0] + 1)) // 2)), py)
                               for px, py in lm.p}
        cv.outline(lm2, C["outline"])
        cv.fill(lm2, C["g1"])
        cv.bevel(lm2, C["g0"], C["g3"])
        cv.rectf(tx + 6, y + tile - 1, 4, 2, C[colors[i]])
    cv.rectf(x + total, y, 1, tile + 2, C["outline"])
    subtitle(cv, "BAUE · KAEMPFE · UEBERLEBE", 58, "g4")
    return cv


@logo("Warpsprung", "Kantige Tech-Schrift mit Sprunglinien, Blau-Weiß-Verlauf")
def l7():
    cv = Canvas(seed=77)
    m = centered("HULLBOUND", 26, "tech", 3, 1, dx=8)
    x0, y0, x1, y1 = m.bbox()
    rnd = random.Random(5)
    for y in range(y0 - 6, y1 + 7):
        if rnd.random() < 0.55:
            ln = rnd.randint(10, 60)
            start = x0 - 6 - ln
            for i in range(ln):
                t = i / ln
                c = C["b4"] if t < 0.4 else C["b3"] if t < 0.75 else C["b2"] if t < 0.92 else C["b1"]
                cv.set(start + i, y, c)
    cv.fill(m.dilate(2), C["b4"])
    cv.outline(m, C["outline"])
    cv.fill_bands(m, [C["g0"], C["b0"], C["b1"], C["b2"], C["b3"]])
    for x, y in m.p:
        if (x - 1, y) not in m.p:
            cv.set(x, y, C["g0"])
    s = Mask(); s.text("SPRUNG BEREIT", x1 - text_w("SPRUNG BEREIT", "mini"), y1 + 7, "mini")
    cv.fill(s, C["b1"])
    return cv


@logo("Planetenring", "Das O wird zum beringten Planeten, Sensor-Violett und Türkis")
def l8():
    cv = Canvas(seed=88)
    pre, post = "HULLB", "UND"
    sc = 2
    wpre, wpost = text_w(pre, "std", sc), text_w(post, "std", sc)
    pw = 22
    total = wpre + wpost + pw + 14
    x = (W - total) // 2
    y = 30
    a = Mask(); a.text(pre, x, y, "std", sc)
    b = Mask(); b.text(post, x + wpre + pw + 14, y, "std", sc)
    cx, cy, r = x + wpre + 7 + pw // 2, y + 7, 10
    planet = Mask()
    for j in range(-r, r + 1):
        for i in range(-r, r + 1):
            if i * i + j * j <= r * r + r * 0.6:
                planet.p.add((cx + i, cy + j))
    # Ring hinten
    ring_back, ring_front = Mask(), Mask()
    import math
    for k in range(400):
        t = k / 400 * 2 * math.pi
        for rr in (17, 18, 19):
            px = cx + round(rr * math.cos(t))
            py = cy + round(rr * 0.32 * math.sin(t) - rr * 0.18 * math.cos(t))
            (ring_front if math.sin(t) > 0 else ring_back).p.add((px, py))
    cv.fill(ring_back, C["v3"])
    cv.outline(planet, C["outline"])
    cv.fill_bands(planet, [C["t1"], C["t2"], C["t2"], C["t3"], C["t4"]])
    for (px, py) in planet.p:
        if (px - cx) + (py - cy) > 6:
            cv.set(px, py, C["t4"])
        if (py - cy) in (-3, 2) and (px + py) % 3:
            cv.set(px, py, C["t3"])
    cv.set(cx - 4, cy - 5, C["t0"]); cv.set(cx - 5, cy - 4, C["t0"]); cv.set(cx - 3, cy - 6, C["t0"])
    cv.fill(ring_front, C["v1"])
    for (px, py) in ring_front.p:
        if (px, py - 1) not in ring_front.p:
            cv.set(px, py, C["v0"])
    for m in (a, b):
        metal_word(cv, m, bands=("v0", "v1", "v2", "v3"), light="g0", dark="v4")
    subtitle(cv, "EIN RAUMSCHIFF-ROGUELIKE", y + 26, "v1")
    return cv


@logo("Neon-Kontur", "Hohle Konturschrift mit Farbversatz wie ein flackerndes Hologramm")
def l9():
    cv = Canvas(seed=99)
    m = centered("HULLBOUND", 24, "std", 3, 1)
    inner = Mask(); inner.p = {p for p in m.p if all(q in m.p for q in
                                                    ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)))}
    border = m - inner
    cv.fill(border.shift(-2, 0), C["p2"])
    cv.fill(border.shift(2, 1), C["b2"])
    cv.fill(border.dilate(1), C["b4"])
    cv.fill(border, C["t1"])
    for x, y in border.p:
        if (x + y) % 7 == 0:
            cv.set(x, y, C["g0"])
    # Störstreifen
    for y in (30, 37):
        for x in range(0, W):
            if (x // 3) % 4 == 0:
                r, g, b, a = cv.get(x, y)
                cv.set(x + 2, y, (r, g, b, 255))
    s = subtitle(cv, "HOLO-LOG  ·  KURS GESETZT", 52, "p1")
    return cv


@logo("App-Icon + Wortmarke", "Monogramm HB auf Rumpfkachel als App-Icon, daneben schlichte Wortmarke")
def l10():
    cv = Canvas(seed=100)
    ix, iy, sz = 10, 10, 60
    icon = Mask().rect(ix, iy, sz, sz)
    for (cx, cy) in ((ix, iy), (ix + sz - 1, iy), (ix, iy + sz - 1), (ix + sz - 1, iy + sz - 1)):
        for dx in range(3):
            for dy in range(3 - dx):
                icon.p.discard((cx + (dx if cx == ix else -dx), cy + (dy if cy == iy else -dy)))
    cv.outline(icon, C["outline"])
    cv.fill_bands(icon, [C["navy3"], C["navy2"], C["navy"]])
    # Raumgitter im Icon
    for (px, py) in icon.p:
        if (px - ix) % 6 == 0 or (py - iy) % 6 == 0:
            if cv.get(px, py) != C["outline"]:
                cv.set(px, py, C["navy4"] if py < iy + 20 else C["navy3"])
    # Blauer Streifen
    cv.rectf(ix, iy + 46, sz, 3, C["b2"]); cv.rectf(ix, iy + 49, sz, 1, C["b3"])
    hb = Mask(); hb.text("HB", ix + 9, iy + 11, "tech", 4, 1)
    hb2 = Mask(); hb2.p = {(x - 0, y) for x, y in hb.p}
    cv.fill(hb2.shift(1, 2).dilate(1), C["outline"])
    cv.outline(hb2, C["outline"])
    cv.fill_bands(hb2, [C["g0"], C["g1"], C["g2"], C["g3"], C["g4"]])
    cv.bevel(hb2, C["g0"], C["g5"])
    for k in range(3):
        cv.rectf(ix + 8 + k * 8, iy + 53, 4, 2, C[("b1", "o2", "r1")[k]])
    cv.bevel(icon, C["navy4"], C["outline"])
    m = Mask(); m.text("HULLBOUND", 82, 30, "tech", 2, 1)
    cv.fill(m, C["g1"])
    for x, y in m.p:
        if (x, y + 1) not in m.p:
            cv.set(x, y, C["g4"])
    s = Mask(); s.text("SPACE ROGUELIKE", 82, 50, "mini"); cv.fill(s, C["b1"])
    cv.rectf(82, 46, text_w("HULLBOUND", "tech", 2), 1, C["b2"])
    return cv


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for i, (fn, title, idea) in enumerate(LOGOS, 1):
        im = fn().save(f"logo_{i:02d}.png")
        tiles.append((im, f"{i:02d}  {title}", idea))
    # Übersicht
    tw, th = W * 4, H * 4
    pad, lab = 24, 54
    sheet = Image.new("RGB", (pad + 2 * (tw + pad), pad + 5 * (th + lab + pad)), (18, 20, 30))
    d = ImageDraw.Draw(sheet)
    try:
        f1 = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
        f2 = ImageFont.truetype("DejaVuSans.ttf", 16)
    except OSError:
        f1 = f2 = ImageFont.load_default()
    for k, (im, t, idea) in enumerate(tiles):
        col, row = k % 2, k // 2
        x = pad + col * (tw + pad)
        y = pad + row * (th + lab + pad)
        sheet.paste(im.resize((tw, th), Image.NEAREST), (x, y))
        d.text((x, y + th + 6), t, fill=(230, 234, 240), font=f1)
        d.text((x, y + th + 32), idea, fill=(142, 151, 164), font=f2)
    sheet.save(os.path.join(OUT, "uebersicht.png"))


if __name__ == "__main__":
    main()
