class_name Loadout
extends RefCounted
## Startausrüstung eines neuen Runs (data/loadout.json): Schiff, Schwierigkeitsgrad, Crew, Waffen
## und Perks. Alles kostet Startpunkte, das Budget hängt am Schwierigkeitsgrad. Wer ein starkes
## Schiff oder teure Waffen nimmt, hat weniger Punkte für Crew und Perks; übrige Punkte werden zu
## Rohstoffen. Reine Daten und Regeln, keine Nodes.
##
## Eine Auswahl ist ein Dictionary:
##   {ship: "frachter", difficulty: "normal", crew: ["mensch", ...], weapons: [IDs], perks: [IDs]}
## `crew` sind die Spezies der Crew ohne Captain (Mara Voss ist immer an Bord und kostet nichts).

const PATH := "res://data/loadout.json"
const SHIPS_DIR := "res://data/ships/%s.json"
const HIGHSCORE_PATH := "user://highscore.json"
const DEFAULT_SHIP := "frachter"
const DEFAULT_DIFFICULTY := "normal"
## Standard-Crew ohne Captain (wie vor der Startauswahl).
const DEFAULT_CREW := ["mensch", "mensch"]

static var _defs: Dictionary = {}


static func defs() -> Dictionary:
	if _defs.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_defs = data if typeof(data) == TYPE_DICTIONARY else {}
	return _defs


static func _keys(section: String) -> Array[String]:
	var out: Array[String] = []
	out.assign((defs().get(section, {}) as Dictionary).keys())
	return out


static func ship_ids() -> Array[String]:
	return _keys("ships")


static func ship(id: String) -> Dictionary:
	return (defs().get("ships", {}) as Dictionary).get(id, {})


static func difficulty_ids() -> Array[String]:
	return _keys("difficulties")


static func difficulty(id: String) -> Dictionary:
	var all: Dictionary = defs().get("difficulties", {})
	return all.get(id, all.get(DEFAULT_DIFFICULTY, {}))


static func weapon_ids() -> Array[String]:
	return _keys("weapons").filter(func(id: String) -> bool: return Weapon.known(id))


static func perk_ids() -> Array[String]:
	return _keys("perks").filter(func(id: String) -> bool: return not Upgrades.perk(id).is_empty())


static func weapon_cost(id: String) -> int:
	return int((defs().get("weapons", {}) as Dictionary).get(id, 3))


static func crew_cost(species: String) -> int:
	return int((defs().get("crew", {}) as Dictionary).get(species, 2))


static func perk_cost(id: String) -> int:
	return int((defs().get("perks", {}) as Dictionary).get(id, 3))


static func ship_cost(id: String) -> int:
	return int(ship(id).get("cost", 0))


static func crew_max() -> int:
	return int(defs().get("crew_max", 4))


static func perks_max() -> int:
	return int(defs().get("perks_max", 2))


## Aufschlag für die n-te Person (0 = erste nach dem Captain): ab der dritten kostet jede mehr.
static func crew_surcharge(index: int) -> int:
	return int(defs().get("crew_extra", 1)) if index >= 2 else 0


# --- Freischalten ---


## Bester erreichter Sektor über alle Modi (Bestwerte in user://highscore.json).
static func best_sector() -> int:
	if not FileAccess.file_exists(HIGHSCORE_PATH):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(HIGHSCORE_PATH))
	var best := 0
	if data is Dictionary:
		for v: Variant in (data as Dictionary).values():
			best = maxi(best, int(v))
	return best


static func known_species() -> Array[String]:
	return Codex.species_ids().filter(func(id: String) -> bool: return Codex.is_known(Codex.KIND_SPECIES, id))


static func is_unlocked(id: String) -> bool:
	var d := ship(id)
	if d.is_empty():
		return false
	var unlock: Dictionary = d.get("unlock", {})
	if unlock.has("sector") and best_sector() < int(unlock.sector):
		return false
	if unlock.has("species") and known_species().size() < int(unlock.species):
		return false
	return true


## Hinweis, wie man ein gesperrtes Schiff freispielt.
static func unlock_text(id: String) -> String:
	var unlock: Dictionary = ship(id).get("unlock", {})
	if unlock.has("sector"):
		return Loc.t("Erreiche in einem Run Sektor %d") % int(unlock.sector)
	if unlock.has("species"):
		return Loc.t("Habe %d Spezies in deiner Crew gehabt") % int(unlock.species)
	return ""


# --- Auswahl ---


## Vorauswahl für ein Schiff: seine Startwaffen, zwei Menschen, keine Perks.
static func default_config(ship_id := DEFAULT_SHIP, difficulty_id := DEFAULT_DIFFICULTY) -> Dictionary:
	if ship(ship_id).is_empty():
		ship_id = DEFAULT_SHIP
	var weapons: Array = (ship(ship_id).get("weapons", []) as Array).duplicate()
	return {"ship": ship_id, "difficulty": difficulty_id if not difficulty(difficulty_id).is_empty() else DEFAULT_DIFFICULTY,
		"crew": DEFAULT_CREW.duplicate(), "weapons": weapons, "perks": []}


## Vervollständigt eine Auswahl (fehlende Felder = Standard). Eine leere Auswahl ergibt den
## Standardstart, wie er vor der Startauswahl war.
static func normalized(cfg: Dictionary) -> Dictionary:
	var ship_id := str(cfg.get("ship", DEFAULT_SHIP))
	var out := default_config(ship_id, str(cfg.get("difficulty", DEFAULT_DIFFICULTY)))
	for key: String in ["crew", "weapons", "perks"]:
		if cfg.get(key) is Array:
			var list: Array = []
			for v: Variant in cfg[key]:
				list.append(str(v))
			out[key] = list
	return out


## Schiffswerte: Basisdatei aus data/ships plus die Abweichungen der Variante.
static func ship_stats(id: String) -> Dictionary:
	var d := ship(id)
	if d.is_empty():
		d = ship(DEFAULT_SHIP)
	var path := SHIPS_DIR % str(d.get("base", "mensch_frachter"))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var stats: Dictionary = (data as Dictionary).duplicate(true) if data is Dictionary else {}
	var over: Dictionary = d.get("stats", {})
	for key: String in over:
		if over[key] is Dictionary and stats.get(key) is Dictionary:
			(stats[key] as Dictionary).merge(over[key], true)
		else:
			stats[key] = over[key]
	if d.has("tint"):
		stats["tint"] = d.tint
	stats["weapons"] = (d.get("weapons", stats.get("weapons", [])) as Array).duplicate()
	return stats


static func budget(cfg: Dictionary) -> int:
	return int(difficulty(str(cfg.get("difficulty", DEFAULT_DIFFICULTY))).get("points", 14))


## Punkte, die die Auswahl kostet.
static func cost(cfg: Dictionary) -> int:
	var total := ship_cost(str(cfg.get("ship", DEFAULT_SHIP)))
	for id: Variant in cfg.get("weapons", []):
		total += weapon_cost(str(id))
	var crew: Array = cfg.get("crew", [])
	for i in crew.size():
		total += crew_cost(str(crew[i])) + crew_surcharge(i)
	for id: Variant in cfg.get("perks", []):
		total += perk_cost(str(id))
	return total


static func remaining(cfg: Dictionary) -> int:
	return budget(cfg) - cost(cfg)


## Rohstoffe für nicht ausgegebene Punkte.
static func leftover_scrap(cfg: Dictionary) -> int:
	return maxi(remaining(cfg), 0) * int(defs().get("leftover_scrap", 5))


## Waffenplätze des gewählten Schiffs.
static func weapon_slots(cfg: Dictionary) -> int:
	var stats := ship_stats(str(cfg.get("ship", DEFAULT_SHIP)))
	return int(stats.get("weapon_slots", (stats.get("weapons", []) as Array).size()))


## Energie, die alle gewählten Waffen zusammen brauchen, und die Balken im Waffensystem.
static func weapon_power(cfg: Dictionary) -> Vector2i:
	var need := 0
	for id: Variant in cfg.get("weapons", []):
		if Weapon.known(str(id)):
			need += Weapon.create(str(id)).cost
	var stats := ship_stats(str(cfg.get("ship", DEFAULT_SHIP)))
	return Vector2i(need, int((stats.get("systems", {}) as Dictionary).get("waffen", 0)))


## Was gegen die Auswahl spricht (leer = startklar). `check_unlocks` = false für Tests und
## gespeicherte Runs: Freischaltungen und Lexikon werden dann nicht geprüft.
static func problems(cfg: Dictionary, check_unlocks := true) -> PackedStringArray:
	var out := PackedStringArray()
	var ship_id := str(cfg.get("ship", ""))
	if ship(ship_id).is_empty():
		out.append(Loc.t("Unbekanntes Schiff"))
	elif check_unlocks and not is_unlocked(ship_id):
		out.append(Loc.t("Schiff noch nicht freigespielt"))
	var crew: Array = cfg.get("crew", [])
	if crew.size() > crew_max():
		out.append(Loc.t("Höchstens %d Crew neben dem Captain") % crew_max())
	var known := known_species()
	for s: Variant in crew:
		if not Species.known(str(s)) or (check_unlocks and not known.has(str(s))):
			out.append(Loc.t("Spezies noch nicht entdeckt"))
			break
	var weapons: Array = cfg.get("weapons", [])
	if weapons.is_empty():
		out.append(Loc.t("Mindestens eine Waffe"))
	if weapons.size() > weapon_slots(cfg):
		out.append(Loc.t("Zu viele Waffen für die Waffenplätze"))
	for id: Variant in weapons:
		if not weapon_ids().has(str(id)):
			out.append(Loc.t("Unbekannte Waffe"))
			break
	var perks: Array = cfg.get("perks", [])
	if perks.size() > perks_max():
		out.append(Loc.t("Höchstens %d Perks zum Start") % perks_max())
	var seen := {}
	for id: Variant in perks:
		if not perk_ids().has(str(id)) or seen.has(id):
			out.append(Loc.t("Ungültiger Perk"))
			break
		seen[id] = true
	if remaining(cfg) < 0:
		out.append(Loc.t("%d Punkte zu viel ausgegeben") % -remaining(cfg))
	return out


static func is_valid(cfg: Dictionary, check_unlocks := true) -> bool:
	return problems(cfg, check_unlocks).is_empty()
