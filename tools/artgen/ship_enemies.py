"""Weitere Gegnerschiffe mit eigenen Grundrissen, Bug nach links (zum Spieler).

Jedes Schiff ist eine Beschreibung (SHIPS): Raster, Räume beliebiger Größe (Spalte, Zeile, Breite,
Höhe in Kacheln), Türen, Rumpfform und Farben. Daraus entstehen das Sprite (build_svg) und die
Grafikpunkte für das Schiffs-JSON (meta: Waffenmündung, Triebwerke, Schildblase).

  pluenderer   – schlanker Keil, zwei Raumreihen, großer Antrieb: schnell und ausweichend
  kanonenboot  – kastiger Rumpf mit Geschützturm oben und Seitenkufen: langsam, zäh, viel Feuer
  fregatte     – Pfeilform mit langem Bug und gepfeilten Flügeln: die Jäger-Fregatte
"""
from icons import icon_svg
from shapely import affinity
from shapely.geometry import box, Polygon
from shapely.ops import unary_union

T = 14
M = 6  # Rumpfrand um die Räume

SHIPS = {
    "pluenderer": {
        "size": (120, 70), "origin": (18, 14), "grid": (6, 3),
        "rooms": [  # (id, Name, System, Spalte, Zeile, Breite, Höhe, Konsole)
            ("cockpit", "Cockpit", "cockpit", 0, 1, 1, 2, (0, 1)),
            ("waffen", "Waffen", "waffen", 1, 0, 2, 1, (1, 0)),
            ("schilde", "Schilde", "schilde", 1, 1, 2, 2, (2, 2)),
            ("reaktor", "Reaktor", "reaktor", 3, 0, 1, 3, None),
            ("antrieb", "Antrieb", "antrieb", 4, 0, 2, 3, (5, 1)),
        ],
        "doors": [((0, 1), (1, 1)), ((1, 0), (1, 1)), ((2, 0), (3, 0)), ((2, 1), (3, 1)), ((3, 1), (4, 1)), ((3, 2), (4, 2))],
        "airlocks": [((5, 2), (0, 1))],
        "shape": "keil",
        "paint": ("#EF9F27", "#854F0B"), "glass": ("#FDE6BF", "#EF9F27", "#4F2E05"),
        "hull": ("#A9B0BB", "#5A6370", "#2A2F3A"),
    },
    "kanonenboot": {
        "size": (112, 92), "origin": (24, 18), "grid": (5, 4),
        "rooms": [
            ("waffen", "Waffen", "waffen", 1, 0, 3, 1, (2, 0)),
            ("cockpit", "Cockpit", "cockpit", 0, 1, 1, 2, (0, 1)),
            ("schilde", "Schilde", "schilde", 1, 1, 2, 2, (1, 2)),
            ("reaktor", "Reaktor", "reaktor", 3, 1, 1, 3, None),
            ("antrieb", "Antrieb", "antrieb", 4, 0, 1, 4, (4, 1)),
            ("medbay", "Medbay", "medbay", 1, 3, 2, 1, None),
        ],
        "doors": [((0, 1), (1, 1)), ((1, 0), (1, 1)), ((3, 0), (3, 1)), ((3, 0), (4, 0)), ((2, 2), (3, 2)),
                  ((1, 2), (1, 3)), ((2, 3), (3, 3)), ((3, 2), (4, 2))],
        "airlocks": [((0, 2), (-1, 0))],
        "shape": "kasten",
        "paint": ("#639922", "#22400A"), "glass": ("#E4F0D0", "#639922", "#22400A"),
        "hull": ("#8E97A4", "#5A6370", "#1A1E27"),
    },
    "fregatte": {
        "size": (122, 96), "origin": (22, 20), "grid": (6, 4),
        "rooms": [
            ("cockpit", "Cockpit", "cockpit", 0, 1, 2, 2, (0, 1)),
            ("waffen", "Waffen", "waffen", 2, 0, 2, 2, (2, 0)),
            ("schilde", "Schilde", "schilde", 2, 2, 2, 2, (2, 3)),
            ("reaktor", "Reaktor", "reaktor", 4, 1, 1, 2, None),
            ("antrieb", "Antrieb", "antrieb", 5, 0, 1, 4, (5, 1)),
        ],
        "doors": [((1, 1), (2, 1)), ((1, 2), (2, 2)), ((3, 1), (3, 2)), ((3, 1), (4, 1)), ((3, 2), (4, 2)),
                  ((4, 1), (5, 1)), ((4, 2), (5, 2))],
        "airlocks": [((5, 3), (0, 1))],
        "shape": "pfeil",
        "paint": ("#E24B4A", "#5E1919"), "glass": ("#F7C1C1", "#E24B4A", "#5E1919"),
        "hull": ("#747D8A", "#424A56", "#161B2B"),
    },
}


def poly_path(g):
    d = []
    for p in getattr(g, "geoms", [g]):
        for ring in [p.exterior] + list(p.interiors):
            d.append("M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in ring.coords) + " Z")
    return " ".join(d)


def _geometry(sp):
    X0, Y0 = sp["origin"]
    GW, GH = sp["grid"]
    gx2, gy2 = X0 + GW * T, Y0 + GH * T
    cy = Y0 + GH * T / 2
    shape = sp["shape"]
    parts, extra = [], []
    if shape == "keil":
        parts.append(box(X0 + T - M, Y0 - M, gx2 + M, gy2 + M).buffer(2, join_style=2))
        parts.append(Polygon([(4, cy + 4), (X0 + T + 2, Y0 + T - M - 2), (X0 + T + 2, gy2 + M), (X0 - 2, gy2 + 2)]))
        parts.append(box(gx2 + M - 2, Y0 - 2, gx2 + M + 5, gy2 + 2))
        extra = [Polygon([(X0 + 3 * T, gy2 + M), (gx2, gy2 + M), (gx2 + 4, gy2 + M + 6), (X0 + 4 * T, gy2 + M + 6)])]
        engines = [(gx2 + M + 5, Y0 + T * 0.5), (gx2 + M + 5, cy), (gx2 + M + 5, gy2 - T * 0.5)]
        canopy = Polygon([(8, cy + 4), (X0 + 2, Y0 + T + 4), (X0 + 4, Y0 + T + 4), (X0 + 4, gy2 - 2), (X0 - 2, gy2 - 2)])
        mount = (6, cy + 8)
    elif shape == "kasten":
        parts.append(box(X0 - M, Y0 + T - M, gx2 + M, gy2 + M).buffer(2, join_style=2))
        parts.append(box(X0 + T - M, Y0 - M, gx2 + M, Y0 + T + M).buffer(1, join_style=2))
        parts.append(Polygon([(X0 - M, Y0 + T - M + 4), (6, Y0 + 2 * T - 2), (6, gy2 - 4), (X0 - M, gy2 + M - 2)]))
        parts.append(box(gx2 + M - 2, Y0 + 2, gx2 + M + 5, gy2 - 2))
        # Kufen an den Seiten
        extra = [box(X0 + 4, gy2 + M, gx2 - 4, gy2 + M + 5), box(X0 + T + 4, Y0 - M - 5, X0 + 3 * T, Y0 - M)]
        engines = [(gx2 + M + 5, Y0 + T), (gx2 + M + 5, Y0 + 2.5 * T), (gx2 + M + 5, gy2 - T * 0.5)]
        canopy = Polygon([(8, Y0 + 2 * T), (X0 - M + 2, Y0 + T + 2), (X0 - 1, Y0 + T + 2), (X0 - 1, gy2 - 2), (X0 - M + 2, gy2 - 2)])
        mount = (X0 + T + 2, Y0 - M - 2)
    else:  # pfeil
        parts.append(box(X0 + T, Y0 - M, gx2 + M, gy2 + M).buffer(2, join_style=2))
        parts.append(Polygon([(2, cy), (X0 + T, Y0 + T - M), (X0 + T, gy2 - T + M)]))
        parts.append(box(gx2 + M - 2, Y0 - 2, gx2 + M + 5, gy2 + 2))
        extra = [Polygon([(X0 + 3 * T, Y0 - M), (gx2, Y0 - M), (gx2 + M + 4, 2), (X0 + 4 * T, 2)]),
                 Polygon([(X0 + 3 * T, gy2 + M), (gx2, gy2 + M), (gx2 + M + 4, sp["size"][1] - 2), (X0 + 4 * T, sp["size"][1] - 2)])]
        engines = [(gx2 + M + 5, Y0 + T * 0.5), (gx2 + M + 5, Y0 + T * 1.5), (gx2 + M + 5, gy2 - T * 1.5), (gx2 + M + 5, gy2 - T * 0.5)]
        canopy = Polygon([(8, cy), (X0 + 2, cy - 8), (X0 + 6, cy - 8), (X0 + 6, cy + 8), (X0 + 2, cy + 8)])
        mount = (4, cy + 10)
    hull = unary_union(parts + extra)
    return hull, extra, engines, canopy, mount


def meta(name):
    """Grafikpunkte für das Schiffs-JSON."""
    sp = SHIPS[name]
    hull, _, engines, _, mount = _geometry(sp)
    x1, y1, x2, y2 = hull.bounds
    W, H = sp["size"]
    return {
        "tile_size": T, "grid_origin": list(sp["origin"]), "grid_size": list(sp["grid"]),
        "weapon_mount": [round(mount[0]), round(mount[1])],
        "engines": [[round(x) + 1, round(y)] for x, y in engines], "engine_dir": 1,
        "shield_ellipse": [round((x1 + x2) / 2), round((y1 + y2) / 2), round((x2 - x1) / 2 + 6), round((y2 - y1) / 2 + 6)],
    }


def build_svg(name):
    sp = SHIPS[name]
    W, H = sp["size"]
    X0, Y0 = sp["origin"]
    hull, extra, engines, canopy, mount = _geometry(sp)
    lt, md, dk = sp["hull"]
    paint, paint_dk = sp["paint"]
    g1, g2, g3 = sp["glass"]
    rim_light = hull.difference(affinity.translate(hull, 1.6, 1.6))
    rim_dark = hull.difference(affinity.translate(hull, -1.6, -1.6))
    defs = [
        f'<linearGradient id="hullG" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="{W}" y2="{H}">'
        f'<stop offset="0" stop-color="{lt}"/><stop offset="0.5" stop-color="{md}"/><stop offset="1" stop-color="{dk}"/></linearGradient>',
        f'<linearGradient id="glass" gradientUnits="userSpaceOnUse" x1="0" y1="{Y0}" x2="{X0}" y2="{Y0 + 40}">'
        f'<stop offset="0" stop-color="{g1}"/><stop offset="0.4" stop-color="{g2}"/><stop offset="1" stop-color="{g3}"/></linearGradient>',
    ]
    s = []
    for x, y in engines:  # Abgasfahnen
        s.append(f'<rect x="{x}" y="{y - 3}" width="5" height="6" fill="#D85A30" fill-opacity="0.6"/>')
        s.append(f'<rect x="{x}" y="{y - 2}" width="3" height="4" fill="#FAC775"/>')
    s.append(f'<path d="{poly_path(hull)}" fill="url(#hullG)"/>')
    s.append(f'<path d="{poly_path(rim_light)}" fill="#C4CAD3"/>')
    s.append(f'<path d="{poly_path(rim_dark)}" fill="#1A1E27"/>')
    for e in extra:
        s.append(f'<path d="{poly_path(e.buffer(-1.2))}" fill="{paint_dk}"/>')
    # Farbstreifen oben und unten am Rumpf
    GW, GH = sp["grid"]
    gx2, gy2 = X0 + GW * T, Y0 + GH * T
    for x in range(X0 + T, gx2, 9):
        s.append(f'<path d="M{x},{Y0 - M + 1} l5,0 l-3,4 l-5,0 Z" fill="{paint}"/>')
        s.append(f'<path d="M{x},{gy2 + M - 1} l5,0 l-3,-4 l-5,0 Z" fill="{paint_dk}"/>')
    s.append(f'<path d="{poly_path(canopy)}" fill="url(#glass)"/>')
    # Geschützrohr an der Mündung
    mx, my = mount
    s.append(f'<rect x="{mx}" y="{my - 1.5}" width="{X0 + T - mx}" height="3" fill="#2A2F3A"/>')
    s.append(f'<rect x="{mx}" y="{my - 1.5}" width="{X0 + T - mx}" height="1" fill="#8E97A4"/>')
    for x, y in engines:  # Düsen
        s.append(f'<rect x="{x - 4}" y="{y - 3}" width="5" height="6" fill="#2A2F3A"/>')
        s.append(f'<rect x="{x - 1}" y="{y - 2}" width="2" height="4" fill="#FDE6BF"/>')
    # Innenräume
    for rid, label, system, c, r, w, h, _ in sp["rooms"]:
        x, y = X0 + c * T, Y0 + r * T
        for i in range(w):
            for j in range(h):
                f = "#2B3249" if (i + j) % 2 == 0 else "#20263A"
                s.append(f'<rect x="{x + i * T}" y="{y + j * T}" width="{T}" height="{T}" fill="{f}"/>')
        s.append(icon_svg(label, x + w * T / 2 - 6, y + h * T / 2 - 6))
    for rid, label, system, c, r, w, h, _ in sp["rooms"]:
        x, y = X0 + c * T, Y0 + r * T
        s.append(f'<rect x="{x}" y="{y}" width="{w * T}" height="{h * T}" fill="none" stroke="#0A0B16" stroke-width="2"/>')
    for (a, b) in sp["doors"]:
        if a[0] != b[0]:  # senkrechte Wand
            x, y = X0 + max(a[0], b[0]) * T, Y0 + a[1] * T + T / 2
            s.append(f'<rect x="{x - 1}" y="{y - 3}" width="2" height="6" fill="#A9B0BB"/>')
        else:
            x, y = X0 + a[0] * T + T / 2, Y0 + max(a[1], b[1]) * T
            s.append(f'<rect x="{x - 3}" y="{y - 1}" width="6" height="2" fill="#A9B0BB"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<defs>{"".join(defs)}</defs>{"".join(s)}</svg>')
