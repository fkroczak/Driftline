class_name ShipState
extends RefCounted
## Zustand eines Schiffs im Spiel: Layout plus Crew. Weiß nichts von Bildschirm oder Eingabe.
##
## Konsolenregel (Räume mit Konsole, siehe data/ships/*.json):
## 1. Ist die Konsole frei, setzt sich die erfahrenste Person im Raum hin.
## 2. Sitzt dort jemand weniger Erfahrenes, tauschen beide den Platz,
##    außer diese Person wurde ausdrücklich an die Konsole geschickt.
## 3. Wer an der Konsole sitzt, sammelt Erfahrung im System des Raums.

const XP_PER_SECOND := 1.0 / 60.0

var layout: ShipLayout
var crew: Array[CrewMember] = []


func _init(p_layout: ShipLayout) -> void:
	layout = p_layout


func add_crew(p_name: String, species: String, tile: Vector2i, experience := {}) -> CrewMember:
	assert(layout.is_walkable(tile), "Crew-Startkachel %s liegt in keinem Raum" % tile)
	var member := CrewMember.new(p_name, species, tile)
	member.experience = experience.duplicate()
	crew.append(member)
	return member


func update(delta: float) -> void:
	for member in crew:
		member.update(delta)
	_staff_consoles()
	for member in crew:
		if not member.is_moving() and layout.is_console(member.tile):
			var room := layout.room_index_at(member.tile)
			member.gain_experience(layout.rooms[room].system, delta * XP_PER_SECOND)


## Crewmitglied, das gerade (überwiegend) auf dieser Kachel steht.
func crew_at_tile(tile: Vector2i) -> CrewMember:
	for member in crew:
		if Vector2i(member.tile_position().round()) == tile:
			return member
	return null


## Nächstes Crewmitglied innerhalb von `radius` Kacheln um eine Position (in Kacheln,
## Kachelmitte = ganze Zahl). Großzügiger als crew_at_tile, damit knappe Treffer zählen.
func crew_near(pos: Vector2, radius: float) -> CrewMember:
	var best: CrewMember = null
	var best_dist := radius
	for member in crew:
		var dist := member.tile_position().distance_to(pos)
		if dist <= best_dist:
			best = member
			best_dist = dist
	return best


## Crewmitglied, das gerade auf einer Konsole sitzt (nicht nur unterwegs dorthin).
func operator_of(room_idx: int) -> CrewMember:
	var console: Variant = layout.console_of(room_idx)
	if console == null:
		return null
	for member in crew:
		if not member.is_moving() and member.tile == console:
			return member
	return null


## Schickt ein Crewmitglied auf eine bestimmte Kachel. Steht dort schon jemand
## (oder ist unterwegs dorthin), weicht diese Person auf die nächste freie Kachel aus,
## sofern `displace` gesetzt ist; sonst wird der Befehl abgelehnt.
func order_move_to_tile(member: CrewMember, tile: Vector2i, displace := true) -> bool:
	if not layout.is_walkable(tile):
		return false
	var occupant: CrewMember = null
	for other in crew:
		if other != member and other.destination() == tile:
			occupant = other
	if occupant and not displace:
		return false
	if not _walk_to(member, tile):
		return false
	member.pinned = layout.is_console(tile)
	if occupant:
		occupant.pinned = false
		var free: Variant = _nearest_free_tile(tile, layout.room_index_at(tile), occupant)
		if free != null:
			_walk_to(occupant, free)
	return true


## Schickt ein Crewmitglied in einen Raum, auf die nächstgelegene freie Kachel.
## Falsch, wenn der Raum voll oder unerreichbar ist.
func order_move(member: CrewMember, room_idx: int) -> bool:
	if room_idx < 0 or room_idx >= layout.rooms.size():
		return false
	var start := _start_tile(member)
	var reserved := _reserved_tiles(member)
	var best: Variant = null
	var best_len := 0
	for t in layout.room_tiles(room_idx):
		if reserved.has(t):
			continue
		var length := layout.find_path(start, t).size()
		if t != start and length == 0:
			continue
		if best == null or length < best_len:
			best = t
			best_len = length
	if best == null:
		return false
	member.pinned = false
	return _walk_to(member, best)


func _staff_consoles() -> void:
	for room in layout.rooms.size():
		var console: Variant = layout.console_of(room)
		if console == null:
			continue
		var system: String = layout.rooms[room].system
		var seated: CrewMember = null
		for member in crew:
			if member.destination() == console:
				seated = member
		if seated and seated.is_moving():
			continue  # jemand ist schon auf dem Weg zur Konsole
		var best: CrewMember = null
		for member in crew:
			if member.is_moving() or layout.room_index_at(member.tile) != room:
				continue
			if best == null or member.level(system) > best.level(system):
				best = member
		if best == null or best == seated:
			continue
		if seated == null:
			_walk_to(best, console)
		elif not seated.pinned and best.level(system) > seated.level(system):
			var free_tile := best.tile
			_walk_to(best, console)
			_walk_to(seated, free_tile)


func _start_tile(member: CrewMember) -> Vector2i:
	return member.path[0] if member.is_moving() else member.tile


## Ziele aller anderen Crewmitglieder.
func _reserved_tiles(except: CrewMember) -> Dictionary:
	var reserved := {}
	for other in crew:
		if other != except:
			reserved[other.destination()] = true
	return reserved


## Nächste freie Kachel ab `from`, bevorzugt im Raum `room_idx`, sonst irgendwo im Schiff.
func _nearest_free_tile(from: Vector2i, room_idx: int, member: CrewMember) -> Variant:
	var reserved := _reserved_tiles(member)
	var fallback: Variant = null
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_front()
		if not reserved.has(t):
			if layout.room_index_at(t) == room_idx:
				return t
			if fallback == null:
				fallback = t
		for n in layout.neighbors(t):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return fallback


## Setzt den Weg zur Zielkachel. Ein angefangener Schritt wird zu Ende gelaufen.
func _walk_to(member: CrewMember, target: Vector2i) -> bool:
	var start := _start_tile(member)
	var path := layout.find_path(start, target)
	if target != start and path.is_empty():
		return false
	if member.is_moving():
		path.push_front(start)
	else:
		member.step_progress = 0.0
	member.path = path
	return true
