class_name Weapon
extends RefCounted
## Eine Waffe an Bord. Werte kommen aus data/weapons.json.
## Mit Energie lädt sie auf; ohne Energie entlädt sie sich schnell.

const DEFS_PATH := "res://data/weapons.json"
const DRAIN_FACTOR := 3.0

static var _defs: Dictionary = {}

var id: String
var display_name: String
var cost := 1
var charge_time := 10.0
var shots := 1
var damage := 1
var charge := 0.0
## Vom Spieler eingeschaltet; ob sie wirklich Energie hat, steht in `powered`.
var wanted := false
var powered := false
## Zielraum im gegnerischen Schiff, -1 = kein Ziel (feuert nicht).
var target := -1


static func create(weapon_id: String) -> Weapon:
	if _defs.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFS_PATH))
		_defs = data if typeof(data) == TYPE_DICTIONARY else {}
	assert(_defs.has(weapon_id), "Unbekannte Waffe: %s" % weapon_id)
	var d: Dictionary = _defs.get(weapon_id, {})
	var w := Weapon.new()
	w.id = weapon_id
	w.display_name = d.get("name", weapon_id)
	w.cost = int(d.get("power", 1))
	w.charge_time = float(d.get("charge", 10.0))
	w.shots = int(d.get("shots", 1))
	w.damage = int(d.get("damage", 1))
	return w


func is_ready() -> bool:
	return powered and charge >= charge_time


func ratio() -> float:
	return clampf(charge / charge_time, 0.0, 1.0)


func update(delta: float, speed: float) -> void:
	if powered:
		charge = minf(charge + delta * speed, charge_time)
	else:
		charge = maxf(charge - delta * DRAIN_FACTOR, 0.0)
