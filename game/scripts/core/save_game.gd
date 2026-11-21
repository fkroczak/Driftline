class_name SaveGame
extends RefCounted
## Spielstand des laufenden Runs, gespeichert in user://savegame.json.
##
## Gespeichert wird auf der Sternenkarte (nach jedem Sprung, jeder Entscheidung, beim Verlassen
## der App). Ein Kampf wird nicht mitten drin gespeichert: Wird die App im Kampf beendet, beginnt
## der Kampf beim nächsten Start neu, mit dem Schiff, wie es vor dem Kampf war.
##
## Updates: Android behält user:// bei einem Update (gleiche Paket-ID, gleicher Schlüssel).
## Damit ein neuer Build einen alten Spielstand nicht zerstört:
## - Die Datei hat eine Formatversion (VERSION). Ältere Formate werden in `_migrate` angehoben,
##   fehlende Felder bekommen Standardwerte, unbekannte Felder werden ignoriert.
## - Die Sternenkarte wird mitgespeichert, nicht aus dem Seed neu erzeugt: Ändert ein Update den
##   Kartengenerator, bleibt die Karte des laufenden Runs trotzdem gleich.
## - Was es im neuen Build nicht mehr gibt (System, Waffe, Ereignis), wird übersprungen.
## - Lässt sich eine Datei nicht lesen oder stammt sie aus einem neueren Build, wird sie nie
##   überschrieben, sondern als savegame-<Zeit>.json beiseitegelegt.
## - Geschrieben wird erst in eine Zwischendatei, dann umbenannt; die vorige Fassung bleibt als
##   savegame.bak.json (Rückfall, falls die Hauptdatei kaputt ist).
##
## Bei Formatänderungen: VERSION erhöhen und in `_migrate` einen Schritt ergänzen.

const VERSION := 1
const PATH := "user://savegame.json"
const BACKUP := "user://savegame.bak.json"
const TEMP := "user://savegame.tmp"

## Für Tests umlenkbar.
static var path := PATH
static var backup := BACKUP


static func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(backup)


## Speichert den Run. Falsch, wenn das Schreiben scheitert (der alte Stand bleibt dann erhalten).
static func save(run: RunState) -> bool:
	var text := JSON.stringify(JSON.from_native(to_dict(run)))
	var temp := path.get_base_dir().path_join(TEMP.get_file())
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_warning("Spielstand nicht speicherbar: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(path, backup)
	return DirAccess.rename_absolute(temp, path) == OK


## Lädt den gespeicherten Run oder null. Erst die Hauptdatei, dann die Sicherung.
static func load_run() -> RunState:
	for file in [path, backup]:
		if not FileAccess.file_exists(file):
			continue
		var data: Variant = _read(file)
		if data is Dictionary and int(data.get("version", 0)) <= VERSION:
			var run := from_dict(_migrate(data))
			if run:
				return run
		_set_aside(file)
	return null


## Run vorbei: Stand löschen, damit der nächste Start einen neuen Run beginnt.
static func clear() -> void:
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(backup)


static func _read(file: String) -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file)) != OK:
		return null
	return JSON.to_native(json.data)


## Unlesbare oder zu neue Datei umbenennen statt überschreiben.
static func _set_aside(file: String) -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var target := file.get_base_dir().path_join("savegame-%s.json" % stamp)
	var n := 2
	while FileAccess.file_exists(target):
		target = file.get_base_dir().path_join("savegame-%s-%d.json" % [stamp, n])
		n += 1
	DirAccess.rename_absolute(file, target)
	push_warning("Spielstand %s nicht lesbar, beiseitegelegt als %s" % [file, target])


## Hebt ältere Formate auf VERSION an. Beispiel für später:
##   if v < 2: data.run["neues_feld"] = 0
static func _migrate(data: Dictionary) -> Dictionary:
	var _v := int(data.get("version", 1))
	data.version = VERSION
	return data


# --- Run ---


static func to_dict(run: RunState) -> Dictionary:
	return {
		"version": VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": Time.get_datetime_string_from_system(),
		"run": {
			"seed": run.seed_value,
			"map": {"nodes": run.map.nodes, "columns": run.map.columns},
			"current": run.current,
			"visited": run.visited,
			"cleared": run.cleared,
			"pending_battle": run.pending_battle,
			"node_events": run.node_events,
			"fuel": run.fuel,
			"scrap": run.scrap,
			"flags": run.flags,
			"result": run.result,
			"dialog": run.dialog,
			"ctx": run._ctx,
			"shop_note": run._shop_note,
			"last_reward": run.last_reward,
			"rng": run._rng.state,
		},
		"ship": _ship_to_dict(run.ship),
	}


static func from_dict(data: Dictionary) -> RunState:
	var r: Dictionary = data.get("run", {})
	var m: Dictionary = r.get("map", {})
	if m.get("nodes", []).is_empty() or not data.has("ship"):
		return null
	var run := RunState.new(int(r.get("seed", 1)))
	run.map.nodes.assign(m.nodes)
	run.map.columns.assign(m.get("columns", []))
	run.current = clampi(int(r.get("current", 0)), 0, run.map.nodes.size() - 1)
	run.visited = r.get("visited", {run.current: true})
	run.cleared = r.get("cleared", {})
	run.pending_battle = r.get("pending_battle", {})
	run.node_events = r.get("node_events", {})
	run.fuel = int(r.get("fuel", run.fuel))
	run.scrap = int(r.get("scrap", run.scrap))
	run.flags = r.get("flags", {})
	run.result = r.get("result", "")
	run.dialog = r.get("dialog", {})
	run._ctx = r.get("ctx", {})
	run._shop_note = r.get("shop_note", "")
	run.last_reward = r.get("last_reward", "")
	if r.has("rng"):
		run._rng.state = int(r.rng)
	if run.dialog.is_empty() != run._ctx.is_empty():
		run.dialog = {}
		run._ctx = {}
	_ship_from_dict(run.ship, data.ship)
	return run


# --- Schiff ---


static func _ship_to_dict(ship: ShipState) -> Dictionary:
	var systems := {}
	for id: String in ship.systems:
		var sys: ShipSystem = ship.systems[id]
		systems[id] = {"capacity": sys.capacity, "damage": sys.damage, "wanted": sys.wanted, "repair": sys.repair_progress}
	var weapons: Array = []
	for w in ship.weapons:
		weapons.append({"id": w.id, "wanted": w.wanted})
	var crew: Array = []
	for c in ship.crew:
		crew.append({"name": c.display_name, "species": c.species, "tile": c.tile, "home": c.home_tile,
			"experience": c.experience, "hp": c.hp, "pinned": c.pinned})
	return {
		"hull": ship.hull,
		"max_hull": ship.max_hull,
		"systems": systems,
		"weapons": weapons,
		"crew": crew,
		"shield_layers": ship.shield_layers,
		"shield_progress": ship.shield_progress,
		"oxygen": ship.oxygen,
		"fires": ship.fires,
		"breaches": ship.breaches,
		"doors": ship.door_open,
		"airlocks": ship.airlock_open,
		"fire_damage": ship._fire_damage,
		"rng": ship.rng.state,
	}


## Überträgt den gespeicherten Zustand auf ein frisch gebautes Schiff. Alles wird gegen das
## aktuelle Layout geprüft, damit ein geändertes Schiff in einem Update nicht zum Absturz führt.
static func _ship_from_dict(ship: ShipState, s: Dictionary) -> void:
	var layout := ship.layout
	ship.max_hull = int(s.get("max_hull", ship.max_hull))
	ship.hull = clampi(int(s.get("hull", ship.hull)), 0, ship.max_hull)
	var systems: Dictionary = s.get("systems", {})
	for id: String in systems:
		if not ship.systems.has(id):
			continue
		var sys: ShipSystem = ship.systems[id]
		var d: Dictionary = systems[id]
		sys.capacity = maxi(sys.capacity, int(d.get("capacity", sys.capacity)))
		sys.damage = clampi(int(d.get("damage", 0)), 0, sys.capacity)
		sys.wanted = clampi(int(d.get("wanted", sys.wanted)), 0, sys.capacity)
		sys.repair_progress = float(d.get("repair", 0.0))
	if s.has("weapons"):
		ship.weapons.clear()
		for d: Dictionary in s.weapons:
			if not Weapon.known(d.get("id", "")):
				continue
			var w := Weapon.create(d.id)
			w.wanted = bool(d.get("wanted", false))
			ship.weapons.append(w)
	if s.has("crew"):
		ship.crew.clear()
		for d: Dictionary in s.crew:
			var tile: Vector2i = d.get("tile", Vector2i(-1, -1))
			var member: CrewMember
			if layout.is_walkable(tile) and ship.crew_at_tile(tile) == null:
				member = ship.add_crew(d.get("name", "?"), d.get("species", "mensch"), tile, d.get("experience", {}))
			else:
				member = ship.add_crew_anywhere(d.get("name", "?"), d.get("species", "mensch"))
				if member:
					member.experience = d.get("experience", {}).duplicate()
			if member == null:
				continue
			var home: Vector2i = d.get("home", member.tile)
			member.home_tile = home if layout.is_walkable(home) else member.tile
			member.hp = clampf(float(d.get("hp", CrewMember.MAX_HP)), 1.0, CrewMember.MAX_HP)
			member.pinned = bool(d.get("pinned", false))
	var oxygen: Array = s.get("oxygen", [])
	for i in mini(oxygen.size(), ship.oxygen.size()):
		ship.oxygen[i] = clampf(float(oxygen[i]), 0.0, 1.0)
	ship.fires = _only_walkable(layout, s.get("fires", {}))
	ship.breaches = _only_walkable(layout, s.get("breaches", {}))
	ship._fire_damage = s.get("fire_damage", {})
	var doors: Dictionary = s.get("doors", {})
	for key: String in doors:
		ship.door_open[key] = doors[key]
	var airlocks: Array = s.get("airlocks", [])
	for i in mini(airlocks.size(), ship.airlock_open.size()):
		ship.airlock_open[i] = bool(airlocks[i])
	if s.has("rng"):
		ship.rng.state = int(s.rng)
	ship._rebalance()
	ship.shield_layers = clampi(int(s.get("shield_layers", ship.shield_layers)), 0, ship.max_shield_layers())
	ship.shield_progress = float(s.get("shield_progress", 0.0))


static func _only_walkable(layout: ShipLayout, tiles: Dictionary) -> Dictionary:
	var out := {}
	for t: Variant in tiles:
		if t is Vector2i and layout.is_walkable(t):
			out[t] = tiles[t]
	return out
