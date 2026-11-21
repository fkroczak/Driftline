class_name ShipState
extends RefCounted
## Zustand eines Schiffs im Spiel: Layout, Crew, Hülle, Systeme, Energie und Waffen.
## Weiß nichts von Bildschirm oder Eingabe.
##
## Energie: Der Reaktor liefert eine feste Zahl Balken (minus Reaktorschaden). Jedes System
## bekommt höchstens, was der Spieler wünscht und was heil ist. Reicht der Reaktor nicht,
## werden die Systeme in POWER_PRIORITY-Reihenfolge versorgt. Nach einer Reparatur kehrt
## die gewünschte Energie von selbst zurück, sofern noch Reaktorleistung frei ist.
##
## Reparatur: Wer (stehend) in einem Raum mit beschädigtem System ist, repariert ihn.
##
## Konsolenregel (Räume mit Konsole, siehe data/ships/*.json):
## 1. Ist die Konsole frei, setzt sich die erfahrenste Person im Raum hin.
## 2. Sitzt dort jemand weniger Erfahrenes, tauschen beide den Platz,
##    außer diese Person wurde ausdrücklich an die Konsole geschickt.
## 3. Wer an der Konsole sitzt, sammelt Erfahrung im System des Raums.

const XP_PER_SECOND := 1.0 / 60.0
const POWER_PRIORITY := ["lebenserhaltung", "schilde", "waffen", "antrieb", "sensoren", "medbay"]
## Sekunden je Schildschicht ohne Besatzung an der Konsole.
const SHIELD_RECHARGE := 2.0
## Bonus für eine besetzte Konsole und je Erfahrungsstufe (Ladezeit, Ausweichen).
const OPERATOR_BONUS := 0.1
const LEVEL_BONUS := 0.05
const EVASION_PER_ENGINE_BAR := 0.08
const MAX_EVASION := 0.6

var layout: ShipLayout
var crew: Array[CrewMember] = []
var hull := 0
var max_hull := 0
var systems: Dictionary = {}  # System-ID -> ShipSystem
var weapons: Array[Weapon] = []
var shield_layers := 0
var shield_progress := 0.0
## Meldungen für die Darstellung (z. B. Reparatur fertig); wer sie liest, leert die Liste.
var events: Array[Dictionary] = []


func _init(p_layout: ShipLayout) -> void:
	layout = p_layout
	var st := layout.stats
	max_hull = int(st.get("hull", 0))
	hull = max_hull
	if st.has("reactor"):
		systems["reaktor"] = ShipSystem.new("reaktor", int(st["reactor"]))
	var caps: Dictionary = st.get("systems", {})
	for id: String in caps:
		systems[id] = ShipSystem.new(id, int(caps[id]))
	var power: Dictionary = st.get("power", {})
	for id: String in power:
		if systems.has(id):
			systems[id].wanted = int(power[id])
	for weapon_id: String in st.get("weapons", []):
		weapons.append(Weapon.create(weapon_id))
	for i in mini(int(st.get("weapons_powered", 0)), weapons.size()):
		weapons[i].wanted = true
	_rebalance()
	shield_layers = max_shield_layers()


func get_system(id: String) -> ShipSystem:
	return systems.get(id)


## Wirksame Stufe eines Systems (0, wenn es fehlt).
func level(id: String) -> int:
	var sys: ShipSystem = systems.get(id)
	return sys.level() if sys else 0


func reactor_output() -> int:
	return level("reaktor")


func power_used() -> int:
	var used := 0
	for sys: ShipSystem in systems.values():
		if not sys.is_passive():
			used += sys.power
	return used


func power_free() -> int:
	return reactor_output() - power_used()


## Einen Balken Energie mehr. Bei Waffen wird die nächste passende Waffe eingeschaltet.
func add_power(id: String) -> bool:
	var sys: ShipSystem = systems.get(id)
	if not sys or sys.is_passive():
		return false
	if id == "waffen":
		for i in weapons.size():
			if not weapons[i].powered and set_weapon_wanted(i, true):
				return true
		return false
	if sys.power >= sys.usable() or power_free() < 1:
		return false
	sys.wanted = sys.power + 1
	_rebalance()
	return true


## Einen Balken Energie weniger. Bei Waffen wird die letzte eingeschaltete Waffe abgeschaltet.
func remove_power(id: String) -> bool:
	var sys: ShipSystem = systems.get(id)
	if not sys or sys.is_passive():
		return false
	if id == "waffen":
		for i in range(weapons.size() - 1, -1, -1):
			if weapons[i].powered:
				return set_weapon_wanted(i, false)
		return false
	if sys.power <= 0:
		return false
	sys.wanted = sys.power - 1
	_rebalance()
	return true


## Waffe ein- oder ausschalten. Falsch, wenn Energie oder heile Waffenbalken fehlen.
func set_weapon_wanted(idx: int, on: bool) -> bool:
	var sys: ShipSystem = systems.get("waffen")
	if not sys or idx < 0 or idx >= weapons.size():
		return false
	var weapon := weapons[idx]
	if on and not weapon.powered:
		if power_free() < weapon.cost or sys.power + weapon.cost > sys.usable():
			return false
	weapon.wanted = on
	_rebalance()
	return weapon.powered == on


func max_shield_layers() -> int:
	return level("schilde") / 2


## Wahrscheinlichkeit, einem Schuss auszuweichen. Ohne Person im Cockpit: 0.
func evasion() -> float:
	var pilot := operator_of_system("cockpit")
	if pilot == null or level("cockpit") <= 0 or level("antrieb") <= 0:
		return 0.0
	var value := level("antrieb") * EVASION_PER_ENGINE_BAR + pilot.level("cockpit") * 0.01
	var engineer := operator_of_system("antrieb")
	if engineer:
		value += 0.05 + engineer.level("antrieb") * 0.01
	return minf(value, MAX_EVASION)


## Faktor für Lade- und Aufladezeiten: besetzte Konsole und Erfahrung beschleunigen.
func skill_factor(system: String) -> float:
	var op := operator_of_system(system)
	return 1.0 if op == null else 1.0 + OPERATOR_BONUS + LEVEL_BONUS * op.level(system)


func operator_of_system(system: String) -> CrewMember:
	var room := layout.room_of_system(system)
	return operator_of(room) if room >= 0 else null


## Treffer in einem Raum: Hüllenschaden und Schaden am System des Raums.
## Liefert den Schaden am System (0, wenn der Raum keins hat oder es schon zerstört ist).
func take_hit(room_idx: int, amount: int) -> int:
	hull = maxi(hull - amount, 0)
	var dealt := 0
	if room_idx >= 0:
		var sys: ShipSystem = systems.get(layout.rooms[room_idx].system)
		if sys:
			dealt = sys.apply_damage(amount)
	_rebalance()
	return dealt


func is_destroyed() -> bool:
	return max_hull > 0 and hull <= 0


func _rebalance() -> void:
	var remaining := reactor_output()
	var order: Array = POWER_PRIORITY.duplicate()
	for id: String in systems:
		if not order.has(id):
			order.append(id)
	for id: String in order:
		var sys: ShipSystem = systems.get(id)
		if not sys or sys.is_passive():
			continue
		var budget := mini(sys.usable(), remaining)
		if id == "waffen":
			var used := 0
			var wanted := 0
			for weapon in weapons:
				weapon.powered = weapon.wanted and used + weapon.cost <= budget
				if weapon.powered:
					used += weapon.cost
				if weapon.wanted:
					wanted += weapon.cost
			sys.power = used
			sys.wanted = wanted
		else:
			sys.power = clampi(sys.wanted, 0, budget)
		remaining -= sys.power
	shield_layers = mini(shield_layers, max_shield_layers())


func _repair(delta: float) -> void:
	for sys: ShipSystem in systems.values():
		var room := layout.room_of_system(sys.id)
		var workers := 0.0
		if sys.damage > 0 and room >= 0:
			for member in crew:
				if not member.is_moving() and layout.room_index_at(member.tile) == room:
					workers += 1.0
		if sys.repair(delta, workers):
			events.append({"type": "repaired", "system": sys.id, "room": room})


func _update_combat(delta: float) -> void:
	_repair(delta)
	_rebalance()
	if shield_layers < max_shield_layers():
		shield_progress += delta * skill_factor("schilde") / SHIELD_RECHARGE
		if shield_progress >= 1.0:
			shield_progress = 0.0
			shield_layers += 1
	else:
		shield_progress = 0.0
	var speed := skill_factor("waffen")
	for weapon in weapons:
		weapon.update(delta, speed)


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
	_update_combat(delta)


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
