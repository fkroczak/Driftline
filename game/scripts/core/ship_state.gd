class_name ShipState
extends RefCounted
## Zustand eines Schiffs im Spiel: Layout plus Crew. Weiß nichts von Bildschirm oder Eingabe.

var layout: ShipLayout
var crew: Array[CrewMember] = []


func _init(p_layout: ShipLayout) -> void:
	layout = p_layout


func add_crew(p_name: String, species: String, tile: Vector2i) -> CrewMember:
	assert(layout.is_walkable(tile), "Crew-Startkachel %s liegt in keinem Raum" % tile)
	var member := CrewMember.new(p_name, species, tile)
	crew.append(member)
	return member


func update(delta: float) -> void:
	for member in crew:
		member.update(delta)


## Crewmitglied, das gerade (überwiegend) auf dieser Kachel steht.
func crew_at_tile(tile: Vector2i) -> CrewMember:
	for member in crew:
		if Vector2i(member.tile_position().round()) == tile:
			return member
	return null


## Schickt ein Crewmitglied in einen Raum. Gewählt wird die nächstgelegene Kachel,
## die keine andere Figur als Ziel hat. Falsch, wenn der Raum voll oder unerreichbar ist.
func order_move(member: CrewMember, room_idx: int) -> bool:
	if room_idx < 0 or room_idx >= layout.rooms.size():
		return false
	var start := member.path[0] if member.is_moving() else member.tile
	var reserved := {}
	for other in crew:
		if other != member:
			reserved[other.destination()] = true

	var best_path: Array[Vector2i] = []
	var found := false
	for t in layout.room_tiles(room_idx):
		if reserved.has(t):
			continue
		var candidate := layout.find_path(start, t)
		if t != start and candidate.is_empty():
			continue
		if not found or candidate.size() < best_path.size():
			best_path = candidate
			found = true
	if not found:
		return false

	if member.is_moving():
		# Den angefangenen Schritt zu Ende laufen, dann dem neuen Weg folgen.
		best_path.push_front(start)
	member.path = best_path
	return true
