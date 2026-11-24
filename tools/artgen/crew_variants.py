"""Individuelle Crew: je Spezies Frau (w) und Mann (m) in drei Farbvarianten (0–2).

Die Grundform kommt aus crew_human.py (Mensch) bzw. crew_species.py (übrige). Eine Variante
überschreibt Farben (colors), ergänzt Formen (parts/lines, nur Porträt) und ersetzt bei Bedarf
die Materialkarte der kleinen Figur (small_map). Alle Farben bleiben bei der Grundfarbe der Spezies.

Ausgabe (build.py crew): assets/crew/<spezies>_<w|m><0-2>_klein_sheet.png und _gross_unten.png
"""
import copy
import crew_human as CH
import crew_species as CS

GENDERS = ["w", "m"]
LOOKS = 3

# --- Mensch: Haut und Haar je Variante, Frauen mit Zopf -----------------------------------------
SKIN = [("#F2C9AE", "#E2AC8B", "#C58A6A"), ("#E2AC8B", "#C58A6A", "#9A6448"), ("#C58A6A", "#9A6448", "#6E4430")]
HAIR = {
    "w": [("#D85A30", "#8A3519", "#5E1919"), ("#FAC775", "#D9A867", "#B07A3C"), ("#5E3614", "#3A2009", "#1A1E27")],
    "m": [("#B07A3C", "#7F4C1E", "#3A2009"), ("#5A6370", "#2A2F3A", "#1A1E27"), ("#D9A867", "#B07A3C", "#7F4C1E")],
}
HUMAN_SMALL_W = [
    "....PPHPP....",
    ".UUUPHHHPUUU.",
    "UUOUHHHHHUOUU",
    "UUOUHHHHHUOUU",
    "UUOUHHHHHUOUU",
    "UUUUCHHHCUUUU",
    "SUUUUSSSUUUUS",
    "S..BB...BB..S",
]

# --- übrige Spezies: Farbvarianten und kleine Unterschiede zwischen Frau und Mann ---------------
VARIANTS = {
    "kithra": {
        "looks": [
            {},
            {"shell": ("#E4F0D0", "#C0DD97", "#639922"), "thorax": ("#E4F0D0", "#C0DD97", "#639922"), "eye": ("#F7C1C1", "#E24B4A", "#A32D2D")},
            {"shell": ("#9FE1CB", "#5DCAA5", "#0F6E56"), "thorax": ("#9FE1CB", "#0F6E56", "#08402F"), "head": ("#DDF5EC", "#9FE1CB", "#5DCAA5"),
             "eye": ("#FDE6BF", "#FAC775", "#EF9F27")},
        ],
        # Frauen: lange, geschwungene Fühler; Männer: kurze Fühler und Kieferzangen
        "w": {"lines": [(-5.5, 16.5, -8.5, 19.5, 0.9, "leg"), (5.5, 16.5, 8.5, 19.5, 0.9, "leg")],
              "small_tail": ["..A.......A.."]},
        "m": {"parts": [("ell", -1.6, 9.2, 0.9, 1.4, "eye"), ("ell", 1.6, 9.2, 0.9, 1.4, "eye")]},
    },
    "androide": {
        "looks": [
            {},
            {"shell": ("#E6EAF0", "#C4CAD3", "#8E97A4"), "visor": ("#FDE6BF", "#EF9F27", "#854F0B"), "dome": ("#FFFFFF", "#FDE6BF", "#FAC775")},
            {"shell": ("#D3E6F8", "#85B7EB", "#378ADD"), "joint": ("#D3E6F8", "#85B7EB", "#185FA5"), "visor": ("#CECBF6", "#7F77DD", "#26215C"),
             "dome": ("#FFFFFF", "#D3E6F8", "#85B7EB")},
        ],
        # Bauform A (w): runde Kuppel ohne Antenne; Bauform B (m): Antenne
        "w": {"drop_parts": ["antenna"], "small_replace": {0: "............."}},
        "m": {},
    },
    "veyari": {
        "looks": [
            {},
            {"head": ("#FFFFFF", "#FBE3EB", "#F4C0D1"), "arm": ("#FFFFFF", "#FBE3EB", "#F4C0D1"), "robe": ("#9FE1CB", "#0F6E56", "#08402F")},
            {"head": ("#FFFFFF", "#D3E6F8", "#85B7EB"), "arm": ("#FFFFFF", "#D3E6F8", "#85B7EB"), "robe": ("#F7C1C1", "#A32D2D", "#5E1919")},
        ],
        # Frauen: doppelter Kamm; Männer: einzelner Kamm
        "w": {"parts": [("rect", -1.6, -6.0, 0.4, 4.0, "crest", 0.2), ("rect", 1.6, -6.0, 0.4, 4.0, "crest", 0.2)],
              "drop_parts": ["crest"], "small_replace": {2: "..RHHKHKHHR..", 3: "..HHHKHKHHH.."}},
        "m": {},
    },
    "ormok": {
        "looks": [
            {},
            {"fur": ("#B07A3C", "#7F4C1E", "#3A2009"), "fist": ("#7F4C1E", "#5E3614", "#3A2009")},
            {"fur": ("#F0997B", "#D85A30", "#8A3519"), "fist": ("#D85A30", "#8A3519", "#5E1919"), "face": ("#D85A30", "#8A3519", "#4F2E05")},
        ],
        # Männer: Hauer; Frauen: keine Hauer, dafür Zöpfe an den Schultern
        "w": {"drop_parts": ["tusk"], "parts": [("ell", -9.0, -8.0, 1.6, 2.6, "fist"), ("ell", 9.0, -8.0, 1.6, 2.6, "fist")],
              "small_replace": {7: "PP.FGGGGGF.PP", 0: "..PFFFFFFFP.."}},
        "m": {},
    },
    "petrani": {
        "looks": [
            {},
            {"stone": ("#D9A867", "#B07A3C", "#7F4C1E"), "head": ("#FDE6BF", "#D9A867", "#B07A3C"),
             "crystal": ("#FFFFFF", "#F4C0D1", "#D4537E"), "crystal2": ("#FFFFFF", "#FAC775", "#EF9F27")},
            {"stone": ("#5A6370", "#2A2F3A", "#1A1E27"), "head": ("#8E97A4", "#5A6370", "#2A2F3A"),
             "crystal": ("#FFFFFF", "#D3E6F8", "#85B7EB"), "crystal2": ("#FFFFFF", "#9FE1CB", "#5DCAA5"), "rune": ("#F7C1C1", "#E24B4A", "#A32D2D")},
        ],
        # Frauen: viele kleine Kristalle; Männer: zwei große
        "w": {"parts": [("rect", -4.0, -8.5, 0.9, 2.2, "crystal2", 0.4), ("rect", 4.0, -8.5, 0.9, 2.2, "crystal", 0.4)],
              "small_replace": {0: ".X..Y...X..Y.", 1: ".XY.......YX."}},
        "m": {},
    },
}


def species_variant(species, gender, look):
    """Kopie der Speziesbeschreibung aus crew_species.SPECIES mit Variante."""
    base = copy.deepcopy(CS.SPECIES[species])
    v = VARIANTS[species]
    base["colors"].update(v["looks"][look])
    g = v.get(gender, {})
    drop = set(g.get("drop_parts", []))
    base["parts"] = [p for p in base["parts"] if p[5] not in drop] + list(g.get("parts", []))
    base["lines"] = list(base.get("lines", [])) + list(g.get("lines", []))
    rows = list(base["small_map"])
    for i, row in g.get("small_replace", {}).items():
        rows[i] = row
    rows += g.get("small_tail", [])
    base["small_map"] = rows
    return base


def human_variant(gender, look):
    """Farben und Formen des Menschen für crew_human (wird vor dem Bauen eingesetzt)."""
    colors = dict(CH.COLORS)
    colors["skin"] = SKIN[look]
    colors["hair"] = HAIR[gender][look]
    spec = copy.deepcopy(CH.SPECS["gross"])
    small = list(CH.SMALL_MAP)
    if gender == "w":
        spec["parts"].insert(3, ("ell", 0, -6.8, 2.4, 3.0, "hair"))  # Zopf am Hinterkopf
        small = list(HUMAN_SMALL_W)
    return colors, spec, small
