class_name Upgrades
extends RefCounted
## Regeln für den Schiffsausbau aus data/upgrades.json: Systemstufen und Preise, Perks (einmalige
## Module), Waffenlager, Verkaufsanteil und Crew-Preise beim Händler. Reine Daten, keine Nodes.

const PATH := "res://data/upgrades.json"
## Reihenfolge auf der Seite SYSTEME.
const SYSTEM_ORDER := ["reaktor", "schilde", "waffen", "antrieb", "medbay", "lebenserhaltung"]

static var _defs: Dictionary = {}


static func defs() -> Dictionary:
	if _defs.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_defs = data if typeof(data) == TYPE_DICTIONARY else {}
	return _defs


static func system_rule(id: String) -> Dictionary:
	return (defs().get("systems", {}) as Dictionary).get(id, {})


static func perk_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign((defs().get("perks", {}) as Dictionary).keys())
	return out


static func perk(id: String) -> Dictionary:
	return (defs().get("perks", {}) as Dictionary).get(id, {})


static func perk_name(id: String) -> String:
	return Loc.t(str(perk(id).get("name", id)))


static func perk_text(id: String) -> String:
	return Loc.t(str(perk(id).get("text", "")))


static func weapon_storage() -> int:
	return int(defs().get("weapon_storage", 2))


static func sell_factor() -> float:
	return float(defs().get("sell_factor", 0.5))


static func shop_weapons() -> int:
	return int(defs().get("shop_weapons", 2))


static func crew_offers() -> int:
	return int((defs().get("crew", {}) as Dictionary).get("offers", 2))


static func crew_price(species: String) -> int:
	return int(((defs().get("crew", {}) as Dictionary).get("price", {}) as Dictionary).get(species, 25))
