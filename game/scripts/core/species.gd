class_name Species
extends RefCounted
## Spezieswerte aus data/species.json (Lebenspunkte, Tempo, Reparatur, Boni, Texte).
## Unbekannte Spezies (z. B. aus einem älteren Spielstand) gelten als Mensch.

const PATH := "res://data/species.json"
const DEFAULT := "mensch"
## Bonus an einer Konsole, wenn die Spezies dort stark ist.
const SYSTEM_BONUS := 0.15

static var _defs: Dictionary = {}


static func _load() -> void:
	if _defs.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(data) == TYPE_DICTIONARY:
			for id: String in data:
				if not id.begins_with("_"):
					_defs[id] = data[id]


static func ids() -> Array[String]:
	_load()
	var out: Array[String] = []
	out.assign(_defs.keys())
	return out


static func known(id: String) -> bool:
	_load()
	return _defs.has(id)


static func data(id: String) -> Dictionary:
	_load()
	return _defs.get(id, _defs.get(DEFAULT, {}))


static func value(id: String, key: String, fallback: Variant) -> Variant:
	return data(id).get(key, fallback)


static func display_name(id: String) -> String:
	return Loc.t(str(value(id, "name", id)))


static func traits(id: String) -> Array:
	return (value(id, "traits", []) as Array).map(func(t: String) -> String: return Loc.t(t))


static func tint(id: String) -> Color:
	return Color(str(value(id, "tint", "#ffffff")))


## Zufällige Spezies nach Gewicht (für neue Crew aus Ereignissen).
static func pick(rng: RandomNumberGenerator) -> String:
	_load()
	var total := 0.0
	for id: String in _defs:
		total += float(_defs[id].get("weight", 1))
	var roll := rng.randf() * total
	for id: String in _defs:
		roll -= float(_defs[id].get("weight", 1))
		if roll <= 0.0:
			return id
	return DEFAULT


## Geschlecht zum Namen: "w" oder "m". Aus names_w/names_m bzw. genders, sonst aus dem Namen gewürfelt.
static func gender_of(id: String, p_name: String) -> String:
	var fixed: Dictionary = value(DEFAULT, "genders", {})
	if fixed.has(p_name):
		return str(fixed[p_name])
	if (value(id, "names_w", []) as Array).has(p_name):
		return "w"
	if (value(id, "names_m", []) as Array).has(p_name):
		return "m"
	return "w" if absi(hash(p_name)) % 2 == 0 else "m"


## Farbvariante (0–2) zum Namen, damit dieselbe Person immer gleich aussieht.
static func look_of(p_name: String) -> int:
	return absi(hash(p_name + "#look")) % 3


static func gender_label(gender: String) -> String:
	return Loc.t("weiblich") if gender == "w" else Loc.t("männlich")
