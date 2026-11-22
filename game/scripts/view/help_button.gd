class_name HelpButton
extends Control
## Kleiner „?“-Knopf; öffnet die Symbol-Legende.

signal pressed

const COLOR_BG := HudStyle.COLOR_BG
const COLOR_EDGE := HudStyle.COLOR_EDGE
const COLOR_TEXT := Color("#FDE6BF")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), COLOR_EDGE, false, 1.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2((size.x - w) / 2.0, size.y / 2.0 + 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_TEXT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
