"""Alle Soundeffekte von Hullbound, prozedural erzeugt.

Klangrichtung: filmische Science-Fiction statt Arcade. Keine Rechteck-Piepser und
Chiptune-Melodien, sondern Flächen, tiefe Drones, Filterfahrten, Metall, Funk und Luft.

Jeder Effekt hat eine oder mehrere Varianten (a, b, c). Ins Spiel kommt die Variante aus
CHOICE (Standard: a); die anderen sind Hörvorschläge zum Vergleichen (preview/).
"""

import numpy as np

from dsp import (bandpass, chord_pad, crackle, drive, echo, env, fade, flanger, fm, highpass, lowpass,
                 loopify, metal, mix, n_of, noise, onepole, pad, radio, reverb, reverse, saw, sine, sweep,
                 time)

# Töne (Hz)
A1, C2, D2, E2, F2, G2, A2 = 55.0, 65.41, 73.42, 82.41, 87.31, 98.0, 110.0
C3, D3, Eb3, E3, F3, G3, Ab3, A3, Bb3, B3 = 130.81, 146.83, 155.56, 164.81, 174.61, 196.0, 207.65, 220.0, 233.08, 246.94
C4, D4, Eb4, E4, F4, G4, A4, B4 = 261.63, 293.66, 311.13, 329.63, 349.23, 392.0, 440.0, 493.88
C5, D5, E5, G5 = 523.25, 587.33, 659.25, 783.99

DARK = 2500  # Halldämpfung: dunkler Raum


def space(x, size=0.8, wet=0.3):
    return reverb(x, size, wet, damp=DARK)


def ping(freq, dur=0.25, ratio=1.41, index=1.2, level=0.4):
    """Weicher, gläserner Signalton (FM, schnell abklingender Obertonanteil) statt Piepser."""
    idx = index * np.exp(-time(dur) * 18)
    return fm(freq, dur, ratio, idx) * env(dur, 0.003, curve=6) * level


def servo(f0, f1, dur, level=0.3, seed=1):
    """Kurzer Stellmotor: gefilterter Sägezahn mit leichtem Rauschen."""
    body = lowpass(saw(sweep(f0, f1, dur), dur), 900, q=1.5) * 0.6
    grit = bandpass(noise(dur, seed), sweep(f0 * 8, f1 * 8, dur), 2.0) * 0.4
    return (body + grit) * env(dur, 0.01, curve=2.5, hold=dur * 0.4) * level


def click(seed=1, level=0.5, tone=3200):
    """Mechanischer Kontakt: sehr kurzer gefilterter Impuls."""
    return bandpass(noise(0.012, seed), tone, 1.5) * env(0.012, 0.0005, curve=6) * level


def sub_drop(f0, f1, dur, level=1.0):
    return sine(sweep(f0, f1, dur), dur) * env(dur, 0.003, curve=4) * level


# ---------------------------------------------------------------- Waffen


def laser_pulse():
    """Plasmapuls: kurzer FM-Zapp mit Resonanzfilter, Entladung und Raumhall."""
    d = 0.22
    f = sweep(1500, 320, d)
    core = fm(f, d, 0.5, sweep(4.0, 0.5, d)) * 0.6 + saw(f * 0.5, d) * 0.3
    core = lowpass(core, sweep(7000, 900, d), q=2.2) * env(d, 0.001, curve=4)
    snap = highpass(noise(0.03, 1), 3500) * env(0.03, 0.0005, curve=7) * 0.5
    crk = bandpass(crackle(0.12, 140, 2, 0.002), 4500, 1.2) * env(0.12, 0.001, curve=4) * 0.5
    thump = sub_drop(180, 60, 0.12, 0.4)
    return space(fade(echo(mix(core, snap, crk, thump), 0.07, 0.22, 2)), 0.6, 0.22)


def laser_heavy():
    """Schwerer Strahl: Ladesog, dann dichter, verzerrter Strahl mit Tiefbass."""
    charge_d = 0.12
    charge = highpass(noise(charge_d, 3), sweep(400, 5000, charge_d)) * np.linspace(0, 1, n_of(charge_d)) ** 2 * 0.5
    d = 0.6
    f = sweep(520, 55, d)
    beam = sum(saw(f * k, d) for k in (1.0, 1.006, 0.994, 2.003)) / 4
    beam = lowpass(beam, sweep(4200, 250, d), q=3.0)
    hiss = bandpass(noise(d, 4), sweep(5000, 700, d), 1.4) * env(d, 0.002, curve=5) * 0.6
    sub = sub_drop(110, 30, d, 0.9)
    body = drive((beam + hiss) * env(d, 0.003, curve=3) + sub, 2.0)
    return space(fade(mix(charge, (body, charge_d))), 1.0, 0.3)


def cannon():
    """Massebeschleuniger: Spulen-Zing, Rückstoß, metallener Nachklang."""
    d = 0.7
    zing = fm(sweep(2600, 900, 0.08), 0.08, 2.1, 3.0) * env(0.08, 0.001, curve=4) * 0.25
    blast = lowpass(noise(d, 21), sweep(2600, 120, d), q=1.2) * env(d, 0.001, curve=6)
    thump = sub_drop(100, 28, 0.5, 1.3)
    ring = metal(140, 0.9, decay=4, seed=22) * 0.25
    out = drive(mix(zing, (blast + pad(thump, d), 0.03), (ring, 0.03)), 2.5)
    return space(fade(out), 1.2, 0.3)


def weapon_ready():
    """Kondensator voll: leises Ansteigen, dann ein gläserner Ton."""
    hum = lowpass(saw(sweep(80, 160, 0.12), 0.12), 600) * np.linspace(0, 1, n_of(0.12)) * 0.25
    return space(fade(mix(hum, (ping(1320, 0.3, 2.0, 1.0, 0.35), 0.1))), 0.5, 0.25)


def weapon_select():
    return fade(mix(click(5, 0.5), (servo(140, 260, 0.12, 0.3, 6), 0.01)))


def target_lock():
    """Zielerfassung: zwei weiche Abtastimpulse, dann Lock mit Resonanz."""
    scan = [(ping(1760, 0.08, 1.5, 0.8, 0.25), t) for t in (0.0, 0.08)]
    lock = fm(1175, 0.35, 0.5, 0.6) * env(0.35, 0.005, curve=5) * 0.3
    return space(fade(mix(*scan, (lock, 0.17))), 0.5, 0.25)


# ---------------------------------------------------------------- Treffer


def explosion(d=0.9, seed=41, low=3500, sub=90, rough=1.0):
    rumble = lowpass(noise(d, seed), sweep(low, 120, d), q=0.8) * env(d, 0.002, curve=4.5)
    thump = sine(sweep(sub, 28, d * 0.6), d * 0.6) * env(d * 0.6, 0.002, curve=4)
    crk = lowpass(crackle(d, 90 * rough, seed + 1), 5000) * env(d, 0.01, curve=3) * 0.9
    return drive(rumble * 1.3 + pad(thump, d) * 1.1 + crk, 2.0)


def hit_hull():
    x = explosion(0.8, 61, low=4000, sub=95, rough=1.8)
    debris = highpass(crackle(0.7, 50, 62, 0.002), 2000) * 0.4
    groan = metal(85, 1.2, partials=(1.0, 2.13, 3.47, 5.1), decay=3, seed=63) * 0.3
    return space(fade(mix(x, (debris, 0.1), (groan, 0.05))), 1.1, 0.3)


def hit_system():
    """Kurzschluss: Lichtbogen, Funken, Netzbrummen das wegbricht."""
    d = 0.6
    rng = np.random.default_rng(71)
    arc_f = onepole(120 + rng.uniform(-60, 400, n_of(d)), 80)
    arc = lowpass(saw(arc_f, d), 2500, q=2) * 0.4
    zaps = bandpass(crackle(d, 140, 72, 0.003), 4000, 1.0) * 2.0
    mains = sine(sweep(100, 40, d), d) * 0.3
    out = (arc + zaps + mains) * env(d, 0.002, curve=3)
    return space(fade(drive(out, 2.0)), 0.6, 0.25)


def shield():
    """Energiefeld: tiefer Stoß ins Feld, flirrendes Nachschwingen."""
    d = 0.8
    t = time(d)
    field = sum(np.sin(2 * np.pi * f * t + i) for i, f in enumerate((180, 271, 404, 607))) / 4
    field *= 1 + 0.6 * np.sin(2 * np.pi * sweep(40, 9, d) * t)
    fizz = bandpass(noise(d, 81), sweep(5000, 1200, d), 2.5) * 0.6
    thud = sub_drop(160, 50, 0.2, 0.8)
    out = mix((field * 0.6 + fizz) * env(d, 0.002, curve=3.5), thud)
    return space(fade(flanger(out, 0.001, 0.004, 0.5, 0.5)), 1.0, 0.35)


def miss():
    d = 0.5
    w = bandpass(noise(d, 91), sweep(3000, 500, d), 3.0) * np.sin(np.linspace(0, np.pi, n_of(d))) ** 2
    return fade(flanger(w * 1.2, 0.004, 0.0008, 0.5, 0.6))


def ship_explode():
    d = 3.2
    parts = [(explosion(1.4, 171 + i, low=3000 - i * 300, sub=80 - i * 6), t)
             for i, t in enumerate((0.0, 0.25, 0.55, 0.8, 1.1))]
    tail = lowpass(noise(d, 179), sweep(1200, 60, d), q=0.7) * env(d, 0.05, curve=2.2) * 0.9
    sub = sine(sweep(55, 22, d), d) * env(d, 0.02, curve=2.2)
    groan = metal(60, 2.5, partials=(1.0, 1.83, 2.94, 4.4), decay=1.5, seed=178) * 0.4
    return space(fade(drive(mix(*parts, tail, sub, (groan, 0.3)) * 0.7, 1.5)), 2.0, 0.35)


# ---------------------------------------------------------------- An Bord


def fire_start():
    d = 0.9
    woosh = lowpass(noise(d, 101), np.concatenate([sweep(300, 2500, 0.15), sweep(2500, 400, d - 0.15)]), q=1.2)
    woosh *= env(d, 0.06, curve=3.5)
    low = sine(sweep(90, 45, d), d) * env(d, 0.05, curve=4) * 0.6
    crk = crackle(d, 50, 102) * env(d, 0.1, curve=2) * 0.6
    return space(fade(drive(woosh * 1.3 + low + crk, 1.5)), 0.7, 0.2)


def fire_loop():
    d = 3.0
    roar = lowpass(noise(d + 0.3, 111), 500, q=0.8) * 0.8
    roar *= 1 + 0.3 * sine(0.7, d + 0.3)
    crk = lowpass(crackle(d + 0.3, 35, 112, 0.006), 4000) * 1.2
    return loopify(roar + crk, 0.3)


def extinguish():
    d = 1.0
    hiss = highpass(noise(d, 121), 2500) * env(d, 0.02, curve=3)
    steam = bandpass(noise(d, 122), sweep(3000, 1200, d), 1.0) * env(d, 0.1, curve=2.5) * 0.6
    return space(fade((hiss + steam) * 0.7), 0.5, 0.15)


def breach():
    d = 1.5
    crack = metal(210, 0.8, partials=(1.0, 2.31, 3.89, 5.67, 7.8), decay=5, seed=131) * 0.8
    snap = highpass(noise(0.03, 132), 1500) * env(0.03, 0.0005, curve=6)
    rush = highpass(noise(d, 133), sweep(1200, 4000, d)) * np.minimum(time(d) / 0.15, 1) * env(d, 0.0, curve=1.2) * 0.6
    boom = sub_drop(110, 35, 0.4, 0.9)
    return space(fade(mix(snap, crack, boom, rush)), 1.0, 0.25)


def breach_fixed():
    """Plasmaschweißen und Dichtung: Brutzeln, Klammern, Druckausgleich."""
    weld = bandpass(crackle(0.45, 220, 141, 0.002), 3500, 0.8) * env(0.45, 0.02, curve=1.5, hold=0.25) * 1.2
    clamps = [(metal(520 + i * 35, 0.2, decay=20, seed=142 + i) * 0.5, 0.45 + i * 0.1) for i in range(2)]
    seal = lowpass(noise(0.4, 146), sweep(3000, 600, 0.4)) * env(0.4, 0.01, curve=4) * 0.3
    return space(fade(mix(weld, *clamps, (seal, 0.65))), 0.6, 0.2)


def repaired():
    """System wieder online: Relais, Netzteil fährt hoch, ruhiger Bestätigungston."""
    relay = mix(click(151, 0.6, 2500), (click(152, 0.5, 2000), 0.06))
    spin = lowpass(saw(sweep(40, 120, 0.35), 0.35), 700) * np.linspace(0, 1, n_of(0.35)) ** 1.5 * 0.35
    tone = ping(E5, 0.6, 1.0, 0.6, 0.3) + ping(B4, 0.6, 1.0, 0.4, 0.2)
    return space(fade(mix(relay, (spin, 0.05), (tone, 0.35))), 0.9, 0.3)


def crew_died():
    """Lebenszeichen erlischt: dumpfer Schlag, Monitor-Ton fällt ab, Rauschen."""
    d = 2.0
    thud = lowpass(noise(0.25, 161), 250) * env(0.25, 0.002, curve=6) * 1.0
    flat = sine(sweep(880, 840, d), d) * env(d, 0.02, curve=2.5) * 0.12
    drone = chord_pad([A2, Eb3], d, 0.2, 1.0, (500, 200), seed=162) * 0.6
    return space(fade(mix(thud, (radio(flat, 163, 0.05), 0.15), (drone, 0.1))), 1.6, 0.35)


def door_open():
    d = 0.55
    hiss = bandpass(noise(d, 261), sweep(3000, 1200, d), 1.5) * env(d, 0.01, curve=4) * 0.7
    motor = servo(70, 120, 0.35, 0.35, 262)
    clunk = mix(metal(110, 0.2, decay=22, seed=263) * 0.5, lowpass(noise(0.04, 264), 500) * 0.5)
    return space(fade(mix(hiss, motor, (clunk, 0.34))), 0.4, 0.2)


def door_close():
    d = 0.45
    motor = servo(120, 70, 0.25, 0.3, 265)
    hiss = bandpass(noise(d, 266), sweep(1200, 2800, d), 1.5) * env(d, 0.01, curve=4) * 0.4
    clunk = mix(metal(95, 0.25, decay=18, seed=267) * 0.7, lowpass(noise(0.06, 268), 450) * 0.8)
    return space(fade(mix(motor, hiss, (clunk, 0.22))), 0.4, 0.2)


def airlock_open():
    d = 1.6
    alarm = mix(*((ping(392, 0.15, 1.0, 0.3, 0.15), t) for t in (0.0, 0.18)))
    clunk = mix(metal(70, 0.5, decay=8, seed=271), lowpass(noise(0.1, 272), 400))
    rush = lowpass(noise(d, 273), sweep(5000, 1200, d)) * np.minimum(time(d) / 0.05, 1) * env(d, 0.0, curve=2.0) * 0.9
    return space(fade(mix(radio(alarm, 270, 0.0), (clunk * 0.8, 0.35), (rush, 0.45))), 1.0, 0.25)


def airlock_close():
    d = 0.6
    hiss = highpass(noise(0.25, 274), 2500) * env(0.25, 0.005, curve=5) * 0.5
    clunk = mix(metal(65, 0.55, decay=7, seed=275), lowpass(noise(0.12, 276), 400) * 0.8)
    return space(fade(pad(mix(hiss, (clunk * 0.8, 0.12)), d)), 1.0, 0.25)


def ship_hum():
    d = 6.0
    t = time(d)
    drone = (np.sin(2 * np.pi * 55.0 * t) * 0.5 + np.sin(2 * np.pi * 110.5 * t) * 0.25
             + np.sin(2 * np.pi * 165.0 * t) * 0.08)
    drone *= 1 + 0.15 * np.sin(2 * np.pi * (1 / 3) * t)
    air = lowpass(noise(d + 0.5, 321), 350, q=0.6) * 0.5
    air = loopify(air, 0.5)
    return drone * 0.6 + air


# ---------------------------------------------------------------- Warnungen


def alarm():
    """Bordalarm: tiefes, gefiltertes Signalhorn, an- und abschwellend (zweimal)."""
    d = 0.6
    parts = []
    for i in range(2):
        f = sweep(330, 440, d, "lin")
        horn = lowpass(saw(f, d) + saw(f * 1.005, d), sweep(800, 2400, d), q=2.5) * 0.4
        horn *= np.sin(np.linspace(0, np.pi, n_of(d))) ** 0.7
        parts.append((horn, i * 0.7))
    return space(fade(mix(*parts)), 0.9, 0.3)


def hull_low():
    """Hülle kritisch: pulsierender tiefer Warnton mit Funkverzerrung."""
    d = 1.4
    t = time(d)
    tone = fm(sweep(220, 196, d), d, 0.5, 1.5) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 3.0 * t)))
    tone = lowpass(tone, 1800) * env(d, 0.01, curve=1.0, hold=1.0) * 0.5
    return space(fade(radio(tone, 401, 0.04) * 0.8), 0.7, 0.25)


# ---------------------------------------------------------------- Sprung


def warp_out_a():
    """Antrieb fährt hoch (Turbine), dann reißt der Raum mit tiefem Schlag auf."""
    up = 0.55
    f = sweep(38, 150, up)
    turbine = sum(saw(f * k, up) / k for k in (1, 2, 3.01, 4.02)) * 0.5
    turbine = lowpass(turbine, sweep(200, 3000, up), q=2.5) * np.linspace(0.15, 1, n_of(up)) ** 1.5
    whine = fm(sweep(500, 2200, up), up, 1.5, 0.8) * np.linspace(0, 1, n_of(up)) ** 3 * 0.12
    riser = highpass(noise(up, 201), sweep(600, 5000, up)) * np.linspace(0, 1, n_of(up)) ** 3 * 0.5
    d = 1.4
    tear = lowpass(noise(d, 202), sweep(6000, 80, d), q=1.0) * env(d, 0.002, curve=4) * 1.3
    boom = sub_drop(70, 22, 1.2, 1.4)
    out = mix(turbine + whine + riser, (drive(tear + pad(boom, d), 2.0), up))
    return space(fade(out), 2.2, 0.35)


def warp_out_b():
    """Raumfaltung: rückwärts angesaugter Hall, Unterdruck, dumpfer Schlag."""
    burst = lowpass(noise(0.3, 211), 3000) * env(0.3, 0.001, curve=5)
    suck = reverse(reverb(burst, 1.0, 1.0, damp=3500))[: n_of(0.75)]
    suck = flanger(suck, 0.006, 0.0006, 0.6, 0.6) * np.linspace(0.2, 1, len(suck)) * 1.5
    drone = lowpass(saw(sweep(45, 90, 0.75), 0.75), 400) * np.linspace(0, 1, n_of(0.75)) ** 2 * 0.4
    boom = mix(sub_drop(80, 24, 1.3, 1.3), lowpass(noise(0.5, 212), sweep(2000, 100, 0.5)) * env(0.5, 0.001, curve=5))
    return space(fade(mix(suck + drone, (drive(boom, 2.0), 0.75))), 2.0, 0.35)


def warp_out_c():
    """Phasenverschiebung: Düsenartiges Phasing steigt, bricht in Stille mit tiefem Nachhall."""
    up = 0.8
    roar = lowpass(noise(up, 221), sweep(400, 6000, up), q=0.8) * np.linspace(0.1, 1, n_of(up)) ** 2
    roar = flanger(roar, 0.008, 0.0004, 0.8, 0.8)
    tone = lowpass(saw(sweep(55, 110, up), up) + saw(sweep(55.3, 110.6, up), up), 600) * 0.2
    thoom = mix(sub_drop(60, 25, 1.4, 1.2), lowpass(noise(0.2, 222), 300) * env(0.2, 0.001, curve=5) * 0.8)
    return space(fade(mix(roar + tone, (thoom, up))), 2.4, 0.4)


def warp_in_a():
    """Austritt: Druckwelle, Phasing fällt ab, Antrieb läuft ruhig aus."""
    d = 1.6
    blast = lowpass(noise(0.15, 231), 2500) * env(0.15, 0.001, curve=5) * 0.8
    wash = flanger(lowpass(noise(d, 232), sweep(5000, 200, d), q=0.8) * env(d, 0.005, curve=3.5), 0.0005, 0.007, 0.7, 0.7)
    sub = sub_drop(65, 28, 1.0, 1.0)
    wind_down = lowpass(saw(sweep(140, 40, d), d), sweep(1500, 150, d), q=2.0) * env(d, 0.05, curve=2.5) * 0.3
    return space(fade(mix(blast, wash * 1.1, sub, wind_down)), 2.0, 0.35)


def warp_in_b():
    """Rückwärtsklang auf die Ankunft zu, dann ein weicher, schwerer Aufsetzer."""
    swell = reverse(lowpass(noise(0.9, 241), sweep(4000, 300, 0.9)) * env(0.9, 0.001, curve=4))
    swell = flanger(swell, 0.0006, 0.005, 0.6, 0.5) * 0.9
    land = mix(sub_drop(90, 30, 0.9, 1.0), lowpass(noise(0.4, 242), sweep(1500, 100, 0.4)) * env(0.4, 0.002, curve=4) * 0.7)
    settle = lowpass(saw(sweep(80, 55, 1.0), 1.0), 300) * env(1.0, 0.1, curve=3) * 0.25
    return space(fade(mix(swell, (land, 0.9), (settle, 1.0))), 1.8, 0.35)


def warp_in_c():
    """Materialisieren: flirrende Teiltöne sinken ins Brummen des Schiffs."""
    d = 1.8
    t = time(d)
    shimmer = np.zeros(len(t))
    rng = np.random.default_rng(251)
    for k in range(10):
        f0 = rng.uniform(1500, 4000)
        f1 = f0 / rng.uniform(4, 10)
        shimmer += sine(sweep(f0, f1, d), d) * env(d, rng.uniform(0.01, 0.2), curve=rng.uniform(3, 6))
    shimmer = shimmer / 10 * (1 + 0.5 * np.sin(2 * np.pi * 17 * t))
    air = lowpass(noise(d, 252), sweep(4000, 200, d)) * env(d, 0.01, curve=4) * 0.5
    drone = lowpass(saw(55, d) + saw(55.4, d), 300) * env(d, 0.4, curve=2) * 0.3
    return space(fade(mix(shimmer * 0.5, air, drone, sub_drop(60, 30, 0.6, 0.6))), 1.8, 0.4)


def jump_ready():
    """Sprungantrieb bereit: Spulen laufen hoch und rasten auf einem satten Ton ein."""
    up = 0.4
    spool = lowpass(saw(sweep(50, 110, up), up) + saw(sweep(50.4, 110.8, up), up), sweep(200, 1200, up)) * np.linspace(0, 1, n_of(up)) * 0.25
    hold = lowpass(saw(110, 0.8) + saw(110.5, 0.8), 900) * env(0.8, 0.01, curve=4) * 0.25
    tone = ping(A4, 0.8, 2.0, 1.0, 0.3)
    return space(fade(mix(spool, (hold + tone, up))), 1.0, 0.3)


def distress():
    """Notsignal: SOS als Funkimpulse mit Rauschen und Echo in den Raum."""
    s, l = 0.08, 0.24
    seq = [(1, s), (0, s), (1, s), (0, s), (1, s), (0, l), (1, l), (0, s), (1, l), (0, s), (1, l), (0, l),
           (1, s), (0, s), (1, s), (0, s), (1, s)]
    parts, t = [], 0.0
    for on, dlen in seq:
        if on:
            parts.append((sine(700, dlen) * env(dlen, 0.006, curve=0.8, hold=dlen * 0.6) * 0.5, t))
        t += dlen
    beeps = mix(*parts)
    return space(fade(echo(radio(beeps, 261, 0.12), 0.35, 0.3, 3)), 1.2, 0.3)


# ---------------------------------------------------------------- Karte und Bedienung


def ui_click():
    return fade(mix(click(231, 0.6, 3000), (ping(2400, 0.06, 1.0, 0.3, 0.12), 0.002)))


def ui_deny():
    """Abgelehnt: zwei dumpfe, tiefe Impulse (Relais schaltet nicht)."""
    one = lowpass(fm(110, 0.12, 1.5, 2.0), 700) * env(0.12, 0.003, curve=4) * 0.6
    return space(fade(mix(one, (one * 0.8, 0.14))), 0.4, 0.2)


def map_open():
    """Holo-Karte baut sich auf: Datenrauschen und aufsteigendes Flirren."""
    d = 0.5
    data = bandpass(crackle(d, 200, 241, 0.0015), sweep(1500, 5000, d), 1.2) * np.linspace(1, 0, n_of(d)) * 0.8
    rise = lowpass(saw(sweep(200, 600, d), d), sweep(500, 3000, d), q=3) * env(d, 0.05, curve=3) * 0.25
    return space(fade(mix(data, rise)), 0.6, 0.3)


def map_close():
    d = 0.4
    data = bandpass(crackle(d, 160, 242, 0.0015), sweep(5000, 1200, d), 1.2) * np.linspace(1, 0, n_of(d)) * 0.6
    fall = lowpass(saw(sweep(500, 180, d), d), sweep(2500, 400, d), q=3) * env(d, 0.01, curve=3) * 0.25
    return space(fade(mix(data, fall)), 0.5, 0.3)


def map_select():
    return space(fade(mix(click(243, 0.3), ping(880, 0.3, 2.0, 1.2, 0.3))), 0.6, 0.3)


def map_travel():
    """Kursberechnung: rasche Datenimpulse, die sich zu einem Ton verdichten."""
    d = 0.6
    rng = np.random.default_rng(251)
    parts = [(ping(rng.uniform(900, 2400), 0.05, 1.5, 0.5, 0.12), i * 0.035) for i in range(12)]
    tone = lowpass(saw(sweep(220, 440, d), d), 1500, q=2) * env(d, 0.2, curve=3) * 0.2
    return space(fade(mix(*parts, (tone, 0.1))), 0.6, 0.3)


def power_up():
    return fade(mix(click(271, 0.4, 2200), (servo(180, 320, 0.12, 0.35, 272), 0.005)))


def power_down():
    return fade(mix(click(273, 0.4, 1800), (servo(300, 140, 0.12, 0.35, 274), 0.005)))


def crew_select():
    """Kanal zur Person offen: kurzes Funkknacken und weicher Ton."""
    sq = bandpass(noise(0.03, 281), 2200, 1.0) * env(0.03, 0.001, curve=5) * 0.5
    return fade(mix(sq, (ping(1480, 0.12, 1.0, 0.4, 0.25), 0.02)))


def crew_order():
    """Befehl bestätigt: Funk-Squelch und zwei leise Datenimpulse."""
    sq = radio(noise(0.06, 282) * 0.3, 283, 0.0) * env(0.06, 0.002, curve=4)
    blips = mix((ping(1175, 0.08, 1.0, 0.3, 0.2), 0.0), (ping(1568, 0.1, 1.0, 0.3, 0.2), 0.06))
    return space(fade(mix(sq, (blips, 0.05))), 0.4, 0.2)


def pause():
    """Zeit hält an: alles sinkt ab wie ein abbremsendes Band."""
    d = 0.4
    x = lowpass(saw(sweep(220, 40, d), d) + saw(sweep(221, 40.5, d), d), sweep(2000, 150, d)) * env(d, 0.005, curve=3) * 0.3
    return space(fade(x), 0.4, 0.2)


def resume():
    d = 0.3
    x = lowpass(saw(sweep(40, 220, d), d) + saw(sweep(40.5, 221, d), d), sweep(150, 2000, d)) * env(d, 0.05, curve=3) * 0.3
    return space(fade(x), 0.4, 0.2)


def dialog_open():
    """Eingehender Funkspruch: Rauschen, Datenburst, Kanal steht."""
    static = bandpass(noise(0.35, 291), 2500, 0.8) * env(0.35, 0.01, curve=3) * 0.35
    rng = np.random.default_rng(292)
    burst = mix(*((ping(rng.uniform(1200, 2600), 0.04, 1.0, 0.2, 0.15), i * 0.03) for i in range(6)))
    tone = ping(988, 0.4, 1.0, 0.5, 0.25)
    return space(fade(mix(static, (radio(burst, 293, 0.0), 0.12), (tone, 0.32))), 0.6, 0.25)


def dialog_choice():
    return fade(mix(click(295, 0.4), ping(1320, 0.12, 2.0, 0.6, 0.22)))


def reward():
    """Fracht an Bord: Greifklammer, Druckausgleich, ruhiger Bestätigungston."""
    clamp = mix(metal(240, 0.3, decay=12, seed=301) * 0.5, lowpass(noise(0.05, 302), 600) * 0.5)
    hiss = highpass(noise(0.3, 303), 2500) * env(0.3, 0.01, curve=4) * 0.25
    tone = ping(G4, 0.7, 1.0, 0.5, 0.25) + ping(D5, 0.7, 1.0, 0.5, 0.2)
    return space(fade(mix(clamp, (hiss, 0.08), (tone, 0.25))), 1.0, 0.3)


# ---------------------------------------------------------------- Ergebnisse


def victory_a():
    """Breite Fläche: offener Quintklang löst sich in Dur auf, darunter Tiefbass."""
    p1 = chord_pad([C3, G3, D4, G4], 1.4, 0.3, 0.5, (400, 1800), seed=401)
    p2 = chord_pad([C3, G3, C4, E4, G4], 2.4, 0.3, 1.5, (1800, 900), seed=402)
    sub = sine(C2, 3.4) * env(3.4, 0.4, curve=2.5) * 0.35
    return space(fade(mix(p1, (p2, 1.0), sub)), 2.5, 0.4)


def victory_b():
    """Systeme fahren hoch: tiefer Drone, zwei warme Akkorde (Fmaj7 → C)."""
    drone = lowpass(saw(C2, 3.4) + saw(C2 * 1.004, 3.4), 300) * env(3.4, 0.3, curve=2) * 0.3
    p1 = chord_pad([F3, A3, C4, E4], 1.3, 0.25, 0.5, (500, 1500), seed=411)
    p2 = chord_pad([C3, G3, C4, E4, G4], 2.2, 0.25, 1.4, (1500, 700), seed=412)
    return space(fade(mix(drone, (p1, 0.2), (p2, 1.2))), 2.5, 0.4)


def victory_c():
    """Ein einzelner, aufblühender Akkord mit glitzernden Obertönen."""
    pad_ = chord_pad([C3, G3, E4, B4], 3.0, 0.6, 1.6, (300, 2500), seed=421)
    glint = mix(*((ping(f, 1.2, 2.0, 0.8, 0.12), t) for f, t in ((G5, 0.6), (E5 * 2, 0.9), (B4 * 2, 1.2))))
    sub = sine(C2, 3.0) * env(3.0, 0.6, curve=2.5) * 0.3
    return space(fade(mix(pad_, (glint, 0.0), sub)), 2.5, 0.45)


def defeat_a():
    """Energie bricht weg: Generator läuft aus, dunkle Moll-Fläche."""
    d = 3.5
    spin = lowpass(sum(saw(sweep(110 * k, 18 * k, d), d) / k for k in (1, 2, 3)), sweep(2000, 100, d), q=2) * env(d, 0.01, curve=2.5) * 0.45
    pad_ = chord_pad([A2, E3, C4], d, 0.8, 1.8, (900, 250), seed=431) * 0.9
    return space(fade(mix(spin, (pad_, 0.3))), 2.5, 0.4)


def defeat_b():
    """Schwere, tiefe Moll-Fläche, Filter schließt sich langsam."""
    d = 4.0
    pad_ = chord_pad([D2, A2, F3, C4], d, 0.5, 2.0, (1400, 150), seed=441)
    sub = sine(D2 / 2, d) * env(d, 0.5, curve=2) * 0.4
    return space(fade(mix(pad_, sub)), 3.0, 0.45)


def defeat_c():
    """Funkstille: Rauschen, letzter Herzschlag, Cluster verklingt."""
    d = 4.0
    static = radio(noise(d, 451) * 0.25, 452, 0.15) * env(d, 0.2, curve=2)
    beats = mix(*((lowpass(noise(0.15, 453 + i), 150) * env(0.15, 0.002, curve=5) * (0.9 - i * 0.25), t)
                  for i, t in enumerate((0.3, 0.55, 1.3, 1.55))))
    cluster = chord_pad([A2, Bb3 / 2 * 2, E3], d - 0.8, 1.0, 2.0, (600, 150), seed=455) * 0.7
    return space(fade(mix(static, beats, (cluster, 0.8))), 2.5, 0.4)


def sector_clear():
    """Boss besiegt: aufsteigender Akkordwechsel, Sprungantrieb summt mit."""
    p1 = chord_pad([D3, A3, E4], 1.2, 0.2, 0.4, (500, 2000), seed=461)
    p2 = chord_pad([G2 * 2, D4, G4, B4], 2.0, 0.2, 1.2, (2000, 900), seed=462)
    spool = lowpass(saw(sweep(55, 110, 3.0), 3.0), 500) * env(3.0, 0.5, curve=2) * 0.15
    return space(fade(mix(p1, (p2, 0.9), spool)), 2.5, 0.4)


def run_complete():
    """Alle Sektoren geschafft: langsamer, großer Aufbau über drei Akkorde."""
    p1 = chord_pad([C3, G3, E4], 1.4, 0.4, 0.4, (400, 1500), seed=471)
    p2 = chord_pad([F3, C4, A4], 1.4, 0.3, 0.4, (800, 2000), seed=472)
    p3 = chord_pad([G2 * 2, D4, G4, B4, D5], 1.4, 0.3, 0.4, (1200, 2500), seed=473)
    p4 = chord_pad([C3, G3, C4, E4, G4, C5], 3.0, 0.3, 2.0, (2500, 900), seed=474)
    sub = sine(C2, 6.0) * env(6.0, 1.0, curve=2) * 0.35
    hits = mix(*((sub_drop(90, 35, 0.6, 0.6), t) for t in (0.0, 1.2, 2.4, 3.6)))
    return space(fade(mix(p1, (p2, 1.2), (p3, 2.4), (p4, 3.6), sub, hits)), 3.0, 0.4)


def loud(fn):
    """Lauter im Mix: sanft verdichten, damit der Klang auch zwischen Kampfgeräuschen trägt."""
    return lambda: drive(fn() / (np.max(np.abs(fn())) + 1e-9), 2.2)


# Name → (Varianten, Beschreibung, Situation, Spitzenpegel dB, Schleife)
SOUNDS = {
    # Waffen
    "laser_pulse": ([laser_pulse], "Pulslaser feuert", "Waffen", -3, False),
    "laser_heavy": ([laser_heavy], "Schwerlaser feuert", "Waffen", -2, False),
    "cannon": ([cannon], "Bordkanone feuert", "Waffen", -2, False),
    "weapon_ready": ([weapon_ready], "Waffe geladen", "Waffen", -13, False),
    "weapon_select": ([weapon_select], "Waffe angewählt", "Waffen", -11, False),
    "target_lock": ([target_lock], "Ziel erfasst", "Waffen", -11, False),
    # Treffer
    "hit_hull": ([hit_hull], "Treffer auf der Hülle (Explosion)", "Treffer", -1, False),
    "hit_system": ([hit_system], "System beschädigt (Funken, Kurzschluss)", "Treffer", -5, False),
    "shield": ([shield], "Schild fängt Schuss ab", "Treffer", -4, False),
    "miss": ([miss], "Schuss verfehlt (Vorbeiflug)", "Treffer", -8, False),
    "ship_explode": ([ship_explode], "Schiff zerstört", "Treffer", -1, False),
    # An Bord
    "fire_start": ([fire_start], "Feuer bricht aus", "An Bord", -4, False),
    "fire_loop": ([fire_loop], "Feuer brennt (Schleife)", "An Bord", -6, True),
    "extinguish": ([extinguish], "Feuer gelöscht", "An Bord", -8, False),
    "breach": ([breach], "Hüllenbruch", "An Bord", -3, False),
    "breach_fixed": ([breach_fixed], "Hüllenbruch geflickt", "An Bord", -8, False),
    "repaired": ([repaired], "System repariert", "An Bord", -9, False),
    "crew_died": ([crew_died], "Crew gefallen", "An Bord", -5, False),
    "door_open": ([door_open], "Tür öffnet", "An Bord", -10, False),
    "door_close": ([door_close], "Tür schließt", "An Bord", -10, False),
    "airlock_open": ([airlock_open], "Luftschleuse öffnet (Luft entweicht)", "An Bord", -6, False),
    "airlock_close": ([airlock_close], "Luftschleuse schließt", "An Bord", -7, False),
    "ship_hum": ([ship_hum], "Schiffsbrummen (Schleife)", "An Bord", -10, True),
    # Warnungen
    "alarm": ([alarm], "Alarm: Gegner flieht / Jäger kommen", "Warnungen", -9, False),
    "hull_low": ([hull_low], "Hülle kritisch", "Warnungen", -8, False),
    # Sprung
    "warp_out": ([loud(warp_out_a), loud(warp_out_b), loud(warp_out_c)], "Sprung: Abflug", "Sprung", -0.5, False),
    "warp_in": ([loud(warp_in_a), loud(warp_in_b), loud(warp_in_c)], "Sprung: Ankunft", "Sprung", -0.5, False),
    "jump_ready": ([jump_ready], "Sprungantrieb geladen", "Sprung", -10, False),
    "distress": ([distress], "Notsignal senden", "Sprung", -8, False),
    # Bedienung
    "ui_click": ([ui_click], "Knopf", "Bedienung", -13, False),
    "ui_deny": ([ui_deny], "Geht nicht", "Bedienung", -13, False),
    "map_open": ([map_open], "Karte öffnen", "Bedienung", -11, False),
    "map_close": ([map_close], "Karte schließen", "Bedienung", -11, False),
    "map_select": ([map_select], "Ziel auf der Karte gewählt", "Bedienung", -11, False),
    "map_travel": ([map_travel], "Schiff fliegt auf der Karte", "Bedienung", -11, False),
    "power_up": ([power_up], "Energie +1", "Bedienung", -12, False),
    "power_down": ([power_down], "Energie −1", "Bedienung", -12, False),
    "crew_select": ([crew_select], "Crew ausgewählt", "Bedienung", -13, False),
    "crew_order": ([crew_order], "Crew-Laufbefehl", "Bedienung", -12, False),
    "pause": ([pause], "Pause", "Bedienung", -11, False),
    "resume": ([resume], "Weiter", "Bedienung", -11, False),
    "dialog_open": ([dialog_open], "Ereignis / Funkspruch", "Bedienung", -9, False),
    "dialog_choice": ([dialog_choice], "Antwort gewählt", "Bedienung", -12, False),
    # Ergebnisse
    "reward": ([reward], "Beute", "Ergebnisse", -8, False),
    "victory": ([victory_a, victory_b, victory_c], "Sieg", "Ergebnisse", -4, False),
    "sector_clear": ([sector_clear], "Sektor geschafft (Boss besiegt)", "Ergebnisse", -4, False),
    "defeat": ([defeat_a, defeat_b, defeat_c], "Niederlage", "Ergebnisse", -4, False),
    "run_complete": ([run_complete], "Alle Sektoren geschafft", "Ergebnisse", -3, False),
}

# Welche Variante ins Spiel kommt (Index in der Variantenliste). Nicht genannt = erste.
CHOICE = {"warp_out": 0, "warp_in": 1, "victory": 2, "defeat": 2}
