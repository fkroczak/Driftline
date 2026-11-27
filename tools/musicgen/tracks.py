"""Die fünf Musikstücke als Beschreibung (Tempo, Akkorde, Abschnitte, Instrumente).

Stil: UK-Garage/Breakbeat zwischen Euphorie und Melancholie – 2-Step- und Breakbeat-Drums mit
Swing, Sub-Bass, breite Synthflächen, gechoppte (synthetische) Vocals mit Echo, Rave-Stabs.

Abschnitte: (Takte, "Ebenen"). Ebenen: kick snare hat perc bass pad voxpad vox stab arp keys,
lp (Drums gedämpft), riser (Rauschanstieg vor dem nächsten Abschnitt), crash, down.
Vocal-Phrasen: (Takt im Akkord, 16tel, Länge in 16teln, Stufe im Akkord, Vokal[, Gleiten]).
"""

TRACKS = {
    # 1 – Hauptmenü: warm, sehnsüchtig, 2-Step mit Vocal-Hook (am nächsten am Vorbild)
    "neonkueste": {
        "title": "Neonküste", "bpm": 132, "swing": 0.16, "seed": 1,
        "chords": [[53, 56, 60, 63, 67], [49, 56, 60, 65], [51, 56, 60, 63], [51, 58, 63, 65]],
        "bars_per_chord": 2, "drums": "2step", "bass": "2step", "pad": "saw", "pad_cut": 1700,
        "vox": [(0, 0, 2, 3, "a"), (0, 3, 1, 2, "o"), (0, 6, 2, 3, "a"), (0, 10, 3, 4, "e", 2),
                (1, 0, 2, 2, "o"), (1, 3, 3, 1, "a"), (1, 8, 1, 2, "a"), (1, 10, 4, 0, "o", -2)],
        "vox_range": (63, 80), "stab_pattern": [(3, 2), (11, 2)], "stab_cut": 2200,
        "sections": [
            (8, "pad voxpad vox hat kick lp"),
            (8, "pad vox kick snare hat perc bass lp riser"),
            (16, "pad vox kick snare hat perc bass stab crash"),
            (8, "pad voxpad vox down"),
            (8, "pad voxpad vox kick snare hat perc bass stab crash"),
        ],
        "mix": {"vox": 1, "pad": -1},
    },
    # 2 – Sternenkarte/Reise: dunkler, rollende Breaks, Reese-Bass
    "driftline": {
        "title": "Driftline", "bpm": 130, "swing": 0.10, "seed": 2,
        "chords": [[50, 57, 60, 65], [46, 53, 57, 62], [55, 58, 62, 65], [57, 62, 64, 69]],
        "bars_per_chord": 2, "drums": "break", "bass": "long", "reese": True, "reese_cut": 520,
        "pad": "saw", "pad_cut": 1100, "pump": 0.5, "kick_tune": 46,
        "vox": [(0, 2, 2, 2, "u"), (0, 7, 3, 3, "o"), (1, 4, 2, 2, "u"), (1, 10, 5, 1, "o", -3)],
        "vox_range": (60, 77), "arp_pattern": [0, 3, 1, 4, 2, 3, 1, 0], "arp_every": 2, "arp_bright": 2200,
        "sections": [
            (8, "pad hat perc kick snare lp"),
            (8, "pad kick snare hat perc bass vox riser"),
            (16, "pad kick snare hat perc bass vox arp crash"),
            (8, "pad voxpad arp down"),
            (8, "pad kick snare hat perc bass vox arp crash"),
        ],
        "mix": {"arp": -2},
    },
    # 3 – Titelstück: euphorisch, Rave-Stabs, Arpeggio, Vocal-Hook
    "hullbound": {
        "title": "Hullbound", "bpm": 134, "swing": 0.12, "seed": 3,
        "chords": [[57, 60, 64, 71], [53, 57, 60, 64], [55, 60, 64, 67], [55, 59, 62, 67]],
        "bars_per_chord": 1, "drums": "break", "bass": "roll", "pad": "saw", "pad_cut": 2000,
        "vox": [(0, 0, 3, 3, "a"), (0, 4, 2, 4, "e"), (0, 7, 1, 3, "a"), (0, 8, 3, 2, "o"), (0, 12, 4, 3, "a", 2)],
        "vox_range": (64, 81), "arp_pattern": [0, 2, 4, 2, 1, 3, 5, 3], "arp_every": 1, "arp_bright": 3800,
        "stab_pattern": [(0, 3), (6, 2), (10, 3)], "keys_pattern": [(2, 4), (8, 4), (14, 2)],
        "sections": [
            (8, "pad keys arp hat lp kick"),
            (8, "pad keys vox kick snare hat perc bass lp riser"),
            (16, "pad vox kick snare hat perc bass stab arp crash"),
            (8, "pad voxpad keys vox down"),
            (8, "pad vox kick snare hat perc bass stab arp crash"),
        ],
        "mix": {"arp": -2, "keys": -2},
    },
    # 4 – Ruhephase/Lexikon: tief, entspannt, Half-Time, E-Piano
    "nachtsektor": {
        "title": "Nachtsektor", "bpm": 122, "swing": 0.18, "seed": 4,
        "chords": [[52, 59, 62, 66, 67], [48, 55, 59, 64], [55, 59, 62, 64], [54, 57, 62, 66]],
        "bars_per_chord": 2, "drums": "half", "bass": "half", "pad": "warm", "pad_cut": 1300,
        "pump": 0.35, "hall": 4.0, "clap": False, "open_hat": False, "kick_decay": 0.5,
        "vox": [(0, 4, 4, 3, "o"), (1, 0, 6, 2, "a", 1), (1, 10, 4, 1, "o")],
        "vox_range": (62, 79), "keys_pattern": [(0, 8), (10, 6)], "voxpad_vowel": "o",
        "sections": [
            (8, "pad keys voxpad"),
            (8, "pad keys hat perc kick lp vox"),
            (16, "pad keys kick snare hat perc bass vox"),
            (8, "pad voxpad keys down"),
            (8, "pad keys kick snare hat perc bass vox voxpad"),
        ],
        "mix": {"keys": 1, "drums": -3, "reverb": 3},
    },
    # 5 – Kampf: schnell, treibend, Acid-Bass, Stabs
    "jaegerfront": {
        "title": "Jägerfront", "bpm": 138, "swing": 0.08, "seed": 5,
        "chords": [[48, 55, 60, 63], [51, 56, 60, 63], [51, 55, 58, 63], [50, 53, 58, 62]],
        "bars_per_chord": 1, "drums": "break", "bass": "acid", "acid_cut": 650, "pad": "saw",
        "pad_cut": 1200, "pump": 0.7, "kick_tune": 50,
        "vox": [(0, 0, 1, 3, "a"), (0, 2, 1, 3, "a"), (0, 6, 2, 4, "e"), (0, 11, 3, 2, "o", -2)],
        "vox_range": (60, 77), "stab_pattern": [(0, 2), (3, 2), (8, 2), (14, 2)], "stab_cut": 3000,
        "arp_pattern": [0, 4, 2, 5, 1, 4, 3, 6], "arp_every": 1, "arp_bright": 2600, "arp_rotate": True,
        "sections": [
            (4, "kick hat bass lp"),
            (8, "kick snare hat perc bass stab riser"),
            (16, "kick snare hat perc bass stab vox pad crash"),
            (4, "pad vox hat down"),
            (16, "kick snare hat perc bass stab vox pad arp crash"),
        ],
        "mix": {"arp": -3, "reverb": -2},
    },
}

# Ruhige Hintergrundmusik: leise Drums (gedämpft), viel Fläche und Raum, wenig Melodie,
# weniger Verdichtung im Master. Je ein Stück pro Spielsituation.
_CALM = {"drive": 1.0, "peak_db": -4.0, "pump": 0.25, "clap": False, "open_hat": False, "fills": False,
         "pad": "warm", "hall": 5.0}

AMBIENT = {
    # Ruhe an Bord / Sternenkarte: fast ohne Rhythmus, schwebend
    "stille_drift": {**_CALM,
        "title": "Stille Drift", "bpm": 84, "seed": 11,
        "chords": [[50, 57, 60, 64, 65], [46, 53, 57, 62], [43, 50, 55, 58, 62], [45, 52, 57, 60, 64]],
        "bars_per_chord": 2, "bass": "drone", "pad_cut": 1100, "voxpad_vowel": "u",
        "keys_pattern": [(0, 10)], "arp_pattern": [0, 3, 2, 4], "arp_every": 4, "arp_wave": "tri",
        "arp_bright": 1600, "arp_range": (62, 81),
        "sections": [(8, "pad voxpad"), (8, "pad keys bass"), (8, "pad keys bass arp voxpad"),
                     (8, "pad bass arp")],
        "mix": {"pad": 2, "voxpad": -4, "keys": -5, "arp": -6, "bass": -6, "reverb": 4},
    },
    # Auftrag / Ereignis: geheimnisvoll, Arpeggio im Nebel, leiser Puls
    "signal_im_nebel": {**_CALM,
        "title": "Signal im Nebel", "bpm": 100, "seed": 12, "swing": 0.1,
        "chords": [[52, 59, 63, 66], [48, 55, 59, 62, 66], [50, 57, 61, 64], [47, 54, 59, 62]],
        "bars_per_chord": 2, "drums": "pulse", "bass": "half", "lp_cut": 900, "pad_cut": 1300,
        "arp_pattern": [0, 2, 4, 3, 1, 3, 5, 2], "arp_every": 2, "arp_wave": "tri", "arp_bright": 2000,
        "arp_range": (64, 84), "voxpad_vowel": "o",
        "sections": [(8, "pad arp"), (8, "pad arp kick hat perc lp bass"),
                     (8, "pad arp kick hat perc lp bass voxpad"), (8, "pad voxpad arp")],
        "mix": {"drums": -9, "arp": -3, "bass": -4, "voxpad": -5, "reverb": 3},
    },
    # Piratenangriff: angespannt, pulsierender Bass, Drums nur angedeutet
    "enterhaken": {**_CALM,
        "title": "Enterhaken", "bpm": 118, "seed": 13, "pad": "saw",
        "chords": [[45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 58], [40, 47, 52, 56]],
        "bars_per_chord": 2, "drums": "pulse", "bass": "pulse8", "lp_cut": 1400, "pad_cut": 800,
        "pump": 0.35, "peak_db": -6.5,
        "arp_pattern": [0, 1, 2, 1], "arp_every": 1, "arp_wave": "saw", "arp_bright": 900,
        "arp_range": (57, 72),
        "sections": [(8, "pad bass kick hat lp"), (8, "pad bass kick hat perc lp arp"),
                     (8, "pad bass kick hat perc arp lp"), (8, "pad bass arp")],
        "mix": {"drums": -7, "bass": -2, "arp": -8, "pad": -1, "reverb": 1},
    },
    # Jägerangriff: dunkel und bedrohlich, tiefer Chor, Trommeln wie aus der Ferne
    "schatten_der_jaeger": {**_CALM,
        "title": "Schatten der Jäger", "bpm": 124, "seed": 14, "pad": "saw",
        "chords": [[41, 48, 53, 56], [40, 47, 52, 55], [44, 51, 56, 60], [43, 50, 55, 59]],
        "bars_per_chord": 2, "drums": "tension", "bass": "drone", "reese": True, "reese_cut": 300,
        "lp_cut": 1100, "pad_cut": 700, "kick_tune": 55, "kick_decay": 0.28, "pump": 0.3,
        "peak_db": -5.0, "voxpad_vowel": "o",
        "arp_pattern": [0, 0, 1, 0, 2, 0, 1, 0], "arp_every": 1, "arp_wave": "saw", "arp_bright": 700,
        "arp_range": (53, 68),
        "sections": [(8, "pad voxpad bass kick lp"), (8, "pad voxpad bass kick snare hat perc lp"),
                     (8, "pad voxpad bass kick snare hat perc lp arp"), (8, "pad voxpad bass arp")],
        "mix": {"drums": -6, "bass": -3, "voxpad": -2, "arp": -9, "reverb": 2},
    },
    # Händler / Reparaturstation: warm, freundlich, E-Piano
    "andockhafen": {**_CALM,
        "title": "Andockhafen", "bpm": 92, "seed": 15, "swing": 0.15,
        "chords": [[53, 60, 64, 69], [50, 57, 60, 65], [46, 53, 57, 62, 64], [48, 55, 58, 64]],
        "bars_per_chord": 2, "drums": "half", "bass": "half", "lp_cut": 1200, "pad_cut": 1500,
        "keys_pattern": [(0, 6), (6, 4), (10, 6)], "voxpad_vowel": "a",
        "sections": [(8, "pad keys"), (8, "pad keys kick hat perc lp bass"),
                     (8, "pad keys kick hat perc lp bass voxpad"), (8, "pad keys voxpad")],
        "mix": {"drums": -9, "keys": 1, "bass": -5, "voxpad": -6, "reverb": 3},
    },
}
