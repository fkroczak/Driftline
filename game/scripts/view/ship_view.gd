class_name ShipView
extends Node2D
## Zeichnet ein ShipState und übersetzt Antippen in Befehle.
## Die Spiellogik liegt in ShipState; hier passiert nur Darstellung und Eingabe.
##
## Bedienung:
## - Figur antippen wählt sie aus (Trefferbereich etwas größer als die Figur).
## - Danach eine freie Kachel antippen: Die Figur läuft genau dorthin, die Auswahl endet.
## - Auf einer besetzten Kachel gedrückt halten: Die Figur geht dorthin, wer dort steht, weicht aus.
## - Die ausgewählte Figur erneut antippen oder neben das Schiff tippen hebt die Auswahl auf.

signal selection_changed(member: CrewMember, room_idx: int)

const CREW_SHEETS := {
	"mensch": preload("res://assets/crew/mensch_klein_sheet.png"),
}
## Reihenfolge im Sprite-Sheet: unten, oben, links, rechts.
const FRAME_BY_FACING := {
	Vector2i.DOWN: 0,
	Vector2i.UP: 1,
	Vector2i.LEFT: 2,
	Vector2i.RIGHT: 3,
}
const COLOR_SELECTED := Color("#5DCAA5")
const COLOR_TARGET := Color("#9FE1CB")
const COLOR_ROOM := Color(1, 1, 1, 0.10)
const COLOR_ROOM_EDGE := Color(1, 1, 1, 0.45)
const COLOR_CONSOLE_FREE := Color("#5A6370")
const COLOR_CONSOLE_MANNED := Color("#5DCAA5")
## Trefferradius für Figuren in Kacheln (0,5 wäre genau die Kachel).
const HIT_RADIUS := 0.75
## Ab dieser Dauer zählt ein Antippen als Gedrückthalten.
const LONG_PRESS_MS := 400

var state: ShipState
var selected: CrewMember
var focused_room := -1
## Zuletzt losgeschickte Figur, für die Statuszeile.
var last_order: CrewMember

var _press_pos := Vector2.ZERO
var _press_time := 0

var _ship_texture: Texture2D
var _crew_sprites := {}  # CrewMember -> Sprite2D


func setup(p_state: ShipState) -> void:
	state = p_state
	_ship_texture = load(state.layout.sprite_path)
	for member in state.crew:
		var sprite := Sprite2D.new()
		sprite.texture = CREW_SHEETS.get(member.species, CREW_SHEETS["mensch"])
		sprite.hframes = 4
		add_child(sprite)
		_crew_sprites[member] = sprite
	_sync_crew()


func get_size() -> Vector2:
	return _ship_texture.get_size() if _ship_texture else Vector2.ZERO


func select(member: CrewMember) -> void:
	_set_selection(member, -1)


func _process(_delta: float) -> void:
	if state:
		_sync_crew()
		queue_redraw()


func _sync_crew() -> void:
	for member: CrewMember in _crew_sprites:
		var sprite: Sprite2D = _crew_sprites[member]
		sprite.position = state.layout.tile_center(member.tile_position()).round()
		sprite.frame = FRAME_BY_FACING.get(member.facing, 0)


func _draw() -> void:
	if not state:
		return
	var layout := state.layout
	draw_texture(_ship_texture, Vector2.ZERO)
	if focused_room >= 0:
		var rect := layout.room_rect(focused_room).grow(-1)
		draw_rect(rect, COLOR_ROOM, true)
		draw_rect(rect, COLOR_ROOM_EDGE, false, 1.0)
	# Konsolen: kleine Leiste an der Kachel, grün wenn besetzt
	for room in layout.rooms.size():
		var console: Variant = layout.console_of(room)
		if console == null:
			continue
		var color := COLOR_CONSOLE_MANNED if state.operator_of(room) else COLOR_CONSOLE_FREE
		var top_left := layout.tile_center(Vector2(console)) - Vector2(7, 7)
		draw_rect(Rect2(top_left + Vector2(4, 1), Vector2(6, 2)), color)
	# Ziele aller laufenden Figuren
	for member in state.crew:
		if member.is_moving():
			var color := COLOR_TARGET if member == selected else Color(COLOR_TARGET, 0.45)
			_draw_tile_frame(layout.tile_center(Vector2(member.destination())), color, true)
	if selected:
		_draw_tile_frame(layout.tile_center(selected.tile_position()).round(), COLOR_SELECTED, false)


## Rahmen um eine Kachel; `corners_only` zeichnet nur die Ecken (Ziel-Markierung).
func _draw_tile_frame(center: Vector2, color: Color, corners_only: bool) -> void:
	var half := state.layout.tile_size / 2.0
	var rect := Rect2(center - Vector2(half, half), Vector2(half, half) * 2)
	if not corners_only:
		draw_rect(rect, color, false, 1.0)
		return
	var p := rect.position
	var s := rect.size
	for corner in [p, p + Vector2(s.x - 3, 0), p + Vector2(0, s.y - 1), p + Vector2(s.x - 3, s.y - 1)]:
		draw_rect(Rect2(corner, Vector2(3, 1)), color)
	for corner in [p, p + Vector2(0, s.y - 3), p + Vector2(s.x - 1, 0), p + Vector2(s.x - 1, s.y - 3)]:
		draw_rect(Rect2(corner, Vector2(1, 3)), color)


func _unhandled_input(event: InputEvent) -> void:
	if not state or not (event is InputEventMouseButton):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_set_selection(null, -1)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_pos = make_input_local(event).position
		_press_time = Time.get_ticks_msec()
	else:
		tap(_press_pos, Time.get_ticks_msec() - _press_time >= LONG_PRESS_MS)
	get_viewport().set_input_as_handled()


## Antippen an einer Position relativ zum Schiff. Andere Eingabearten
## (Controller, Tastatur) können später ebenfalls hierüber gehen.
func tap(local_pos: Vector2, long_press := false) -> void:
	var layout := state.layout
	var tile := layout.local_to_tile(local_pos)
	var room := layout.room_index_at(tile)
	var in_tiles := (local_pos - Vector2(layout.grid_origin)) / layout.tile_size - Vector2(0.5, 0.5)
	var near := state.crew_near(in_tiles, HIT_RADIUS)

	if selected and long_press and room >= 0 and near != selected:
		if state.order_move_to_tile(selected, tile, true):
			_finish_order(room)
			return
	if near:
		_set_selection(null if near == selected else near, -1)
		return
	if selected and room >= 0:
		# Kachel nur reserviert (jemand ist unterwegs dorthin): freie Kachel im Raum nehmen
		if state.order_move_to_tile(selected, tile, false) or state.order_move(selected, room):
			_finish_order(room)
		return
	_set_selection(null, room)


func _finish_order(room: int) -> void:
	last_order = selected
	_set_selection(null, room)


func _set_selection(member: CrewMember, room_idx: int) -> void:
	selected = member
	focused_room = room_idx
	queue_redraw()
	selection_changed.emit(member, room_idx)
