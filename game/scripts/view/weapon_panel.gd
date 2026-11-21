class_name WeaponPanel
extends Control
## Waffenleiste: eine Karte je Waffe mit Name, Energiebedarf und Ladebalken.
## Antippen schaltet die Waffe ein oder aus. Geladene Waffen feuern selbst, sobald ein
## Ziel gewählt ist; ohne Ziel blinkt die Karte.

const CARD := Vector2(66, 30)
const GAP := 3.0
const FONT_SIZE := 8
const COLOR_BG := Color("#161B2B", 0.88)
const COLOR_EDGE := Color("#363E58")
const COLOR_READY := Color("#5DCAA5")
const COLOR_CHARGING := Color("#FAC775")
const COLOR_OFF := Color("#2A2F3A")
const COLOR_TEXT := Color("#C4CAD3")
const COLOR_TEXT_OFF := Color("#5A6370")

var state: ShipState
var battle: Battle
var _time := 0.0
var _deny := {}  # Waffenindex -> Sekunden Schütteln
var _fired := {}  # Waffenindex -> Sekunden Aufleuchten


func setup(p_state: ShipState, p_battle: Battle) -> void:
	state = p_state
	battle = p_battle
	custom_minimum_size = Vector2(state.weapons.size() * (CARD.x + GAP) - GAP, CARD.y)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func flash_fired(idx: int) -> void:
	_fired[idx] = 0.25


func _process(delta: float) -> void:
	_time += delta
	for d: Dictionary in [_deny, _fired]:
		for k in d.keys():
			d[k] -= delta
			if d[k] <= 0.0:
				d.erase(k)
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	var font := ThemeDB.fallback_font
	for i in state.weapons.size():
		var w := state.weapons[i]
		var x := i * (CARD.x + GAP)
		if _deny.has(i):
			x += roundf(sin(_deny[i] * 60.0) * 1.5)
		var rect := Rect2(Vector2(x, 0), CARD)
		var waiting := w.is_ready() and battle and battle.player_target < 0
		var edge := COLOR_EDGE
		if w.is_ready():
			edge = COLOR_READY if not waiting or fmod(_time, 0.6) < 0.3 else COLOR_EDGE
		draw_rect(rect, COLOR_BG)
		if _fired.has(i):
			draw_rect(rect, Color(1, 1, 1, _fired[i] * 1.2))
		draw_rect(rect.grow(-0.5), edge, false, 1.0)
		draw_string(font, rect.position + Vector2(3, 10), w.display_name, HORIZONTAL_ALIGNMENT_LEFT,
			CARD.x - 6, FONT_SIZE, COLOR_TEXT if w.powered else COLOR_TEXT_OFF)
		# Energiebedarf als kleine Balken oben rechts
		for p in w.cost:
			var pip := Rect2(rect.position + Vector2(CARD.x - 5 - p * 4, 13), Vector2(3, 2))
			draw_rect(pip, Color("#5DCAA5") if w.powered else COLOR_OFF)
		# Ladebalken
		var bar := Rect2(rect.position + Vector2(3, CARD.y - 8), Vector2(CARD.x - 6, 4))
		draw_rect(bar, COLOR_OFF)
		var fill := Rect2(bar.position, Vector2(roundf(bar.size.x * w.ratio()), bar.size.y))
		draw_rect(fill, COLOR_READY if w.is_ready() else (COLOR_CHARGING if w.powered else COLOR_TEXT_OFF))
		if waiting:
			draw_string(font, rect.position + Vector2(3, 20), "Ziel wählen", HORIZONTAL_ALIGNMENT_LEFT,
				CARD.x - 6, FONT_SIZE, COLOR_READY)


func _gui_input(event: InputEvent) -> void:
	if not state or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var idx := int(event.position.x / (CARD.x + GAP))
	if idx >= 0 and idx < state.weapons.size():
		var w := state.weapons[idx]
		if not state.set_weapon_wanted(idx, not w.powered):
			_deny[idx] = 0.25
	accept_event()
