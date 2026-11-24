"""Erzeugt alle Soundeffekte: python3 tools/sfxgen/build.py [--preview ORDNER]

- game/assets/sfx/<name>.wav: die gewählte Variante jedes Effekts (siehe CHOICE in sounds.py)
- mit --preview: alle Varianten als <name>_<a|b|c>.wav in ORDNER, zum Vergleichen
"""

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from dsp import normalize, trim, write_wav  # noqa: E402
from sounds import CHOICE, SOUNDS  # noqa: E402

OUT = HERE.parent.parent / "game" / "assets" / "sfx"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", type=Path, help="alle Varianten zusätzlich hierhin")
    parser.add_argument("only", nargs="*", help="nur diese Effekte")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.preview:
        args.preview.mkdir(parents=True, exist_ok=True)
    for name, (variants, _desc, _group, peak, loop) in SOUNDS.items():
        if args.only and name not in args.only:
            continue
        chosen = CHOICE.get(name, 0)
        for i, fn in enumerate(variants):
            if i != chosen and not args.preview:
                continue
            x = normalize(fn(), peak)
            if not loop:
                x = trim(x)
            if i == chosen:
                write_wav(OUT / f"{name}.wav", x, loop)
            if args.preview:
                write_wav(args.preview / f"{name}_{'abc'[i]}.wav", x, loop)
        print(name, f"({len(variants)} Varianten)" if len(variants) > 1 else "")


if __name__ == "__main__":
    main()
