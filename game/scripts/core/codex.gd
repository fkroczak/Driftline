class_name Codex
extends RefCounted
## Lexikon: welche Schiffe und Spezies der Spieler schon gesehen hat (user://codex.json, über alle
## Runs hinweg). Schiffe gelten als entdeckt, sobald man gegen sie kämpft, Spezies, sobald jemand
## dieser Spezies in der eigenen Crew ist. Das eigene Schiff und die Menschen kennt man von Anfang an.

const PATH := "user://codex.json"
const SHIPS_DIR := "res://data/ships"
const KIND_SHIP := "ships"
const KIND_SPECIES := "species"
const STARTERS := {KIND_SHIP: ["mensch_frachter"], KIND_SPECIES: ["mensch"]}

static var _known: Dictionary = {}
static var _ships: Dictionary = {}  # id -> JSON-Daten


static func _load() -> void:
	if not _known.is_empty():
		return
	_known = {KIND_SHIP: {}, KIND_SPECIES: {}}
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for kind: String in _known:
				if parsed.get(kind) is Dictionary:
					_known[kind] = parsed[kind]
	for kind: String in STARTERS:
		for id: String in STARTERS[kind]:
			_known[kind][id] = true


static func is_known(kind: String, id: String) -> bool:
	_load()
	return _known.get(kind, {}).has(id)


## Vermerkt einen Eintrag. Liefert true, wenn er neu ist.
static func discover(kind: String, id: String) -> bool:
	_load()
	if id == "" or is_known(kind, id):
		return false
	_known[kind][id] = true
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_known))
	return true


## Alle Schiffe aus data/ships, das eigene zuerst, dann nach Hülle.
static func ship_ids() -> Array[String]:
	if _ships.is_empty():
		for file in DirAccess.get_files_at(SHIPS_DIR):
			if file.ends_with(".json"):
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHIPS_DIR.path_join(file)))
				if data is Dictionary:
					_ships[file.get_basename()] = data
	var ids: Array[String] = []
	ids.assign(_ships.keys())
	ids.sort_custom(func(a: String, b: String) -> bool:
		var sa: bool = a in STARTERS[KIND_SHIP]
		var sb: bool = b in STARTERS[KIND_SHIP]
		if sa != sb:
			return sa
		return int(_ships[a].get("hull", 0)) < int(_ships[b].get("hull", 0)) or (int(_ships[a].get("hull", 0)) == int(_ships[b].get("hull", 0)) and a < b))
	return ids


static func ship(id: String) -> Dictionary:
	if _ships.is_empty():
		ship_ids()
	return _ships.get(id, {})


static func species_ids() -> Array[String]:
	var ids := Species.ids()
	ids.erase(Species.DEFAULT)
	ids.push_front(Species.DEFAULT)
	return ids


static func count_known() -> Vector2i:
	var known := 0
	var total := 0
	for id in ship_ids():
		total += 1
		known += 1 if is_known(KIND_SHIP, id) else 0
	for id in species_ids():
		total += 1
		known += 1 if is_known(KIND_SPECIES, id) else 0
	return Vector2i(known, total)
