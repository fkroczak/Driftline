"""Mensch Frachter: C-Form (Öffnung zum Heck) mit Shuttlebucht, Bug nach rechts."""
from icons import icon_svg
from shapely.geometry import box, Point, Polygon
from shapely.ops import unary_union
from shapely import affinity

W, H = 280, 140
T = 14                     # Kachel (px); 1 Raum = 2x2 Kacheln = 28 px
X0, Y0 = 70, 14            # Rasterursprung
M = 7                      # Rumpfrand um die Räume
CY = Y0 + 4 * T            # Mittellinie

ROOMS = [  # (Name, Spalte, Zeile) in Kacheln, je 2x2
    ("Antrieb", 0, 0), ("Erweiterung", 2, 0), ("Lebenserhaltung", 4, 0), ("Schilde", 6, 0),
    ("Erweiterung", 0, 6), ("Medbay", 2, 6), ("Erweiterung", 4, 6), ("Waffen", 6, 6),
    ("Reaktor", 6, 2), ("Sensoren", 6, 4), ("Cockpit", 9, 3),
]
CORRIDOR = (8, 1, 1, 6)    # Spalte, Zeile, Breite, Höhe in Kacheln
DOORS = [  # (x, y, vertikal?) Wandmitte in Kacheln
    (2, 1.5, True), (4, 1.5, True), (6, 1.5, True),           # obere Reihe
    (2, 6.5, True), (4, 6.5, True), (6, 6.5, True),           # untere Reihe
    (6.5, 2, False), (7.5, 4, False), (6.5, 6, False),        # Bugsäule
    (8, 1.5, True), (8, 3.5, True), (8, 4.5, True), (8, 6.5, True),  # Korridor
    (9, 3.5, True),                                           # Cockpit
]


def px(c, r):
    return X0 + c * T, Y0 + r * T


def poly_path(g):
    geoms = getattr(g, "geoms", [g])
    d = []
    for p in geoms:
        for ring in [p.exterior] + list(p.interiors):
            pts = list(ring.coords)
            d.append("M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in pts) + " Z")
    return " ".join(d)


def rounded_box(x1, y1, x2, y2, r):
    return box(x1 + r, y1 + r, x2 - r, y2 - r).buffer(r, quad_segs=8)


# ---------- Rumpfgeometrie ----------
upper = rounded_box(X0 - M, Y0 - M, X0 + 8 * T, Y0 + 2 * T + M, 4)
lower = rounded_box(X0 - M, Y0 + 6 * T - M, X0 + 8 * T, Y0 + 8 * T + M, 4)
bow_ell = affinity.scale(Point(0, 0).buffer(1, quad_segs=32), 98, 63).buffer(0)
bow_ell = affinity.translate(bow_ell, X0 + 6 * T, CY)
bow = bow_ell.intersection(box(X0 + 6 * T - M, 0, W, H))
bow = unary_union([bow, box(X0 + 6 * T - M, Y0 + T, X0 + 7 * T, Y0 + 7 * T)])
# Triebwerksgondeln an den Armenden
nac = [rounded_box(X0 - 24, Y0 + T - 12, X0 + 2, Y0 + T + 12, 3),
       rounded_box(X0 - 24, Y0 + 7 * T - 12, X0 + 2, Y0 + 7 * T + 12, 3)]
hull = unary_union([upper, lower, bow] + nac)

interior = unary_union([box(*px(c, r), *px(c + 2, r + 2)) for _, c, r in ROOMS] +
                       [box(*px(CORRIDOR[0], CORRIDOR[1]),
                            *px(CORRIDOR[0] + CORRIDOR[2], CORRIDOR[1] + CORRIDOR[3]))])

rim_light = hull.difference(affinity.translate(hull, 1.6, 1.6))
rim_dark = hull.difference(affinity.translate(hull, -1.6, -1.6))


def build_svg():
    s = []
    defs = [
        '<linearGradient id="hullG" gradientUnits="userSpaceOnUse" x1="40" y1="0" x2="230" y2="140">'
        '<stop offset="0" stop-color="#C4CAD3"/><stop offset="0.45" stop-color="#8E97A4"/>'
        '<stop offset="1" stop-color="#5A6370"/></linearGradient>',
        '<linearGradient id="nacG" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="140">'
        '<stop offset="0" stop-color="#8E97A4"/><stop offset="1" stop-color="#424A56"/></linearGradient>',
        '<linearGradient id="glass" gradientUnits="userSpaceOnUse" x1="200" y1="45" x2="240" y2="100">'
        '<stop offset="0" stop-color="#85B7EB"/><stop offset="0.35" stop-color="#378ADD"/>'
        '<stop offset="1" stop-color="#0E3A66"/></linearGradient>',
        '<linearGradient id="shut" gradientUnits="userSpaceOnUse" x1="90" y1="44" x2="125" y2="70">'
        '<stop offset="0" stop-color="#E6EAF0"/><stop offset="0.6" stop-color="#C4CAD3"/>'
        '<stop offset="1" stop-color="#8E97A4"/></linearGradient>',
        '<pattern id="hatch" patternUnits="userSpaceOnUse" width="4" height="4">'
        '<rect width="4" height="4" fill="#2A2F3A"/>'
        '<path d="M0,4 L4,0 M-1,1 L1,-1 M3,5 L5,3" stroke="#424A56" stroke-width="1"/></pattern>',
    ]
    # --- Triebwerks-Abgasfahnen (hinter dem Rumpf) ---
    for cy in (Y0 + T, Y0 + 7 * T):
        for oy in (-5, 5):
            s.append(f'<rect x="{X0 - 34}" y="{cy + oy - 3}" width="5" height="6" fill="#378ADD" fill-opacity="0.6"/>')
            s.append(f'<rect x="{X0 - 32}" y="{cy + oy - 2}" width="3" height="4" fill="#85B7EB"/>')
    # --- Rumpf ---
    s.append(f'<path d="{poly_path(hull)}" fill="url(#hullG)"/>')
    for n in nac:
        s.append(f'<path d="{poly_path(n)}" fill="url(#nacG)"/>')
    s.append(f'<path d="{poly_path(rim_light)}" fill="#E6EAF0"/>')
    s.append(f'<path d="{poly_path(rim_dark)}" fill="#5A6370"/>')
    # Blaues Lackband entlang der Bugkontur (Fortsetzung der Armstreifen)
    band = bow_ell.buffer(-3).difference(bow_ell.buffer(-5)).intersection(box(X0 + 8 * T, 0, W, H))
    s.append(f'<path d="{poly_path(band)}" fill="#378ADD"/>')
    # Bugpaneele: Frachtluken + Lüftungsgitter
    for (px1, py1) in [(X0 + 9 * T + 2, Y0 + 10), (X0 + 9 * T + 2, Y0 + 6 * T + 4)]:
        s.append(f'<rect x="{px1}" y="{py1}" width="22" height="14" fill="#747D8A"/>'
                 f'<rect x="{px1}" y="{py1}" width="22" height="1" fill="#5A6370"/>'
                 f'<rect x="{px1}" y="{py1}" width="1" height="14" fill="#5A6370"/>'
                 f'<rect x="{px1}" y="{py1 + 13}" width="22" height="1" fill="#C4CAD3"/>'
                 f'<rect x="{px1 + 21}" y="{py1}" width="1" height="14" fill="#C4CAD3"/>')
        for k in range(3):
            s.append(f'<rect x="{px1 + 4}" y="{py1 + 4 + 3 * k}" width="10" height="1" fill="#2A2F3A"/>')
        s.append(f'<rect x="{px1 + 17}" y="{py1 + 5}" width="2" height="4" fill="#EF9F27"/>')
    # Fenster am Bug
    for k in range(4):
        s.append(f'<rect x="{X0 + 11 * T - 10 + 4 * k}" y="{Y0 + 2 * T - 1 + 2 * k}" width="2" height="1" fill="#D3E6F8"/>')
        s.append(f'<rect x="{X0 + 11 * T - 10 + 4 * k}" y="{Y0 + 6 * T + 1 - 2 * k}" width="2" height="1" fill="#85B7EB"/>')
    # Plattenfugen (dunkle Fuge + helle Kante unten/rechts)
    seams = []
    for c in range(0, 9, 2):
        x = X0 + c * T
        seams += [(x, Y0 - M + 2, x, Y0 - 1), (x, Y0 + 2 * T + 1, x, Y0 + 2 * T + M - 2),
                  (x, Y0 + 6 * T - M + 2, x, Y0 + 6 * T - 1), (x, Y0 + 8 * T + 1, x, Y0 + 8 * T + M - 2)]
    nose_x = X0 + 11 * T
    seams += [(X0 + 9 * T, Y0 + 2, X0 + 9 * T, Y0 + 3 * T - 2), (X0 + 9 * T, Y0 + 5 * T + 2, X0 + 9 * T, Y0 + 8 * T - 2),
              (X0 + 8 * T + 2, Y0 + 3 * T - 1, nose_x + 8, Y0 + 3 * T - 1),
              (X0 + 8 * T + 2, Y0 + 5 * T + 1, nose_x + 8, Y0 + 5 * T + 1),
              ]
    for x1, y1, x2, y2 in seams:
        s.append(f'<line x1="{x1 + .5}" y1="{y1}" x2="{x2 + .5}" y2="{y2}" stroke="#5A6370" stroke-width="1"/>'
                 if x1 == x2 else
                 f'<line x1="{x1}" y1="{y1 + .5}" x2="{x2}" y2="{y2 + .5}" stroke="#5A6370" stroke-width="1"/>')
        if x1 == x2:
            s.append(f'<line x1="{x1 + 1.5}" y1="{y1}" x2="{x2 + 1.5}" y2="{y2}" stroke="#E6EAF0" stroke-width="1"/>')
        else:
            s.append(f'<line x1="{x1}" y1="{y1 + 1.5}" x2="{x2}" y2="{y2 + 1.5}" stroke="#E6EAF0" stroke-width="1"/>')
    # Nieten auf dem Bug
    for (rx, ry) in [(X0 + 10 * T, Y0 + 2 * T - 4), (X0 + 10 * T + 8, Y0 + 2 * T), (X0 + 10 * T, Y0 + 6 * T + 4),
                     (X0 + 10 * T + 8, Y0 + 6 * T), (X0 + 9 * T + 6, Y0 + 12), (X0 + 9 * T + 6, Y0 + 8 * T - 12)]:
        s.append(f'<rect x="{rx}" y="{ry}" width="1" height="1" fill="#5A6370"/>'
                 f'<rect x="{rx - 1}" y="{ry - 1}" width="1" height="1" fill="#E6EAF0"/>')
    # Blaue Kennstreifen auf den Außenkanten der Arme
    s.append(f'<rect x="{X0 - 4}" y="{Y0 - 5}" width="{8 * T + 4}" height="2" fill="#378ADD"/>')
    s.append(f'<rect x="{X0 - 4}" y="{Y0 + 8 * T + 3}" width="{8 * T + 4}" height="2" fill="#185FA5"/>')
    # Fensterreihen
    for x in range(X0 + 4, X0 + 8 * T, 6):
        s.append(f'<rect x="{x}" y="{Y0 - 3}" width="2" height="1" fill="#D3E6F8"/>')
        s.append(f'<rect x="{x}" y="{Y0 + 8 * T + 2}" width="2" height="1" fill="#85B7EB"/>')
    for x in range(X0 + 6 * T + 4, X0 + 9 * T + 2, 6):
        s.append(f'<rect x="{x}" y="{Y0 + 2 * T + 3}" width="2" height="1" fill="#D3E6F8"/>')
    # Cockpitkanzel
    canopy = Polygon([(nose_x + 2, CY - 13), (nose_x + 12, CY - 10), (nose_x + 19, CY - 4), (nose_x + 20, CY),
                      (nose_x + 19, CY + 4), (nose_x + 12, CY + 10), (nose_x + 2, CY + 13)])
    s.append(f'<path d="{poly_path(canopy)}" fill="url(#glass)"/>')
    s.append(f'<path d="M{nose_x + 4},{CY - 10} L{nose_x + 11},{CY - 8} L{nose_x + 15},{CY - 4}" '
             f'stroke="#D3E6F8" stroke-width="1.2" fill="none"/>')
    s.append(f'<line x1="{nose_x + 2}" y1="{CY - 13}" x2="{nose_x + 2}" y2="{CY + 13}" stroke="#2A2F3A" stroke-width="1.2"/>')
    # Geschützturm unten (Waffenraum) und Sensorschüssel oben
    tx, ty = X0 + 7 * T, Y0 + 8 * T + 5
    s.append(f'<rect x="{tx + 2}" y="{ty - 1.5}" width="13" height="3" fill="#424A56"/>')
    s.append(f'<rect x="{tx + 2}" y="{ty - 1.5}" width="13" height="1" fill="#8E97A4"/>')
    s.append(f'<circle cx="{tx}" cy="{ty}" r="5" fill="#8E97A4"/><circle cx="{tx - 1}" cy="{ty - 1}" r="3" fill="#C4CAD3"/>'
             f'<circle cx="{tx}" cy="{ty}" r="5" fill="none" stroke="#424A56" stroke-width="1"/>')
    sx, sy = X0 + 9 * T + 4, Y0 + 2
    s.append(f'<circle cx="{sx}" cy="{sy}" r="5" fill="#A9B0BB"/><circle cx="{sx + 1}" cy="{sy + 1}" r="3" fill="#5A6370"/>'
             f'<circle cx="{sx}" cy="{sy}" r="1.4" fill="#CECBF6"/>')
    # --- Innenräume ---
    for name, c, r in ROOMS:
        x, y = px(c, r)
        if name == "Erweiterung":
            s.append(f'<rect x="{x}" y="{y}" width="{2 * T}" height="{2 * T}" fill="url(#hatch)"/>')
        else:
            for i in range(2):
                for j in range(2):
                    f = "#2B3249" if (i + j) % 2 == 0 else "#20263A"
                    s.append(f'<rect x="{x + i * T}" y="{y + j * T}" width="{T}" height="{T}" fill="{f}"/>')
            s.append(f'<path d="M{x},{y + T + .5} H{x + 2 * T} M{x + T + .5},{y} V{y + 2 * T}" stroke="#161B2B" stroke-width="1"/>')
    cx_, cy_ = px(CORRIDOR[0], CORRIDOR[1])
    for j in range(CORRIDOR[3]):
        f = "#2B3249" if j % 2 == 0 else "#20263A"
        s.append(f'<rect x="{cx_}" y="{cy_ + j * T}" width="{T}" height="{T}" fill="{f}"/>')
    for name, c, r in ROOMS:
        x, y = px(c, r)
        if name == "Erweiterung":
            m = x + T, y + T
            s.append(f'<rect x="{m[0] - 5}" y="{m[1] - 1}" width="10" height="2" fill="#C4CAD3"/>'
                     f'<rect x="{m[0] - 1}" y="{m[1] - 5}" width="2" height="10" fill="#C4CAD3"/>')
        else:
            s.append(icon_svg(name, x + 8, y + 8))
    # Wände (2 px, auf Raumkanten zentriert)
    walls = [box(*px(c, r), *px(c + 2, r + 2)) for _, c, r in ROOMS]
    walls.append(box(*px(CORRIDOR[0], CORRIDOR[1]), *px(CORRIDOR[0] + 1, CORRIDOR[1] + CORRIDOR[3])))
    for wbox in walls:
        x1, y1, x2, y2 = wbox.bounds
        s.append(f'<rect x="{x1}" y="{y1}" width="{x2 - x1}" height="{y2 - y1}" fill="none" stroke="#0A0B16" stroke-width="2"/>')
    # Türen
    for dc, dr, vert in DOORS:
        x, y = X0 + dc * T, Y0 + dr * T
        if vert:
            s.append(f'<rect x="{x - 1}" y="{y - 3}" width="2" height="6" fill="#A9B0BB"/>')
        else:
            s.append(f'<rect x="{x - 3}" y="{y - 1}" width="6" height="2" fill="#A9B0BB"/>')
    # --- Shuttlebucht: Klammern, Leitlichter, Shuttle ---
    bay_top, bay_bot = Y0 + 2 * T + M, Y0 + 6 * T - M
    shx, shy = X0 + 34, CY
    for yy in (bay_top, bay_bot):
        sgn = 1 if yy == bay_top else -1
        s.append(f'<rect x="{shx - 1}" y="{min(yy, yy + sgn * 9)}" width="4" height="9" fill="#5A6370"/>'
                 f'<rect x="{shx - 1}" y="{min(yy, yy + sgn * 9)}" width="1" height="9" fill="#A9B0BB"/>')
    for x in range(X0 - 2, X0 + 6 * T - 8, 9):
        for yy in (bay_top - 2, bay_bot + 1):
            s.append(f'<rect x="{x}" y="{yy}" width="2" height="1" fill="#FAC775"/>')
    shuttle = Polygon([(shx - 22, shy), (shx - 16, shy - 7), (shx + 14, shy - 8), (shx + 18, shy - 5),
                       (shx + 18, shy + 5), (shx + 14, shy + 8), (shx - 16, shy + 7)])
    s.append(f'<path d="{poly_path(shuttle)}" fill="url(#shut)"/>')
    s.append(f'<path d="{poly_path(shuttle.difference(affinity.translate(shuttle, -1.2, -1.2)))}" fill="#747D8A"/>')
    s.append(f'<rect x="{shx - 8}" y="{shy - 1}" width="22" height="2" fill="#378ADD"/>')
    s.append(f'<path d="M{shx - 20},{shy} L{shx - 15},{shy - 4} L{shx - 11},{shy - 4} L{shx - 11},{shy + 4} L{shx - 15},{shy + 4} Z" fill="#185FA5"/>'
             f'<path d="M{shx - 18},{shy - 1} L{shx - 15},{shy - 3} L{shx - 12},{shy - 3}" stroke="#D3E6F8" stroke-width="1" fill="none"/>')
    s.append(f'<rect x="{shx + 18}" y="{shy - 4}" width="3" height="3" fill="#85B7EB"/>'
             f'<rect x="{shx + 18}" y="{shy + 1}" width="3" height="3" fill="#85B7EB"/>'
             f'<rect x="{shx + 18}" y="{shy - 3}" width="2" height="1" fill="#FFFFFF"/>'
             f'<rect x="{shx + 18}" y="{shy + 2}" width="2" height="1" fill="#FFFFFF"/>')
    # --- Triebwerksdüsen mit Leuchtrand ---
    for cy in (Y0 + T, Y0 + 7 * T):
        for oy in (-5, 5):
            y = cy + oy
            s.append(f'<rect x="{X0 - 30}" y="{y - 4}" width="7" height="8" fill="#2A2F3A"/>')
            s.append(f'<rect x="{X0 - 30}" y="{y - 4}" width="7" height="1" fill="#8E97A4"/>')
            s.append(f'<rect x="{X0 - 30}" y="{y - 3}" width="2" height="6" fill="#D3E6F8"/>')
            s.append(f'<rect x="{X0 - 30}" y="{y - 2}" width="1" height="4" fill="#FFFFFF"/>')
            s.append(f'<rect x="{X0 - 28}" y="{y - 3}" width="1" height="6" fill="#85B7EB"/>')
    # --- Positionsleuchten: rot oben, grün unten ---
    for (lx, ly, core, glow) in [(X0 + 3 * T, Y0 - M - 1, "#F7C1C1", "#E24B4A"),
                                 (X0 + 3 * T, Y0 + 8 * T + M - 1, "#E4F0D0", "#639922")]:
        s.append(f'<rect x="{lx - 2}" y="{ly - 1}" width="6" height="4" fill="{glow}" fill-opacity="0.6"/>'
                 f'<rect x="{lx - 1}" y="{ly}" width="4" height="2" fill="{glow}"/>'
                 f'<rect x="{lx}" y="{ly}" width="2" height="2" fill="{core}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<defs>{"".join(defs)}</defs>{"".join(s)}</svg>')
