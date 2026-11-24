"""Symbole 12x12 für Waffen und Perks (Händler, Schiffsausbau). X = Grundton, o = Lichtton.
Atlas: game/assets/ui/item_icons.png, je 14 x 14 (Symbol + Schattenkante), Reihenfolge ORDER."""

ITEMS = {
    "pulslaser": (("#E24B4A", "#F7C1C1"), [
        "............", "..XX........", ".XooX.......", "..XXXXXX....", "............", "............",
        "......XX....", ".....XooX...", "......XXXXXX", "............", "............", "............"]),
    "schwerer_laser": (("#E24B4A", "#F7C1C1"), [
        "............", "............", "XXX.........", "XoXXXXXXXXXX", "XoooooooooooX"[:12], "XoooooooooooX"[:12],
        "XoXXXXXXXXXX", "XXX.........", "............", "............", "............", "............"]),
    "bordkanone": (("#8E97A4", "#E6EAF0"), [
        "............", "............", "XXXX........", "XooXXXXXX...", "XooooooooX..", "XooXXXXXX.XX",
        "XXXX.....XoX", ".........XX.", "............", "............", "............", "............"]),
    "salvenlaser": (("#E24B4A", "#F7C1C1"), [
        ".XX.........", "XooXXXXX....", ".XX.........", "....XX......", "...XooXXXXX.", "....XX......",
        "........XX..", ".......XooXX", "........XX..", "............", "............", "............"]),
    "brandkanone": (("#EF9F27", "#FDE6BF"), [
        "........X...", ".......XoX..", "......XooX..", "......XooXX.", ".....XoooooX", "XXXX.XoooooX",
        "XooXXXXooooX", "XooooooXoooX", "XooXXXXXXXX.", "XXXX........", "............", "............"]),
    "schwere_kanone": (("#747D8A", "#C4CAD3"), [
        "............", "XXXXX.......", "XoooXXXXXXX.", "XoooooooooXX", "XoooooooooXo", "XoooooooooXo",
        "XoooooooooXX", "XoooXXXXXXX.", "XXXXX.......", "............", "............", "............"]),
    "durchschlaglaser": (("#378ADD", "#D3E6F8"), [
        "......X.....", ".....X......", "....X.......", "....X.......", "XXXXXXXXXXXX", "ooooXooooooo",
        "XXXXXXXXXXXX", "....X.......", "....X.......", ".....X......", "......X.....", "............"]),
    "torpedo": (("#D4537E", "#FBE3EB"), [
        "............", "XX..........", "XXX.XXXXX...", ".XXXoooooXX.", ".XXXooooooXX", ".XXXoooooXX.",
        "XXX.XXXXX...", "XX..........", "............", "............", "............", "............"]),
    # Perks
    "panzerung": (("#8E97A4", "#E6EAF0"), [
        "XXXXXXXXXXXX", "XooooooooooX", "XoXXooooXXoX", "XoXXooooXXoX", "XooooooooooX", "XooooooooooX",
        ".XooooooooX.", ".XooXXXXooX.", "..XooooooX..", "...XooooX...", "....XXXX....", "............"]),
    "zielcomputer": (("#E24B4A", "#F7C1C1"), [
        ".....XX.....", "...XXooXX...", "..X..XX..X..", ".X...XX...X.", ".X...XX...X.", "XXXXXooXXXXX",
        "XXXXXooXXXXX", ".X...XX...X.", ".X...XX...X.", "..X..XX..X..", "...XXooXX...", ".....XX....."]),
    "ausweichduesen": (("#5DCAA5", "#DDF5EC"), [
        "............", ".....XX.....", "....XooX....", "...XooooX...", "..XooooooX..", ".XXXXooXXXX.",
        "....XooX....", "....XooX....", "...X.XX.X...", "..X..XX..X..", ".....XX.....", "............"]),
    "reparaturdrohne": (("#FAC775", "#FDE6BF"), [
        "XXX......XXX", "XoX......XoX", ".XXX....XXX.", "...XXXXXX...", "...XooooX...", "...XoXXoX...",
        "...XooooX...", "...XXXXXX...", ".XXX....XXX.", "XoX......XoX", "XXX......XXX", "............"]),
    "brandschutz": (("#85B7EB", "#D3E6F8"), [
        ".....XX.....", ".....XX.....", "...XXXXXX...", "..XooooooX..", "..XooooooX..", "..XoXooXoX..",
        "..XooooooX..", "..XoXooXoX..", "..XooooooX..", "..XooooooX..", "...XXXXXX...", "............"]),
    "bergungsgreifer": (("#D9A867", "#FDE6BF"), [
        "....XXXX....", "....XooX....", "....XooX....", "..XXXooXXX..", ".XooXXXXooX.", "Xoo......ooX",
        "Xo........oX", "Xo........oX", ".Xo......oX.", "..X......X..", "............", "............"]),
    "treibstoffrecycler": (("#EF9F27", "#FDE6BF"), [
        "...XXXXX....", "..XoooooX...", ".XoXXXXXoX..", "XoX.....XoX.", "XoX.......XX", "XoX......XoX",
        "XoX.....XooX", ".X.....XoooX", "...XXXXXXXX.", "............", "............", "............"]),
    "batterie": (("#D4537E", "#FBE3EB"), [
        "............", "....XXXX....", "..XXXXXXXX..", "..X......X..", "..X.oooo.X..", "..X......X..",
        "..X.oooo.X..", "..X......X..", "..X.oooo.X..", "..X......X..", "..XXXXXXXX..", "............"]),
}

ORDER = list(ITEMS)

for k, (_, rows) in ITEMS.items():
    assert len(rows) == 12 and all(len(r) == 12 for r in rows), (k, [len(r) for r in rows])


def atlas_image():
    from PIL import Image
    cell = 14
    img = Image.new("RGBA", (cell * len(ORDER), cell), (0, 0, 0, 0))
    hexrgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
    for n, name in enumerate(ORDER):
        (base, light), rows = ITEMS[name]
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch != ".":
                    img.putpixel((n * cell + dx + 1, dy + 1), hexrgb("#0A0B16"))
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch == "X":
                    img.putpixel((n * cell + dx, dy), hexrgb(base))
                elif ch == "o":
                    img.putpixel((n * cell + dx, dy), hexrgb(light))
    return img
