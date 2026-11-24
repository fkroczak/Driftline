"""Erzeugt alle Grafiken unter art/ neu.  Aufruf:  python3 tools/artgen/build.py"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import pipeline as P
import crew_human as CH
import crew_species as CS
import crew_variants as CV
import ship_human_freighter as FR
import ship_pirate_cutter as PC
import ship_enemies as SE

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "art")


def path(*p):
    full = os.path.join(ART, *p)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def save_sprite(img, rel):
    img.save(path("export", "1x", rel))
    P.upscale(img).save(path("export", "4x", rel))


def build_crew(species="mensch"):
    sheets = {}
    for size in ("gross", "klein"):
        if species != "mensch":
            if size == "gross":
                (w, h), shadow, make = CS.SIZE, CS.SHADOW, lambda d: CS.build_svg(species, d)
            else:
                (w, h), shadow, make = CH.SMALL_SIZE, CH.SMALL_SHADOW, lambda d: CS.build_svg_small(species, d)
        elif size == "gross":
            w, h = CH.SPECS["gross"]["size"]
            shadow, make = CH.SPECS["gross"]["shadow"], lambda d: CH.build_svg("gross", d)
        else:
            (w, h), shadow, make = CH.SMALL_SIZE, CH.SMALL_SHADOW, CH.build_svg_small
        frames = []
        for d in CH.DIRECTIONS:
            svg = make(d)
            with open(path("source", "crew", f"{species}_{size}_{d}.svg"), "w") as f:
                f.write(svg)
            img = P.process(svg, w, h, shadow)
            save_sprite(img, f"crew/{species}_{size}_{d}.png")
            frames.append(img)
        sheet = Image.new("RGBA", (w * 4, h), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.alpha_composite(fr, (i * w, 0))
        save_sprite(sheet, f"crew/{species}_{size}_sheet.png")
        sheets[size] = dict(zip(CH.DIRECTIONS, frames))
    return sheets


def build_freighter():
    svg = FR.build_svg()
    with open(path("source", "ships", "mensch_frachter.svg"), "w") as f:
        f.write(svg)
    img = P.process(svg, FR.W, FR.H, 3)
    save_sprite(img, "ships/mensch_frachter.png")
    return img


def build_cutter():
    svg = PC.build_svg()
    with open(path("source", "ships", "piraten_kutter.svg"), "w") as f:
        f.write(svg)
    img = P.process(svg, PC.W, PC.H, 3)
    save_sprite(img, "ships/piraten_kutter.png")
    P.on_space(P.upscale(img), 40).save(path("preview", "piraten_kutter.png"))
    return img


# Besatzung an Bord für die Vorschau: (Kachel-Spalte, Kachel-Zeile, Blickrichtung)
ON_BOARD = [(10, 3, "rechts"), (7, 7, "rechts"), (1, 0, "unten"), (6, 3, "oben"),
            (8, 4, "unten"), (2, 7, "rechts"), (5, 1, "links")]


def previews(crew, ship):
    # Schiff mit kleiner Crew an Bord
    board = ship.copy()
    for c, r, d in ON_BOARD:
        board.alpha_composite(crew["klein"][d], (FR.X0 + c * FR.T - 1, FR.Y0 + r * FR.T - 1))
    P.on_space(P.upscale(board), 40).save(path("preview", "mensch_frachter_an_bord.png"))
    P.on_space(P.upscale(ship), 40).save(path("preview", "mensch_frachter.png"))
    # Größenvergleich: klein (x8) neben gross (x4) – beide auf gleicher Anzeigehöhe
    big = Image.new("RGBA", (40 * 4, 44), (0, 0, 0, 0))
    small = Image.new("RGBA", (16 * 4, 16), (0, 0, 0, 0))
    for i, d in enumerate(CH.DIRECTIONS):
        big.alpha_composite(crew["gross"][d], (i * 40, 0))
        small.alpha_composite(crew["klein"][d], (i * 16, 0))
    P.on_space(P.upscale(big, 4), 32).save(path("preview", "mensch_crew_gross.png"))
    P.on_space(P.upscale(small, 8), 32).save(path("preview", "mensch_crew_klein_x8.png"))


def build_crew_variants():
    """Alle Spezies je Frau/Mann und drei Farben; nur das Sheet (klein) und das Porträt (unten)."""
    out_dir = os.path.join(ROOT, "game", "assets", "crew")
    for sp in ["mensch"] + list(CS.SPECIES):
        for g in CV.GENDERS:
            for look in range(CV.LOOKS):
                key = f"{sp}_{g}{look}"
                if sp == "mensch":
                    colors, spec, small = CV.human_variant(g, look)
                    saved = (CH.COLORS, CH.SPECS["gross"], CH.SMALL_MAP)
                    CH.COLORS, CH.SPECS["gross"], CH.SMALL_MAP = colors, spec, small
                    try:
                        big = lambda d: CH.build_svg("gross", d)
                        little = CH.build_svg_small
                        frames = _variant_frames(big, little, spec["size"], spec["shadow"])
                    finally:
                        CH.COLORS, CH.SPECS["gross"], CH.SMALL_MAP = saved
                else:
                    CS.SPECIES["_v"] = CV.species_variant(sp, g, look)
                    frames = _variant_frames(lambda d: CS.build_svg("_v", d), lambda d: CS.build_svg_small("_v", d), CS.SIZE, CS.SHADOW)
                    del CS.SPECIES["_v"]
                frames["gross"]["unten"].save(os.path.join(out_dir, f"{key}_gross_unten.png"))
                w, h = CH.SMALL_SIZE
                sheet = Image.new("RGBA", (w * 4, h), (0, 0, 0, 0))
                for i, d in enumerate(CH.DIRECTIONS):
                    sheet.alpha_composite(frames["klein"][d], (i * w, 0))
                sheet.save(os.path.join(out_dir, f"{key}_klein_sheet.png"))
                yield key, frames


def _variant_frames(big, little, big_size, big_shadow):
    out = {"gross": {}, "klein": {}}
    for d in CH.DIRECTIONS:
        if d == "unten":
            out["gross"][d] = P.process(big(d), big_size[0], big_size[1], big_shadow)
        out["klein"][d] = P.process(little(d), CH.SMALL_SIZE[0], CH.SMALL_SIZE[1], CH.SMALL_SHADOW)
    return out


def crew_variants_preview(rows):
    """Vorschau: je Spezies eine Zeile, Porträts (x2) und Figuren (x4)."""
    by_species = {}
    for key, frames in rows:
        by_species.setdefault(key.split("_")[0], []).append(frames)
    cell_w, cell_h = 40 * 2 + 4, 44 * 2 + 16 * 4 + 6
    sheet = Image.new("RGBA", (cell_w * 6, cell_h * len(by_species)), (0, 0, 0, 0))
    for r, (sp, frames_list) in enumerate(by_species.items()):
        for c, fr in enumerate(frames_list):
            sheet.alpha_composite(P.upscale(fr["gross"]["unten"], 2), (c * cell_w, r * cell_h))
            sheet.alpha_composite(P.upscale(fr["klein"]["unten"], 4), (c * cell_w + 10, r * cell_h + 44 * 2 + 2))
    P.on_space(sheet, 12).save(path("preview", "crew_varianten.png"))


def build_enemies():
    """Weitere Gegnerschiffe (ship_enemies.py): Sprite, Vorschau, Grafikpunkte fürs JSON."""
    out = {}
    for name in SE.SHIPS:
        svg = SE.build_svg(name)
        with open(path("source", "ships", f"gegner_{name}.svg"), "w") as f:
            f.write(svg)
        w, h = SE.SHIPS[name]["size"]
        img = P.process(svg, w, h, 3)
        save_sprite(img, f"ships/gegner_{name}.png")
        P.on_space(P.upscale(img), 40).save(path("preview", f"gegner_{name}.png"))
        out[name] = SE.meta(name)
    return out


def species_preview(all_crew):
    """Alle Spezies nebeneinander: oben groß (x4), darunter klein (x8), je 4 Richtungen."""
    rows = []
    for sheets in all_crew.values():
        big = Image.new("RGBA", (40 * 4, 44), (0, 0, 0, 0))
        small = Image.new("RGBA", (16 * 4, 16), (0, 0, 0, 0))
        for i, d in enumerate(CH.DIRECTIONS):
            big.alpha_composite(sheets["gross"][d], (i * 40, 0))
            small.alpha_composite(sheets["klein"][d], (i * 16, 0))
        rows.append((P.upscale(big, 2), P.upscale(small, 5)))
    W = sum(max(b.width, s.width) for b, s in rows) + 16 * len(rows)
    H = max(b.height + s.height for b, s in rows) + 8
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = 0
    for b, s in rows:
        sheet.alpha_composite(b, (x, 0))
        sheet.alpha_composite(s, (x, b.height + 8))
        x += max(b.width, s.width) + 16
    P.on_space(sheet, 24).save(path("preview", "spezies_crew.png"))


def palette_files():
    with open(path("palette", "hullbound.hex"), "w") as f:
        f.write("\n".join(h.lstrip("#").lower() for h in P.PALETTE_HEX) + "\n")
    with open(path("palette", "hullbound.gpl"), "w") as f:
        f.write("GIMP Palette\nName: Hullbound\nColumns: 8\n#\n")
        for h in P.PALETTE_HEX:
            r, g, b = P.hex2rgb(h)
            f.write(f"{r:3d} {g:3d} {b:3d}\t{h}\n")
    n = len(P.PALETTE_HEX)
    img = Image.new("RGB", (8, (n + 7) // 8), P.hex2rgb(P.SPACE))
    for i, h in enumerate(P.PALETTE_HEX):
        img.putpixel((i % 8, i // 8), P.hex2rgb(h))
    img.resize((img.width * 16, img.height * 16), Image.NEAREST).save(path("palette", "hullbound.png"))


if __name__ == "__main__":
    if sys.argv[1:] == ["gegner"]:
        import json
        import icons
        build_cutter()
        icons.atlas_image().save(os.path.join(ROOT, "game", "assets", "ui", "system_icons.png"))
        print(json.dumps(build_enemies(), indent=1))
        sys.exit(0)
    if sys.argv[1:] == ["crew"]:
        crew_variants_preview(list(build_crew_variants()))
        print("fertig: Crew-Varianten")
        sys.exit(0)
    if sys.argv[1:] == ["spezies"]:
        # Nur die Crew-Sprites der Spezies neu bauen (Mensch, Schiffe und Palette bleiben unberührt)
        all_crew = {sp: build_crew(sp) for sp in CS.SPECIES}
        species_preview(all_crew)
        print("fertig:", ", ".join(CS.SPECIES))
        sys.exit(0)
    palette_files()
    crew = build_crew()
    ship = build_freighter()
    build_cutter()
    previews(crew, ship)
    print("fertig:", ART)
