"""Crew aller Spezies als Vektor-Vorlage (Draufsicht), 4 Blickrichtungen.

Gleicher Aufbau wie crew_human.py (der Mensch bleibt dort), Vorbild ist
art/pixel/species_pixel.png:

  gross  40x44 px  – Porträt in der Crew-Liste, aus Vektorformen (parts) und Linien (lines)
  klein  16x16 px  – Figur an Bord, aus einer Materialkarte (small_map), höchstens 13x13

Lage "Blick nach unten" (vorne = +y), Koordinaten relativ zur Körpermitte.
parts: (typ, cx, cy, rx, ry, farbe[, eckradius]); lines: (x1, y1, x2, y2, breite, farbe).
face: Mitte des Kopfs im großen Bild (Pixel); die gültigen Werte stehen in game/data/species.json.
"""
import crew_human as CH

SPECIES = {}

# --- Kith'ra: Insektoid, grüner Chitinpanzer, sechs Beine, Fühler, orange Augen ---------------
SPECIES["kithra"] = {
    "colors": {
        "shell": ("#C0DD97", "#639922", "#3B6D11"),
        "seam": ("#639922", "#3B6D11", "#22400A"),
        "thorax": ("#C0DD97", "#639922", "#3B6D11"),
        "head": ("#E4F0D0", "#C0DD97", "#639922"),
        "eye": ("#FAC775", "#D85A30", "#854F0B"),
        "leg": ("#639922", "#3B6D11", "#22400A"),
    },
    "parts": [
        ("ell", 0, -9.5, 5.6, 8.4, "shell"),
        ("rect", 0, -9.5, 0.45, 7.2, "seam", 0.2),
        ("ell", 0, 0.5, 4.2, 3.6, "thorax"),
        ("ell", 0, 5.6, 5.0, 3.8, "head"),
        ("ell", -3.6, 6.4, 1.7, 1.9, "eye"),
        ("ell", 3.6, 6.4, 1.7, 1.9, "eye"),
    ],
    "lines": [
        (-3.5, -1.5, -13.5, -9.0, 1.4, "leg"), (3.5, -1.5, 13.5, -9.0, 1.4, "leg"),
        (-4.0, 0.8, -15.0, 1.8, 1.4, "leg"), (4.0, 0.8, 15.0, 1.8, 1.4, "leg"),
        (-3.2, 3.0, -12.5, 10.5, 1.4, "leg"), (3.2, 3.0, 12.5, 10.5, 1.4, "leg"),
        (-1.4, 9.0, -5.5, 16.5, 0.9, "leg"), (1.4, 9.0, 5.5, 16.5, 0.9, "leg"),
    ],
    "face": (20, 30),
    # L=Bein A=Fühler G=Panzer N=Naht T=Brust H=Kopf E=Auge
    "small_map": [
        "....GGGGG....",
        "L..GGGNGGG..L",
        ".L.GGGNGGG.L.",
        "..LGGGNGGGL..",
        "....GGGGG....",
        "..LLLTTTLLL..",
        ".L...TTT...L.",
        "L..HHHHHHH..L",
        "...EHHHHHE...",
        "....HHHHH....",
        "....A...A....",
        "...A.....A...",
    ],
    "mat": {"L": "leg", "A": "leg", "G": "shell", "N": "seam", "T": "thorax", "H": "head", "E": "eye"},
    "group": {"L": "l", "A": "l", "G": "b", "N": "b", "T": "t", "H": "h", "E": "e"},
}

# --- Androide: weiß-graue Hülle, Kuppelkopf mit Visier, Schulterkugeln, blauer Kern -----------
SPECIES["androide"] = {
    "colors": {
        "shell": ("#FFFFFF", "#E6EAF0", "#A9B0BB"),
        "joint": ("#E6EAF0", "#C4CAD3", "#8E97A4"),
        "dome": ("#FFFFFF", "#DDF5EC", "#9FE1CB"),
        "visor": ("#DDF5EC", "#5DCAA5", "#0F6E56"),
        "core": ("#85B7EB", "#378ADD", "#185FA5"),
        "leg": ("#8E97A4", "#5A6370", "#2A2F3A"),
        "antenna": ("#FAC775", "#EF9F27", "#854F0B"),
    },
    "parts": [
        ("rect", -8.0, 9.0, 2.6, 2.4, "leg", 1.0),
        ("rect", 8.0, 9.0, 2.6, 2.4, "leg", 1.0),
        ("rect", -14.0, 7.2, 2.2, 2.6, "leg", 1.0),
        ("rect", 14.0, 7.2, 2.2, 2.6, "leg", 1.0),
        ("rect", 0, 1.5, 13.0, 7.0, "shell", 3.0),
        ("ell", -12.5, -0.5, 4.4, 4.4, "joint"),
        ("ell", 12.5, -0.5, 4.4, 4.4, "joint"),
        ("ell", 0, 4.0, 3.0, 3.0, "core"),
        ("rect", 0, -6.0, 6.0, 5.0, "dome", 3.0),
        ("rect", 0, -3.2, 5.4, 1.6, "visor", 0.8),
        ("rect", 0, -12.0, 0.8, 1.4, "antenna", 0.4),
    ],
    "lines": [],
    "glow": (0, 4.0, 1.0),
    "face": (20, 21),
    # P=Rückenteil J=Schulter W=Hülle D=Kuppel V=Visier C=Kern B=Bein
    "small_map": [
        ".....P.P.....",
        "....DDDDD....",
        ".JJWDDDDDWJJ.",
        "JJJWDDDDDWJJJ",
        "JJJWVVVVVWJJJ",
        ".JWWWWWWWWWJ.",
        "..WWWWCWWWW..",
        "..WWWCCCWWW..",
        "..BB.....BB..",
        "..BB.....BB..",
    ],
    "mat": {"P": "antenna", "J": "joint", "W": "shell", "D": "dome", "V": "visor", "C": "core", "B": "leg"},
    "group": {"P": "p", "J": "j", "W": "b", "D": "h", "V": "h", "C": "c", "B": "f"},
}

# --- Veyari: großer heller Kopf, dunkle Augen, violettes Gewand, dünne Arme -------------------
SPECIES["veyari"] = {
    "colors": {
        "robe": ("#A6A0EA", "#534AB7", "#26215C"),
        "trim": ("#E6EAF0", "#A9B0BB", "#5A6370"),
        "head": ("#FFFFFF", "#E6EAF0", "#CECBF6"),
        "crest": ("#E6EAF0", "#A9B0BB", "#747D8A"),
        "eye": ("#424A56", "#1A1E27", "#0A0B16"),
        "arm": ("#FFFFFF", "#CECBF6", "#A6A0EA"),
        "gem": ("#C0DD97", "#5DCAA5", "#0F6E56"),
    },
    "parts": [
        ("ell", -4.0, 10.5, 2.0, 2.0, "robe"),
        ("ell", 4.0, 10.5, 2.0, 2.0, "robe"),
        ("rect", 0, 4.5, 8.0, 6.8, "robe", 3.5),
        ("rect", 0, 4.5, 0.6, 6.0, "trim", 0.3),
        ("ell", 13.0, 10.0, 2.6, 2.0, "gem"),
        ("ell", 0, -2.5, 9.0, 8.6, "head"),
        ("rect", 0, -6.5, 0.5, 4.5, "crest", 0.2),
        ("ell", -3.8, 0.5, 2.5, 2.0, "eye"),
        ("ell", 3.8, 0.5, 2.5, 2.0, "eye"),
    ],
    "lines": [
        (-8.0, 3.0, -10.5, 8.0, 1.1, "arm"), (-10.5, 8.0, -9.5, 12.0, 1.1, "arm"),
        (8.0, 3.0, 10.5, 8.0, 1.1, "arm"), (10.5, 8.0, 12.0, 10.0, 1.1, "arm"),
    ],
    "face": (20, 25),
    # R=Gewand K=Kamm H=Kopf E=Auge A=Arm
    "small_map": [
        "....RRRRR....",
        "...RHHHHHR...",
        "..RHHHKHHHR..",
        "..HHHHKHHHH..",
        "..HHHHHHHHH..",
        ".AHEEHHHEEHA.",
        ".A.HHHHHHH.A.",
        ".A..RRRRR..A.",
        ".A..RRRRR..A.",
        "....RR.RR....",
    ],
    "mat": {"R": "robe", "K": "crest", "H": "head", "E": "eye", "A": "arm"},
    "group": {"R": "b", "K": "h", "H": "h", "E": "e", "A": "a"},
}

# --- Ormok: massig, braunes Fell, Helmplatte, Hauer, große Pranken ---------------------------
SPECIES["ormok"] = {
    "colors": {
        "fur": ("#D9A867", "#B07A3C", "#7F4C1E"),
        "fist": ("#B07A3C", "#7F4C1E", "#5E3614"),
        "plate": ("#A9B0BB", "#747D8A", "#424A56"),
        "face": ("#B07A3C", "#7F4C1E", "#3A2009"),
        "eye": ("#FAC775", "#EF9F27", "#854F0B"),
        "tusk": ("#FFFFFF", "#E6EAF0", "#A9B0BB"),
        "boot": ("#424A56", "#2A2F3A", "#1A1E27"),
    },
    "parts": [
        ("ell", -5.0, 10.5, 3.2, 2.6, "boot"),
        ("ell", 5.0, 10.5, 3.2, 2.6, "boot"),
        ("ell", -14.5, 1.0, 4.2, 6.5, "fur"),
        ("ell", 14.5, 1.0, 4.2, 6.5, "fur"),
        ("ell", -14.5, 8.5, 3.6, 3.2, "fist"),
        ("ell", 14.5, 8.5, 3.6, 3.2, "fist"),
        ("ell", 0, 0.0, 14.0, 10.0, "fur"),
        ("rect", 0, -3.0, 6.5, 4.6, "plate", 1.5),
        ("ell", 0, 5.0, 5.4, 3.6, "face"),
        ("ell", -2.4, 4.0, 1.0, 0.9, "eye"),
        ("ell", 2.4, 4.0, 1.0, 0.9, "eye"),
        ("rect", -2.6, 8.2, 0.7, 1.8, "tusk", 0.3),
        ("rect", 2.6, 8.2, 0.7, 1.8, "tusk", 0.3),
    ],
    "lines": [],
    "face": (20, 28),
    # F=Fell P=Pranke M=Helmplatte G=Gesicht E=Auge T=Hauer
    "small_map": [
        "...FFFFFFF...",
        ".FFFFFFFFFFF.",
        "FFFFMMMMMFFFF",
        "FFFFMMMMMFFFF",
        "FFFFMMMMMFFFF",
        "FFFFGGGGGFFFF",
        "FFFGEGGGEGFFF",
        "PP.FGTGTGF.PP",
        "PP...G.G...PP",
    ],
    "mat": {"F": "fur", "P": "fist", "M": "plate", "G": "face", "E": "eye", "T": "tusk"},
    "group": {"F": "b", "P": "p", "M": "m", "G": "g", "E": "g", "T": "t"},
}

# --- Petrani: Steinkörper, Kristalle auf den Schultern, glühende Rune ----------------------
SPECIES["petrani"] = {
    "colors": {
        "stone": ("#A9B0BB", "#747D8A", "#424A56"),
        "head": ("#C4CAD3", "#8E97A4", "#5A6370"),
        "crystal": ("#FFFFFF", "#9FE1CB", "#5DCAA5"),
        "crystal2": ("#FFFFFF", "#CECBF6", "#A6A0EA"),
        "rune": ("#FDE6BF", "#EF9F27", "#854F0B"),
        "eye": ("#F7C1C1", "#F0997B", "#D85A30"),
        "leg": ("#5A6370", "#2A2F3A", "#1A1E27"),
    },
    "parts": [
        ("rect", -6.0, 9.6, 3.0, 2.6, "leg", 1.0),
        ("rect", 6.0, 9.6, 3.0, 2.6, "leg", 1.0),
        ("rect", -14.5, 6.0, 3.0, 4.2, "stone", 1.2),
        ("rect", 14.5, 6.0, 3.0, 4.2, "stone", 1.2),
        ("rect", 0, 1.0, 13.0, 8.4, "stone", 2.5),
        ("rect", -11.0, -8.0, 1.4, 4.0, "crystal", 0.5),
        ("rect", -8.0, -9.5, 1.2, 3.4, "crystal", 0.5),
        ("rect", 11.0, -8.0, 1.4, 4.0, "crystal2", 0.5),
        ("rect", 8.0, -9.5, 1.2, 3.4, "crystal2", 0.5),
        ("rect", 0, -4.0, 5.0, 4.0, "head", 1.5),
        ("rect", -2.0, -2.0, 1.0, 0.8, "eye", 0.3),
        ("rect", 2.0, -2.0, 1.0, 0.8, "eye", 0.3),
        ("ell", 0, 5.0, 3.6, 2.6, "rune"),
        ("rect", 0, -11.0, 0.7, 1.6, "crystal", 0.3),
    ],
    "lines": [],
    "glow": (0, 5.0, 1.0),
    "face": (20, 22),
    # X=Kristall Y=Kristall violett S=Stein H=Kopf E=Auge O=Rune B=Bein
    "small_map": [
        ".X.........Y.",
        ".XX.......YY.",
        "..SSSHHHSSS..",
        ".SSSHHHHHSSS.",
        "SSSSHEHEHSSSS",
        "SSSSSSSSSSSSS",
        "SSSSSOOOSSSSS",
        "SS.SSSOSSS.SS",
        "...BB...BB...",
    ],
    "mat": {"X": "crystal", "Y": "crystal2", "S": "stone", "H": "head", "E": "eye", "O": "rune", "B": "leg"},
    "group": {"X": "x", "Y": "y", "S": "b", "H": "h", "E": "h", "O": "o", "B": "f"},
}

SIZE = (40, 44)
CENTER = (19.5, 20.5)
SHADOW = 2


def build_svg(species, direction):
    sp = SPECIES[species]
    colors = sp["colors"]
    W, H = SIZE
    CX, CY = CENTER
    rot = CH.ROT[direction]
    swap = direction in ("links", "rechts")
    defs, body = [], []
    for ln in sp.get("lines", []):
        x1, y1, x2, y2, width, col = ln
        a, b = rot(x1, y1), rot(x2, y2)
        body.append(f'<line x1="{CX + a[0]}" y1="{CY + a[1]}" x2="{CX + b[0]}" y2="{CY + b[1]}" '
                    f'stroke="{colors[col][1]}" stroke-width="{width}" stroke-linecap="round"/>')
    for i, p in enumerate(sp["parts"]):
        kind, x, y, rx, ry, col = p[:6]
        r = p[6] if len(p) > 6 else 0.0
        wx, wy = rot(x, y)
        if swap:
            rx, ry = ry, rx
        g, e = _shape(i, kind, CX + wx, CY + wy, rx, ry, colors[col], r)
        defs.append(g)
        body.append(e)
    if sp.get("glow"):
        gx, gy, gr = sp["glow"]
        wx, wy = rot(gx, gy)
        body.append(f'<circle cx="{CX + wx}" cy="{CY + wy}" r="{gr + 1.1}" fill="#FFFFFF" fill-opacity="0.35"/>')
        body.append(f'<circle cx="{CX + wx}" cy="{CY + wy}" r="{gr}" fill="#FFFFFF"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<defs>{"".join(defs)}</defs>{"".join(body)}</svg>')


def _shape(i, kind, cx, cy, rx, ry, tones, r=0.0):
    lt, md, dk = tones
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


def build_svg_small(species, direction):
    """Wie crew_human.build_svg_small: Materialkarte drehen, Kanten oben/links hell, unten/rechts dunkel."""
    sp = SPECIES[species]
    rows = CH._rotate(sp["small_map"], CH._ROT90[direction])
    h, w = len(rows), len(rows[0])
    assert w <= 13 and h <= 13, species
    SW, SH = CH.SMALL_SIZE
    ox, oy = (SW - 1 - w) // 2, (SH - 1 - h) // 2
    group = dict(sp["group"], **{".": "."})
    at = lambda x, y: group[rows[y][x]] if 0 <= y < h and 0 <= x < w else "."
    rects = []
    for y in range(h):
        for x in range(w):
            ch = rows[y][x]
            if ch == ".":
                continue
            lt, md, dk = sp["colors"][sp["mat"][ch]]
            g = group[ch]
            score = (at(x, y - 1) != g) + (at(x - 1, y) != g) - (at(x, y + 1) != g) - (at(x + 1, y) != g)
            col = lt if score > 0 else dk if score < 0 else md
            rects.append(f'<rect x="{ox + x}" y="{oy + y}" width="1" height="1" fill="{col}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SW}" height="{SH}" viewBox="0 0 {SW} {SH}">'
            f'{"".join(rects)}</svg>')
