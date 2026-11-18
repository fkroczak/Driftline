"""Raumsymbole 12x12 als Pixelmasken (X = Grundton, o = Lichtton)."""

ROOM_COLORS = {
    "Reaktor": ("#EF9F27", "#FDE6BF"),
    "Schilde": ("#378ADD", "#D3E6F8"),
    "Waffen": ("#E24B4A", "#F7C1C1"),
    "Antrieb": ("#D85A30", "#F9C9B6"),
    "Cockpit": ("#5DCAA5", "#DDF5EC"),
    "Medbay": ("#639922", "#E4F0D0"),
    "Sensoren": ("#7F77DD", "#CECBF6"),
    "Lebenserhaltung": ("#85B7EB", "#D3E6F8"),
    "Modul": ("#D4537E", "#FBE3EB"),
}

ICONS = {
    "Reaktor": [
        "....XXXX....",
        "..XXXXXXXX..",
        ".XX......XX.",
        ".X..XXXX..X.",
        "XX.XooooX.XX",
        "XX.XooooX.XX",
        "XX.XooooX.XX",
        "XX.XooooX.XX",
        ".X..XXXX..X.",
        ".XX......XX.",
        "..XXXXXXXX..",
        "....XXXX....",
    ],
    "Schilde": [
        "............",
        "....XXXX....",
        "..XX....XX..",
        ".X..oooo..X.",
        ".X.o....o.X.",
        "X.o..XX..o.X",
        "X.o.XooX.o.X",
        "X.o.XooX.o.X",
        "X.o.XooX.o.X",
        "............",
        "XXXXXXXXXXXX",
        "............",
    ],
    "Waffen": [
        ".....XX.....",
        "...XXXXXX...",
        "..X..XX..X..",
        ".X...XX...X.",
        ".X........X.",
        "XXXX.oo.XXXX",
        "XXXX.oo.XXXX",
        ".X........X.",
        ".X...XX...X.",
        "..X..XX..X..",
        "...XXXXXX...",
        ".....XX.....",
    ],
    "Antrieb": [
        "o.....o.....",
        "oo....oo....",
        ".oo....oo...",
        "..oo....oo..",
        "...oo....oo.",
        "....oo....oo",
        "....XX....XX",
        "...XX....XX.",
        "..XX....XX..",
        ".XX....XX...",
        "XX....XX....",
        "X.....X.....",
    ],
    "Cockpit": [
        "............",
        "XX........XX",
        "Xo........oX",
        "Xo........oX",
        "XXo......oXX",
        ".XXXXooXXXX.",
        "..XXXooXXX..",
        ".....XX.....",
        ".....XX.....",
        ".....XX.....",
        "...XXXXXX...",
        "...XXXXXX...",
    ],
    "Medbay": [
        "....XXXX....",
        "....XooX....",
        "....XooX....",
        "....XooX....",
        "XXXXXooXXXXX",
        "Xoooooooooo X".replace(" ", ""),
        "XooooooooooX",
        "XXXXXooXXXXX",
        "....XooX....",
        "....XooX....",
        "....XooX....",
        "....XXXX....",
    ],
    "Sensoren": [
        "............",
        "...XXXXXX...",
        ".XX......XX.",
        "X..........X",
        "...XXXXXX...",
        "..X......X..",
        ".X........X.",
        "....XXXX....",
        "...X....X...",
        "............",
        ".....oo.....",
        ".....oo.....",
    ],
    "Lebenserhaltung": [
        "......XXXX..",
        ".....XooooX.",
        ".....XooooX.",
        ".....XooooX.",
        "......XXXX..",
        ".XXX........",
        "XoooX.......",
        "XoooX..XXX..",
        ".XXX..XoooX.",
        "......XoooX.",
        ".......XXX..",
        "............",
    ],
}

for k, v in ICONS.items():
    assert len(v) == 12 and all(len(r) == 12 for r in v), k


def icon_svg(name, x, y):
    """Symbol mit 1-px-Schattenkante nach unten rechts (Licht oben links)."""
    base, light = ROOM_COLORS[name]
    out = []
    rows = ICONS[name]
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != ".":
                out.append(f'<rect x="{x + dx + 1}" y="{y + dy + 1}" width="1" height="1" fill="#0A0B16"/>')
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch == "X":
                out.append(f'<rect x="{x + dx}" y="{y + dy}" width="1" height="1" fill="{base}"/>')
            elif ch == "o":
                out.append(f'<rect x="{x + dx}" y="{y + dy}" width="1" height="1" fill="{light}"/>')
    return "".join(out)
