"""UI-Stilprobe Kampf-HUD für Handy-Querformat 2400×1080 (20:9).

Logisches Raster 600×270, Pixelfaktor 4. Alle Farben aus der festen Palette.
Aufruf:  python3 tools/artgen/ui_kampf.py   (nach build.py, nutzt art/export/1x)
Ausgabe: art/ui/kampf_hud_600x270.png, art/ui/kampf_hud_2400x1080.png, art/ui/kampf_hud_raster_2400x1080.png
"""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw
import pipeline as P
import pixelfont as F
import ship_human_freighter as FR
import ship_hunter as SH
from icons import ICONS, ROOM_COLORS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "art")
OUT = os.path.join(ART, "ui")

W, H, SCALE = 600, 270, 4
SAFE_X, SAFE_TOP, SAFE_BOTTOM = 24, 4, 6          # Kamera-Aussparung links/rechts, Gestenleiste unten
TOUCH = 32                                         # 32 logische px = 128 px ≈ 48 dp bei 2,625 px/dp
R = P.hex2rgb

# ---------- Farbrollen (alle aus der Palette) ----------
SPACE = R(P.SPACE)
OUTL = R("#0A0B16")
PANEL = R("#161B2B")
PANEL_HI = R("#363E58")
PANEL_LO = R("#0A0B16")
BTN = R("#20263A")
BTN_HI = R("#424A56")
EMPTY = R("#20263A")
TXT = R("#E6EAF0")
LABEL = R("#8E97A4")
DIM = R("#5A6370")
ACCENT = R("#FAC775")          # Auswahl, bereit, Ziel
ACCENT_BG = R("#4F2E05")
GREEN, GREEN_HI = R("#639922"), R("#C0DD97")
ORANGE, ORANGE_HI = R("#EF9F27"), R("#FDE6BF")
RED, RED_HI = R("#E24B4A"), R("#F7C1C1")
BLUE, BLUE_HI, BLUE_LO = R("#378ADD"), R("#85B7EB"), R("#185FA5")
TIP_BG, TIP_EDGE = R("#0A0B16"), R("#85B7EB")

HITS = []        # (x, y, w, h, Name) – tippbare Flächen für das Raster-Overlay


def hit(x, y, w, h, name):
    HITS.append((x, y, w, h, name))


# ---------- Grundformen ----------
def rect(d, x, y, w, h, c):
    if w > 0 and h > 0:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def panel(d, x, y, w, h, fill=PANEL, edge=OUTL, hi=PANEL_HI, lo=PANEL_LO):
    """Fläche mit 1-px-Rand, abgeschnittenen Eckpixeln und Lichtkante oben links."""
    rect(d, x + 1, y + 1, w - 2, h - 2, fill)
    rect(d, x + 1, y, w - 2, 1, edge); rect(d, x + 1, y + h - 1, w - 2, 1, edge)
    rect(d, x, y + 1, 1, h - 2, edge); rect(d, x + w - 1, y + 1, 1, h - 2, edge)
    rect(d, x + 1, y + 1, w - 2, 1, hi); rect(d, x + 1, y + 1, 1, h - 2, hi)
    rect(d, x + 2, y + h - 2, w - 3, 1, lo); rect(d, x + w - 2, y + 2, 1, h - 3, lo)


def button(d, x, y, w, h, state="normal"):
    if state == "active":
        panel(d, x, y, w, h, fill=ACCENT_BG, edge=ACCENT, hi=R("#854F0B"), lo=OUTL)
    elif state == "off":
        panel(d, x, y, w, h, fill=R("#161B2B"), edge=OUTL, hi=R("#20263A"), lo=OUTL)
    else:
        panel(d, x, y, w, h, fill=BTN, edge=OUTL, hi=BTN_HI, lo=OUTL)


def text(img, x, y, s, c=TXT, shadow=OUTL):
    return F.draw(img, x, y, s, c, shadow)


def text_c(img, cx, y, s, c=TXT, shadow=OUTL):
    F.draw(img, cx - F.width(s) // 2, y, s, c, shadow)


def bar(d, x, y, w, h, frac, c, c_hi, back=EMPTY):
    rect(d, x, y, w, h, OUTL)
    rect(d, x + 1, y + 1, w - 2, h - 2, back)
    fw = round((w - 2) * frac)
    rect(d, x + 1, y + 1, fw, h - 2, c)
    rect(d, x + 1, y + 1, fw, 1, c_hi)


def stamp(img, rows, x, y, cols, shadow=OUTL):
    """Pixelmaske stempeln. cols: Zeichen -> Farbe. Schattenkante 1 px unten rechts."""
    px = img.load()
    if shadow:
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch in cols:
                    px[x + dx + 1, y + dy + 1] = shadow
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch in cols:
                px[x + dx, y + dy] = cols[ch]


def room_icon(img, name, x, y, dim=False):
    base, light = ROOM_COLORS[name]
    if dim:
        base, light = "#5A6370", "#747D8A"
    stamp(img, ICONS[name], x, y, {"X": R(base), "o": R(light)})


# ---------- Ressourcen-Symbole 10×10 (X Grundton, o Licht, d Schatten) ----------
RES_ICONS = {
    "Treibstoff": (["....XXX...", "...X...X..", ".XXXXXXXX.", ".XooXXXXd.", ".XoXXXXXd.",
                    ".XXXXXXXd.", ".XXXXXXXd.", ".XXXXXXXd.", ".XXXXXXdd.", "..dddddd.."],
                   ("#EF9F27", "#FDE6BF", "#854F0B")),
    "Rohstoffe": (["..........", "....oo....", "...oXXd...", "..oXXXXd..", ".oXXXXXXd.",
                   ".oXXXXXXd.", "oXXXXXXXdd", ".XXXXXXdd.", "..dddddd..", ".........."],
                  ("#B07A3C", "#D9A867", "#5E3614")),
    "Raketen": (["........oo", ".......oXX", "......oXXd", ".....oXXd.", "....oXXd..",
                 "...oXXd...", ".ooXXd....", ".XXXd.....", "XXd.......", "Xd........"],
                ("#E24B4A", "#F7C1C1", "#A32D2D")),
    "Drohnenteile": ([".oo....oo.", "oXXd..oXXd", ".ddXooXdd.", "...oXXd...", "...XXXd...",
                      "...XXXd...", ".ooXddXoo.", "oXXd..oXXd", ".dd....dd.", ".........."],
                     ("#5DCAA5", "#DDF5EC", "#0F6E56")),
}


def res_icon(img, name, x, y):
    rows, (b, l, dk) = RES_ICONS[name]
    stamp(img, rows, x, y, {"X": R(b), "o": R(l), "d": R(dk)})


SHIELD_PIP = [".XXXXX.", "XXXXXXX", "XXXXXXX", "XXXXXXX", "XXXXXXX", "XXXXXXX", ".XXXXX."]


def shield_pip(img, d, x, y, frac):
    """Schildbarriere: gefüllt von unten nach oben (frac 0..1)."""
    px = img.load()
    for dy, row in enumerate(SHIELD_PIP):
        for dx, ch in enumerate(row):
            if ch != "X":
                continue
            edge = dy in (0, 6) or dx in (0, 6) or (dy in (1, 5) and dx in (1, 5) and row[dx - 1] == ".")
            filled = (6 - dy) / 6 <= frac - 1e-6 or frac >= 1
            if edge:
                c = BLUE_HI if frac >= 1 else R("#363E58")
            elif filled:
                c = BLUE_HI if dy == 1 else (BLUE if dy < 5 else BLUE_LO)
            else:
                c = EMPTY
            px[x + dx, y + dy] = c


# ---------- Hintergrund ----------
def background(img):
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    for _ in range(170):
        x, y = rnd.randrange(W), rnd.randrange(H)
        img.putpixel((x, y), R(rnd.choice(["#2A2F3A", "#424A56", "#5A6370", "#5A6370", "#8E97A4", "#363E58"])))
    for _ in range(14):
        x, y = rnd.randrange(2, W - 2), rnd.randrange(2, H - 2)
        img.putpixel((x, y), R("#E6EAF0"))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            img.putpixel((x + dx, y + dy), R("#424A56"))
    # Planet unten rechts, Licht oben links, geordnetes 2×2-Dithering zwischen den Stufen
    ramp = [R(h) for h in ("#1A1E27", "#3A2009", "#5E3614", "#7F4C1E", "#B07A3C")]
    cx, cy, r = 520, 252, 84
    bayer = [[0.0, 0.5], [0.75, 0.25]]
    lx, ly, lz = -0.62, -0.55, 0.56
    for y in range(cy - r, min(H, cy + r)):
        for x in range(max(0, cx - r), min(W, cx + r)):
            nx, ny = (x - cx) / r, (y - cy) / r
            q = nx * nx + ny * ny
            if q > 1:
                continue
            nz = math.sqrt(1 - q)
            l = max(0.0, nx * lx + ny * ly + nz * lz)
            l += 0.06 * math.sin(ny * 11 + nx * 2)                 # Wolkenbänder
            v = l * (len(ramp) - 1) + bayer[y % 2][x % 2] - 0.5
            img.putpixel((x, y), ramp[max(0, min(len(ramp) - 1, round(v)))])
    return d


def ellipse_ring(img, cx, cy, rx, ry, c, c_hi, inner=None):
    """Schildblase: 1-px-Ring, oben links heller; gepunkteter Innenring statt Wabenmuster."""
    pts = set()
    n = int(2 * math.pi * max(rx, ry) * 2)
    for i in range(n):
        a = 2 * math.pi * i / n
        pts.add((round(cx + rx * math.cos(a)), round(cy + ry * math.sin(a)), a))
    for x, y, a in pts:
        if 0 <= x < W and 0 <= y < H:
            lit = math.cos(a - math.radians(225)) > 0.55
            img.putpixel((x, y), c_hi if lit else c)
    if inner:
        for i in range(0, n, 6):
            a = 2 * math.pi * i / n
            x, y = round(cx + (rx - 3) * math.cos(a)), round(cy + (ry - 3) * math.sin(a))
            if 0 <= x < W and 0 <= y < H:
                img.putpixel((x, y), inner)


def outline_recolor(sprite, color):
    """Auswahlzustand: dunkle Kontur durch Akzentfarbe ersetzen."""
    s = sprite.copy()
    px = s.load()
    for y in range(s.height):
        for x in range(s.width):
            p = px[x, y]
            if p[3] == 255 and p[:3] == OUTL:
                px[x, y] = color + (255,)
    return s


def reticle(d, x, y, size, c):
    """Zielmarkierung: vier Eckwinkel um einen Raum."""
    x1, y1, x2, y2 = x - 2, y - 2, x + size + 1, y + size + 1
    L = 6
    for (ax, ay, sx, sy) in ((x1, y1, 1, 1), (x2, y1, -1, 1), (x1, y2, 1, -1), (x2, y2, -1, -1)):
        for k in range(L):
            d.point((ax + sx * k, ay), c); d.point((ax, ay + sy * k), c)


# ---------- Szene ----------
CREW = [  # Name, Raum-Kachel (Spalte, Zeile) im Frachter, Blickrichtung, Gesundheit
    ("Rhea", (10, 3), "rechts", 1.0),
    ("Mara", (6, 1), "oben", 0.85),
    ("Jonas", (7, 7), "rechts", 0.9),
    ("Ilka", (1, 0), "unten", 0.35),
]
SELECTED_CREW = "Mara"

OX, OY = 62, 50            # Frachter (280×140)
EX, EY = 384, 72           # Jäger (176×112)


def load(rel):
    return Image.open(os.path.join(ART, "export", "1x", rel)).convert("RGBA")


def draw_hud():
    img = Image.new("RGB", (W, H), SPACE)
    d = background(img)
    crew_small = {dname: load(f"crew/mensch_klein_{dname}.png") for dname in ("unten", "oben", "links", "rechts")}
    ship = load("ships/mensch_frachter.png")
    hunter = P.process(SH.build_svg(), SH.W, SH.H, 3)

    # --- Schiffe und Schildblasen ---
    ellipse_ring(img, OX + 154, OY + 70, 128, 77, BLUE, BLUE_HI, inner=BLUE_LO)
    ellipse_ring(img, EX + 93, EY + 56, 92, 60, BLUE_LO, BLUE)
    canvas = img.convert("RGBA")
    canvas.alpha_composite(ship, (OX, OY))
    canvas.alpha_composite(hunter, (EX, EY))
    for name, (c, r), facing, hp in CREW:
        spr = crew_small[facing]
        if name == SELECTED_CREW:
            spr = outline_recolor(spr, ACCENT)
        canvas.alpha_composite(spr, (OX + FR.X0 + c * FR.T - 1, OY + FR.Y0 + r * FR.T - 1))
    img = canvas.convert("RGB")
    d = ImageDraw.Draw(img)
    for name, (c, r), facing, hp in CREW:      # Lebensbalken über verletzten/ausgewählten Figuren
        if hp < 1 and (hp < 0.5 or name == SELECTED_CREW):
            x, y = OX + FR.X0 + c * FR.T, OY + FR.Y0 + r * FR.T - 3
            rect(d, x, y, 14, 1, EMPTY)
            rect(d, x, y, round(14 * hp), 1, GREEN if hp > 0.6 else (ORANGE if hp > 0.3 else RED))
    for name, c, r in FR.ROOMS:                 # Räume des eigenen Schiffs: knapp unter 48 dp
        hit(OX + FR.X0 + c * FR.T, OY + FR.Y0 + r * FR.T, 2 * FR.T, 2 * FR.T, "Raum")
    for name, c, r in SH.ROOMS:
        hit(EX + SH.X0 + c * SH.T, EY + SH.Y0 + r * SH.T, 2 * SH.T, 2 * SH.T, "Raum")
    # Ziel: Waffe 1 auf den Waffenraum des Jägers
    tx, ty = EX + SH.X0 + 2 * SH.T, EY + SH.Y0
    reticle(d, tx, ty, 2 * SH.T, ACCENT)
    panel(d, tx + 2 * SH.T - 4, ty - 9, 9, 11, fill=ACCENT_BG, edge=ACCENT, hi=R("#854F0B"))
    text(img, tx + 2 * SH.T - 2, ty - 7, "1", ACCENT, None)

    # --- Oben links: Hülle und Schilde ---
    x, y, w, h = SAFE_X, SAFE_TOP, 162, 32
    panel(d, x, y, w, h)
    text(img, x + 5, y + 4, "HÜLLE", LABEL)
    hull, hull_max = 22, 30
    text(img, x + w - 5 - F.width(f"{hull}/{hull_max}"), y + 4, f"{hull}/{hull_max}", TXT)
    seg_c = (GREEN, GREEN_HI) if hull > 15 else ((ORANGE, ORANGE_HI) if hull > 7 else (RED, RED_HI))
    for i in range(hull_max):
        sx = x + 5 + i * 5
        rect(d, sx, y + 13, 4, 6, OUTL)
        if i < hull:
            rect(d, sx, y + 13, 4, 6, seg_c[0]); rect(d, sx, y + 13, 4, 1, seg_c[1])
        else:
            rect(d, sx, y + 13, 4, 6, EMPTY)
    for i, frac in enumerate((1, 1, 0.45, 0)):
        shield_pip(img, d, x + 5 + i * 10, y + 22, frac)
    text(img, x + 46, y + 22, "SCHILDE 2/4", BLUE_HI)
    hit(x, y, w, h, "Hülle/Schilde (Halten: Info)")

    # --- Sauerstoff und Ausweichen ---
    x = SAFE_X + 166
    panel(d, x, y, 48, h)
    room_icon(img, "Lebenserhaltung", x + 4, y + 3)
    text(img, x + 19, y + 6, "100%", R("#D3E6F8"))
    room_icon(img, "Antrieb", x + 4, y + 17)
    text(img, x + 19, y + 20, "18%", R("#F9C9B6"))
    hit(x, y, 48, h, "O2/Ausweichen")

    # --- Oben Mitte: Ressourcen ---
    x = SAFE_X + 218
    panel(d, x, y, 158, h)
    for i, (name, val) in enumerate((("Treibstoff", "12"), ("Rohstoffe", "34"), ("Raketen", "8"), ("Drohnenteile", "3"))):
        cx = x + 5 + i * 38
        res_icon(img, name, cx, y + 11)
        text(img, cx + 14, y + 12, val)
        hit(x + 1 + i * 39, y, 39, h, name)

    # --- Oben rechts: Sprung, Karte, Pause ---
    rx = W - SAFE_X
    button(d, rx - 32, y, 32, h)                                    # Pause
    rect(d, rx - 22, y + 9, 4, 14, TXT); rect(d, rx - 14, y + 9, 4, 14, TXT)
    rect(d, rx - 18, y + 10, 1, 13, OUTL); rect(d, rx - 10, y + 10, 1, 13, OUTL)
    hit(rx - 32, y, 32, h, "Pause")
    button(d, rx - 70, y, 34, h)                                    # Karte
    text_c(img, rx - 53, y + 12, "KARTE")
    hit(rx - 70, y, 34, h, "Karte")
    button(d, rx - 140, y, 66, h)                                   # Sprung (lädt)
    text_c(img, rx - 107, y + 6, "SPRUNG", ORANGE_HI)
    bar(d, rx - 134, y + 19, 54, 6, 0.62, ORANGE, ORANGE_HI)
    hit(rx - 140, y, 66, h, "Sprung")

    # --- Auto-Pause-Hinweis ---
    msg = "PAUSE · Ziel für Laser wählen"
    mw = F.width(msg) + 12
    mx = 312 - mw // 2
    panel(d, mx, 40, mw, 13, fill=ACCENT_BG, edge=ACCENT, hi=R("#854F0B"))
    text(img, mx + 6, 43, msg, ACCENT)

    # --- Gegner-Status ---
    x, y2, w = W - SAFE_X - 150, 58, 150
    panel(d, x, y2, w, 24, edge=R("#5E1919"), hi=R("#363E58"))
    text(img, x + 5, y2 + 4, "JÄGER · Abfangjäger", RED_HI)
    for i in range(12):
        sx = x + 5 + i * 5
        rect(d, sx, y2 + 15, 4, 5, RED if i < 9 else EMPTY)
        if i < 9:
            rect(d, sx, y2 + 15, 4, 1, RED_HI)
    for i, frac in enumerate((1, 0)):
        shield_pip(img, d, x + 70 + i * 10, y2 + 14, frac)
    text(img, x + w - 5 - F.width("9/12"), y2 + 14, "9/12", TXT)

    # --- Links: Crew-Liste ---
    for i, (name, _, _, hp) in enumerate(CREW):
        cx, cy = SAFE_X, 40 + i * TOUCH
        sel = name == SELECTED_CREW
        if sel:
            panel(d, cx, cy, 56, 30, fill=ACCENT_BG, edge=ACCENT, hi=R("#854F0B"))
        else:
            panel(d, cx, cy, 56, 30)
        rect(d, cx + 3, cy + 6, 18, 18, OUTL)
        rect(d, cx + 4, cy + 7, 16, 16, R("#20263A"))
        spr = crew_small["unten"].copy()
        tmp = img.crop((cx + 4, cy + 7, cx + 20, cy + 23)).convert("RGBA")
        tmp.alpha_composite(spr)
        img.paste(tmp.convert("RGB"), (cx + 4, cy + 7))
        text(img, cx + 24, cy + 5, name, ACCENT if sel else TXT)
        hc = (GREEN, GREEN_HI) if hp > 0.6 else ((ORANGE, ORANGE_HI) if hp > 0.3 else (RED, RED_HI))
        bar(d, cx + 24, cy + 18, 28, 5, hp, *hc)
        hit(cx, cy, 56, TOUCH, "Crew")

    # --- Unten links: Reaktor und Energiesäulen ---
    by, bh = H - SAFE_BOTTOM - 66, 66
    x = SAFE_X
    panel(d, x, by, 192, bh)
    reactor, free = 8, 2
    for i in range(reactor):
        sy = by + bh - 26 - (i + 1) * 4
        c, chi = (GREEN, GREEN_HI) if i < free else (EMPTY, EMPTY)
        rect(d, x + 7, sy, 10, 3, c); rect(d, x + 7, sy, 10, 1, chi)
    plaque(img, d, x + 2, by + bh - 24, "Reaktor", True)
    text_c(img, x + 12, by + 4, f"{free}", GREEN_HI)
    systems = [("Schilde", 2, 4, "Mara"), ("Antrieb", 1, 3, "Ilka"), ("Waffen", 2, 4, "Jonas"),
               ("Medbay", 0, 1, None), ("Lebenserhaltung", 1, 1, None)]
    for k, (name, on, mx_, crew) in enumerate(systems):
        cx = x + 28 + k * 32
        for j in range(mx_):
            sy = by + bh - 30 - j * 6
            if j < on:
                rect(d, cx + 5, sy, 20, 5, OUTL); rect(d, cx + 5, sy, 20, 4, GREEN); rect(d, cx + 5, sy, 20, 1, GREEN_HI)
            else:
                rect(d, cx + 5, sy, 20, 5, OUTL); rect(d, cx + 6, sy + 1, 18, 3, EMPTY)
        plaque(img, d, cx + 5, by + bh - 24, name, on > 0)
        if crew:                       # Besetzt-Symbol mit Stufe
            stamp(img, [".X.", "XXX", "X.X"], cx + 4, by + 4, {"X": TXT})
            for s_ in range(2 if crew != "Ilka" else 1):
                d.point((cx + 9 + s_ * 2, by + 5), ACCENT)
        if name == "Waffen":
            panel(d, cx, by + 1, 30, bh - 2, fill=PANEL, edge=TIP_EDGE, hi=PANEL_HI)
            for j in range(mx_):
                sy = by + bh - 30 - j * 6
                if j < on:
                    rect(d, cx + 5, sy, 20, 5, OUTL); rect(d, cx + 5, sy, 20, 4, GREEN); rect(d, cx + 5, sy, 20, 1, GREEN_HI)
                else:
                    rect(d, cx + 5, sy, 20, 5, OUTL); rect(d, cx + 6, sy + 1, 18, 3, EMPTY)
            plaque(img, d, cx + 5, by + bh - 24, name, True)
            stamp(img, [".X.", "XXX", "X.X"], cx + 4, by + 4, {"X": TXT})
            for s_ in range(2 if crew != "Ilka" else 1):
                d.point((cx + 9 + s_ * 2, by + 5), ACCENT)
        hit(cx - 1, by, 32, bh, "System")

    # --- Unten Mitte: Waffen ---
    x = SAFE_X + 196
    panel(d, x, by, 202, bh)
    text(img, x + 5, by + 4, "WAFFEN", LABEL)
    text(img, x + 202 - 5 - F.width("2/4 Energie"), by + 4, "2/4 Energie", DIM)
    weapons = [("Laser", 1.0, "ready", 1), ("Ionen", 0.6, "load", 1), ("Rakete", 0.3, "load", 0),
               ("Strahl", 0.0, "off", 0)]
    for i, (name, ch, st, pw) in enumerate(weapons):
        wx, wy, ww, wh = x + 4 + i * 49, by + 14, 47, bh - 18
        if i == 0:
            panel(d, wx, wy, ww, wh, fill=ACCENT_BG, edge=ACCENT, hi=R("#854F0B"))
        elif st == "off":
            button(d, wx, wy, ww, wh, "off")
        else:
            button(d, wx, wy, ww, wh)
        weapon_art(img, d, wx + 8, wy + 13, name, st == "off")
        text(img, wx + 4, wy + 3, name, ACCENT if i == 0 else (DIM if st == "off" else TXT))
        if st == "off":
            text(img, wx + ww - 4 - F.width("AUS"), wy + wh - 13, "AUS", DIM)
            bar(d, wx + 4, wy + wh - 5, ww - 8, 4, 0, GREEN, GREEN_HI)
        else:
            c = (ACCENT, R("#FDE6BF")) if ch >= 1 else (GREEN, GREEN_HI)
            bar(d, wx + 4, wy + wh - 5, ww - 8, 4, ch, *c)
        if name == "Rakete":
            res_icon(img, "Raketen", wx + ww - 13, wy + 13)
        hit(wx, wy, ww, wh, "Waffe")

    # --- Unten rechts: Drohne, Türen, Schleuse ---
    x = SAFE_X + 402
    panel(d, x, by, W - SAFE_X - x, bh)
    dx_ = x + 4
    button(d, dx_, by + 4, 42, bh - 8)
    text(img, dx_ + 4, by + 7, "Abwehr", TXT)
    res_icon(img, "Drohnenteile", dx_ + 16, by + 22)
    bar(d, dx_ + 4, by + bh - 13, 34, 4, 1.0, R("#5DCAA5"), R("#DDF5EC"))
    hit(dx_, by + 4, 42, bh - 8, "Drohne")
    tx_ = dx_ + 45
    button(d, tx_, by + 4, 40, bh - 8)
    door_icon(img, d, tx_ + 13, by + 14)
    text_c(img, tx_ + 20, by + bh - 17, "TÜREN")
    hit(tx_, by + 4, 40, bh - 8, "Türen")
    sx_ = tx_ + 43
    button(d, sx_, by + 4, W - SAFE_X - 4 - sx_, bh - 8)
    airlock_icon(img, d, sx_ + 19, by + 14)
    text_c(img, sx_ + (W - SAFE_X - 4 - sx_) // 2, by + bh - 17, "SCHLEUSE", RED_HI)
    hit(sx_, by + 4, W - SAFE_X - 4 - sx_, bh - 8, "Schleuse")

    # --- Tooltip (langes Tippen auf die Waffen-Säule) ---
    tooltip(img, d, SAFE_X + 28 + 2 * 32, by)
    return img


def plaque(img, d, x, y, name, on):
    """Runde Systemplakette 20×20 mit Raumsymbol."""
    base = R(ROOM_COLORS[name][0]) if on else DIM
    d.ellipse([x, y, x + 19, y + 19], fill=OUTL)
    d.ellipse([x + 1, y + 1, x + 18, y + 18], fill=base)
    d.ellipse([x + 2, y + 2, x + 17, y + 17], fill=PANEL)
    room_icon(img, name, x + 4, y + 4, dim=not on)


def weapon_art(img, d, x, y, name, off):
    """Kleine Waffensilhouetten (Platzhalter für 48×32-Gegenstandsbilder)."""
    g1, g2, g3 = (R("#5A6370"), R("#424A56"), R("#2A2F3A")) if off else (R("#C4CAD3"), R("#8E97A4"), R("#424A56"))
    glow = DIM if off else {"Laser": RED, "Ionen": BLUE_HI, "Rakete": ORANGE, "Strahl": R("#A6A0EA")}[name]
    rect(d, x, y + 3, 10, 8, g2); rect(d, x, y + 3, 10, 1, g1); rect(d, x, y + 10, 10, 1, g3)
    if name == "Laser":
        rect(d, x + 10, y + 6, 18, 2, g1); rect(d, x + 10, y + 7, 18, 1, g3); rect(d, x + 28, y + 6, 2, 2, glow)
    elif name == "Ionen":
        rect(d, x + 10, y + 5, 14, 4, g2); rect(d, x + 10, y + 5, 14, 1, g1)
        for k in range(3):
            rect(d, x + 12 + k * 4, y + 4, 2, 6, glow)
    elif name == "Rakete":
        for k in range(2):
            rect(d, x + 10, y + 3 + k * 5, 8, 3, g1); rect(d, x + 18, y + 3 + k * 5, 2, 3, glow)
    else:
        rect(d, x + 10, y + 2, 6, 10, g2); rect(d, x + 10, y + 2, 6, 1, g1)
        rect(d, x + 16, y + 4, 3, 6, glow)
    rect(d, x + 2, y + 5, 2, 4, glow)


def door_icon(img, d, x, y):
    """Tür in Draufsicht: Wandstücke, Türflügel, Pfeile nach innen (= alle schließen)."""
    rect(d, x, y, 14, 14, OUTL)
    rect(d, x + 1, y + 1, 12, 12, R("#20263A"))
    rect(d, x + 1, y + 7, 3, 4, R("#5A6370")); rect(d, x + 10, y + 7, 3, 4, R("#5A6370"))
    rect(d, x + 4, y + 8, 6, 2, R("#E6EAF0")); rect(d, x + 6, y + 8, 2, 2, R("#A9B0BB"))
    for k in range(3):
        d.point((x + 2 + k, y + 2 + k), ACCENT); d.point((x + 2 + k, y + 6 - k), ACCENT)
        d.point((x + 11 - k, y + 2 + k), ACCENT); d.point((x + 11 - k, y + 6 - k), ACCENT)


def airlock_icon(img, d, x, y):
    rect(d, x, y, 14, 14, OUTL)
    rect(d, x + 1, y + 1, 12, 12, R("#5E1919"))
    for k in range(4):
        rect(d, x + 2 + k * 3, y + 2 + (k % 2) * 2, 2, 2, RED_HI)
    rect(d, x + 3, y + 8, 8, 2, RED); rect(d, x + 9, y + 6, 2, 6, RED)


def tooltip(img, d, col_x, bottom_y):
    lines = [("WAFFEN · Stufe 4", R("#F7C1C1")),
             ("Versorgt bis zu 4 Waffen.", TXT),
             ("Strahl hat keine Energie.", TXT),
             ("Besetzt (Jonas): +10 % Laden", GREEN_HI),
             ("Tippen +1 · Wischen ab -1", LABEL)]
    w = max(F.width(t) for t, _ in lines) + 12
    h = len(lines) * 10 + 8
    x, y = col_x - 4, bottom_y - h - 5
    rect(d, x + 2, y + 2, w, h, OUTL)                           # Schlagschatten
    panel(d, x, y, w, h, fill=TIP_BG, edge=TIP_EDGE, hi=R("#20263A"), lo=TIP_BG)
    for k in range(4):                                          # Zeiger zur Säule
        rect(d, col_x + 11 + k, y + h - 1 + k, 8 - 2 * k, 1, TIP_EDGE)
        rect(d, col_x + 12 + k, y + h - 1 + k, 6 - 2 * k, 1, TIP_BG)
    for i, (t, c) in enumerate(lines):
        text(img, x + 6, y + 5 + i * 10, t, c, None)


def snap_palette(img):
    """Halbtransparente Sprite-Schatten ergeben Mischfarben: auf die nächste Palettenfarbe ziehen."""
    import numpy as np
    pal = np.array([P.hex2rgb(h) for h in P.PALETTE_HEX] + [SPACE], dtype=np.float64)
    a = np.asarray(img, dtype=np.float64).reshape(-1, 3)
    known = (np.abs(a[:, None, :] - pal[None]).sum(-1) == 0).any(-1)
    lab_pal = P._lab(pal)
    lab = P._lab(a[~known])
    a[~known] = pal[((lab[:, None, :] - lab_pal[None]) ** 2).sum(-1).argmin(-1)]
    return Image.fromarray(a.reshape(H, W, 3).astype("uint8"))


def raster_overlay(img):
    """Prüfbild: Safe Areas und Trefferflächen (grün ≥ 48 dp, orange darunter)."""
    big = img.resize((W * SCALE, H * SCALE), Image.NEAREST).convert("RGBA")
    ov = Image.new("RGBA", big.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    s = SCALE
    for x0, x1 in ((0, SAFE_X), (W - SAFE_X, W)):
        d.rectangle([x0 * s, 0, x1 * s - 1, H * s - 1], fill=(226, 75, 74, 70))
    d.rectangle([0, (H - SAFE_BOTTOM) * s, W * s - 1, H * s - 1], fill=(226, 75, 74, 70))
    for x, y, w, h, name in HITS:
        ok = w >= TOUCH and h >= TOUCH
        c = (99, 190, 90, 255) if ok else (239, 159, 39, 255)
        d.rectangle([x * s, y * s, (x + w) * s - 1, (y + h) * s - 1], outline=c, width=3)
    return Image.alpha_composite(big, ov).convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    img = draw_hud()
    img = snap_palette(img)
    img.save(os.path.join(OUT, "kampf_hud_600x270.png"))
    img.resize((W * SCALE, H * SCALE), Image.NEAREST).save(os.path.join(OUT, "kampf_hud_2400x1080.png"))
    raster_overlay(img).save(os.path.join(OUT, "kampf_hud_raster_2400x1080.png"))
    small = [(n, w, h) for x, y, w, h, n in HITS if w < TOUCH or h < TOUCH]
    print(f"{len(HITS)} Trefferflächen, {len(small)} unter {TOUCH} px:", sorted({f'{n} {w}×{h}' for n, w, h in small}))


if __name__ == "__main__":
    main()
