"""Arrangement und Mix: aus einer Stück-Beschreibung (siehe tracks.py) eine nahtlose Stereo-Schleife.

Ablauf: Raster aus 16teln (mit Swing) -> Instrumente je Takt nach Abschnitt einsetzen ->
Busse (Drums, Bass, Flächen, Vocals ...) -> Sidechain auf die Kick, Hall, Echo -> Master.
Alle Effekte arbeiten zirkulär, damit das Ende ohne Knacks in den Anfang übergeht.
"""

import numpy as np

import instruments as ins
from synth import (SR, delay_loop, filt, ns, pan, place, reverb_ir, reverb_loop, soft,
                   sweep_filt)

BUSES = ("drums", "bass", "pad", "vox", "voxpad", "stab", "arp", "keys", "fx")
## Zielpegel je Bus (RMS in dBFS, gemessen nur dort, wo er spielt); "mix" im Stück verschiebt in dB.
LEVELS = {"drums": -15, "bass": -17, "pad": -19, "vox": -20, "voxpad": -22, "stab": -22,
          "arp": -24, "keys": -22, "fx": -28}

DRUMS = {
    "2step": {
        "kick": ["X.........X.....", "X.........X..x.."],
        "snare": ["....X.......X...", "....X.......X..."],
        "hat": ["..x...x...x...x.", "..x...x...x.x.x."],
        "shaker": ["o.o.o.o.o.o.o.o.", "o.oxo.o.o.oxo.o."],
        "rim": [".......o.....o..", "...o...o.....o.."],
    },
    "break": {
        "kick": ["X.x.......Xx....", "X.x.......x..x.."],
        "snare": ["....X..o.o..X..o", "....X..o.o..X.oX"],
        "hat": ["x.x.x.x.x.x.x.x.", "x.x.x.xxx.x.x.x."],
        "shaker": ["................", "................"],
        "rim": ["..o.......o.....", "..o....o..o....."],
    },
    "half": {
        "kick": ["X.........x.....", "X.....x...x....."],
        "snare": ["........X.......", "........X......o"],
        "hat": ["x.o.x.o.x.o.x.o.", "x.o.x.o.x.oox.o."],
        "shaker": ["..o...o...o...o.", "..o...o...o...o."],
        "rim": ["......o.......o.", "...o..o.......o."],
    },
    "four": {
        "kick": ["X...X...X...X...", "X...X...X...X..x"],
        "snare": ["....X.......X...", "....X.......X..."],
        "hat": ["..x...x...x...x.", "..x...x...x...x."],
        "shaker": ["xoxoxoxoxoxoxoxo", "xoxoxoxoxoxoxoxo"],
        "rim": ["...o.....o......", "...o.....o...o.."],
    },
    "pulse": {
        "kick": ["X.......X.......", "X.......X.....x."],
        "snare": ["................", "................"],
        "hat": ["....o.......o...", "....o.......o.o."],
        "shaker": ["o.o.o.o.o.o.o.o.", "o.o.o.o.o.o.o.o."],
        "rim": ["................", ".............o.."],
    },
    "tension": {
        "kick": ["X..x..X...x..x..", "X..x..X...x.xx.x"],
        "snare": ["........o.......", "........o.....o."],
        "hat": ["o.o.o.o.o.o.o.o.", "o.o.o.o.o.o.oooo"],
        "shaker": ["................", "................"],
        "rim": ["....o.......o...", "....o.......o..."],
    },
}
FILL = "....X..o.oXoXoXX"
VEL = {"X": 1.0, "x": 0.75, "o": 0.35, ".": 0.0}

BASS = {
    "2step": [(0, 5, 0), (10, 3, 0), (13, 3, 7)],
    "roll": [(0, 3, 0), (3, 3, 0), (8, 2, 12), (10, 4, 0), (14, 2, 10)],
    "long": [(0, 14, 0), (14, 2, 7)],
    "half": [(0, 12, 0), (12, 4, -2)],
    "pulse8": [(i, 1.6, 0) for i in range(0, 16, 2)],
    "drone": [(0, 16, 0)],
    "acid": [(0, 1, 0), (2, 1, 0), (3, 1, 12), (6, 1, 0), (7, 1, 3), (8, 1, 0), (10, 1, 12),
             (11, 1, 0), (12, 1, 7), (14, 1, 10), (15, 1, 0)],
}


class Song:
    def __init__(self, spec):
        self.spec = spec
        self.bpm = spec["bpm"]
        self.swing = spec.get("swing", 0.0)
        self.step = 60.0 / self.bpm / 4
        self.bars = sum(b for b, _ in spec["sections"])
        self.n = ns(self.bars * 16 * self.step)
        self.bus = {b: np.zeros((2, self.n)) for b in BUSES}
        self.rng = np.random.default_rng(spec["seed"])
        self.kicks = []
        # Abschnitt je Takt
        self.layers = []
        self.section_start = set()
        self.section_end = set()
        for bars, layer_str in spec["sections"]:
            self.section_start.add(len(self.layers))
            self.layers += [set(layer_str.split())] * bars
            self.section_end.add(len(self.layers) - 1)

    def pos(self, bar, step):
        sec = (bar * 16 + step) * self.step
        if int(step) % 2 == 1:
            sec += self.swing * self.step
        return ns(sec)

    def add(self, bus, sig, bar, step, gain=1.0, p=0.0, jitter=0.0):
        if sig.ndim == 1:
            sig = pan(sig, p)
        off = ns(self.rng.uniform(0, jitter)) if jitter else 0
        place(self.bus[bus], sig * gain, self.pos(bar, step) + off)

    def chord(self, bar):
        per = self.spec.get("bars_per_chord", 2)
        prog = self.spec["chords"]
        return prog[(bar // per) % len(prog)]

    def has(self, bar, layer):
        return layer in self.layers[bar]


def _bass_root(chord, lo=33):
    r = chord[0] % 12
    while r < lo:
        r += 12
    return r


def _drums(song, bar):
    s = song.spec
    style = DRUMS[s.get("drums", "2step")]
    rng = song.rng
    var = 1 if bar % 4 == 3 else 0
    fill = bar in song.section_end and song.has(bar, "snare") and s.get("fills", True)
    kit = s["_kit"]
    if song.has(bar, "kick"):
        for i, c in enumerate(style["kick"][var]):
            if VEL[c]:
                song.add("drums", kit["kick"], bar, i, 0.7 * VEL[c])
                song.kicks.append((song.pos(bar, i), VEL[c]))
    if song.has(bar, "snare"):
        pat = FILL if fill else style["snare"][var]
        for i, c in enumerate(pat):
            if VEL[c]:
                sn = kit["snare"][rng.integers(len(kit["snare"]))]
                song.add("drums", sn, bar, i, 0.55 * VEL[c], p=rng.uniform(-0.1, 0.1))
                if c == "X" and s.get("clap", True):
                    song.add("drums", kit["clap"], bar, i, 0.35, p=0.15)
    if song.has(bar, "hat"):
        for i, c in enumerate(style["hat"][var]):
            if VEL[c]:
                h = kit["hat"][rng.integers(len(kit["hat"]))]
                song.add("drums", h, bar, i, 0.38 * VEL[c] * rng.uniform(0.8, 1.1), p=0.35)
        if s.get("open_hat", True):
            for i in (6, 14):
                song.add("drums", kit["ohat"], bar, i, 0.16, p=-0.3)
    if song.has(bar, "perc"):
        for i, c in enumerate(style["shaker"][var]):
            if VEL[c]:
                song.add("drums", kit["shaker"], bar, i, 0.14 * VEL[c], p=-0.45)
        for i, c in enumerate(style["rim"][var]):
            if VEL[c]:
                song.add("drums", kit["rim"], bar, i, 0.28 * VEL[c], p=0.5)
    if bar in song.section_start and song.has(bar, "crash"):
        song.add("fx", ins.crash(rng), bar, 0, 0.18)


def _bass(song, bar, cache):
    if not song.has(bar, "bass"):
        return
    s = song.spec
    style = s.get("bass", "2step")
    root = _bass_root(song.chord(bar), s.get("bass_lo", 33))
    prev = None
    for step, length, off in BASS[style]:
        note = root + off
        sec = length * song.step * 0.95
        key = (style, note, length)
        if key not in cache:
            if style == "acid":
                cache[key] = ins.acid(note + 12, sec, s.get("acid_cut", 700), accent=0.8 if off else 0.3)
            elif style == "long" and s.get("reese"):
                cache[key] = ins.reese(note, sec, s.get("reese_cut", 480))
            else:
                cache[key] = ins.sub(note, sec, glide_from=None)
        gain = 0.3 if style in ("acid", "pulse8") else 0.42
        song.add("bass", cache[key], bar, step, gain)
        prev = note
    return prev


def _pads(song, bar):
    s = song.spec
    per = s.get("bars_per_chord", 2)
    if bar % per or not song.has(bar, "pad"):
        return
    chord = song.chord(bar)
    sec = per * 16 * song.step
    if s.get("pad", "saw") == "warm":
        sig = ins.warm_pad(chord, sec + 0.8, song.rng)
        song.add("pad", sig, bar, 0, 1.0)
    else:
        sig = ins.supersaw(chord, sec + 0.6, song.rng, attack=s.get("pad_attack", 0.4))
        song.add("pad", sig, bar, 0, 0.8)


def _voxpad(song, bar):
    per = song.spec.get("bars_per_chord", 2)
    if bar % per or not song.has(bar, "voxpad"):
        return
    chord = [n + 12 if n < 60 else n for n in song.chord(bar)][:3]
    sec = per * 16 * song.step
    song.add("voxpad", ins.vox_pad(chord, sec + 0.8, song.spec.get("voxpad_vowel", "a"), song.rng), bar, 0, 1.6)


def _chord_tones(chord, lo, hi):
    pcs = sorted({n % 12 for n in chord})
    tones = [n for n in range(lo, hi + 1) if n % 12 in pcs]
    return tones


def _vox(song, bar):
    if not song.has(bar, "vox"):
        return
    s = song.spec
    phrase = s["vox"]  # Liste (Takt im Akkord, 16tel, Länge, Stufe, Vokal[, Gleit])
    per = s.get("bars_per_chord", 2)
    tones = _chord_tones(song.chord(bar), *s.get("vox_range", (62, 79)))
    within = bar % per
    for item in phrase:
        b, step, length, deg, vowel = item[:5]
        slide = item[5] if len(item) > 5 else 0.0
        if b != within:
            continue
        note = tones[min(deg, len(tones) - 1)]
        sig = ins.vox(note, length * song.step * 0.9, vowel, song.rng, vib=0.3, slide=slide)
        song.add("vox", sig, bar, step, 0.9, p=song.rng.uniform(-0.25, 0.25))


def _stabs(song, bar):
    if not song.has(bar, "stab"):
        return
    s = song.spec
    chord = song.chord(bar)
    for step, length in s.get("stab_pattern", [(0, 3), (6, 2), (10, 3)]):
        sig = ins.stab([n + 12 for n in chord], length * song.step * 1.4, song.rng, s.get("stab_cut", 2600))
        song.add("stab", sig, bar, step, 0.42, p=song.rng.uniform(-0.3, 0.3))


def _arp(song, bar):
    if not song.has(bar, "arp"):
        return
    s = song.spec
    tones = _chord_tones(song.chord(bar), *s.get("arp_range", (67, 86)))
    pattern = s.get("arp_pattern", [0, 2, 1, 3, 2, 4, 1, 3])
    every = s.get("arp_every", 2)
    for k, i in enumerate(range(0, 16, every)):
        deg = pattern[(k + bar * 3) % len(pattern)] if s.get("arp_rotate") else pattern[k % len(pattern)]
        note = tones[min(deg, len(tones) - 1)]
        sig = ins.pluck(note, every * song.step * 2.2, song.rng, s.get("arp_bright", 3000), s.get("arp_wave", "saw"))
        song.add("arp", sig, bar, i, 0.24, p=0.5 * np.sin(k * 1.3))


def _keys(song, bar):
    if not song.has(bar, "keys"):
        return
    chord = [n + 12 for n in song.chord(bar)]
    for step, length in song.spec.get("keys_pattern", [(0, 6), (6, 4), (10, 6)]):
        song.add("keys", ins.keys(chord, length * song.step * 2.0, song.rng), bar, step, 0.3, p=-0.2)


def _fx(song, bar):
    rng = song.rng
    if bar in song.section_end and song.has(bar, "riser"):
        sec = 2 * 16 * song.step
        sig = ins.riser(rng, sec)
        song.add("fx", sig, bar - 1, 0, 0.16)
    if bar in song.section_start and song.has(bar, "down"):
        song.add("fx", ins.downlifter(rng, 16 * song.step), bar, 0, 0.12, p=-0.2)


def _sidechain(song, depth, release=0.16):
    env = np.zeros(song.n)
    n = ns(release * 3)
    shape = np.exp(-np.arange(n) / ns(release))
    for p, vel in song.kicks:
        seg = shape * vel
        end = min(p + n, song.n)
        env[p:end] = np.maximum(env[p:end], seg[: end - p])
        if p + n > song.n:
            r = p + n - song.n
            env[:r] = np.maximum(env[:r], seg[n - r:])
    return 1 - depth * env


def _level(x, target_db):
    """Bus auf Zielpegel bringen; gemessen nur in Blöcken, in denen er hörbar spielt."""
    blk = 4096
    m = x[:, : x.shape[1] // blk * blk].reshape(2, -1, blk)
    r = np.sqrt(np.mean(m ** 2, axis=(0, 2)))
    if r.max() < 1e-6:
        return x
    active = r[r > r.max() * 0.1]
    rms = np.sqrt(np.mean(active ** 2))
    return x * (10 ** (target_db / 20) / rms)


def _bar_curve(song, fn):
    """Werte je Takt (fn(bar)) als Kurve mit 4 Punkten je Takt."""
    return np.repeat([fn(b) for b in range(song.bars)], 4).astype(float)


def render(spec):
    rng = np.random.default_rng(spec["seed"] + 100)
    spec["_kit"] = {
        "kick": ins.kick(rng, tune=spec.get("kick_tune", 48), decay=spec.get("kick_decay", 0.38)),
        "snare": [ins.snare(rng, spec.get("snare_tone", 185)) for _ in range(3)],
        "clap": ins.clap(rng),
        "hat": [ins.hat(rng, 0.03 + 0.01 * k) for k in range(3)],
        "ohat": ins.hat(rng, 0.16, 7000),
        "shaker": ins.shaker(rng),
        "rim": ins.rim(rng),
    }
    song = Song(spec)
    bass_cache = {}
    for bar in range(song.bars):
        _drums(song, bar)
        _bass(song, bar, bass_cache)
        _pads(song, bar)
        _voxpad(song, bar)
        _vox(song, bar)
        _stabs(song, bar)
        _arp(song, bar)
        _keys(song, bar)
        _fx(song, bar)
    b = song.bus

    # Drums: in Abschnitten mit "lp" gedämpft (Tiefpass), sonst offen
    cut = _bar_curve(song, lambda bar: spec.get("lp_cut", 700) if song.has(bar, "lp") else 18000)
    if np.any(cut < 18000):
        b["drums"] = sweep_filt(b["drums"], cut, q=0.8, circular=True)
    b["drums"] = soft(b["drums"] * 1.1, 1.2)

    # Flächen: langsam atmender Filter, im Break offener
    t = np.linspace(0, song.bars, song.bars * 8)
    base = spec.get("pad_cut", 1500)
    lfo = base * (1 + 0.5 * np.sin(2 * np.pi * t / 8))
    b["pad"] = sweep_filt(b["pad"], lfo, q=1.0, circular=True)
    b["pad"] = filt(b["pad"], 150, 0.7, "high", True)
    b["keys"] = filt(b["keys"], 200, 0.7, "high", True)

    g = spec.get("mix", {})
    for name in BUSES:
        b[name] = _level(b[name], LEVELS[name] + g.get(name, 0.0))

    # Sidechain-Pumpen
    sc = _sidechain(song, spec.get("pump", 0.6))
    sc_soft = _sidechain(song, spec.get("pump", 0.6) * 0.5)
    for name in ("pad", "voxpad", "stab", "arp", "keys"):
        b[name] = b[name] * sc
    b["bass"] = b["bass"] * _sidechain(song, 0.85, 0.09)
    b["vox"] = b["vox"] * sc_soft

    # Echo und Hall
    dly = delay_loop(b["vox"], 3 * song.step, fb=0.42, taps=5) - b["vox"]
    arp_dly = delay_loop(b["arp"], 3 * song.step, fb=0.35, taps=4) - b["arp"]
    ir_big = reverb_ir(spec.get("hall", 3.2), 5500, spec["seed"])
    ir_small = reverb_ir(0.9, 7000, spec["seed"] + 1)
    send_big = (b["vox"] * 0.7 + dly * 0.4 + b["voxpad"] * 0.8 + b["pad"] * 0.35 + b["stab"] * 0.45
                + b["arp"] * 0.35 + b["keys"] * 0.4 + b["fx"] * 0.4)
    wet_big = reverb_loop(filt(send_big, 300, 0.7, "high", True), ir_big)
    wet_small = reverb_loop(filt(b["drums"], 500, 0.7, "high", True), ir_small)

    if spec.get("_debug"):
        for name in BUSES:
            r = np.sqrt(np.mean(b[name] ** 2)) + 1e-9
            print(f"  {name:7s} {20 * np.log10(r):6.1f} dB")
    mix = (b["drums"] + b["bass"] + b["pad"] + b["voxpad"] + b["vox"] + dly * 0.35 + b["stab"]
           + b["arp"] + arp_dly * 0.4 + b["keys"] + b["fx"]
           + wet_big * 10 ** (g.get("reverb", 0.0) / 20) * 0.6 + wet_small * 0.12)

    # Leichtes Bandrauschen für Wärme
    hiss = filt(rng.standard_normal((2, song.n)), 6000, 0.5, "low", True) * 0.0025
    mix = filt(mix + hiss, 30, 0.7, "high", True)
    mix = mix + filt(mix, 7000, 0.6, "high", True) * 0.5  # etwas Luft obenrum
    mix = mix / (np.max(np.abs(mix)) + 1e-9)
    mix = soft(mix * spec.get("drive", 1.6), 1.0)
    return mix / (np.max(np.abs(mix)) + 1e-9) * 10 ** (spec.get("peak_db", -1.0) / 20), song
