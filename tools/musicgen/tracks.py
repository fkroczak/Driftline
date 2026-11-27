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
