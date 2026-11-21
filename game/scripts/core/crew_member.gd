class_name CrewMember
extends RefCounted
## Ein Crewmitglied an Bord: Position im Raster und Bewegung entlang eines Pfads.

const DEFAULT_SPEED := 2.5  # Kacheln pro Sekunde
const MAX_EXPERIENCE := 5.0

var display_name: String
var species: String
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


func _init(p_name: String, p_species: String, p_tile: Vector2i) -> void:
	display_name = p_name
	species = p_species
	tile = p_tile
	home_tile = p_tile


func level(system: String) -> int:
	return int(experience.get(system, 0.0))


func gain_experience(system: String, amount: float) -> void:
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
