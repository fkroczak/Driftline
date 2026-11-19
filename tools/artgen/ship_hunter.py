"""Jägerflotte: Abfangjäger. Kantig, dunkel mit roten Kennungen, Bug nach links (zeigt auf den Spieler).

Platzhalter-Gegner für die UI-Stilprobe; nutzt dasselbe Raumraster (14 px) wie der Frachter.
"""
from icons import icon_svg
from ship_human_freighter import poly_path
from shapely.geometry import box, Polygon
from shapely.ops import unary_union
from shapely import affinity

W, H = 176, 112
T = 14
X0, Y0 = 40, 28
M = 7
CY = Y0 + 2 * T

ROOMS = [("Cockpit", 0, 1), ("Waffen", 2, 0), ("Schilde", 2, 2),
         ("Reaktor", 4, 0), ("Lebenserhaltung", 4, 2), ("Antrieb", 6, 1)]
DOORS = [(2, 1.5, True), (2, 2.5, True), (3, 2, False), (4, 0.5, True), (4, 3.5, True),
         (5, 2, False), (6, 1.5, True), (6, 2.5, True)]
REAR = X0 + 8 * T + M


def px(c, r):
    return X0 + c * T, Y0 + r * T


body = Polygon([(12, CY), (34, CY - 18), (X0 - 2, Y0 - M), (REAR, Y0 - M), (REAR, Y0 + 4 * T + M),
                (X0 - 2, Y0 + 4 * T + M), (34, CY + 18)])
fin_top = Polygon([(X0 + 3 * T, Y0 - M + 1), (X0 + 6 * T, 4), (X0 + 8 * T, 4), (REAR, Y0 - M + 1)])
fin_bot = affinity.scale(fin_top, 1, -1, origin=(0, CY))
engines = [box(REAR - 2, Y0 + 4, REAR + 9, Y0 + 18), box(REAR - 2, Y0 + 4 * T - 18, REAR + 9, Y0 + 4 * T - 4)]
hull = unary_union([body, fin_top, fin_bot] + engines)
rim_light = hull.difference(affinity.translate(hull, 1.6, 1.6))
rim_dark = hull.difference(affinity.translate(hull, -1.6, -1.6))


def build_svg():
    s = []
    defs = [
        '<linearGradient id="hullH" gradientUnits="userSpaceOnUse" x1="10" y1="0" x2="170" y2="112">'
        '<stop offset="0" stop-color="#8E97A4"/><stop offset="0.5" stop-color="#5A6370"/>'
        '<stop offset="1" stop-color="#2A2F3A"/></linearGradient>',
        '<linearGradient id="glassH" gradientUnits="userSpaceOnUse" x1="20" y1="46" x2="38" y2="66">'
        '<stop offset="0" stop-color="#F7C1C1"/><stop offset="0.35" stop-color="#E24B4A"/>'
        '<stop offset="1" stop-color="#5E1919"/></linearGradient>',
    ]
    # Abgasfahnen hinter den Triebwerken (Jäger: rot-orange)
    for e in engines:
        x1, y1, x2, y2 = e.bounds
        cy = (y1 + y2) / 2
        s.append(f'<rect x="{x2}" y="{cy - 4}" width="6" height="8" fill="#D85A30" fill-opacity="0.6"/>')
        s.append(f'<rect x="{x2}" y="{cy - 2}" width="3" height="4" fill="#FAC775"/>')
    s.append(f'<path d="{poly_path(hull)}" fill="url(#hullH)"/>')
    s.append(f'<path d="{poly_path(rim_light)}" fill="#C4CAD3"/>')
    s.append(f'<path d="{poly_path(rim_dark)}" fill="#2A2F3A"/>')
    # rote Kennung: Vorderkanten der Finnen und Bugkeil
    for sgn in (-1, 1):
        y1, y2 = CY + sgn * (CY - (Y0 - M + 3)), CY + sgn * (CY - 6)
        s.append(f'<path d="M{X0 + 3 * T + 2},{y1} L{X0 + 6 * T + 1},{y2}" stroke="#E24B4A" stroke-width="2.4"/>')
    for sgn in (-1, 1):
        s.append(f'<path d="M16,{CY + sgn * 2} L33,{CY + sgn * 16}" stroke="#A32D2D" stroke-width="2"/>')
    # Plattenfugen auf den Finnen
    for x in (X0 + 5 * T, X0 + 7 * T):
        for y1, y2 in ((9, Y0 - M), (Y0 + 4 * T + M, H - 9)):
            s.append(f'<line x1="{x + .5}" y1="{y1}" x2="{x + .5}" y2="{y2}" stroke="#2A2F3A" stroke-width="1"/>'
                     f'<line x1="{x + 1.5}" y1="{y1}" x2="{x + 1.5}" y2="{y2}" stroke="#A9B0BB" stroke-width="1"/>')
    # Zwillingsgeschütz vorn oben und unten
    for sgn in (-1, 1):
        y = CY + sgn * 26
        s.append(f'<rect x="20" y="{y - 1}" width="22" height="2" fill="#2A2F3A"/>'
                 f'<rect x="20" y="{y - 1}" width="22" height="1" fill="#A9B0BB"/>'
                 f'<rect x="38" y="{y - 4}" width="8" height="8" fill="#5A6370"/>'
                 f'<rect x="38" y="{y - 4}" width="8" height="1" fill="#C4CAD3"/>')
    # Kanzel
    canopy = Polygon([(19, CY), (28, CY - 8), (38, CY - 10), (38, CY + 10), (28, CY + 8)])
    s.append(f'<path d="{poly_path(canopy)}" fill="url(#glassH)"/>')
    s.append(f'<path d="M23,{CY - 2} L29,{CY - 7} L35,{CY - 8}" stroke="#F7C1C1" stroke-width="1" fill="none"/>')
    # Räume
    for name, c, r in ROOMS:
        x, y = px(c, r)
        for i in range(2):
            for j in range(2):
                f = "#2B3249" if (i + j) % 2 == 0 else "#20263A"
                s.append(f'<rect x="{x + i * T}" y="{y + j * T}" width="{T}" height="{T}" fill="{f}"/>')
        s.append(f'<path d="M{x},{y + T + .5} H{x + 2 * T} M{x + T + .5},{y} V{y + 2 * T}" stroke="#161B2B" stroke-width="1"/>')
    for name, c, r in ROOMS:
        x, y = px(c, r)
        s.append(icon_svg(name, x + 8, y + 8))
    for name, c, r in ROOMS:
        x, y = px(c, r)
        s.append(f'<rect x="{x}" y="{y}" width="{2 * T}" height="{2 * T}" fill="none" stroke="#0A0B16" stroke-width="2"/>')
    for dc, dr, vert in DOORS:
        x, y = X0 + dc * T, Y0 + dr * T
        s.append(f'<rect x="{x - 1}" y="{y - 3}" width="2" height="6" fill="#A9B0BB"/>' if vert else
                 f'<rect x="{x - 3}" y="{y - 1}" width="6" height="2" fill="#A9B0BB"/>')
    # Triebwerksdüsen
    for e in engines:
        x1, y1, x2, y2 = e.bounds
        s.append(f'<rect x="{x2 - 3}" y="{y1 + 2}" width="3" height="{y2 - y1 - 4}" fill="#FAC775"/>'
                 f'<rect x="{x2 - 2}" y="{y1 + 4}" width="2" height="{y2 - y1 - 8}" fill="#FFFFFF"/>')
    # Positionsleuchten: rot oben, grün unten
    for (lx, ly, core, glow) in [(X0 + 7 * T, 5, "#F7C1C1", "#E24B4A"), (X0 + 7 * T, H - 7, "#E4F0D0", "#639922")]:
        s.append(f'<rect x="{lx - 1}" y="{ly}" width="4" height="2" fill="{glow}"/>'
                 f'<rect x="{lx}" y="{ly}" width="2" height="2" fill="{core}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<defs>{"".join(defs)}</defs>{"".join(s)}</svg>')
