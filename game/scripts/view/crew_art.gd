class_name CrewArt
extends RefCounted
## Grafiken der Crew je Spezies: Figur an Bord (Sheet mit 4 Richtungen, je 16 × 16) und Porträt
## (40 × 44, Blick nach unten) aus assets/crew/. Je Person gibt es Varianten nach Geschlecht und
## Farbe (<spezies>_<w|m><0-2>_..., tools/artgen/crew_variants.py). Fehlt eine Datei, gilt die
## Grundform der Spezies, dann der Mensch.
## Der Porträtausschnitt richtet sich nach `face` in data/species.json (Mitte des Kopfs im Porträt).

const SHEET := "res://assets/crew/%s_klein_sheet.png"
const PORTRAIT := "res://assets/crew/%s_gross_unten.png"
const DEFAULT_FACE := Vector2(20, 21)

static var _cache: Dictionary = {}


static func sheet(species: String) -> Texture2D:
	return _texture(SHEET, species)


static func portrait(species: String) -> Texture2D:
	return _texture(PORTRAIT, species)


## Figur und Porträt einer bestimmten Person (Geschlecht und Farbvariante).
static func sheet_of(species: String, gender: String, look: int) -> Texture2D:
	return _variant(SHEET, species, gender, look)


static func portrait_of(species: String, gender: String, look: int) -> Texture2D:
	return _variant(PORTRAIT, species, gender, look)


static func _variant(pattern: String, species: String, gender: String, look: int) -> Texture2D:
	var key := pattern % ("%s_%s%d" % [species, gender, look])
	if not _cache.has(key):
		_cache[key] = load(key) if ResourceLoader.exists(key) else _texture(pattern, species)
	return _cache[key]


static func _texture(pattern: String, species: String) -> Texture2D:
	var key := pattern % species
	if not _cache.has(key):
		_cache[key] = load(key) if ResourceLoader.exists(key) else load(pattern % Species.DEFAULT)
	return _cache[key]


static func face(species: String) -> Vector2:
	var f: Variant = Species.value(species, "face", [])
	return Vector2(float(f[0]), float(f[1])) if f is Array and f.size() == 2 else DEFAULT_FACE


## Ausschnitt um den Kopf (Crew-Liste mit Namen): 20 × 14 px.
static func head_crop(species: String) -> Rect2:
	return Rect2(face(species) - Vector2(10, 13), Vector2(20, 14))


## Quadratischer Ausschnitt (schmale Crew-Liste): 20 × 20 px.
static func square_crop(species: String) -> Rect2:
	return Rect2(face(species) - Vector2(10, 11), Vector2(20, 20))
