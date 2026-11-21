"""Erzeugt alle Grafiken unter art/ neu.  Aufruf:  python3 tools/artgen/build.py"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import pipeline as P
import crew_human as CH
import ship_human_freighter as FR
import ship_pirate_cutter as PC

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
        if size == "gross":
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
    palette_files()
    crew = build_crew()
    ship = build_freighter()
    build_cutter()
    previews(crew, ship)
    print("fertig:", ART)
