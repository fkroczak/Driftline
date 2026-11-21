class_name PauseButton
extends Control
## Pauseknopf: Antippen pausiert oder setzt fort. Gedrückt halten schaltet die Auto-Pause
## um (Kampf hält an, solange eine Crew-Figur oder Waffe zum Befehlen ausgewählt ist).
## Das kleine „A“ unten rechts zeigt, ob die Auto-Pause an ist.

signal toggled_pause
signal toggled_auto

const LONG_PRESS_MS := 400
const COLOR_BG := Color("#161B2B", 0.88)
const COLOR_EDGE := Color("#363E58")
const COLOR_ICON := Color("#FDE6BF")
const COLOR_ACTIVE := Color("#5DCAA5")
const COLOR_OFF := Color("#5A6370")

var paused := false
var auto_pause := true
var _press_time := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, COLOR_BG)
	draw_rect(rect.grow(-0.5), COLOR_ACTIVE if paused else COLOR_EDGE, false, 1.0)
	var c := (size / 2.0).floor() + Vector2(0, -1)
	if paused:
		# Abspielen-Dreieck: weiterlaufen lassen
		draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -5), c + Vector2(4, 0), c + Vector2(-3, 5)]), COLOR_ACTIVE)
	else:
		draw_rect(Rect2(c + Vector2(-4, -5), Vector2(3, 10)), COLOR_ICON)
		draw_rect(Rect2(c + Vector2(1, -5), Vector2(3, 10)), COLOR_ICON)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(size.x - 6, size.y - 1), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		COLOR_ACTIVE if auto_pause else COLOR_OFF)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if event.pressed:
		_press_time = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _press_time >= LONG_PRESS_MS:
		toggled_auto.emit()
	else:
		toggled_pause.emit()
