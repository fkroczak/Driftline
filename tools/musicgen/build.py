"""Erzeugt die Spielmusik: python3 tools/musicgen/build.py [NAME ...] [--wav ORDNER]

- game/assets/music/<name>.ogg: nahtlose Schleife je Stück (Ogg Vorbis über ffmpeg)
- mit --wav: zusätzlich unkomprimiert, zum Anhören und Vergleichen
"""

import argparse
import subprocess
import sys
import tempfile
import time
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from song import render  # noqa: E402
from synth import SR  # noqa: E402
from tracks import TRACKS  # noqa: E402

OUT = HERE.parent.parent / "game" / "assets" / "music"


def write_wav(path, x):
    data = (np.clip(x.T, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("only", nargs="*", help="nur diese Stücke")
    parser.add_argument("--wav", type=Path, help="zusätzlich WAV-Dateien hierhin")
    parser.add_argument("--quality", type=float, default=4.0, help="Vorbis-Qualität (0–10)")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in TRACKS.items():
        if args.only and name not in args.only:
            continue
        t0 = time.time()
        x, song = render(dict(spec))
        with tempfile.TemporaryDirectory() as tmp:
            wav = Path(tmp) / f"{name}.wav"
            write_wav(wav, x)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis",
                            "-q:a", str(args.quality), "-metadata", f"title={spec['title']}",
                            str(OUT / f"{name}.ogg")], check=True)
            if args.wav:
                args.wav.mkdir(parents=True, exist_ok=True)
                write_wav(args.wav / f"{name}.wav", x)
        print(f"{name}: {spec['title']}, {spec['bpm']} BPM, {song.bars} Takte, "
              f"{x.shape[1] / SR:.1f} s ({time.time() - t0:.0f} s Rechenzeit)")


if __name__ == "__main__":
    main()
