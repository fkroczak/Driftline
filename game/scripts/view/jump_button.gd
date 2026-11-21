class_name JumpButton
extends Control
## Sprungknopf: zeigt den Ladestand des Sprungantriebs. Voll geladen blinkt er grün;
## Antippen löst den Fluchtsprung aus. Lädt er nicht, steht der Grund darunter.

signal jump_requested

const COLOR_BG := Color("#161B2B", 0.88)
const COLOR_EDGE := Color("#363E58")
const COLOR_READY := Color("#5DCAA5")
const COLOR_CHARGE := Color("#D85A30")
const COLOR_OFF := Color("#2A2F3A")
const COLOR_TEXT := Color("#C4CAD3")
const COLOR_TEXT_OFF := Color("#5A6370")

var state: ShipState
var _time := 0.0
var _deny := 0.0


func setup(p_state: ShipState) -> void:
	state = p_state
	mouse_filter = Control.MOUSE_FILTER_STOP


func deny() -> void:
	_deny = 0.25


func _process(delta: float) -> void:
	_time += delta
	_deny = maxf(_deny - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	var font := ThemeDB.fallback_font
	var x := roundf(sin(_deny * 60.0) * 1.5) if _deny > 0.0 else 0.0
	var rect := Rect2(Vector2(x, 0), size)
	var ready := state.jump_ready()
	draw_rect(rect, COLOR_BG)
	if ready and fmod(_time, 0.6) < 0.3:
		draw_rect(rect, Color(COLOR_READY, 0.25))
	draw_rect(rect.grow(-0.5), COLOR_READY if ready else COLOR_EDGE, false, 1.0)
	draw_string(font, rect.position + Vector2(3, 10), "SPRUNG", HORIZONTAL_ALIGNMENT_LEFT, size.x - 6, 8,
		COLOR_READY if ready else COLOR_TEXT)
	var reason := ""
	if ready:
		reason = "bereit!"
	elif state.level("antrieb") <= 0:
		reason = "Antrieb aus"
	elif state.operator_of_system("cockpit") == null:
		reason = "kein Pilot"
	else:
		reason = "%d %%" % floori(state.jump_charge * 100.0)
	draw_string(font, rect.position + Vector2(3, 20), reason, HORIZONTAL_ALIGNMENT_LEFT, size.x - 6, 8,
		COLOR_READY if ready else COLOR_TEXT_OFF)
	var bar := Rect2(rect.position + Vector2(3, size.y - 6), Vector2(size.x - 6, 3))
	draw_rect(bar, COLOR_OFF)
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * state.jump_charge), 3)), COLOR_READY if ready else COLOR_CHARGE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		jump_requested.emit()
		accept_event()
