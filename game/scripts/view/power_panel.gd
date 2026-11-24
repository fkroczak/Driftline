class_name PowerPanel
extends Control
## Energieleiste: links der Reaktor (grün = frei), daneben eine Spalte je System.
##
## - Spalte antippen: ein Balken Energie mehr
## - Gedrückt halten (oder Rechtsklick): ein Balken weniger
## Balken: grün = versorgt, dunkel = frei, rot = beschädigt.
## Schilde: je zwei Balken nebeneinander (Backbord, Steuerbord) ergeben eine Schicht.
## Ein versorgter Balken ohne versorgten Partner ist gelb: Er bewirkt nichts.

const SYSTEMS := ["schilde", "waffen", "antrieb", "sensoren", "medbay", "lebenserhaltung"]
const REACTOR_W := 12
const COL_W := 20
const HEIGHT := 34
const BAR_H := 2
const BAR_STEP := 3
const COLOR_BG := HudStyle.COLOR_BG
const COLOR_EDGE := HudStyle.COLOR_EDGE
const COLOR_ON := Color("#5DCAA5")
const COLOR_OFF := Color("#2A2F3A")
const COLOR_BROKEN := Color("#E24B4A")
const COLOR_REACTOR := Color("#FAC775")
const COLOR_HALF := Color("#FAC775")
const LONG_PRESS_MS := 400

## Bei jedem Antippen einer Spalte, damit die Infozeile erklären kann, was das System tut.
signal system_tapped(system: String, changed: bool)

var state: ShipState
var _icons := {}  # System -> AtlasTexture (Raumsymbol aus dem Schiffs-Sprite)
var _columns: Array[String] = []
var _pop := {}  # System -> Sekunden Aufleuchten
var _deny := {}  # System -> Sekunden Schütteln
var _press_time := 0
var _press_col := -1


func setup(p_state: ShipState, ship_texture: Texture2D) -> void:
	state = p_state
	_columns.clear()
	for id in SYSTEMS:
		if state.systems.has(id):
			_columns.append(id)
			var room := state.layout.room_of_system(id)
			if room >= 0:
				var icon := AtlasTexture.new()
				icon.atlas = ship_texture
				icon.region = Rect2(state.layout.room_rect(room).position + Vector2(8, 8), Vector2(12, 12))
				_icons[id] = icon
	custom_minimum_size = Vector2(REACTOR_W + 4 + _columns.size() * COL_W, HEIGHT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	for d: Dictionary in [_pop, _deny]:
		for k in d.keys():
			d[k] -= delta
			if d[k] <= 0.0:
				d.erase(k)
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	HudStyle.box(self, Rect2(0, 3, size.x, size.y - 3))
	draw_rect(Rect2(5, 0, HudStyle.text_width("ENERGIE") + 4, 7), HudStyle.COLOR_BG)
	HudStyle.text(self, Vector2(7, 7), "ENERGIE", HudStyle.COLOR_TEXT)
	# Reaktor: unten freie Balken (gelb), darüber belegte (dunkel), oben zerstörte (rot)
	var reactor := state.get_system("reaktor")
	if reactor:
		var free := state.power_free()
		for i in reactor.capacity:
			var color := COLOR_OFF
			if i >= reactor.usable():
				color = COLOR_BROKEN
			elif i < free:
				color = COLOR_REACTOR
			draw_rect(Rect2(Vector2(3, HEIGHT - 4 - i * BAR_STEP), Vector2(REACTOR_W - 4, BAR_H)), color)
	for c in _columns.size():
		_draw_column(c)


func _draw_column(c: int) -> void:
	var id := _columns[c]
	var sys := state.get_system(id)
	var x := REACTOR_W + 4 + c * COL_W
	if _deny.has(id):
		x += roundf(sin(_deny[id] * 60.0) * 1.5)
	var icon: Texture2D = _icons.get(id)
	if icon:
		var dim := 1.0 if sys.power > 0 else 0.45
		draw_texture(icon, Vector2(x + 4, HEIGHT - 14), Color(dim, dim, dim))
	if id == "schilde":
		_draw_shield_pairs(sys, x)
		return
	for b in sys.capacity:
		var color := COLOR_OFF
		if b >= sys.usable():
			color = COLOR_BROKEN
		elif b < sys.power:
			color = COLOR_ON
			if _pop.has(id) and b == sys.power - 1:
				color = Color.WHITE
		draw_rect(Rect2(Vector2(x + 4, HEIGHT - 17 - b * BAR_STEP), Vector2(12, BAR_H)), color)


func _draw_shield_pairs(sys: ShipSystem, x: float) -> void:
	for b in sys.capacity:
		var row := b / 2
		var side := b % 2
		var color := COLOR_OFF
		if b >= sys.usable():
			color = COLOR_BROKEN
		elif b < sys.power:
			color = COLOR_ON if sys.power >= (row + 1) * 2 else COLOR_HALF
			if _pop.has(sys.id) and b == sys.power - 1:
				color = Color.WHITE
		draw_rect(Rect2(Vector2(x + 4 + side * 7, HEIGHT - 17 - row * BAR_STEP), Vector2(5, BAR_H)), color)


func _gui_input(event: InputEvent) -> void:
	if not state or not (event is InputEventMouseButton):
		return
	var col := int((event.position.x - REACTOR_W - 4) / COL_W)
	if event.position.x < REACTOR_W + 4 or col < 0 or col >= _columns.size():
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_change(col, false)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_time = Time.get_ticks_msec()
			_press_col = col
		elif col == _press_col:
			_change(col, Time.get_ticks_msec() - _press_time < LONG_PRESS_MS)
	accept_event()


func _change(col: int, add: bool) -> void:
	var id := _columns[col]
	var ok := state.add_power(id) if add else state.remove_power(id)
	system_tapped.emit(id, ok)
	Sfx.play(("power_up" if add else "power_down") if ok else "ui_deny")
	if ok:
		if add:
			_pop[id] = 0.2
	else:
		_deny[id] = 0.25
