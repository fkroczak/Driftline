"""Instrumente der Spielmusik: Drums, Bass, Flächen, Stabs, Vocal-Chops, Effekte.

Jede Funktion liefert ein Mono- oder Stereo-Array (siehe synth.py) für einen einzelnen Ton/Schlag.
"""

import numpy as np

from synth import (SR, adsr, filt, formant, hz, noise, ns, pan, perc, saw_blep, sine,
                   soft, sweep_filt, tri)


# --- Drums --------------------------------------------------------------------

def kick(rng, punch=1.0, tune=48.0, decay=0.38):
    n = ns(decay + 0.1)
    t = np.arange(n) / SR
    f = tune + (tune * 3.2 - tune) * np.exp(-t / 0.035)
    body = sine(f, n) * np.exp(-t / decay)
    click = filt(noise(ns(0.006), rng), 3500, 0.7, "band") * np.linspace(1, 0, ns(0.006))
    body[: len(click)] += click * 0.5 * punch
    return soft(body * 1.4, 1.6)


def snare(rng, tone=185.0, snap=1.0, decay=0.16):
    n = ns(decay + 0.15)
    t = np.arange(n) / SR
    body = (sine(tone, n) * 0.6 + sine(tone * 1.6, n) * 0.25) * np.exp(-t / 0.05)
    nz = filt(noise(n, rng), 4200, 0.6, "band") + filt(noise(n, rng), 9000, 0.7, "high") * 0.4
    nz *= np.exp(-t / decay) * snap
    return soft(body + nz * 0.9, 1.3)


def clap(rng, decay=0.18):
    n = ns(decay + 0.08)
    t = np.arange(n) / SR
    env = np.zeros(n)
    for k, off in enumerate((0.0, 0.009, 0.019, 0.028)):
        s = ns(off)
        env[s:] += np.exp(-(t[: n - s]) / (0.008 if k < 3 else decay)) * (0.8 if k < 3 else 1.0)
    return filt(noise(n, rng), 1600, 1.1, "band") * env * 1.6


def hat(rng, decay=0.035, bright=8000.0):
    n = ns(decay * 5)
    t = np.arange(n) / SR
    x = filt(noise(n, rng), bright, 0.8, "high") * np.exp(-t / decay)
    return x


def shaker(rng, decay=0.05):
    n = ns(decay * 4)
    t = np.arange(n) / SR
    env = np.minimum(t / 0.012, 1) * np.exp(-t / decay)
    return filt(noise(n, rng), 6500, 1.2, "band") * env


def rim(rng):
    n = ns(0.08)
    t = np.arange(n) / SR
    return (sine(820, n) * 0.6 + filt(noise(n, rng), 2500, 3, "band")) * np.exp(-t / 0.012)


def crash(rng, sec=2.2):
    n = ns(sec)
    t = np.arange(n) / SR
    x = filt(noise(n, rng), 5500, 0.5, "high") * np.exp(-t / (sec * 0.35))
    return np.stack([x, filt(noise(n, rng), 5500, 0.5, "high") * np.exp(-t / (sec * 0.35))])


def riser(rng, sec, top=9000.0):
    """Rauschanstieg vor einem Einsatz."""
    n = ns(sec)
    t = np.linspace(0, 1, n)
    x = noise(n, rng)
    y = sweep_filt(x, 300 * (top / 300) ** np.linspace(0, 1, 64), q=2.0, mode="band")
    return pan(y * t ** 2, 0.0)


def downlifter(rng, sec):
    n = ns(sec)
    t = np.linspace(0, 1, n)
    y = sweep_filt(noise(n, rng), 8000 * (200 / 8000) ** np.linspace(0, 1, 64), q=1.5, mode="band")
    return y * (1 - t) ** 2


# --- Bass ---------------------------------------------------------------------

def sub(note, sec, glide_from=None, drive=1.6):
    n = ns(sec)
    f = np.full(n, float(hz(note)))
    if glide_from is not None:
        g = min(ns(0.06), n)
        f[:g] = np.linspace(float(hz(glide_from)), float(hz(note)), g)
    x = sine(f, n) + 0.18 * sine(f * 2, n)
    return soft(x * adsr(n, 0.004, 0.25, 0.85, 0.03), drive)


def reese(note, sec, cutoff=520.0, detune=0.011):
    n = ns(sec)
    f = float(hz(note))
    x = saw_blep(f * (1 - detune), n) + saw_blep(f * (1 + detune), n, 0.37) + 0.8 * sine(f / 2, n)
    x = filt(x, cutoff, 0.9)
    return soft(x * 0.5 * adsr(n, 0.008, 0.3, 0.9, 0.04), 2.0)


def acid(note, sec, cutoff=900.0, accent=0.5):
    n = ns(sec)
    x = saw_blep(float(hz(note)), n)
    env = np.exp(-np.arange(64) / (12 - 6 * accent))
    cuts = cutoff * (0.6 + (2.5 + 3 * accent) * env)
    y = sweep_filt(x, cuts, q=4.5, block=512)
    return soft(y * adsr(n, 0.002, 0.15, 0.6, 0.02), 2.5)


# --- Flächen, Akkorde, Melodie ------------------------------------------------

def supersaw(notes, sec, rng, voices=5, spread=0.012, attack=0.6, release=0.8):
    """Breite Fläche: je Ton mehrere verstimmte Sägezähne, links/rechts verteilt."""
    n = ns(sec)
    out = np.zeros((2, n))
    for note in notes:
        f = float(hz(note))
        for v in range(voices):
            d = (v / (voices - 1) - 0.5) * 2 * spread if voices > 1 else 0.0
            p = (v / (voices - 1) - 0.5) * 1.6 if voices > 1 else 0.0
            out += pan(saw_blep(f * (1 + d), n, rng.uniform()), p)
    out /= len(notes) * voices ** 0.7
    return out * adsr(n, attack, 1.0, 0.85, release)


def warm_pad(notes, sec, rng, attack=1.2, release=1.5):
    """Weichere Fläche aus Dreieck + Sinus mit leichter Schwebung (für ruhige Stücke)."""
    n = ns(sec)
    out = np.zeros((2, n))
    t = np.arange(n) / SR
    for note in notes:
        f = float(hz(note))
        for p, d in ((-0.7, -0.004), (0.7, 0.004)):
            vib = 1 + 0.002 * np.sin(2 * np.pi * (0.25 + rng.uniform(0, 0.2)) * t)
            out += pan(tri(f * (1 + d) * vib, n, rng.uniform()) * 0.7 + sine(f * 2 * vib, n) * 0.15, p)
    out /= len(notes) * 1.5
    return out * adsr(n, attack, 1.0, 0.9, release)


def stab(notes, sec, rng, cutoff=2600.0):
    """Rave-Akkordstab: kurzer Sägezahn-Akkord mit Filterhüllkurve."""
    n = ns(sec)
    x = np.zeros(n)
    for note in notes:
        f = float(hz(note))
        x += saw_blep(f * 0.996, n, rng.uniform()) + saw_blep(f * 1.004, n, rng.uniform())
    x /= len(notes) * 2
    env = np.exp(-np.arange(64) / 10)
    y = sweep_filt(x, cutoff * (0.25 + env * 1.2), q=1.4, block=512)
    return y * perc(n, 0.002, sec * 0.45)


def pluck(note, sec, rng, bright=3500.0, wave="saw"):
    n = ns(sec)
    f = float(hz(note))
    x = saw_blep(f, n, rng.uniform()) if wave == "saw" else tri(f, n) + 0.3 * saw_blep(f * 2, n)
    env = np.exp(-np.arange(64) / 6)
    y = sweep_filt(x, bright * (0.12 + env), q=1.2, block=512)
    return y * perc(n, 0.002, sec * 0.35)


def keys(notes, sec, rng):
    """E-Piano-artiger Akkord (FM-Glocke, weich)."""
    n = ns(sec)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for note in notes:
        f = float(hz(note))
        idx = 1.6 * np.exp(-t / 0.4)
        x += np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 14 * t) * 0.15
                    + idx * np.sin(2 * np.pi * f * t))
    return x / len(notes) * perc(n, 0.003, sec * 0.5)


def vox(note, sec, vowel, rng, vib=0.0, breath=0.12, slide=0.0):
    """Synthetischer Vocal-Chop: Stimmquelle (Sägezahn + Hauch) durch Vokalformanten."""
    n = ns(sec)
    t = np.arange(n) / SR
    f = float(hz(note)) * (1 + vib * 0.012 * np.sin(2 * np.pi * 5.5 * t))
    if slide:
        f = f * 2 ** (slide / 12 * np.exp(-t / 0.05))
    src = saw_blep(f, n, rng.uniform()) + breath * noise(n, rng)
    y = formant(src, vowel)
    y = filt(y, 180, 0.7, "high")
    return y * adsr(n, 0.006, 0.12, 0.75, min(0.05, sec * 0.3))


def vox_pad(notes, sec, vowel, rng):
    """Chor-Fläche ("aah"): mehrere Stimmen, leicht verstimmt, langsam ein."""
    n = ns(sec)
    out = np.zeros((2, n))
    for i, note in enumerate(notes):
        for p in (-0.6, 0.6):
            v = vox(note + rng.uniform(-0.08, 0.08), sec, vowel, rng, vib=0.6, breath=0.25)
            out += pan(v, p * (1 if i % 2 else -1))
    return out / (len(notes) * 2) * adsr(n, 0.9, 1.0, 1.0, 1.0)
