"""Bausteine für die Spielmusik (nur numpy, schnell: Filter im Frequenzbereich).

Stereo-Signale sind Arrays der Form (2, n). Alles bei SR Hz.
"""

import numpy as np

SR = 44100


def ns(sec):
    return max(int(round(sec * SR)), 1)


def hz(midi):
    return 440.0 * 2 ** ((np.asarray(midi, dtype=float) - 69) / 12)


# --- Oszillatoren -------------------------------------------------------------

def phase(freq, n, ph0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return ph0 + np.cumsum(f / SR)


def saw_blep(freq, n, ph0=0.0):
    """Sägezahn mit PolyBLEP gegen Aliasing."""
    p = phase(freq, n, ph0) % 1.0
    dt = np.broadcast_to(np.asarray(freq, dtype=float) / SR, (n,))
    y = 2 * p - 1
    a = p < dt
    t = p[a] / dt[a]
    y[a] -= t + t - t * t - 1
    b = p > 1 - dt
    t = (p[b] - 1) / dt[b]
    y[b] -= t * t + t + t + 1
    return y


def sine(freq, n, ph0=0.0):
    return np.sin(2 * np.pi * phase(freq, n, ph0))


def tri(freq, n, ph0=0.0):
    p = phase(freq, n, ph0) % 1.0
    return 4 * np.abs(p - 0.5) - 1


def noise(n, rng):
    return rng.uniform(-1, 1, n)


# --- Hüllkurven ---------------------------------------------------------------

def adsr(n, a=0.005, d=0.1, s=0.7, r=0.1, gate=None):
    """ADSR über n Samples; gate = Sekunden bis zum Loslassen (Standard: n - r)."""
    t = np.arange(n) / SR
    g = (n / SR - r) if gate is None else gate
    e = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6) * 3))
    rel = np.clip((t - g) / max(r, 1e-6), 0, 1)
    return e * (1 - rel) ** 2


def perc(n, a=0.001, decay=0.2):
    t = np.arange(n) / SR
    return np.minimum(t / max(a, 1e-6), 1) * np.exp(-t / max(decay, 1e-6))


# --- Filter im Frequenzbereich ------------------------------------------------

def _resp(f, cutoff, q, mode):
    w = f / max(cutoff, 1.0)
    if mode == "low":
        mag = 1 / np.sqrt((1 - w ** 2) ** 2 + (w / q) ** 2)
    elif mode == "high":
        mag = w ** 2 / np.sqrt((1 - w ** 2) ** 2 + (w / q) ** 2)
    else:  # band
        mag = (w / q) / np.sqrt((1 - w ** 2) ** 2 + (w / q) ** 2)
    return mag


def filt(x, cutoff, q=0.707, mode="low", circular=False):
    """Statisches Filter (12 dB/Okt.-Kurve) per FFT. x: mono oder stereo.
    circular: Ausschwingen am Ende läuft am Anfang weiter (für Schleifen)."""
    n = x.shape[-1]
    size = n if circular else 1 << (n - 1).bit_length()
    f = np.fft.rfftfreq(size, 1 / SR)
    X = np.fft.rfft(x, size, axis=-1) * _resp(f, cutoff, q, mode)
    return np.fft.irfft(X, size, axis=-1)[..., :n]


def sweep_filt(x, cutoffs, q=0.707, mode="low", block=2048, circular=False):
    """Filter mit wanderndem Cutoff (STFT, Hann, 75 % Überlappung).
    cutoffs: Array beliebiger Länge, wird über x gestreckt. circular: für Schleifen."""
    mono = x.ndim == 1
    xs = x[None, :] if mono else x
    n = xs.shape[1]
    hop = block // 4
    win = np.hanning(block)
    if circular:
        pad = np.concatenate([xs[:, -block:], xs, xs[:, :block]], axis=1)
    else:
        pad = np.concatenate([np.zeros((xs.shape[0], block)), xs, np.zeros((xs.shape[0], block))], axis=1)
    out = np.zeros_like(pad)
    norm = np.zeros(pad.shape[1])
    f = np.fft.rfftfreq(block, 1 / SR)
    cut = np.interp(np.linspace(0, 1, pad.shape[1] // hop + 1), np.linspace(0, 1, len(cutoffs)), cutoffs)
    for k, start in enumerate(range(0, pad.shape[1] - block, hop)):
        seg = pad[:, start:start + block] * win
        Y = np.fft.rfft(seg, axis=1) * _resp(f, cut[k], q, mode)
        out[:, start:start + block] += np.fft.irfft(Y, block, axis=1) * win
        norm[start:start + block] += win ** 2
    out = out / np.maximum(norm, 1e-6)
    out = out[:, block:block + n]
    return out[0] if mono else out


def formant(x, vowel):
    """Vokalfilter: drei Bandpässe (Formanten) addiert."""
    table = {
        "a": ((800, 1.0), (1150, 0.6), (2900, 0.25)),
        "o": ((450, 1.0), (800, 0.5), (2830, 0.15)),
        "u": ((325, 1.0), (700, 0.3), (2530, 0.1)),
        "e": ((400, 1.0), (1700, 0.5), (2600, 0.3)),
        "i": ((300, 1.0), (2300, 0.4), (3000, 0.3)),
    }
    y = np.zeros_like(x)
    for fc, g in table[vowel]:
        y += filt(x, fc, q=fc / 90.0, mode="band") * g
    return y


# --- Effekte ------------------------------------------------------------------

def fft_conv(x, h):
    n = x.shape[-1] + h.shape[-1] - 1
    size = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, size, axis=-1) * np.fft.rfft(h, size, axis=-1), size, axis=-1)[..., :n]


def reverb_ir(sec=2.5, damp=5000, seed=11):
    rng = np.random.default_rng(seed)
    n = ns(sec)
    t = np.arange(n) / SR
    h = rng.standard_normal((2, n)) * np.exp(-6.9 * t / sec)
    h = filt(h, damp, 0.5)
    h[:, : ns(0.02)] = 0
    return h / np.sqrt(np.sum(h ** 2, axis=1, keepdims=True))


def reverb_loop(x, ir):
    """Hall für eine Schleife: der Nachhall vom Ende läuft am Anfang weiter (nahtlos)."""
    n = x.shape[-1]
    src = x if x.ndim == 2 else np.stack([x, x])
    y = fft_conv(src, ir)
    out = y[:, :n].copy()
    tail = y[:, n:]
    out[:, : tail.shape[1]] += tail
    return out


def delay_loop(x, sec, fb=0.4, taps=5, pingpong=True):
    """Echo (zirkulär, damit die Schleife nahtlos bleibt)."""
    src = x if x.ndim == 2 else np.stack([x, x])
    out = src.copy()
    d = ns(sec)
    for k in range(1, taps + 1):
        tap = np.roll(src, d * k, axis=1) * fb ** k
        if pingpong and k % 2:
            tap = tap[::-1]
        out += tap
    return out


def pan(x, p):
    """Mono nach Stereo, p = -1 (links) .. 1 (rechts), Constant Power."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)])


def soft(x, amount=1.5):
    return np.tanh(x * amount) / np.tanh(amount)


def place(buf, sig, start):
    """sig (mono/stereo) ab Sample start zirkulär in buf (Stereo) addieren."""
    n = buf.shape[1]
    s = sig if sig.ndim == 2 else np.stack([sig, sig])
    start %= n
    end = start + s.shape[1]
    if end <= n:
        buf[:, start:end] += s
    else:
        first = n - start
        buf[:, start:] += s[:, :first]
        rest = s[:, first:]
        while rest.shape[1] > 0:
            m = min(n, rest.shape[1])
            buf[:, :m] += rest[:, :m]
            rest = rest[:, m:]
