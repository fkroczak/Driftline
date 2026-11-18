"""Mensch-Crew als Vektor-Vorlage (Draufsicht), 4 Blickrichtungen.

Zwei Größen:
  gross  40x44 px  – Porträt/UI (Crew-Liste, Auswahl, Dialoge), aus Vektorformen
  klein  16x16 px  – Figur an Bord (13 px + Kontur, passt in 1 Kachel à 14 px),
                     aus einer Materialkarte (siehe SMALL_MAP)
"""
COLORS = {
    "uniform": ("#378ADD", "#185FA5", "#0E3A66"),
    "pad": ("#85B7EB", "#378ADD", "#185FA5"),
    "collar": ("#5A6370", "#2A2F3A", "#1A1E27"),
    "skin": ("#F2C9AE", "#E2AC8B", "#C58A6A"),
    "hair": ("#B07A3C", "#7F4C1E", "#3A2009"),
    "boot": ("#5A6370", "#2A2F3A", "#1A1E27"),
    "pack": ("#C4CAD3", "#8E97A4", "#424A56"),
    "stripe": ("#FAC775", "#EF9F27", "#854F0B"),
}

# Teile in lokaler Lage "Blick nach unten" (vorne = +y), relativ zur Körpermitte:
# (typ, cx, cy, rx, ry, farbe[, eckradius])
SPECS = {
    "gross": {
        "size": (40, 44), "center": (19.5, 20.5), "shadow": 2,
        "parts": [
            ("ell", -4.2, 8.4, 2.3, 2.7, "boot"),
            ("ell", 4.2, 8.4, 2.3, 2.7, "boot"),
            ("rect", 0, -5.4, 5.2, 2.3, "pack", 1.6),
            ("ell", -13.0, 2.0, 2.8, 5.4, "uniform"),
            ("ell", 13.0, 2.0, 2.8, 5.4, "uniform"),
            ("ell", -13.2, 7.0, 2.1, 2.1, "skin"),
            ("ell", 13.2, 7.0, 2.1, 2.1, "skin"),
            ("rect", 0, 1.2, 12.4, 6.0, "uniform", 5.0),
            ("ell", -9.8, 0.4, 4.0, 4.9, "pad"),
            ("ell", 9.8, 0.4, 4.0, 4.9, "pad"),
            ("rect", -10.6, 0.4, 0.8, 4.1, "stripe", 0.4),
            ("rect", 10.6, 0.4, 0.8, 4.1, "stripe", 0.4),
            ("ell", 0, 2.2, 6.2, 4.2, "collar"),
            ("ell", 0, 2.0, 5.2, 5.6, "skin"),
            ("ell", 0, 0.3, 5.45, 5.2, "hair"),
        ],
        "strands": [(-1.4, -3.2), (1.6, -2.6)],
        "glow": (-9.4, 3.6, 0.75),
    },
}

ROT = {
    "unten": lambda x, y: (x, y),
    "oben": lambda x, y: (-x, -y),
    "links": lambda x, y: (-y, x),
    "rechts": lambda x, y: (y, -x),
}
DIRECTIONS = ["unten", "oben", "links", "rechts"]


def _shape(i, kind, cx, cy, rx, ry, col, r=0.0):
    lt, md, dk = COLORS[col]
    # Licht oben links: Gradientzentrum in Weltkoordinaten versetzt (dreht nicht mit)
    gx, gy, gr = cx - 0.45 * rx, cy - 0.5 * ry, 1.35 * max(rx, ry)
    grad = (f'<radialGradient id="g{i}" gradientUnits="userSpaceOnUse" cx="{gx}" cy="{gy}" r="{gr}">'
            f'<stop offset="0" stop-color="{lt}"/><stop offset="0.5" stop-color="{md}"/>'
            f'<stop offset="1" stop-color="{dk}"/></radialGradient>')
    if kind == "ell":
        el = f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#g{i})"/>'
    else:
        el = (f'<rect x="{cx - rx}" y="{cy - ry}" width="{2 * rx}" height="{2 * ry}" '
              f'rx="{r}" ry="{r}" fill="url(#g{i})"/>')
    return grad, el


def build_svg(size, direction):
    spec = SPECS[size]
    W, H = spec["size"]
    CX, CY = spec["center"]
    rot = ROT[direction]
    swap = direction in ("links", "rechts")
    defs, body = [], []
    for i, p in enumerate(spec["parts"]):
        kind, x, y, rx, ry, col = p[:6]
        r = p[6] if len(p) > 6 else 0.0
        wx, wy = rot(x, y)
        if swap:
            rx, ry = ry, rx
        g, e = _shape(i, kind, CX + wx, CY + wy, rx, ry, col, r)
        defs.append(g)
        body.append(e)
    for ox, oy in spec["strands"]:
        a, b = rot(ox, oy), rot(ox * 0.4, oy + 3.6)
        body.append(f'<line x1="{CX + a[0]}" y1="{CY + a[1]}" x2="{CX + b[0]}" y2="{CY + b[1]}" '
                    f'stroke="#5E3614" stroke-width="0.9" stroke-linecap="round"/>')
    if spec["glow"]:
        gx, gy, gr = spec["glow"]
        wx, wy = rot(gx, gy)
        body.append(f'<circle cx="{CX + wx}" cy="{CY + wy}" r="{gr + 1.1}" fill="#5DCAA5" fill-opacity="0.55"/>')
        body.append(f'<circle cx="{CX + wx}" cy="{CY + wy}" r="{gr}" fill="#DDF5EC"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<defs>{"".join(defs)}</defs>{"".join(body)}</svg>')


# ---------------------------------------------------------------------------
# Kleine Bord-Figur (ca. 14 px): bei dieser Größe wird nicht aus Vektorformen
# gerechnet, sondern aus einer Materialkarte, die pro Richtung gedreht und dann
# automatisch schattiert wird (Licht oben links: Kanten oben/links hell,
# unten/rechts dunkel). Die Karte wird als SVG aus 1-px-Rechtecken exportiert.
# P=Rucksack U=Uniform O=Streifen H=Haar S=Haut C=Kragen B=Stiefel
SMALL_MAP = [
    "....PPPPP....",
    ".UUUPHHHPUUU.",
    "UUOUHHHHHUOUU",
    "UUOUHHHHHUOUU",
    "UUOUHHHHHUOUU",
    "UUUUCHHHCUUUU",
    "SUUUUSSSUUUUS",
    "S..BB...BB..S",
]
SMALL_MAT = {"P": "pack", "U": "uniform", "O": "stripe", "H": "hair", "S": "skin", "C": "collar", "B": "boot"}
SMALL_GROUP = {"U": "b", "O": "b", "C": "b", "H": "h", "S": "s", "P": "p", "B": "f", ".": "."}  # Flächen für die Schattierung
SMALL_SIZE = (16, 16)
SMALL_SHADOW = 1
_ROT90 = {"unten": 0, "rechts": 1, "oben": 2, "links": 3}


def _rotate(rows, k):
    import numpy as np
    return ["".join(r) for r in np.rot90(np.array([list(r) for r in rows]), k)]


def build_svg_small(direction):
    rows = _rotate(SMALL_MAP, _ROT90[direction])
    h, w = len(rows), len(rows[0])
    ox, oy = (SMALL_SIZE[0] - 1 - w) // 2, (SMALL_SIZE[1] - 1 - h) // 2
    at = lambda x, y: SMALL_GROUP[rows[y][x]] if 0 <= y < h and 0 <= x < w else "."
    rects = []
    for y in range(h):
        for x in range(w):
            ch = rows[y][x]
            if ch == ".":
                continue
            lt, md, dk = COLORS[SMALL_MAT[ch]]
            g = SMALL_GROUP[ch]
            score = (at(x, y - 1) != g) + (at(x - 1, y) != g) - (at(x, y + 1) != g) - (at(x + 1, y) != g)
            col = lt if score > 0 else dk if score < 0 else md
            if ch == "H" and score == 0 and (x + y) % 3 == 0:
                col = COLORS["hair"][0]  # Haarsträhnen
            rects.append(f'<rect x="{ox + x}" y="{oy + y}" width="1" height="1" fill="{col}"/>')
    W, H = SMALL_SIZE
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'{"".join(rects)}</svg>')
