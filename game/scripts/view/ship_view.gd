class_name ShipView
extends Node2D
## Zeichnet ein ShipState und übersetzt Antippen in Befehle.
## Die Spiellogik liegt in ShipState; hier passiert nur Darstellung und Eingabe.
##
## Eigenes Schiff (hostile = false):
## - Figur antippen wählt sie aus (Trefferbereich etwas größer als die Figur).
## - Danach eine freie Kachel antippen: Die Figur läuft genau dorthin, die Auswahl endet.
## - Auf einer besetzten Kachel gedrückt halten: Die Figur geht dorthin, wer dort steht, weicht aus.
## - Die ausgewählte Figur erneut antippen oder neben das Schiff tippen hebt die Auswahl auf.
##
## Gegnerschiff (hostile = true): Einen Raum antippen meldet room_tapped (Ziel wählen).

signal selection_changed(member: CrewMember, room_idx: int)
signal room_tapped(room_idx: int)

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
const COLOR_DAMAGE := Color("#E24B4A")
const COLOR_REPAIR := Color("#FAC775")
const COLOR_AIM := Color("#E24B4A")
const COLOR_SHIELD := Color("#85B7EB")
const COLOR_SHIELD_CORE := Color("#D3E6F8")
const FLAME_PLAYER := [Color("#378ADD"), Color("#D3E6F8")]
const FLAME_ENEMY := [Color("#D85A30"), Color("#FDE6BF")]
const SHIELD_SEGMENTS := 56
## Trefferradius für Figuren in Kacheln (0,5 wäre genau die Kachel).
const HIT_RADIUS := 0.75
## Ab dieser Dauer zählt ein Antippen als Gedrückthalten.
const LONG_PRESS_MS := 400

@export var hostile := false

var state: ShipState
var selected: CrewMember
var focused_room := -1
## Zuletzt losgeschickte Figur, für die Statuszeile.
var last_order: CrewMember
## Gegnerschiff: angepeilter Raum.
var target_room := -1

var _press_pos := Vector2.ZERO
var _press_time := 0
var _ship_texture: Texture2D
var _crew_sprites := {}  # CrewMember -> Sprite2D
var _time := 0.0
var _target_anim := 0.0
var _room_flash := {}  # Raumindex -> verbleibende Sekunden
var _shield_flash := 0.0
var _ghost_hull := 0.0


func setup(p_state: ShipState) -> void:
	state = p_state
	_ship_texture = load(state.layout.sprite_path)
	_ghost_hull = state.hull
	for member in state.crew:
		var sprite := Sprite2D.new()
		sprite.texture = CREW_SHEETS.get(member.species, CREW_SHEETS["mensch"])
		sprite.hframes = 4
		if hostile:
			sprite.modulate = Color(1.0, 0.82, 0.78)
		add_child(sprite)
		_crew_sprites[member] = sprite
	_sync_crew()


func get_size() -> Vector2:
	return _ship_texture.get_size() if _ship_texture else Vector2.ZERO


func select(member: CrewMember) -> void:
	_set_selection(member, -1)


func set_target(room: int) -> void:
	target_room = room
	_target_anim = 1.0


func flash_room(room: int) -> void:
	_room_flash[room] = 0.35


func flash_shield() -> void:
	_shield_flash = 1.0


func room_center(room: int) -> Vector2:
	return state.layout.room_rect(room).get_center()


func mount_point() -> Vector2:
	var m: Array = state.layout.stats.get("weapon_mount", [0, 0])
	return Vector2(m[0], m[1])


## Schildblase als [Mittelpunkt, Radien] in lokalen Koordinaten.
func shield_ellipse() -> Array:
	var e: Array = state.layout.stats.get("shield_ellipse", [0, 0, 1, 1])
	return [Vector2(e[0], e[1]), Vector2(e[2], e[3])]


func _process(delta: float) -> void:
	if not state:
		return
	_time += delta
	_target_anim = maxf(_target_anim - delta * 4.0, 0.0)
	_shield_flash = maxf(_shield_flash - delta * 3.0, 0.0)
	_ghost_hull = move_toward(_ghost_hull, state.hull, delta * 4.0) if _ghost_hull > state.hull else float(state.hull)
	for room in _room_flash.keys():
		_room_flash[room] -= delta
		if _room_flash[room] <= 0.0:
			_room_flash.erase(room)
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
	_draw_engines()
	draw_texture(_ship_texture, Vector2.ZERO)
	_draw_airlocks()
	_draw_damage()
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
		if member.is_moving() and not hostile:
			var color := COLOR_TARGET if member == selected else Color(COLOR_TARGET, 0.45)
			_draw_tile_frame(layout.tile_center(Vector2(member.destination())), color, true)
	if selected:
		_draw_tile_frame(layout.tile_center(selected.tile_position()).round(), COLOR_SELECTED, false)
	if hostile and target_room >= 0:
		_draw_aim()
	_draw_shield()
	if hostile:
		_draw_hull_bar()


## Triebwerksflammen: Länge folgt der Antriebsenergie, flackern leicht.
func _draw_engines() -> void:
	var level := state.level("antrieb")
	if level <= 0 or state.is_destroyed():
		return
	var dir := float(state.layout.stats.get("engine_dir", -1))
	var colors: Array = FLAME_ENEMY if hostile else FLAME_PLAYER
	var tick := int(_time * 18.0)
	var i := 0
	for e: Array in state.layout.stats.get("engines", []):
		i += 1
		var flicker := float((tick * 7 + i * 13) % 5) * 0.5
		var length := roundf(3.0 + level * 3.0 + flicker)
		var p := Vector2(e[0], e[1])
		var outer := Rect2(p + Vector2(0 if dir > 0 else -length, -2), Vector2(length, 4))
		var core_len := roundf(length * 0.55)
		var core := Rect2(p + Vector2(0 if dir > 0 else -core_len, -1), Vector2(core_len, 2))
		draw_rect(outer, Color(colors[0], 0.75))
		draw_rect(core, colors[1])


## Luftschleusen: Luke mit gelbem Warnstreifen auf der Außenwand.
func _draw_airlocks() -> void:
	var layout := state.layout
	for lock in layout.airlocks:
		var dir: Vector2 = Vector2(lock.dir)
		var edge := layout.tile_center(Vector2(lock.tile)) + dir * (layout.tile_size / 2.0)
		var along := Vector2(absf(dir.y), absf(dir.x))  # entlang der Wand
		var size := along * 7.0 + Vector2(absf(dir.x), absf(dir.y)) * 3.0
		var rect := Rect2((edge - size / 2.0).round(), size)
		draw_rect(rect, Color("#2A2F3A"))
		draw_rect(rect, Color("#0A0B16"), false, 1.0)
		var stripe := along * 5.0 + Vector2(absf(dir.x), absf(dir.y))
		draw_rect(Rect2((edge - stripe / 2.0).round(), stripe), Color("#FAC775"))


## Beschädigte Systeme: rot pulsierender Raum, gelber Balken für den Reparaturfortschritt.
## Frisch getroffene Räume blitzen kurz auf.
func _draw_damage() -> void:
	var layout := state.layout
	for room in layout.rooms.size():
		var rect := layout.room_rect(room).grow(-1)
		var sys: ShipSystem = state.systems.get(layout.rooms[room].system)
		if sys and sys.damage > 0:
			var pulse := 0.16 + 0.10 * sin(_time * 6.0)
			if sys.usable() <= 0:
				pulse += 0.08
			draw_rect(rect, Color(COLOR_DAMAGE, pulse))
			draw_rect(rect, Color(COLOR_DAMAGE, 0.7), false, 1.0)
			if sys.repair_progress > 0.0:
				var bar := Rect2(rect.position + Vector2(3, rect.size.y - 4), Vector2(rect.size.x - 6, 2))
				draw_rect(bar, Color(0, 0, 0, 0.7))
				draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * sys.repair_progress), 2)), COLOR_REPAIR)
		if _room_flash.has(room):
			var t: float = _room_flash[room] / 0.35
			draw_rect(rect, Color(1, 1, 1, 0.55 * t) if t > 0.6 else Color(COLOR_DAMAGE, 0.5 * t))


## Fadenkreuz-Ecken um den Zielraum; beim Anvisieren ziehen sie sich zusammen.
func _draw_aim() -> void:
	var grow := 1.0 + roundf(_target_anim * 6.0)
	var rect := state.layout.room_rect(target_room).grow(grow)
	var color := Color(COLOR_AIM, 0.75 + 0.25 * sin(_time * 8.0))
	var p := rect.position
	var s := rect.size
	var l := 5.0
	for c: Vector2 in [p, p + Vector2(s.x, 0), p + Vector2(0, s.y), p + s]:
		var dx := 1.0 if c.x == p.x else -1.0
		var dy := 1.0 if c.y == p.y else -1.0
		draw_rect(Rect2(c.x if dx > 0 else c.x - l, c.y if dy > 0 else c.y - 1, l, 1), color)
		draw_rect(Rect2(c.x if dx > 0 else c.x - 1, c.y if dy > 0 else c.y - l, 1, l), color)


## Schildblase: schimmernde Ellipse je nach Schichtzahl, Aufladen als wachsender Bogen.
func _draw_shield() -> void:
	var e := shield_ellipse()
	var center: Vector2 = e[0]
	var radius: Vector2 = e[1]
	var layers := state.shield_layers
	var pts := PackedVector2Array()
	for i in SHIELD_SEGMENTS + 1:
		var a := TAU * i / SHIELD_SEGMENTS
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	if layers > 0 or _shield_flash > 0.0:
		var fill := Color(COLOR_SHIELD, 0.05 * layers + 0.18 * _shield_flash)
		draw_colored_polygon(pts.slice(0, SHIELD_SEGMENTS), fill)
		for i in SHIELD_SEGMENTS:
			var alpha := 0.25 + 0.2 * sin(i * 0.9 - _time * 3.0) + 0.12 * layers + 0.6 * _shield_flash
			var color := COLOR_SHIELD_CORE if _shield_flash > 0.5 else COLOR_SHIELD
			draw_line(pts[i], pts[i + 1], Color(color, clampf(alpha, 0.0, 1.0)), 1.0)
	if layers < state.max_shield_layers() and state.shield_progress > 0.0:
		var n := int(SHIELD_SEGMENTS * state.shield_progress)
		for i in n:
			draw_line(pts[i], pts[i + 1], Color(COLOR_SHIELD, 0.3), 1.0)


## Gegner: Hüllenbalken über dem Schiff; frisch verlorene Punkte leuchten kurz weiß nach.
func _draw_hull_bar() -> void:
	var origin := Vector2(4, -12)
	var ratio := float(state.hull) / maxf(state.max_hull, 1)
	var color := Color("#5DCAA5") if ratio > 0.5 else (Color("#FAC775") if ratio > 0.25 else COLOR_DAMAGE)
	for i in state.max_hull:
		var rect := Rect2(origin + Vector2(i * 3, 0), Vector2(2, 4))
		if i < state.hull:
			draw_rect(rect, color)
		elif i < ceili(_ghost_hull):
			draw_rect(rect, Color(1, 1, 1, 0.9))
		else:
			draw_rect(rect, Color("#2A2F3A"))
	for i in state.max_shield_layers():
		var p := origin + Vector2(state.max_hull * 3 + 3 + i * 5, 0)
		draw_rect(Rect2(p, Vector2(4, 4)), COLOR_SHIELD if i < state.shield_layers else Color("#2A2F3A"))


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
	if hostile:
		_hostile_input(event)
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


## Gegnerschiff: nur Antippen innerhalb des Sprites gehört hierher.
func _hostile_input(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local: Vector2 = (make_input_local(event) as InputEventMouseButton).position
	if not Rect2(Vector2.ZERO, get_size()).has_point(local):
		return
	get_viewport().set_input_as_handled()
	if event.pressed:
		return
	var room := state.layout.room_index_at(state.layout.local_to_tile(local))
	if room < 0:
		# Knapp daneben: nächsten Raum nehmen, damit der Daumen nicht genau treffen muss
		var best := INF
		for i in state.layout.rooms.size():
			var d := room_center(i).distance_to(local)
			if d < best and d < 24.0:
				best = d
				room = i
	if room >= 0:
		room_tapped.emit(room)


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
