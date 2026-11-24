class_name CrewMember
extends RefCounted
## Ein Crewmitglied an Bord: Position im Raster und Bewegung entlang eines Pfads.
## Spezieswerte (Lebenspunkte, Tempo, Reparatur, Boni) kommen aus data/species.json.

const DEFAULT_SPEED := 2.5  # Kacheln pro Sekunde
const MAX_EXPERIENCE := 5.0
## Lebenspunkte eines Menschen; andere Spezies haben eigene Werte (max_hp).
const MAX_HP := 100.0
const ROLE_CAPTAIN := "captain"
## Fertigkeit fürs Löschen, Flicken und Reparieren (lernt man bei der Arbeit, nicht an Konsolen).
const REPAIR_SKILL := "reparatur"
## Je Stufe Reparatur so viel schneller (Stufe 5 = +50 %).
const REPAIR_LEVEL_BONUS := 0.1

var display_name: String
var species: String
## "w" oder "m" und Farbvariante 0–2 (Grafik assets/crew/<spezies>_<w|m><n>_*), aus dem Namen.
var gender := "w"
var look := 0
## "captain" oder "" (die übrigen Aufgaben ergeben sich aus der Erfahrung).
var role := ""
var max_hp := MAX_HP
var tile: Vector2i
## Noch zu laufende Kacheln; path[0] ist die Kachel, auf die gerade zugelaufen wird.
var path: Array[Vector2i] = []
var step_progress := 0.0
var speed := DEFAULT_SPEED
var facing := Vector2i.DOWN
## Erfahrung je System (z. B. "waffen" -> 2.4). Die ganze Zahl ist die Stufe.
var experience: Dictionary = {}
## Ausdrücklich an eine Konsole geschickt: wird nicht automatisch verdrängt.
var pinned := false
## Stammplatz (z. B. die eigene Konsole), zu dem die Gegner-KI nach Reparaturen zurückkehrt.
var home_tile := Vector2i(-1, -1)
var hp := MAX_HP
## Was die Figur gerade tut (für die Darstellung): "", "loeschen", "flicken", "reparieren", "heilen".
var activity := ""
## Kachel, an der gearbeitet wird (Feuer, Leck); sonst die eigene.
var activity_tile := Vector2i.ZERO


func _init(p_name: String, p_species: String, p_tile: Vector2i) -> void:
	display_name = p_name
	species = p_species if Species.known(p_species) else Species.DEFAULT
	gender = Species.gender_of(species, p_name)
	look = Species.look_of(p_name)
	tile = p_tile
	home_tile = p_tile
	max_hp = float(Species.value(species, "hp", MAX_HP))
	hp = max_hp
	speed = DEFAULT_SPEED * float(Species.value(species, "speed", 1.0))


func is_captain() -> bool:
	return role == ROLE_CAPTAIN


## Tempo beim Löschen, Flicken und Reparieren (1 = Mensch ohne Erfahrung): Spezies mal Erfahrung.
func repair_factor() -> float:
	return float(Species.value(species, "repair", 1.0)) * (1.0 + REPAIR_LEVEL_BONUS * level(REPAIR_SKILL))


func breathes() -> bool:
	return bool(Species.value(species, "breathes", true))


func fire_factor() -> float:
	return float(Species.value(species, "fire", 1.0))


func medbay_factor() -> float:
	return float(Species.value(species, "medbay", 1.0))


## Bonus an einer Konsole durch die Spezies: stark (+15 %), schwach (×0,8) oder neutral.
func console_factor(system: String) -> float:
	var f := float(Species.value(species, "console", 1.0))
	if (Species.value(species, "bonus", []) as Array).has(system):
		f += Species.SYSTEM_BONUS
	return f


## System mit der meisten Erfahrung ("" ohne Erfahrung).
func best_system() -> String:
	var best := ""
	for system: String in experience:
		if system == REPAIR_SKILL:
			continue
		if best == "" or experience[system] > experience[best]:
			best = system
	return best


## Kachel, auf der die Figur gerade überwiegend steht.
func current_tile() -> Vector2i:
	return Vector2i(tile_position().round())


## Tätigkeit setzen und zur Arbeitsstelle schauen.
func set_activity(kind: String, target: Vector2i) -> void:
	activity = kind
	activity_tile = target
	var d := target - tile
	if d != Vector2i.ZERO and not is_moving():
		facing = Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))


func level(system: String) -> int:
	return int(experience.get(system, 0.0))


func gain_experience(system: String, amount: float) -> void:
	if system != REPAIR_SKILL:
		amount *= float(Species.value(species, "learn", 1.0))  # gilt an Konsolen
	experience[system] = minf(experience.get(system, 0.0) + amount, MAX_EXPERIENCE)


func is_moving() -> bool:
	return not path.is_empty()


func destination() -> Vector2i:
	return path.back() if is_moving() else tile


func update(delta: float) -> void:
	var remaining := delta * speed
	while is_moving() and remaining > 0.0:
		facing = path[0] - tile
		var needed := 1.0 - step_progress
		if remaining >= needed:
			remaining -= needed
			tile = path.pop_front()
			step_progress = 0.0
		else:
			step_progress += remaining
			remaining = 0.0


## Aktuelle Position in Kacheln, zwischen zwei Kacheln interpoliert.
func tile_position() -> Vector2:
	if not is_moving():
		return Vector2(tile)
	return Vector2(tile).lerp(Vector2(path[0]), step_progress)
