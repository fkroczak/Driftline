class_name SaveGame
extends RefCounted
## Spielstand des laufenden Runs: je Modus ein Slot, user://savegame.json (Jagd) und
## user://savegame_endlos.json (Endloses Universum).
##
## Gespeichert wird auf der Sternenkarte (nach jedem Sprung, jeder Entscheidung, beim Verlassen
## der App). Ein Kampf wird nicht mitten drin gespeichert: Wird die App im Kampf beendet, beginnt
## der Kampf beim nächsten Start neu, mit dem Schiff, wie es vor dem Kampf war.
##
## Updates: Android behält user:// bei einem Update (gleiche Paket-ID, gleicher Schlüssel), iOS bei gleicher Bundle-ID.
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
## Version 2: Modus, Sektor, Sprungzähler, Jägerfront, freie Karte mit Verbindungen in beide Richtungen.
## Version 3: Schiffsausbau (Perks, Waffenlager) und Händlerwaren; ältere Stände bekommen leere Listen.
## Version 4: Aufträge (`quests`, Ziel-Knoten -> Abschlussereignis); ältere Stände starten ohne Auftrag.
## Version 5: Batterie (`battery_room`) und Perks/Batterie im Händlerangebot; fehlt beides, wird es
## beim nächsten Besuch des Händlers nachgewürfelt.
## Version 6: Startausrüstung (`loadout`: Schiffsvariante, Schwierigkeit …); ältere Stände sind
## der Standardstart (Frachter, Normal).

const VERSION := 6
const PATH := "user://savegame.json"
const BACKUP := "user://savegame.bak.json"
const TEMP := "user://savegame.tmp"

## Für Tests umlenkbar.
static var path := PATH
static var backup := BACKUP


## Hauptdatei und Sicherung des Slots für einen Modus.
static func _files(mode: String) -> Array[String]:
	if mode == RunState.MODE_ENDLESS:
		return [path.get_basename() + "_" + mode + ".json", backup.replace(".bak.", "_%s.bak." % mode)]
	return [path, backup]


static func exists(mode := RunState.MODE_HUNT) -> bool:
	var files := _files(mode)
	return FileAccess.file_exists(files[0]) or FileAccess.file_exists(files[1])


## Speichert den Run. Falsch, wenn das Schreiben scheitert (der alte Stand bleibt dann erhalten).
static func save(run: RunState) -> bool:
	var files := _files(run.mode)
	var main := files[0]
	var bak := files[1]
	var text := JSON.stringify(JSON.from_native(to_dict(run)))
	var temp := main.get_base_dir().path_join(TEMP.get_file())
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_warning("Spielstand nicht speicherbar: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(main):
		DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(main, bak)
	return DirAccess.rename_absolute(temp, main) == OK


## Lädt den gespeicherten Run oder null. Erst die Hauptdatei, dann die Sicherung.
static func load_run(mode := RunState.MODE_HUNT) -> RunState:
	for file in _files(mode):
		if not FileAccess.file_exists(file):
			continue
		var data: Variant = _read(file)
		if data is Dictionary and int(data.get("version", 0)) <= VERSION:
			var run := from_dict(_migrate(data), mode)
			if run:
				return run
		_set_aside(file)
	return null


## Run vorbei: Stand löschen, damit der nächste Start einen neuen Run beginnt.
static func clear(mode := RunState.MODE_HUNT) -> void:
	for file in _files(mode):
		DirAccess.remove_absolute(file)


## Kurzbeschreibung eines gespeicherten Runs für das Hauptmenü ("" = keiner), ohne ihn zu laden.
static func summary(mode: String) -> Dictionary:
	for file in _files(mode):
		if not FileAccess.file_exists(file):
			continue
		var data: Variant = _read(file)
		if data is Dictionary and int(data.get("version", 0)) <= VERSION:
			var r: Dictionary = _migrate(data).get("run", {})
			return {"sector": int(r.get("sector", 1)), "jumps": int(r.get("jumps", 0)), "hull": int(data.get("ship", {}).get("hull", 0))}
	return {}


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


## Hebt ältere Formate auf VERSION an.
static func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	var r: Dictionary = data.get("run", {})
	if v < 2:
		# Version 1: nur Jagd, Karte in Spalten mit Verbindungen nach rechts, Sprung = Spalte.
		r["mode"] = RunState.MODE_HUNT
		r["sector"] = 1
		var nodes: Array = r.get("map", {}).get("nodes", [])
		var cur := int(r.get("current", 0))
		var jumps := int(nodes[cur].get("column", 0)) if cur >= 0 and cur < nodes.size() else 0
		r["jumps"] = jumps
		r["total_jumps"] = jumps
		r["front"] = RunState.FRONT_START + jumps * RunState.FRONT_STEP
		for c: Dictionary in data.get("ship", {}).get("crew", []):
			if c.get("name", "") == "Mara Voss":
				c["role"] = CrewMember.ROLE_CAPTAIN
	# v2 -> v3: nichts umzurechnen; perks, stored_weapons und shop_stock fehlen und starten leer.
	# v3 -> v4: nichts umzurechnen; quests fehlt und startet leer.
	# v4 -> v5: nichts umzurechnen; ohne battery_room keine Batterie, Händlerperks werden nachgetragen.
	# v5 -> v6: nichts umzurechnen; loadout fehlt und gilt als Standardstart.
	data.version = VERSION
	data["run"] = r
	return data


# --- Run ---


static func to_dict(run: RunState) -> Dictionary:
	return {
		"version": VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": Time.get_datetime_string_from_system(),
		"run": {
			"seed": run.seed_value,
			"mode": run.mode,
			"sector": run.sector,
			"jumps": run.jumps,
			"total_jumps": run.total_jumps,
			"front": run.front,
			"hunter_battle": run.hunter_battle,
			"sector_cleared": run.sector_cleared,
			"map": {"nodes": run.map.nodes, "exit_type": run.map.exit_type},
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
			"shop_stock": run.shop_stock,
			"quests": run.quests,
			"quest_note": run.quest_note,
			"loadout": run.loadout,
			"rng": run._rng.state,
		},
		"ship": _ship_to_dict(run.ship),
	}


static func from_dict(data: Dictionary, mode := RunState.MODE_HUNT) -> RunState:
	var r: Dictionary = data.get("run", {})
	var m: Dictionary = r.get("map", {})
	if m.get("nodes", []).is_empty() or not data.has("ship"):
		return null
	var cfg: Dictionary = r.get("loadout", {}) if r.get("loadout") is Dictionary else {}
	var run := RunState.new(int(r.get("seed", 1)), r.get("mode", mode), cfg)
	run.sector = maxi(int(r.get("sector", 1)), 1)
	run.jumps = int(r.get("jumps", 0))
	run.total_jumps = int(r.get("total_jumps", run.jumps))
	run.front = float(r.get("front", RunState.FRONT_START))
	run.hunter_battle = bool(r.get("hunter_battle", false))
	run.sector_cleared = bool(r.get("sector_cleared", false))
	run.map.nodes.assign(m.nodes)
	run.map.exit_type = m.get("exit_type", "boss" if run.mode == RunState.MODE_HUNT else "ausgang")
	for n: Dictionary in run.map.nodes:
		var links: Array[int] = []
		for to: Variant in n.get("links", []):
			links.append(int(to))
		n["links"] = links
	run.map.make_links_mutual()
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
	run.shop_stock = {}
	var stock: Dictionary = r.get("shop_stock", {})
	for key: Variant in stock:
		var entry: Dictionary = stock[key]
		var weapons: Array = (entry.get("weapons", []) as Array).filter(func(id: Variant) -> bool: return Weapon.known(str(id)))
		run.shop_stock[int(key)] = {"weapons": weapons, "crew": entry.get("crew", [])}
		if entry.has("perks"):
			run.shop_stock[int(key)]["perks"] = (entry.perks as Array).filter(func(id: Variant) -> bool: return not Upgrades.perk(str(id)).is_empty())
			run.shop_stock[int(key)]["battery"] = bool(entry.get("battery", false))
	run.quests = {}
	var quests: Dictionary = r.get("quests", {})
	for key: Variant in quests:
		var q: Dictionary = quests[key]
		if not run.events.get_event(str(q.get("event", ""))).is_empty():
			run.quests[int(key)] = {"event": str(q.event), "title": str(q.get("title", "")), "deadline": int(q.get("deadline", 0))}
	run.quest_note = r.get("quest_note", "")
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
		crew.append({"name": c.display_name, "species": c.species, "role": c.role, "tile": c.tile, "home": c.home_tile,
			"experience": c.experience, "hp": c.hp, "pinned": c.pinned})
	return {
		"hull": ship.hull,
		"max_hull": ship.max_hull,
		"systems": systems,
		"weapons": weapons,
		"stored_weapons": ship.stored_weapons,
		"perks": ship.perks,
		"battery_room": ship.battery_room_id(),
		"crew": crew,
		"shield_layers": ship.shield_layers,
		"shield_progress": ship.shield_progress,
		"oxygen": ship.oxygen,
		"fires": ship.fires,
		"breaches": ship.breaches,
		"doors": ship.door_open,
		"airlocks": ship.airlock_open,
		"fire_damage": ship._fire_damage,
		"jump_charge": ship.jump_charge,
		"rng": ship.rng.state,
	}


## Überträgt den gespeicherten Zustand auf ein frisch gebautes Schiff. Alles wird gegen das
## aktuelle Layout geprüft, damit ein geändertes Schiff in einem Update nicht zum Absturz führt.
static func _ship_from_dict(ship: ShipState, s: Dictionary) -> void:
	var layout := ship.layout
	ship.max_hull = int(s.get("max_hull", ship.max_hull))
	ship.hull = clampi(int(s.get("hull", ship.hull)), 0, ship.max_hull)
	var systems: Dictionary = s.get("systems", {})
	if systems.has("batterie"):
		ship.install_battery(int(systems.batterie.get("capacity", 2)), str(s.get("battery_room", "")))
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
	ship.stored_weapons.clear()
	for id: Variant in s.get("stored_weapons", []):
		if Weapon.known(str(id)) and ship.stored_weapons.size() < Upgrades.weapon_storage():
			ship.stored_weapons.append(str(id))
	ship.perks.clear()
	for id: Variant in s.get("perks", []):
		if not Upgrades.perk(str(id)).is_empty() and not ship.perks.has(str(id)):
			ship.perks.append(str(id))
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
			member.hp = clampf(float(d.get("hp", member.max_hp)), 1.0, member.max_hp)
			member.pinned = bool(d.get("pinned", false))
			member.role = d.get("role", "")
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
	ship.jump_charge = clampf(float(s.get("jump_charge", 0.0)), 0.0, 1.0)
	ship._rebalance()
	ship.shield_layers = clampi(int(s.get("shield_layers", ship.shield_layers)), 0, ship.max_shield_layers())
	ship.shield_progress = float(s.get("shield_progress", 0.0))


static func _only_walkable(layout: ShipLayout, tiles: Dictionary) -> Dictionary:
	var out := {}
	for t: Variant in tiles:
		if t is Vector2i and layout.is_walkable(t):
			out[t] = tiles[t]
	return out
