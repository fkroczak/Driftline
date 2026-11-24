"""Kleine DSP-Bausteine für die Soundeffekte (nur numpy).

Alles arbeitet mit Mono-float64-Arrays bei SR Hz. Frequenzen dürfen Arrays sein
(Sweeps), Filter dürfen zeitlich veränderliche Grenzfrequenzen haben.
"""

import math
import struct
import wave

import numpy as np

SR = 44100


def n_of(dur):
    return max(int(round(dur * SR)), 1)


def time(dur):
    return np.arange(n_of(dur)) / SR


def _as_arr(v, n):
    if np.isscalar(v):
        return np.full(n, float(v))
    v = np.asarray(v, dtype=float)
    if len(v) != n:
        v = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(v)), v)
    return v


def sweep(a, b, dur, curve="exp"):
    """Verlauf von a nach b über dur Sekunden (exp oder lin)."""
    x = np.linspace(0, 1, n_of(dur))
    if curve == "exp" and a > 0 and b > 0:
        return a * (b / a) ** x
    return a + (b - a) * x


def phase(freq, dur):
    f = _as_arr(freq, n_of(dur))
    return np.cumsum(2 * np.pi * f / SR)


def sine(freq, dur, ph=0.0):
    return np.sin(phase(freq, dur) + ph)


def square(freq, dur, duty=0.5):
    p = (phase(freq, dur) / (2 * np.pi)) % 1.0
    return np.where(p < duty, 1.0, -1.0)


def saw(freq, dur):
    p = (phase(freq, dur) / (2 * np.pi)) % 1.0
    return 2 * p - 1


def tri(freq, dur):
    p = (phase(freq, dur) / (2 * np.pi)) % 1.0
    return 4 * np.abs(p - 0.5) - 1


def noise(dur, seed=0):
    return np.random.default_rng(seed).uniform(-1, 1, n_of(dur))


def env(dur, attack=0.005, decay=None, curve=4.0, hold=0.0):
    """Hüllkurve: linearer Anstieg, Halten, exponentielles Abklingen bis Ende."""
    n = n_of(dur)
    t = np.arange(n) / SR
    e = np.ones(n)
    if attack > 0:
        e = np.minimum(t / attack, 1.0)
    rest = np.clip((t - attack - hold) / max((decay or dur) - attack - hold, 1e-6), 0, 1)
    return e * np.exp(-curve * rest) * (1 - rest) ** 0.5


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = n_of(fin), n_of(fout)
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def svf(x, cutoff, q=0.7, mode="low"):
    """Zustandsvariables Filter (Chamberlin, 2x überabgetastet). mode: low, band, high."""
    n = len(x)
    fc = np.clip(_as_arr(cutoff, n), 10, SR / 4.2)
    f = 2 * np.sin(np.pi * fc / (2 * SR))
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty(n)
    sel = {"low": 0, "band": 1, "high": 2}[mode]
    for i in range(n):
        xi = x[i]
        fi = f[i]
        for _ in range(2):
            low += fi * band
            high = xi - low - damp * band
            band += fi * high
        out[i] = low if sel == 0 else (band if sel == 1 else high)
    return out


def lowpass(x, cutoff, q=0.7):
    return svf(x, cutoff, q, "low")


def highpass(x, cutoff, q=0.7):
    return svf(x, cutoff, q, "high")


def bandpass(x, cutoff, q=2.0):
    return svf(x, cutoff, q, "band")


def onepole(x, cutoff):
    """Sanfter Tiefpass erster Ordnung (schnell, für Rauschfärbung)."""
    a = math.exp(-2 * math.pi * cutoff / SR)
    out = np.empty_like(x)
    y = 0.0
    for i in range(len(x)):
        y = (1 - a) * x[i] + a * y
        out[i] = y
    return out


def drive(x, amount=2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def crush(x, steps=16):
    return np.round(x * steps) / steps


def mix(*parts):
    """Teile (Array oder (Array, Startzeit)) zu einem Signal addieren."""
    items = [(p, 0.0) if isinstance(p, np.ndarray) else p for p in parts]
    n = max(n_of(start) + len(a) for a, start in items)
    out = np.zeros(n)
    for a, start in items:
        s = n_of(start) if start > 0 else 0
        out[s:s + len(a)] += a
    return out


def pad(x, dur):
    n = n_of(dur)
    return np.concatenate([x, np.zeros(max(n - len(x), 0))])[:max(n, len(x))]


def _fft_convolve(x, h):
    n = len(x) + len(h) - 1
    size = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(h, size), size)
    return y[:n]


def reverb(x, size=0.6, wet=0.25, damp=4000, seed=7):
    """Hall über gefaltetes, abklingendes Rauschen (Raumgefühl im Schiff)."""
    h = noise(size, seed) * np.exp(-6.0 * time(size) / size)
    h = onepole(h, damp)
    h[: n_of(0.008)] = 0  # Vorverzögerung
    h /= np.sqrt(np.sum(h ** 2)) + 1e-9
    y = _fft_convolve(np.concatenate([x, np.zeros(n_of(size))]), h)[: len(x) + n_of(size)]
    dry = np.concatenate([x, np.zeros(n_of(size))])
    return dry * (1 - wet * 0.5) + y * wet


def echo(x, delay=0.12, feedback=0.35, taps=4):
    d = n_of(delay)
    out = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        out[d * k: d * k + len(x)] += x * feedback ** k
    return out


def metal(freq, dur, partials=(1.0, 2.76, 5.40, 8.93), decay=6.0, seed=1):
    """Unharmonische Teiltöne: Metallklang (Rumpf, Werkzeug, Luke)."""
    rng = np.random.default_rng(seed)
    t = time(dur)
    out = np.zeros(len(t))
    for k, p in enumerate(partials):
        detune = 1 + rng.uniform(-0.01, 0.01)
        out += np.sin(2 * np.pi * freq * p * detune * t + rng.uniform(0, 6)) * np.exp(-decay * (1 + k * 0.6) * t) / (1 + k * 0.7)
    return out


def crackle(dur, rate=40, seed=3, length=0.004):
    """Knistern: zufällige kurze Rauschimpulse."""
    rng = np.random.default_rng(seed)
    out = np.zeros(n_of(dur))
    count = int(rate * dur)
    ln = n_of(length)
    for _ in range(count):
        s = rng.integers(0, max(len(out) - ln, 1))
        amp = rng.uniform(0.2, 1.0) ** 2
        out[s: s + ln] += rng.uniform(-1, 1, ln) * np.exp(-np.linspace(0, 5, ln)) * amp
    return out


def tone(freq, dur, wave_fn=sine, attack=0.004, curve=5.0):
    return wave_fn(freq, dur) * env(dur, attack, curve=curve)


def notes(seq, wave_fn=sine, gap=0.0, curve=5.0, harmonics=(1.0,), detune=0.0):
    """Folge (Frequenz, Dauer) als Töne hintereinander. Frequenz 0 = Pause."""
    parts = []
    t = 0.0
    for f, d in seq:
        if f > 0:
            s = np.zeros(n_of(d * 1.6))
            for k, h in enumerate(harmonics):
                s += wave_fn(f * (k + 1), d * 1.6) * h
                if detune:
                    s += wave_fn(f * (k + 1) * (1 + detune), d * 1.6) * h * 0.6
            parts.append((s * env(d * 1.6, 0.004, curve=curve), t))
        t += d + gap
    return mix(*parts)


def normalize(x, peak_db=-1.0):
    peak = np.max(np.abs(x)) + 1e-9
    return x / peak * 10 ** (peak_db / 20)


def trim(x, floor_db=-60.0, tail=0.03):
    """Stille am Ende abschneiden (Hallfahnen laufen sonst lange leer)."""
    above = np.nonzero(np.abs(x) > 10 ** (floor_db / 20) * np.max(np.abs(x)))[0]
    if len(above) == 0:
        return x
    end = min(above[-1] + n_of(tail), len(x))
    return fade(x[:end], 0.0005, tail)


def loopify(x, xfade=0.25):
    """Nahtlose Schleife: Ende in den Anfang überblenden."""
    n = n_of(xfade)
    body = x[:-n].copy()
    tail = x[-n:]
    ramp = np.linspace(0, 1, n)
    body[:n] = body[:n] * ramp + tail * (1 - ramp)
    return body


def write_wav(path, x, loop=False):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    if loop:
        # smpl-Chunk mit Schleifenpunkten anhängen: Godot erkennt die Schleife beim Import.
        frames = len(x)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
        chunk = b"smpl" + struct.pack("<I", len(smpl)) + smpl
        with open(path, "r+b") as f:
            f.seek(0, 2)
            f.write(chunk)
            size = f.tell() - 8
            f.seek(4)
            f.write(struct.pack("<I", size))
