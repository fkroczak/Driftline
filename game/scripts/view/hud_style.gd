class_name HudStyle
extends RefCounted
## Gemeinsamer Look der Bedienelemente nach dem Mockup (art/pixel/hud_kampf_pixel.png):
## dunkle Kästen mit blauem Rahmen, Beschriftung in Versalien, Akzentfarben aus der Palette.

const FONT_SIZE := 8
const COLOR_BG := Color("#0A0B16", 0.9)
const COLOR_EDGE := Color("#185FA5")
const COLOR_EDGE_HI := Color("#378ADD")
const COLOR_TEXT := Color("#C4CAD3")
const COLOR_DIM := Color("#747D8A")
const COLOR_OFF := Color("#2A2F3A")
const COLOR_OK := Color("#5DCAA5")
const COLOR_WARN := Color("#FAC775")
const COLOR_BAD := Color("#E24B4A")
const COLOR_FUEL := Color("#EF9F27")
const COLOR_SCRAP := Color("#A9B0BB")
const COLOR_SHIELD := Color("#85B7EB")
const COLOR_GOLD := Color("#FAC775")


static func font() -> Font:
	return ThemeDB.fallback_font


## Kasten mit Rahmen; `edge` überschreibt die Rahmenfarbe.
static func box(ci: CanvasItem, rect: Rect2, edge := COLOR_EDGE, fill := COLOR_BG) -> void:
	ci.draw_rect(rect, fill)
	ci.draw_rect(rect.grow(-0.5), edge, false, 1.0)


static func text(ci: CanvasItem, pos: Vector2, value: String, color := COLOR_TEXT, width := -1.0, size := FONT_SIZE) -> void:
	ci.draw_string(font(), pos, value, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


static func text_width(value: String, size := FONT_SIZE) -> float:
	return font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Kleiner Stern (5×5) für den Captain.
static func star(ci: CanvasItem, pos: Vector2, color := COLOR_GOLD) -> void:
	ci.draw_rect(Rect2(pos + Vector2(2, 0), Vector2(1, 5)), color)
	ci.draw_rect(Rect2(pos + Vector2(0, 2), Vector2(5, 1)), color)
	ci.draw_rect(Rect2(pos + Vector2(1, 1), Vector2(3, 3)), color)


## Pixel-Symbole (7×7) statt Wörtern, damit die Anzeige ohne Sprache auskommt.
const ICONS := {
	# Kanister mit Querstreifen
	"fuel": [".XX....", "XXXXXX.", "X.XXXXX", "XX.XXXX", "XXX.XXX", "XXXX.XX", "XXXXXXX"],
	# Zahnrad
	"scrap": [".X.X.X.", "XXXXXXX", ".XX.XX.", "XX...XX", ".XX.XX.", "XXXXXXX", ".X.X.X."],
	# Schiffsrumpf von oben, Bug rechts
	"hull": ["XX.....", ".XXXX..", "XXXXXXX", "XXXXXXX", ".XXXX..", "XX.....", "......."],
	# Schild
	"shield": ["XXXXXXX", "X.XXX.X", "XXXXXXX", ".XXXXX.", ".XXXXX.", "..XXX..", "...X..."],
	# Ausweichen: Pfeil schräg nach oben
	"evade": ["..XXXXX", "....XXX", "...X.XX", "..X...X", ".X.....", "X......", "......."],
}


static func icon(ci: CanvasItem, pos: Vector2, kind: String, color: Color) -> void:
	var rows: Array = ICONS.get(kind, [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "X":
				ci.draw_rect(Rect2(pos + Vector2(x, y), Vector2.ONE), color)
