class_name StatusBar
extends Control
## Oben rechts: Hülle des eigenen Schiffs, Schildschichten und Ausweichchance.
## Verlorene Hüllenpunkte leuchten kurz weiß nach.

const FONT_SIZE := 8
const COLOR_OK := Color("#5DCAA5")
const COLOR_WARN := Color("#FAC775")
const COLOR_BAD := Color("#E24B4A")
const COLOR_OFF := Color("#2A2F3A")
const COLOR_SHIELD := Color("#85B7EB")
const COLOR_TEXT := Color("#A9B0BB")

var state: ShipState
var _ghost := 0.0
var _time := 0.0


func setup(p_state: ShipState) -> void:
	state = p_state
	_ghost = state.hull
	custom_minimum_size = Vector2(state.max_hull * 3 + 85, 22)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not state:
		return
	_time += delta
	_ghost = move_toward(_ghost, state.hull, delta * 4.0) if _ghost > state.hull else float(state.hull)
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	var font := ThemeDB.fallback_font
	var ratio := float(state.hull) / maxf(state.max_hull, 1)
	var color := COLOR_OK if ratio > 0.5 else (COLOR_WARN if ratio > 0.25 else COLOR_BAD)
	if ratio <= 0.25 and fmod(_time, 0.8) < 0.4:
		color = color.lightened(0.4)
	draw_string(font, Vector2(0, 7), "HÜLLE", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
	var x0 := 30.0
	for i in state.max_hull:
		var rect := Rect2(Vector2(x0 + i * 3, 1), Vector2(2, 6))
		if i < state.hull:
			draw_rect(rect, color)
		elif i < ceili(_ghost):
			draw_rect(rect, Color.WHITE)
		else:
			draw_rect(rect, COLOR_OFF)
	draw_string(font, Vector2(0, 19), "SCHILD", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
	for i in state.max_shield_layers():
		var r := Rect2(Vector2(x0 + i * 8, 12), Vector2(6, 6))
		draw_rect(r, COLOR_SHIELD if i < state.shield_layers else COLOR_OFF)
		if i == state.shield_layers and state.shield_progress > 0.0:
			draw_rect(Rect2(r.position, Vector2(roundf(6 * state.shield_progress), 6)), Color(COLOR_SHIELD, 0.4))
	var evade := "Ausweichen %d %%" % roundi(state.evasion() * 100.0)
	draw_string(font, Vector2(x0 + 24, 19), evade, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
	var air := state.average_oxygen()
	var air_color := COLOR_TEXT if air > 0.5 else (COLOR_WARN if air > 0.25 else COLOR_BAD)
	draw_string(font, Vector2(x0 + 102, 19), "Luft %d %%" % roundi(air * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, air_color)
