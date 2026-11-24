"""Alle Soundeffekte von Hullbound, prozedural erzeugt.

Jeder Effekt hat eine oder mehrere Varianten (a, b, c). Ins Spiel kommt die Variante aus
CHOICE (Standard: a); die anderen sind Hörvorschläge zum Vergleichen (preview/).
"""

import numpy as np

from dsp import (bandpass, crackle, drive, echo, env, fade, highpass, lowpass, loopify, metal, mix,
                 n_of, noise, notes, onepole, pad, reverb, saw, sine, square, sweep, time, tri)

# Noten
C4, D4, E4, F4, G4, A4, B4 = 261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 493.88
C5, D5, E5, F5, G5, A5, B5 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 987.77
C6, E6, G6 = 1046.5, 1318.5, 1568.0
Eb4, Bb4, Ab4, Eb5 = 311.13, 466.16, 415.3, 622.25


# ---------------------------------------------------------------- Waffen


def laser_pulse_a():
    d = 0.22
    body = saw(sweep(1700, 260, d), d) * 0.5 + square(sweep(1720, 250, d), d, 0.3) * 0.3
    body = lowpass(body, sweep(6000, 900, d), q=1.5)
    zap = highpass(noise(0.04, 1), 3000) * env(0.04, 0.001, curve=6) * 0.5
    return reverb(fade(mix(body * env(d, 0.002, curve=4), zap)), 0.35, 0.18)


def laser_pulse_b():
    d = 0.18
    f = sweep(2400, 400, d)
    fm = sine(f * 1.5, d) * 2.5
    body = np.sin(np.cumsum(2 * np.pi * f / 44100) + fm) * env(d, 0.001, curve=5)
    return reverb(fade(body * 0.8), 0.3, 0.15)


def laser_pulse_c():
    d = 0.2
    a = square(sweep(1200, 300, d), d, 0.25)
    b = square(sweep(1210, 290, d) * 1.5, d, 0.5) * 0.5
    body = lowpass(a + b, sweep(5000, 1200, d), q=2.5) * env(d, 0.001, curve=3.5)
    return reverb(fade(echo(body, 0.06, 0.3, 2)), 0.3, 0.15)


def laser_heavy_a():
    d = 0.55
    f = sweep(950, 70, d)
    body = sum(saw(f * k, d) for k in (1.0, 1.007, 0.993)) / 3
    body = drive(lowpass(body, sweep(5000, 300, d), q=2.0), 2.5)
    sub = sine(sweep(160, 40, d), d) * env(d, 0.003, curve=4)
    charge = sine(sweep(300, 1800, 0.08), 0.08) * env(0.08, 0.07, curve=0.5) * 0.3
    out = mix((charge, 0), (body * env(d, 0.004, curve=3.5) * 0.8 + sub * 0.7, 0.07))
    return reverb(fade(out), 0.6, 0.25)


def laser_heavy_b():
    d = 0.6
    f = sweep(600, 55, d)
    body = square(f, d, 0.4) * 0.6 + saw(f * 2.01, d) * 0.4
    body = lowpass(body, sweep(3000, 200, d), q=4.0)
    hiss = bandpass(noise(d, 4), sweep(5000, 800, d), 1.5) * env(d, 0.002, curve=6) * 0.6
    return reverb(fade(drive(body * env(d, 0.003, curve=3) + hiss, 2.0)), 0.7, 0.3)


def laser_heavy_c():
    d = 0.5
    f = sweep(1400, 90, d, "lin")
    ring = sine(f, d) * sine(f * 0.31 + 40, d)
    body = drive(ring + saw(f * 0.5, d) * 0.5, 3.0)
    body = lowpass(body, sweep(7000, 400, d), q=1.2)
    return reverb(fade(body * env(d, 0.002, curve=3)), 0.6, 0.25)


def cannon_a():
    d = 0.7
    blast = lowpass(noise(d, 11), sweep(5000, 180, d), q=0.9) * env(d, 0.001, curve=7)
    thump = sine(sweep(140, 38, 0.35), 0.35) * env(0.35, 0.002, curve=5)
    click = highpass(noise(0.015, 12), 2500) * 0.6
    mech = metal(420, 0.25, decay=18, seed=3) * 0.25
    out = mix(drive(blast * 1.2 + pad(thump, d) * 1.0, 2.0), click, (mech, 0.04))
    return reverb(fade(out), 0.8, 0.25)


def cannon_b():
    d = 0.6
    blast = lowpass(noise(d, 21), sweep(2500, 120, d), q=1.3) * env(d, 0.001, curve=6)
    thump = sine(sweep(95, 30, 0.45), 0.45) * env(0.45, 0.003, curve=4)
    out = drive(blast + pad(thump, d) * 1.3, 3.0)
    return reverb(fade(echo(out, 0.09, 0.25, 3)), 0.9, 0.3)


def cannon_c():
    d = 0.45
    crack = highpass(noise(0.05, 31), 1500) * env(0.05, 0.0005, curve=8)
    blast = bandpass(noise(d, 32), sweep(1800, 250, d), 1.2) * env(d, 0.001, curve=6) * 1.5
    thump = sine(sweep(180, 50, 0.25), 0.25) * env(0.25, 0.001, curve=6)
    return reverb(fade(drive(mix(crack, blast, thump), 2.0)), 0.5, 0.2)


# ---------------------------------------------------------------- Treffer


def explosion(d=0.9, seed=41, low=3500, sub=90, rough=1.0):
    rumble = lowpass(noise(d, seed), sweep(low, 120, d), q=0.8) * env(d, 0.002, curve=4.5)
    thump = sine(sweep(sub, 28, d * 0.6), d * 0.6) * env(d * 0.6, 0.002, curve=4)
    crk = lowpass(crackle(d, 90 * rough, seed + 1), 5000) * env(d, 0.01, curve=3) * 0.9
    return drive(rumble * 1.3 + pad(thump, d) * 1.1 + crk, 2.0)


def hit_hull_a():
    return reverb(fade(explosion(0.9, 41)), 0.7, 0.25)


def hit_hull_b():
    x = explosion(0.8, 51, low=2200, sub=70)
    clang = metal(190, 0.8, decay=5, seed=52) * 0.35
    return reverb(fade(mix(x, clang)), 0.9, 0.3)


def hit_hull_c():
    x = explosion(0.7, 61, low=5000, sub=110, rough=2.0)
    debris = highpass(crackle(0.6, 60, 62, 0.002), 2000) * 0.5
    return reverb(fade(mix(x, (debris, 0.1))), 0.6, 0.2)


def hit_system():
    d = 0.45
    rng = np.random.default_rng(71)
    f = 120 + rng.uniform(-40, 140, n_of(d))
    buzz = square(onepole(f, 60), d, 0.3) * 0.5
    zaps = bandpass(crackle(d, 120, 72, 0.003), 3500, 1.2) * 2.0
    out = (buzz + zaps) * env(d, 0.002, curve=3)
    return reverb(fade(drive(out, 2.0)), 0.4, 0.2)


def shield_a():
    d = 0.6
    t = time(d)
    shimmer = sum(np.sin(2 * np.pi * f * t + i) for i, f in enumerate((620, 931, 1404, 2107))) / 4
    shimmer *= 1 + 0.5 * np.sin(2 * np.pi * 23 * t)
    sweep_n = bandpass(noise(d, 81), sweep(4000, 900, d), 3.0) * 0.8
    thud = sine(sweep(220, 90, 0.12), 0.12) * env(0.12, 0.001, curve=5) * 0.5
    out = mix((shimmer * 0.7 + sweep_n) * env(d, 0.002, curve=4), thud)
    return reverb(fade(out), 0.7, 0.3)


def shield_b():
    d = 0.55
    f = sweep(900, 450, d)
    wob = sine(f, d) * (1 + 0.6 * sine(sweep(40, 12, d), d))
    zap = highpass(noise(0.06, 82), 3000) * env(0.06, 0.001, curve=5) * 0.6
    return reverb(fade(mix(wob * env(d, 0.002, curve=3.5) * 0.7, zap)), 0.8, 0.35)


def shield_c():
    d = 0.5
    t = time(d)
    tones = (np.sin(2 * np.pi * 1200 * t) + np.sin(2 * np.pi * 1212 * t) + 0.5 * np.sin(2 * np.pi * 2410 * t))
    body = tones * env(d, 0.001, curve=5) * 0.5
    fizz = highpass(noise(d, 83), sweep(6000, 2000, d)) * env(d, 0.001, curve=8) * 0.5
    return reverb(fade(body + fizz), 0.9, 0.4)


def miss():
    d = 0.4
    w = bandpass(noise(d, 91), sweep(2500, 600, d), 4.0) * np.sin(np.linspace(0, np.pi, n_of(d))) ** 2
    return fade(w * 1.2)


# ---------------------------------------------------------------- Schäden an Bord


def fire_start():
    d = 0.8
    woosh = lowpass(noise(d, 101), np.concatenate([sweep(300, 2500, 0.15), sweep(2500, 400, d - 0.15)]), q=1.2)
    woosh *= env(d, 0.06, curve=3.5)
    low = sine(sweep(90, 50, d), d) * env(d, 0.05, curve=4) * 0.5
    crk = crackle(d, 50, 102) * env(d, 0.1, curve=2) * 0.6
    return reverb(fade(drive(woosh * 1.3 + low + crk, 1.5)), 0.5, 0.2)


def fire_loop():
    d = 3.0
    roar = lowpass(noise(d + 0.3, 111), 500, q=0.8) * 0.8
    roar *= 1 + 0.3 * sine(0.7, d + 0.3)
    crk = lowpass(crackle(d + 0.3, 35, 112, 0.006), 4000) * 1.2
    return loopify(roar + crk, 0.3)


def extinguish():
    d = 0.9
    hiss = highpass(noise(d, 121), 2500) * env(d, 0.02, curve=3)
    steam = bandpass(noise(d, 122), sweep(3000, 1500, d), 1.0) * env(d, 0.1, curve=2.5) * 0.6
    return reverb(fade((hiss + steam) * 0.7), 0.4, 0.15)


def breach():
    d = 1.3
    crack = metal(310, 0.6, partials=(1.0, 2.31, 3.89, 5.67, 7.8), decay=7, seed=131) * 0.8
    snap = highpass(noise(0.03, 132), 1500) * env(0.03, 0.0005, curve=6)
    rush = highpass(noise(d, 133), sweep(1500, 4000, d)) * np.minimum(time(d) / 0.15, 1) * env(d, 0.0, curve=1.2) * 0.6
    boom = sine(sweep(110, 40, 0.3), 0.3) * env(0.3, 0.001, curve=5) * 0.7
    return reverb(fade(mix(snap, crack, boom, rush)), 0.8, 0.25)


def breach_fixed():
    parts = []
    for i, f in enumerate((780, 820, 760)):
        parts.append((metal(f, 0.18, decay=22, seed=140 + i) * 0.6, i * 0.11))
        parts.append((highpass(noise(0.02, 145 + i), 3000) * 0.4, i * 0.11))
    seal = sine(sweep(400, 900, 0.15), 0.15) * env(0.15, 0.01, curve=3) * 0.3
    return reverb(fade(mix(*parts, (seal, 0.36))), 0.4, 0.2)


def repaired():
    tick = mix(*((metal(1200, 0.08, decay=40, seed=150 + i) * 0.5, i * 0.07) for i in range(2)))
    chime = notes([(C6, 0.09), (G6, 0.22)], tri, curve=4) * 0.45
    return reverb(fade(mix(tick, (chime, 0.16))), 0.6, 0.3)


def crew_died():
    d = 1.4
    thud = lowpass(noise(0.2, 161), 300) * env(0.2, 0.002, curve=6) * 1.2
    tone = sine(sweep(330, 196, d), d) * 0.4 + sine(sweep(330, 196, d) * 1.5, d) * 0.15
    tone *= env(d, 0.05, curve=3)
    return reverb(fade(mix(thud, (tone, 0.08))), 1.2, 0.35)


def ship_explode():
    d = 2.8
    parts = [(explosion(1.4, 171 + i, low=3000 - i * 300, sub=80 - i * 6), t)
             for i, t in enumerate((0.0, 0.25, 0.55, 0.8, 1.1))]
    tail = lowpass(noise(d, 179), sweep(1200, 80, d), q=0.7) * env(d, 0.05, curve=2.5) * 0.9
    sub = sine(sweep(60, 25, d), d) * env(d, 0.02, curve=2.5) * 0.9
    return reverb(fade(drive(mix(*parts, tail, sub) * 0.7, 1.5)), 1.5, 0.35)


# ---------------------------------------------------------------- Warnungen


def alarm_a():
    seq = [(A5, 0.13), (E5, 0.13), (A5, 0.13), (E5, 0.13)]
    return reverb(fade(notes(seq, square, curve=1.5, gap=0.02) * 0.35), 0.4, 0.2)


def alarm_b():
    d = 1.0
    f = 700 + 300 * np.sin(2 * np.pi * 2.0 * time(d) - np.pi / 2)
    x = lowpass(saw(f, d), 3000) * env(d, 0.01, curve=1.0, hold=0.7)
    return reverb(fade(x * 0.5), 0.4, 0.2)


def alarm_c():
    beep = []
    for i in range(3):
        beep.append((square(1000, 0.07, 0.5) * env(0.07, 0.002, curve=1) * 0.35, i * 0.12))
    return reverb(fade(mix(*beep)), 0.3, 0.2)


def hull_low():
    seq = [(D5, 0.16), (0, 0.04), (D5, 0.16), (0, 0.04), (A4, 0.35)]
    x = notes(seq, square, curve=2.5) * 0.3
    return reverb(fade(lowpass(x, 3500)), 0.5, 0.25)


# ---------------------------------------------------------------- Sprung


def warp_out_a():
    rise_d = 0.5
    rise = sine(sweep(110, 880, rise_d), rise_d) * 0.4 + saw(sweep(55, 440, rise_d), rise_d) * 0.2
    rise = lowpass(rise, sweep(400, 5000, rise_d)) * np.linspace(0.2, 1, n_of(rise_d))
    rise_noise = bandpass(noise(rise_d, 201), sweep(500, 6000, rise_d), 2) * np.linspace(0, 1, n_of(rise_d)) ** 2 * 0.6
    d = 0.9
    whoosh = lowpass(noise(d, 202), sweep(8000, 300, d), q=0.8) * env(d, 0.003, curve=4) * 1.2
    boom = sine(sweep(160, 35, 0.6), 0.6) * env(0.6, 0.002, curve=4)
    return reverb(fade(drive(mix(rise + rise_noise, (whoosh + pad(boom, d), rise_d)), 1.5)), 1.0, 0.3)


def warp_out_b():
    d = 1.3
    f = sweep(80, 2000, 0.55)
    rise = sum(saw(f * k, 0.55) for k in (1, 1.01, 0.5)) / 3
    rise = lowpass(rise, sweep(300, 7000, 0.55), q=3) * np.linspace(0.1, 1, n_of(0.55)) ** 1.5
    zap = sine(sweep(3000, 60, 0.7), 0.7) * env(0.7, 0.002, curve=3) * 0.7
    air = highpass(noise(0.7, 203), sweep(6000, 500, 0.7)) * env(0.7, 0.002, curve=4) * 0.6
    return reverb(fade(drive(pad(mix(rise * 0.6, (zap + air, 0.5)), d), 1.5)), 1.1, 0.35)


def warp_out_c():
    t = time(0.5)
    wobble = sine(sweep(200, 1200, 0.5) * (1 + 0.08 * np.sin(2 * np.pi * sweep(6, 30, 0.5) * t)), 0.5) * np.linspace(0.1, 1, len(t)) * 0.5
    pop = mix(sine(sweep(1800, 200, 0.12), 0.12) * env(0.12, 0.001, curve=4) * 0.6,
              lowpass(noise(0.8, 204), sweep(5000, 200, 0.8)) * env(0.8, 0.001, curve=5))
    return reverb(fade(mix(wobble, (pop, 0.5))), 1.2, 0.35)


def warp_in():
    d = 1.1
    whoosh = lowpass(noise(d, 211), sweep(6000, 250, d), q=0.9) * env(d, 0.02, curve=3.5)
    fall = sine(sweep(900, 120, d), d) * env(d, 0.01, curve=3) * 0.35
    settle = sine(sweep(160, 60, 0.5), 0.5) * env(0.5, 0.05, curve=3) * 0.5
    return reverb(fade(mix(whoosh + fall, (settle, 0.5))), 1.0, 0.3)


def jump_ready():
    seq = [(E5, 0.08), (A5, 0.08), (E6, 0.25)]
    return reverb(fade(notes(seq, tri, curve=4, harmonics=(1.0, 0.2)) * 0.45), 0.7, 0.3)


def distress():
    s, l = 0.07, 0.21
    seq = [(1000, s), (0, s), (1000, s), (0, s), (1000, s), (0, l),
           (1000, l), (0, s), (1000, l), (0, s), (1000, l), (0, l),
           (1000, s), (0, s), (1000, s), (0, s), (1000, s)]
    beeps = notes(seq, sine, curve=0.5) * 0.4
    static = bandpass(noise(len(beeps) / 44100, 221), 2000, 0.8) * 0.08
    return reverb(fade(beeps + static), 0.8, 0.3)


# ---------------------------------------------------------------- Karte und Bedienung


def ui_click():
    d = 0.05
    x = sine(sweep(2400, 1800, d), d) * env(d, 0.0005, curve=9) * 0.5
    return fade(mix(x, highpass(noise(0.01, 231), 4000) * 0.2))


def ui_deny():
    seq = [(150, 0.09), (0, 0.03), (150, 0.12)]
    return fade(lowpass(notes(seq, square, curve=1.5), 1500) * 0.35)


def map_open():
    d = 0.3
    x = sine(sweep(300, 1200, d), d) * env(d, 0.01, curve=4) * 0.35
    s = bandpass(noise(d, 241), sweep(1000, 5000, d), 2) * env(d, 0.05, curve=4) * 0.25
    return reverb(fade(x + s), 0.4, 0.2)


def map_close():
    d = 0.25
    x = sine(sweep(1100, 350, d), d) * env(d, 0.01, curve=4) * 0.35
    s = bandpass(noise(d, 242), sweep(4000, 800, d), 2) * env(d, 0.03, curve=4) * 0.25
    return reverb(fade(x + s), 0.4, 0.2)


def map_select():
    return reverb(fade(notes([(G5, 0.05), (D5 * 2, 0.08)], sine, curve=5) * 0.4), 0.3, 0.2)


def map_travel():
    d = 0.6
    x = tri(sweep(400, 900, d), d) * np.sin(np.linspace(0, np.pi, n_of(d))) * 0.3
    s = bandpass(noise(d, 251), 2500, 3) * np.sin(np.linspace(0, np.pi, n_of(d))) * 0.25
    return reverb(fade(x + s), 0.4, 0.2)


def power_up():
    d = 0.12
    x = square(sweep(500, 1000, d), d, 0.25) * env(d, 0.002, curve=4) * 0.25
    return fade(lowpass(x, 4000))


def power_down():
    d = 0.12
    x = square(sweep(800, 350, d), d, 0.25) * env(d, 0.002, curve=4) * 0.25
    return fade(lowpass(x, 3000))


def door_open():
    d = 0.45
    hiss = bandpass(noise(d, 261), sweep(3000, 1500, d), 1.5) * env(d, 0.01, curve=4) * 0.7
    motor = saw(sweep(90, 140, 0.3), 0.3) * env(0.3, 0.02, curve=2) * 0.15
    clunk = metal(160, 0.15, decay=25, seed=262) * 0.5
    return reverb(fade(mix(hiss, lowpass(motor, 800), (clunk, 0.28))), 0.3, 0.2)


def door_close():
    d = 0.35
    hiss = bandpass(noise(d, 263), sweep(1500, 3000, d), 1.5) * env(d, 0.01, curve=4) * 0.5
    clunk = mix(metal(130, 0.2, decay=20, seed=264) * 0.7, lowpass(noise(0.05, 265), 600) * 0.7)
    return reverb(fade(mix(hiss, (clunk, 0.18))), 0.3, 0.2)


def airlock_open():
    d = 1.5
    clunk = mix(metal(95, 0.4, decay=10, seed=271), lowpass(noise(0.08, 272), 500))
    rush = lowpass(noise(d, 273), sweep(5000, 1500, d)) * np.minimum(time(d) / 0.05, 1) * env(d, 0.0, curve=2.0) * 0.9
    return reverb(fade(mix(clunk * 0.8, (rush, 0.12))), 0.8, 0.25)


def airlock_close():
    d = 0.5
    hiss = highpass(noise(0.25, 274), 2500) * env(0.25, 0.005, curve=5) * 0.5
    clunk = mix(metal(85, 0.45, decay=9, seed=275), lowpass(noise(0.1, 276), 450) * 0.8)
    return reverb(fade(pad(mix(hiss, (clunk * 0.8, 0.12)), d)), 0.8, 0.25)


def crew_select():
    return fade(notes([(B5, 0.035), (E6, 0.06)], sine, curve=6) * 0.35)


def crew_order():
    x = notes([(E5, 0.05), (A5, 0.05), (C6 * 0.95, 0.08)], square, curve=5) * 0.2
    return reverb(fade(lowpass(x, 3500)), 0.3, 0.15)


def weapon_select():
    d = 0.15
    click = highpass(noise(0.01, 281), 3000) * 0.4
    whine = sine(sweep(600, 1600, d), d) * env(d, 0.01, curve=3) * 0.25
    return fade(mix(click, whine))


def target_lock():
    seq = [(1400, 0.035), (0, 0.025), (1400, 0.035), (0, 0.025), (2100, 0.09)]
    return reverb(fade(notes(seq, square, curve=3) * 0.22), 0.3, 0.15)


def weapon_ready():
    x = notes([(A5, 0.04), (E6, 0.07)], tri, curve=6) * 0.35
    return fade(x)


def pause():
    d = 0.22
    x = sine(sweep(900, 300, d), d) * env(d, 0.003, curve=4) * 0.4
    return fade(x)


def resume():
    d = 0.18
    x = sine(sweep(300, 900, d), d) * env(d, 0.003, curve=4) * 0.4
    return fade(x)


def dialog_open():
    static = bandpass(noise(0.25, 291), 2500, 0.8) * env(0.25, 0.01, curve=4) * 0.35
    chirp = notes([(1320, 0.06), (0, 0.04), (1760, 0.09)], sine, curve=4) * 0.35
    return reverb(fade(mix(static, (chirp, 0.15))), 0.5, 0.2)


def dialog_choice():
    return fade(notes([(D5 * 2, 0.04), (A5, 0.07)], tri, curve=6) * 0.35)


def reward():
    seq = [(E6, 0.05), (G6, 0.05), (C6 * 2, 0.16)]
    sparkle = notes(seq, sine, curve=5, harmonics=(1.0, 0.3)) * 0.35
    coin = metal(2600, 0.3, partials=(1.0, 1.5, 2.2), decay=10, seed=301) * 0.2
    return reverb(fade(mix(coin, (sparkle, 0.04))), 0.8, 0.3)


# ---------------------------------------------------------------- Ergebnisse (kurze Jingles)


def victory_a():
    seq = [(C5, 0.12), (E5, 0.12), (G5, 0.12), (C6, 0.5)]
    lead = notes(seq, square, curve=2.5, detune=0.004) * 0.18
    bass = notes([(C4 / 2, 0.36), (G4 / 2, 0.5)], tri, curve=2) * 0.35
    return reverb(fade(lowpass(mix(lead, bass), 4500)), 1.2, 0.3)


def victory_b():
    seq = [(G4, 0.1), (C5, 0.1), (E5, 0.1), (G5, 0.1), (E5, 0.1), (G5, 0.55)]
    lead = notes(seq, tri, curve=2.5, harmonics=(1.0, 0.3, 0.1)) * 0.35
    return reverb(fade(lead), 1.2, 0.35)


def victory_c():
    chords = [((C5, E5, G5), 0.25), ((F5, A5, C6), 0.25), ((G5, B5, D5 * 2), 0.25), ((C5, E5, G5, C6), 0.8)]
    parts, t = [], 0.0
    for freqs, d in chords:
        for f in freqs:
            parts.append((saw(f, d * 1.4) * env(d * 1.4, 0.01, curve=2.5) * 0.12, t))
        t += d
    return reverb(fade(lowpass(mix(*parts), 3000)), 1.4, 0.35)


def defeat():
    seq = [(G4, 0.35), (Eb4, 0.35), (C4, 0.35), (C4 * 0.94, 1.0)]
    lead = notes(seq, saw, curve=2.0, detune=0.005) * 0.18
    lead = lowpass(lead, 1800)
    drone = sine(C4 / 4, 2.6) * env(2.6, 0.3, curve=2) * 0.4
    return reverb(fade(mix(lead, drone)), 1.8, 0.4)


def sector_clear():
    seq = [(C5, 0.1), (G5, 0.1), (C6, 0.1), (E6, 0.1), (G6, 0.45)]
    lead = notes(seq, tri, curve=3, harmonics=(1.0, 0.25)) * 0.35
    pad_ = sum(sine(f, 1.4) for f in (C4, G4, C5)) * env(1.4, 0.2, curve=2.5) * 0.12
    return reverb(fade(mix(pad_, lead)), 1.4, 0.35)


def run_complete():
    seq = [(G4, 0.15), (C5, 0.15), (E5, 0.15), (G5, 0.3), (E5, 0.15), (G5, 0.9)]
    lead = notes(seq, square, curve=2.0, detune=0.003) * 0.15
    lead = lowpass(lead, 4000)
    brass = notes([(C4, 0.6), (F4, 0.3), (G4, 1.0)], saw, curve=1.5, detune=0.006) * 0.12
    brass = lowpass(brass, 1500)
    drums = mix(*((lowpass(noise(0.15, 311 + i), 400) * env(0.15, 0.001, curve=6) * 0.5, i * 0.3) for i in range(6)))
    return reverb(fade(mix(lead, brass, drums)), 1.6, 0.35)


# ---------------------------------------------------------------- Dauerklänge (Schleifen)


def ship_hum():
    d = 6.0
    t = time(d)
    # ganzzahlige Schwingungen je Schleife, damit es nahtlos läuft
    drone = (np.sin(2 * np.pi * 55.0 * t) * 0.5 + np.sin(2 * np.pi * 110.5 * t) * 0.25
             + np.sin(2 * np.pi * 165.0 * t) * 0.08)
    drone *= 1 + 0.15 * np.sin(2 * np.pi * (1 / 3) * t)
    air = lowpass(noise(d + 0.5, 321), 350, q=0.6) * 0.5
    air = loopify(air, 0.5)
    return drone * 0.6 + air


# Name → (Varianten, Beschreibung, Situation, Spitzenpegel dB, Schleife)
SOUNDS = {
    # Waffen
    "laser_pulse": ([laser_pulse_a, laser_pulse_b, laser_pulse_c], "Pulslaser feuert", "Waffen", -3, False),
    "laser_heavy": ([laser_heavy_a, laser_heavy_b, laser_heavy_c], "Schwerlaser feuert", "Waffen", -2, False),
    "cannon": ([cannon_a, cannon_b, cannon_c], "Bordkanone feuert", "Waffen", -2, False),
    "weapon_ready": ([weapon_ready], "Waffe geladen", "Waffen", -12, False),
    "weapon_select": ([weapon_select], "Waffe angewählt", "Waffen", -10, False),
    "target_lock": ([target_lock], "Ziel erfasst", "Waffen", -10, False),
    # Treffer
    "hit_hull": ([hit_hull_a, hit_hull_b, hit_hull_c], "Treffer auf der Hülle (Explosion)", "Treffer", -1, False),
    "hit_system": ([hit_system], "System beschädigt (Funken, Kurzschluss)", "Treffer", -5, False),
    "shield": ([shield_a, shield_b, shield_c], "Schild fängt Schuss ab", "Treffer", -4, False),
    "miss": ([miss], "Schuss verfehlt (Vorbeiflug)", "Treffer", -8, False),
    "ship_explode": ([ship_explode], "Schiff zerstört", "Treffer", -1, False),
    # An Bord
    "fire_start": ([fire_start], "Feuer bricht aus", "An Bord", -4, False),
    "fire_loop": ([fire_loop], "Feuer brennt (Schleife)", "An Bord", -6, True),
    "extinguish": ([extinguish], "Feuer gelöscht", "An Bord", -8, False),
    "breach": ([breach], "Hüllenbruch", "An Bord", -3, False),
    "breach_fixed": ([breach_fixed], "Hüllenbruch geflickt", "An Bord", -8, False),
    "repaired": ([repaired], "System repariert", "An Bord", -8, False),
    "crew_died": ([crew_died], "Crew gefallen", "An Bord", -5, False),
    "door_open": ([door_open], "Tür öffnet", "An Bord", -10, False),
    "door_close": ([door_close], "Tür schließt", "An Bord", -10, False),
    "airlock_open": ([airlock_open], "Luftschleuse öffnet (Luft entweicht)", "An Bord", -6, False),
    "airlock_close": ([airlock_close], "Luftschleuse schließt", "An Bord", -7, False),
    "ship_hum": ([ship_hum], "Schiffsbrummen (Schleife)", "An Bord", -10, True),
    # Warnungen
    "alarm": ([alarm_a, alarm_b, alarm_c], "Gegner lädt Sprungantrieb", "Warnungen", -9, False),
    "hull_low": ([hull_low], "Hülle kritisch", "Warnungen", -8, False),
    # Sprung
    "warp_out": ([warp_out_a, warp_out_b, warp_out_c], "Sprung: Abflug", "Sprung", -2, False),
    "warp_in": ([warp_in], "Sprung: Ankunft", "Sprung", -4, False),
    "jump_ready": ([jump_ready], "Sprungantrieb geladen", "Sprung", -9, False),
    "distress": ([distress], "Notsignal senden", "Sprung", -8, False),
    # Bedienung
    "ui_click": ([ui_click], "Knopf", "Bedienung", -12, False),
    "ui_deny": ([ui_deny], "Geht nicht", "Bedienung", -15, False),
    "map_open": ([map_open], "Karte öffnen", "Bedienung", -10, False),
    "map_close": ([map_close], "Karte schließen", "Bedienung", -10, False),
    "map_select": ([map_select], "Ziel auf der Karte gewählt", "Bedienung", -10, False),
    "map_travel": ([map_travel], "Schiff fliegt auf der Karte", "Bedienung", -10, False),
    "power_up": ([power_up], "Energie +1", "Bedienung", -12, False),
    "power_down": ([power_down], "Energie −1", "Bedienung", -12, False),
    "crew_select": ([crew_select], "Crew ausgewählt", "Bedienung", -12, False),
    "crew_order": ([crew_order], "Crew-Laufbefehl", "Bedienung", -11, False),
    "pause": ([pause], "Pause", "Bedienung", -10, False),
    "resume": ([resume], "Weiter", "Bedienung", -10, False),
    "dialog_open": ([dialog_open], "Ereignis / Funkspruch", "Bedienung", -8, False),
    "dialog_choice": ([dialog_choice], "Antwort gewählt", "Bedienung", -11, False),
    # Ergebnisse
    "reward": ([reward], "Beute", "Ergebnisse", -7, False),
    "victory": ([victory_a, victory_b, victory_c], "Sieg", "Ergebnisse", -4, False),
    "sector_clear": ([sector_clear], "Sektor geschafft (Boss besiegt)", "Ergebnisse", -4, False),
    "defeat": ([defeat], "Niederlage", "Ergebnisse", -4, False),
    "run_complete": ([run_complete], "Alle Sektoren geschafft", "Ergebnisse", -3, False),
}

# Welche Variante ins Spiel kommt (Index in der Variantenliste). Nicht genannt = erste.
CHOICE = {"laser_pulse": 2, "laser_heavy": 1, "cannon": 1, "hit_hull": 2}
