class_name ShipLayout
extends RefCounted
## Raumraster eines Schiffs: Räume, Türen, Wegfindung.
## Reine Logik ohne Nodes; die Daten kommen aus data/ships/*.json.

const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var id: String = ""
var display_name: String = ""
var sprite_path: String = ""
var tile_size: int = 14
## Pixelposition der oberen linken Rasterecke im Schiffs-Sprite.
var grid_origin: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ZERO
## Jeder Raum: {id, name, system, pos: Vector2i, size: Vector2i, console: Vector2i oder null}
var rooms: Array[Dictionary] = []
## Übrige Schiffswerte aus der JSON-Datei (Hülle, Reaktor, Systeme, Waffen, Grafikpunkte).
var stats: Dictionary = {}
## Luftschleusen nach draußen: {tile: Vector2i, dir: Vector2i}. `dir` zeigt aus dem Schiff.
## Später: Schleuse öffnen lässt den Sauerstoff des Raums ins All entweichen (Feuer und
## Enterkommandos ersticken), über offene Türen auch den der Nachbarräume.
var airlocks: Array[Dictionary] = []

var _room_at: Dictionary = {}  # Vector2i -> Raumindex
var _doors: Dictionary = {}  # Türschlüssel -> [Vector2i, Vector2i]
var _overlaps: Array[Vector2i] = []


static func load_json(path: String) -> ShipLayout:
	if not FileAccess.file_exists(path):
		push_error("Schiffslayout nicht gefunden: %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Schiffslayout ist kein gültiges JSON-Objekt: %s" % path)
		return null
	return from_dict(data)


static func from_dict(d: Dictionary) -> ShipLayout:
	var layout := ShipLayout.new()
	layout.id = d.get("id", "")
	layout.display_name = d.get("name", layout.id)
	layout.sprite_path = d.get("sprite", "")
	layout.tile_size = int(d.get("tile_size", 14))
	layout.grid_origin = _vec(d.get("grid_origin", [0, 0]))
	layout.grid_size = _vec(d.get("grid_size", [0, 0]))
	layout.stats = d
	for r: Dictionary in d.get("rooms", []):
		var idx := layout.rooms.size()
		layout.rooms.append({
			"id": r["id"],
			"name": r.get("name", r["id"]),
			"system": r.get("system", ""),
			"pos": _vec(r["pos"]),
			"size": _vec(r.get("size", [2, 2])),
			"console": _vec(r["console"]) if r.has("console") else null,
		})
		for t in layout.room_tiles(idx):
			if layout._room_at.has(t):
				layout._overlaps.append(t)
			layout._room_at[t] = idx
	for lock: Array in d.get("airlocks", []):
		layout.airlocks.append({"tile": _vec(lock[0]), "dir": _vec(lock[1])})
	for door: Array in d.get("doors", []):
		var a := _vec(door[0])
		var b := _vec(door[1])
		layout._doors[_door_key(a, b)] = [a, b]
	return layout


## Liefert eine Liste von Fehlern; leer bedeutet: Layout ist in Ordnung.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if grid_size.x <= 0 or grid_size.y <= 0:
		errors.append("Rastergröße fehlt")
	if rooms.is_empty():
		errors.append("Keine Räume")
		return errors
	var bounds := Rect2i(Vector2i.ZERO, grid_size)
	for i in rooms.size():
		var room := rooms[i]
		if not bounds.encloses(Rect2i(room.pos, room.size)):
			errors.append("Raum %s liegt außerhalb des Rasters" % room.id)
		if room.console != null and room_index_at(room.console) != i:
			errors.append("Konsole von %s liegt nicht im Raum" % room.id)
	for t in _overlaps:
		errors.append("Räume überlappen bei %s" % t)
	for pair: Array in _doors.values():
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		if absi(a.x - b.x) + absi(a.y - b.y) != 1:
			errors.append("Tür %s–%s verbindet keine Nachbarkacheln" % [a, b])
		elif room_index_at(a) < 0 or room_index_at(b) < 0:
			errors.append("Tür %s–%s führt ins Leere" % [a, b])
		elif room_index_at(a) == room_index_at(b):
			errors.append("Tür %s–%s liegt innerhalb eines Raums" % [a, b])
	for lock in airlocks:
		var t: Vector2i = lock.tile
		var dir: Vector2i = lock.dir
		if room_index_at(t) < 0:
			errors.append("Luftschleuse %s liegt in keinem Raum" % t)
		elif absi(dir.x) + absi(dir.y) != 1:
			errors.append("Luftschleuse %s braucht eine Richtung nach oben, unten, links oder rechts" % t)
		elif room_index_at(t + dir) >= 0:
			errors.append("Luftschleuse %s führt in einen Raum statt nach draußen" % t)
	var start: Vector2i = rooms[0].pos
	for i in rooms.size():
		var target: Vector2i = rooms[i].pos
		if target != start and find_path(start, target).is_empty():
			errors.append("Raum %s ist nicht erreichbar" % rooms[i].id)
	return errors


func room_index_at(tile: Vector2i) -> int:
	return _room_at.get(tile, -1)


## Raum, in dem ein System sitzt, oder -1.
func room_of_system(system: String) -> int:
	for i in rooms.size():
		if rooms[i].system == system:
			return i
	return -1


## Räume mit eigener Luftschleuse.
func rooms_with_airlock() -> Array[int]:
	var result: Array[int] = []
	for lock in airlocks:
		var room := room_index_at(lock.tile)
		if room >= 0 and not result.has(room):
			result.append(room)
	return result


func room_index_by_id(room_id: String) -> int:
	for i in rooms.size():
		if rooms[i].id == room_id:
			return i
	return -1


func room_tiles(idx: int) -> Array[Vector2i]:
	var room := rooms[idx]
	var tiles: Array[Vector2i] = []
	for y in room.size.y:
		for x in room.size.x:
			tiles.append(room.pos + Vector2i(x, y))
	return tiles


## Konsolenkachel des Raums oder null, wenn der Raum keine Konsole hat.
func console_of(room_idx: int) -> Variant:
	return rooms[room_idx].console


func is_console(tile: Vector2i) -> bool:
	var idx := room_index_at(tile)
	return idx >= 0 and rooms[idx].console == tile


func is_walkable(tile: Vector2i) -> bool:
	return _room_at.has(tile)


func has_door(a: Vector2i, b: Vector2i) -> bool:
	return _doors.has(_door_key(a, b))


## Begehbare Nachbarkacheln: im selben Raum oder durch eine Tür.
func neighbors(tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var room := room_index_at(tile)
	if room < 0:
		return result
	for dir in DIRECTIONS:
		var n := tile + dir
		var n_room := room_index_at(n)
		if n_room < 0:
			continue
		if n_room == room or has_door(tile, n):
			result.append(n)
	return result


## Kürzester Weg (Breitensuche). Enthält das Ziel, nicht den Start.
## Leer, wenn Start == Ziel oder kein Weg existiert.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if from == to or not is_walkable(from) or not is_walkable(to):
		return path
	var came_from := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			break
		for n in neighbors(current):
			if not came_from.has(n):
				came_from[n] = current
				queue.append(n)
	if not came_from.has(to):
		return path
	var step := to
	while step != from:
		path.push_front(step)
		step = came_from[step]
	return path


## Mittelpunkt einer Kachel in Pixeln, relativ zum Schiffs-Sprite.
func tile_center(tile: Vector2) -> Vector2:
	return Vector2(grid_origin) + (tile + Vector2(0.5, 0.5)) * tile_size


func local_to_tile(local_pos: Vector2) -> Vector2i:
	return Vector2i(((local_pos - Vector2(grid_origin)) / tile_size).floor())


func room_rect(idx: int) -> Rect2:
	var room := rooms[idx]
	return Rect2(Vector2(grid_origin + room.pos * tile_size), Vector2(room.size * tile_size))


static func _vec(a: Variant) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _door_key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var tmp := a
		a = b
		b = tmp
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
