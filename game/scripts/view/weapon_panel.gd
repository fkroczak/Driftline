class_name WeaponPanel
extends Control
## Waffenleiste: eine Karte je Waffe mit Nummer, Name, Ziel, Energiebedarf und Ladebalken.
##
## - Karte antippen: Waffe zum Zielen auswählen (ohne Energie wird sie dabei eingeschaltet).
##   Danach einen Gegnerraum antippen: nur diese Waffe zielt dorthin.
##   Ihren aktuellen Zielraum erneut antippen: Ziel aufheben, die Waffe hält das Feuer.
## - Gedrückt halten oder Rechtsklick: Waffe ein- oder ausschalten.
## Ohne ausgewählte Waffe zielt ein Gegnerraum für alle Waffen (siehe main.gd).
## Geladene Waffen feuern selbst; ohne Ziel blinkt die Karte.

signal selection_changed(idx: int)

const CARD := Vector2(74, 30)
const GAP := 3.0
const FONT_SIZE := 8
const LONG_PRESS_MS := 400
const COLOR_BG := Color("#161B2B", 0.88)
const COLOR_EDGE := Color("#363E58")
const COLOR_READY := Color("#5DCAA5")
const COLOR_CHARGING := Color("#FAC775")
const COLOR_OFF := Color("#2A2F3A")
const COLOR_TEXT := Color("#C4CAD3")
const COLOR_TEXT_OFF := Color("#5A6370")
const COLOR_AIM := Color("#E24B4A")

var state: ShipState
var enemy: ShipState
## Zum Zielen ausgewählte Waffe, -1 = keine.
var selected := -1
var _time := 0.0
var _deny := {}  # Waffenindex -> Sekunden Schütteln
var _fired := {}  # Waffenindex -> Sekunden Aufleuchten
var _press_time := 0
var _press_idx := -1


func setup(p_state: ShipState, p_enemy: ShipState) -> void:
	state = p_state
	enemy = p_enemy
	custom_minimum_size = Vector2(state.weapons.size() * (CARD.x + GAP) - GAP, CARD.y)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func select(idx: int) -> void:
	selected = idx
	selection_changed.emit(idx)


func flash_fired(idx: int) -> void:
	_fired[idx] = 0.25


func _process(delta: float) -> void:
	_time += delta
	for d: Dictionary in [_deny, _fired]:
		for k in d.keys():
			d[k] -= delta
			if d[k] <= 0.0:
				d.erase(k)
	if selected >= 0 and not state.weapons[selected].powered:
		select(-1)
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
		var waiting := w.is_ready() and w.target < 0
		var blink := fmod(_time, 0.6) < 0.3
		var edge := COLOR_EDGE
		if i == selected:
			edge = COLOR_AIM if blink else COLOR_AIM.darkened(0.4)
		elif w.is_ready():
			edge = COLOR_READY if not waiting or blink else COLOR_EDGE
		draw_rect(rect, COLOR_BG)
		if _fired.has(i):
			draw_rect(rect, Color(1, 1, 1, _fired[i] * 1.2))
		draw_rect(rect.grow(-0.5), edge, false, 1.0)
		if i == selected:
			draw_rect(rect.grow(-1.5), Color(COLOR_AIM, 0.5), false, 1.0)
		# Nummer wie am Fadenkreuz
		var badge := Rect2(rect.position + Vector2(2, 2), Vector2(8, 9))
		draw_rect(badge, COLOR_AIM if w.target >= 0 else COLOR_OFF)
		draw_string(font, badge.position + Vector2(2, 8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
		var text_color := COLOR_TEXT if w.powered else COLOR_TEXT_OFF
		draw_string(font, rect.position + Vector2(12, 10), w.display_name, HORIZONTAL_ALIGNMENT_LEFT,
			CARD.x - 15, FONT_SIZE, text_color)
		# Energiebedarf als kleine Balken oben rechts
		for p in w.cost:
			var pip := Rect2(rect.position + Vector2(CARD.x - 5 - p * 4, 13), Vector2(3, 2))
			draw_rect(pip, COLOR_READY if w.powered else COLOR_OFF)
		# Zweite Zeile: Ziel oder Hinweis
		var line := ""
		var line_color := COLOR_TEXT_OFF
		if i == selected:
			line = "Raum antippen"
			line_color = COLOR_AIM
		elif not w.powered:
			line = "aus"
		elif waiting:
			line = "Ziel wählen"
			line_color = COLOR_READY
		elif w.target >= 0 and enemy:
			line = "→ " + enemy.layout.rooms[w.target].name
			line_color = COLOR_TEXT
		draw_string(font, rect.position + Vector2(3, 20), line, HORIZONTAL_ALIGNMENT_LEFT, CARD.x - 14, FONT_SIZE, line_color)
		# Ladebalken
		var bar := Rect2(rect.position + Vector2(3, CARD.y - 6), Vector2(CARD.x - 6, 3))
		draw_rect(bar, COLOR_OFF)
		var fill := Rect2(bar.position, Vector2(roundf(bar.size.x * w.ratio()), bar.size.y))
		draw_rect(fill, COLOR_READY if w.is_ready() else (COLOR_CHARGING if w.powered else COLOR_TEXT_OFF))


func _gui_input(event: InputEvent) -> void:
	if not state or not (event is InputEventMouseButton):
		return
	var idx := int(event.position.x / (CARD.x + GAP))
	if idx < 0 or idx >= state.weapons.size():
		return
	accept_event()
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_toggle_power(idx)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_time = Time.get_ticks_msec()
			_press_idx = idx
		elif idx == _press_idx:
			if Time.get_ticks_msec() - _press_time >= LONG_PRESS_MS:
				_toggle_power(idx)
			else:
				_tap(idx)


func _tap(idx: int) -> void:
	if selected == idx:
		select(-1)
		return
	if not state.weapons[idx].powered and not state.set_weapon_wanted(idx, true):
		_deny[idx] = 0.25
		return
	select(idx)


func _toggle_power(idx: int) -> void:
	var w := state.weapons[idx]
	if not state.set_weapon_wanted(idx, not w.powered):
		_deny[idx] = 0.25
	elif selected == idx and not w.powered:
		select(-1)
