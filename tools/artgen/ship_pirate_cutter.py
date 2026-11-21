"""Piratenkutter: kleines Gegnerschiff für den Kampf-Prototyp, Bug nach links (zum Spieler).

Keilförmiger Rumpf mit Kanzel vorn, zwei Raumreihen und einem breiten Triebwerksblock am Heck.
Rostrote Lackierung statt Blau, damit Freund und Feind sofort unterscheidbar sind.
"""
from icons import icon_svg
from shapely.geometry import box, Polygon
from shapely.ops import unary_union

W, H = 116, 80
T = 14
X0, Y0 = 18, 12            # Rasterursprung
M = 6                      # Rumpfrand um die Räume
GW, GH = 6, 4              # Raster in Kacheln
CY = Y0 + GH * T / 2       # Mittellinie

ROOMS = [  # (Name, Spalte, Zeile) in Kacheln, je 2x2
    ("Cockpit", 0, 1), ("Waffen", 2, 0), ("Schilde", 2, 2), ("Antrieb", 4, 0), ("Reaktor", 4, 2),
]
DOORS = [  # (x, y, vertikal?) Wandmitte in Kacheln
    (2, 1.5, True), (2, 2.5, True), (3.5, 2, False), (4, 0.5, True), (4, 3.5, True), (5.5, 2, False),
]


def px(c, r):
    return X0 + c * T, Y0 + r * T


def poly_path(g):
    geoms = getattr(g, "geoms", [g])
    d = []
    for p in geoms:
        for ring in [p.exterior] + list(p.interiors):
            d.append("M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in ring.coords) + " Z")
    return " ".join(d)


# ---------- Rumpfgeometrie ----------
gx2, gy2 = X0 + GW * T, Y0 + GH * T
body = box(X0 + 2 * T - M, Y0 - M, gx2 + M, gy2 + M).buffer(2, join_style=2)
nose = Polygon([(3, CY), (X0 - 2, Y0 + T - 8), (X0 + 2 * T + 2, Y0 + T - M - 2),
                (X0 + 2 * T + 2, Y0 + 3 * T + M + 2), (X0 - 2, Y0 + 3 * T + 8)])
engine = box(gx2 + M - 2, Y0 + 4, gx2 + M + 6, gy2 - 4)
fins = [Polygon([(X0 + 3 * T, Y0 - M), (X0 + 5 * T, Y0 - M), (X0 + 6 * T + 4, Y0 - M - 5), (X0 + 4 * T, Y0 - M - 5)]),
        Polygon([(X0 + 3 * T, gy2 + M), (X0 + 5 * T, gy2 + M), (X0 + 6 * T + 4, gy2 + M + 5), (X0 + 4 * T, gy2 + M + 5)])]
hull = unary_union([body, nose, engine] + fins)
from shapely import affinity
rim_light = hull.difference(affinity.translate(hull, 1.6, 1.6))
rim_dark = hull.difference(affinity.translate(hull, -1.6, -1.6))


def build_svg():
    s = []
    defs = [
        '<linearGradient id="hullG" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="110" y2="80">'
        '<stop offset="0" stop-color="#A9B0BB"/><stop offset="0.5" stop-color="#747D8A"/>'
        '<stop offset="1" stop-color="#424A56"/></linearGradient>',
        '<linearGradient id="glass" gradientUnits="userSpaceOnUse" x1="4" y1="30" x2="20" y2="52">'
        '<stop offset="0" stop-color="#F7C1C1"/><stop offset="0.4" stop-color="#E24B4A"/>'
        '<stop offset="1" stop-color="#5A1E1E"/></linearGradient>',
    ]
    # Abgasfahnen hinter dem Rumpf
    for oy in (-9, 0, 9):
        y = CY + oy
        s.append(f'<rect x="{gx2 + M + 6}" y="{y - 3}" width="5" height="6" fill="#D85A30" fill-opacity="0.6"/>')
        s.append(f'<rect x="{gx2 + M + 6}" y="{y - 2}" width="3" height="4" fill="#FAC775"/>')
    s.append(f'<path d="{poly_path(hull)}" fill="url(#hullG)"/>')
    s.append(f'<path d="{poly_path(rim_light)}" fill="#C4CAD3"/>')
    s.append(f'<path d="{poly_path(rim_dark)}" fill="#2A2F3A"/>')
    # Rostrote Warnstreifen auf Rumpf und Finnen
    for x in range(X0 + 2 * T, gx2 + M - 4, 8):
        s.append(f'<path d="M{x},{Y0 - M + 1} l4,0 l-3,4 l-4,0 Z" fill="#D85A30"/>')
        s.append(f'<path d="M{x},{gy2 + M - 1} l4,0 l-3,-4 l-4,0 Z" fill="#993C1D"/>')
    for f in fins:
        s.append(f'<path d="{poly_path(f.buffer(-1.2))}" fill="#993C1D"/>')
    # Plattenfugen auf der Nase
    s.append(f'<line x1="{X0 - 2}" y1="{Y0 + T - 7.5}" x2="{X0 + 2 * T}" y2="{Y0 + T - 7.5}" stroke="#424A56"/>')
    s.append(f'<line x1="{X0 - 2}" y1="{Y0 + 3 * T + 7.5}" x2="{X0 + 2 * T}" y2="{Y0 + 3 * T + 7.5}" stroke="#424A56"/>')
    # Kanzel an der Spitze
    canopy = Polygon([(6, CY), (X0 - 2, CY - 7), (X0 + 1, CY - 7), (X0 + 1, CY + 7), (X0 - 2, CY + 7)])
    s.append(f'<path d="{poly_path(canopy)}" fill="url(#glass)"/>')
    s.append(f'<path d="M{X0 - 6},{CY - 4} L{X0 - 1},{CY - 5}" stroke="#FBE3EB" stroke-width="1"/>')
    # Kanone unter der Nase
    s.append(f'<rect x="{X0 - 10}" y="{gy2 - 3}" width="{2 * T + 8}" height="3" fill="#2A2F3A"/>')
    s.append(f'<rect x="{X0 - 10}" y="{gy2 - 3}" width="{2 * T + 8}" height="1" fill="#8E97A4"/>')
    # Triebwerksdüsen
    for oy in (-9, 0, 9):
        y = CY + oy
        s.append(f'<rect x="{gx2 + M + 2}" y="{y - 3}" width="5" height="6" fill="#2A2F3A"/>')
        s.append(f'<rect x="{gx2 + M + 5}" y="{y - 2}" width="2" height="4" fill="#FDE6BF"/>')
    # --- Innenräume ---
    for name, c, r in ROOMS:
        x, y = px(c, r)
        for i in range(2):
            for j in range(2):
                f = "#2B3249" if (i + j) % 2 == 0 else "#20263A"
                s.append(f'<rect x="{x + i * T}" y="{y + j * T}" width="{T}" height="{T}" fill="{f}"/>')
        s.append(f'<path d="M{x},{y + T + .5} H{x + 2 * T} M{x + T + .5},{y} V{y + 2 * T}" stroke="#161B2B" stroke-width="1"/>')
        s.append(icon_svg(name, x + 8, y + 8))
    for _, c, r in ROOMS:
        x, y = px(c, r)
        s.append(f'<rect x="{x}" y="{y}" width="{2 * T}" height="{2 * T}" fill="none" stroke="#0A0B16" stroke-width="2"/>')
    for dc, dr, vert in DOORS:
        x, y = X0 + dc * T, Y0 + dr * T
        if vert:
            s.append(f'<rect x="{x - 1}" y="{y - 3}" width="2" height="6" fill="#A9B0BB"/>')
        else:
            s.append(f'<rect x="{x - 3}" y="{y - 1}" width="6" height="2" fill="#A9B0BB"/>')
    # Positionsleuchten: rot oben, grün unten
    for (lx, ly, core, glow) in [(X0 + 5 * T, Y0 - M - 4, "#F7C1C1", "#E24B4A"),
                                 (X0 + 5 * T, gy2 + M + 3, "#E4F0D0", "#639922")]:
        s.append(f'<rect x="{lx - 1}" y="{ly}" width="4" height="2" fill="{glow}"/>'
                 f'<rect x="{lx}" y="{ly}" width="2" height="2" fill="{core}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<defs>{"".join(defs)}</defs>{"".join(s)}</svg>')
