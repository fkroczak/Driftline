class_name Legend
extends Control
## Symbol-Legende über dem ganzen Bildschirm: Raumsymbol, Name, Wirkung, dazu die Bedienung.
## Antippen schließt sie. Solange sie offen ist, pausiert battle_screen.gd den Kampf.

signal closed

const FONT_SIZE := 8
const ROW_H := 17.0
const COLOR_BG := Color("#07080F", 0.92)
const COLOR_TITLE := Color("#FDE6BF")
const COLOR_NAME := Color("#E6EAF0")
const COLOR_TEXT := Color("#A9B0BB")
const CONTROLS := [
	"Gegnerraum antippen: alle Waffen zielen · Waffenkarte, dann Raum: nur diese Waffe",  # i18n
	"Energie: Spalte antippen +1, gedrückt halten −1 · Waffenkarte halten: an/aus",  # i18n
	"Tür oder gelbe Schleuse antippen: auf/zu · offene Schleuse saugt Luft ab",  # i18n
	"Crew antippen, dann Ziel · Wer im Raum steht, löscht, flickt und repariert",  # i18n
	"SPRUNG lädt nach jedem Sprung neu (Pilot nötig, im Kampf auch Antrieb) · voll: Ziel auf der Karte",  # i18n
	"Pause antippen (oder Leertaste) · halten: Auto-Pause an/aus (A)",  # i18n
]

var _icons := {}  # System-ID ("" = Erweiterung) -> AtlasTexture


func setup(layout: ShipLayout, ship_texture: Texture2D) -> void:
	for i in layout.rooms.size():
		var system: String = layout.rooms[i].system
		if _icons.has(system) or (system == "" and layout.rooms[i].size != Vector2i(2, 2)):
			continue
		var icon := AtlasTexture.new()
		icon.atlas = ship_texture
		icon.region = Rect2(layout.room_rect(i).position + Vector2(8, 8), Vector2(12, 12))
		_icons[system] = icon
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_string(font, Vector2(10, 14), Loc.t("Symbole"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TITLE)
	draw_string(font, Vector2(size.x - 78, 14), Loc.t("Tippen: weiter"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
	var entries := SystemInfo.ENTRIES
	var per_col := ceili(entries.size() / 2.0)
	var col_w := (size.x - 20.0) / 2.0
	for k in entries.size():
		var e: Array = entries[k]
		var p := Vector2(10 + (k / per_col) * col_w, 22 + (k % per_col) * ROW_H)
		var icon: Texture2D = _icons.get(e[0])
		if icon:
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(14, 14)), Color("#20263A"))
			draw_texture(icon, p)
		draw_string(font, p + Vector2(17, 6), Loc.t(e[1]), HORIZONTAL_ALIGNMENT_LEFT, col_w - 20, FONT_SIZE, COLOR_NAME)
		draw_string(font, p + Vector2(17, 14), Loc.t(e[2]), HORIZONTAL_ALIGNMENT_LEFT, col_w - 20, FONT_SIZE, COLOR_TEXT)
	var y := 22 + per_col * ROW_H + 8
	draw_line(Vector2(10, y - 5), Vector2(size.x - 10, y - 5), Color("#363E58"))
	for line in CONTROLS:
		draw_string(font, Vector2(10, y + 4), Loc.t(line), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, FONT_SIZE, COLOR_TEXT)
		y += 11


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		visible = false
		Sfx.play("ui_click")
		closed.emit()
		accept_event()
