class_name EventBook
extends RefCounted
## Ereignisse aus data/events.json (Format siehe "_doc" dort). Reine Logik, keine Nodes.

const PATH := "res://data/events.json"

var events: Dictionary = {}  # id -> Ereignis


static func load_default() -> EventBook:
	var book := EventBook.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Ereignisse sind kein gültiges JSON: %s" % PATH)
		return book
	for e: Dictionary in data.get("events", []):
		book.events[e.id] = e
	return book


func get_event(id: String) -> Dictionary:
	return events.get(id, {})


func ids_in_pool(pool: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in events:
		if events[id].get("pool", "") == pool:
			result.append(id)
	return result


## Gewichtet ein Ereignis aus dem Pool ziehen; `exclude` (schon verwendet) nur, solange noch andere übrig sind.
func pick(pool: String, rng: RandomNumberGenerator, exclude := {}) -> String:
	var ids := ids_in_pool(pool)
	var fresh := ids.filter(func(id: String) -> bool: return not exclude.has(id))
	if not fresh.is_empty():
		ids = fresh
	if ids.is_empty():
		return ""
	var total := 0.0
	for id in ids:
		total += float(events[id].get("weight", 1.0))
	var roll := rng.randf() * total
	for id in ids:
		roll -= float(events[id].get("weight", 1.0))
		if roll <= 0.0:
			return id
	return ids.back()


## Prüft alle Ereignisse auf Tippfehler in Effekten und Bedingungen. Liefert Fehlertexte.
func validate() -> Array[String]:
	const EFFECTS := ["scrap", "fuel", "hull", "hull_full", "crew_hp", "crew_lose", "crew_add", "flag"]
	var errors: Array[String] = []
	for id: String in events:
		var e: Dictionary = events[id]
		for key in ["title", "text", "choices"]:
			if not e.has(key):
				errors.append("%s: %s fehlt" % [id, key])
		for choice: Dictionary in e.get("choices", []):
			if choice.get("outcomes", []).is_empty():
				errors.append("%s: Option ohne Ausgang" % id)
			for outcome: Dictionary in choice.get("outcomes", []):
				for effects: Dictionary in [outcome.get("effects", {}), outcome.get("victory", {})]:
					for key: String in effects:
						if not EFFECTS.has(key):
							errors.append("%s: unbekannter Effekt %s" % [id, key])
				if outcome.has("next") and not events.has(outcome.next):
					errors.append("%s: Folgeereignis %s fehlt" % [id, outcome.next])
	return errors
