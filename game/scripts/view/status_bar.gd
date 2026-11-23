class_name StatusBar
extends Control
## Oben links (wie im Mockup): Kasten mit Hülle (Symbol, Segmente und Zahl), darunter die
## Schildschichten als Kreise, Luft und Ausweichchance. Symbole statt Wörtern, damit es
## ohne Sprache lesbar ist.
## Verlorene Hüllenpunkte leuchten kurz rot nach.

const SEG := 3
const HULL_X := 13.0
## Erster Schildkreis (links davon das Schild-Symbol).
const SHIELD_X := 17.0

var state: ShipState
var _ghost := 0.0
var _time := 0.0


func setup(p_state: ShipState) -> void:
	state = p_state
	_ghost = state.hull
	custom_minimum_size = Vector2(_box_width(), 24.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _box_width() -> float:
	return HULL_X + state.max_hull * SEG + 26.0


func _process(delta: float) -> void:
	if not state:
		return
	_time += delta
	_ghost = move_toward(_ghost, state.hull, delta * 4.0) if _ghost > state.hull else float(state.hull)
	if size.x != _box_width():
		custom_minimum_size.x = _box_width()
		size.x = custom_minimum_size.x
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	var box := Rect2(Vector2.ZERO, Vector2(size.x, 24))
	HudStyle.box(self, box)
	var ratio := float(state.hull) / maxf(state.max_hull, 1)
	var color := HudStyle.COLOR_OK if ratio > 0.5 else (HudStyle.COLOR_WARN if ratio > 0.25 else HudStyle.COLOR_BAD)
	if ratio <= 0.25 and fmod(_time, 0.8) < 0.4:
		color = color.lightened(0.4)
	HudStyle.icon(self, Vector2(3, 3), "hull", HudStyle.COLOR_TEXT)
	var x0 := HULL_X
	for i in state.max_hull:
		var rect := Rect2(Vector2(x0 + i * SEG, 3), Vector2(SEG - 1, 7))
		if i < state.hull:
			draw_rect(rect, color)
		elif i < ceili(_ghost):
			draw_rect(rect, Color(HudStyle.COLOR_BAD, 0.5 + 0.5 * sin(_time * 20.0)))
		else:
			draw_rect(rect, HudStyle.COLOR_OFF)
	HudStyle.text(self, Vector2(x0 + state.max_hull * SEG + 3, 10), "%d" % state.hull, color)
	# Schildschichten als Kreise, die gerade ladende füllt sich
	HudStyle.icon(self, Vector2(3, 14), "shield", HudStyle.COLOR_SHIELD)
	for i in maxi(state.max_shield_layers(), 1):
		var c := Vector2(SHIELD_X + i * 10, 17)
		var up := i < state.shield_layers
		draw_circle(c, 4.0, HudStyle.COLOR_SHIELD if up else HudStyle.COLOR_OFF)
		if not up:
			draw_arc(c, 3.5, 0, TAU, 12, HudStyle.COLOR_SHIELD.darkened(0.3), 1.0)
			if i == state.shield_layers and state.shield_progress > 0.0:
				draw_arc(c, 2.0, -PI / 2, -PI / 2 + TAU * state.shield_progress, 10, HudStyle.COLOR_SHIELD, 2.0)
	# Luft und Ausweichen rechts daneben in derselben Zeile
	var air := state.average_oxygen()
	var air_color := HudStyle.COLOR_TEXT if air > 0.5 else (HudStyle.COLOR_WARN if air > 0.25 else HudStyle.COLOR_BAD)
	var x := SHIELD_X - 2.0 + maxi(state.max_shield_layers(), 1) * 10.0
	var line_a := "O2 %d %%" % roundi(air * 100.0)
	HudStyle.text(self, Vector2(x, 21), line_a, air_color)
	x += HudStyle.text_width(line_a) + 8.0
	HudStyle.icon(self, Vector2(x, 14), "evade", HudStyle.COLOR_TEXT)
	HudStyle.text(self, Vector2(x + 9.0, 21), "%d %%" % roundi(state.evasion() * 100.0), HudStyle.COLOR_TEXT)
