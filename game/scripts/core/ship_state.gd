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
## Arbeit im Raum: Wer (stehend) in einem Raum ist, löscht zuerst Feuer, flickt dann
## Hüllenbrüche und repariert zuletzt das System des Raums.
##
## Sauerstoff je Raum (0..1): Die Lebenserhaltung füllt nach. Feuer verbraucht ihn,
## Hüllenbrüche und offene Luftschleusen lassen ihn entweichen, offene Türen gleichen
## zwischen Nachbarräumen aus. Unter O2_LOW erstickt die Crew, unter FIRE_DIE_O2 geht Feuer aus.
##
## Feuer (je Kachel): breitet sich bei genug Sauerstoff aus (im Raum und durch offene Türen),
## beschädigt das System im Raum und verletzt Crew.
##
## Sprungantrieb: Mit Energie im Antrieb und einer Person im Cockpit lädt der Sprung
## (JUMP_TIME Sekunden je Balken Antrieb geteilt). Voll geladen kann das Schiff fliehen.
## Außerhalb des Kampfs (in_combat = false) lädt er schneller und auch ohne Energie im Antrieb
## (PEACE_JUMP_TIME, geteilt durch 1 + Balken Antrieb); Waffen laden dann nicht.
##
## Treffer: Die Hülle verliert immer Punkte. Das System im Raum nimmt nur mit der
## Systemchance der Waffe Schaden (data/weapons.json: system), Feuer und Hüllenbrüche ebenso
## (fire, breach). So fallen Räume nicht bei jedem Treffer aus.
##
## Spezies (data/species.json): Lebenspunkte, Tempo, Reparatur, Feuer- und Luftbedarf,
## Medbay-Heilung und Konsolenboni hängen an der Spezies der Person.
##
## Türen sind anfangs zu. Die eigene Crew läuft trotzdem hindurch; Luft und Feuer nicht.
##
## Konsolenregel (Räume mit Konsole, siehe data/ships/*.json):
## 1. Ist die Konsole frei, setzt sich die erfahrenste Person im Raum hin.
## 2. Sitzt dort jemand weniger Erfahrenes, tauschen beide den Platz,
##    außer diese Person wurde ausdrücklich an die Konsole geschickt.
## 3. Wer an der Konsole sitzt, sammelt Erfahrung im System des Raums.

const XP_PER_SECOND := 1.0 / 60.0
const POWER_PRIORITY := ["lebenserhaltung", "schilde", "waffen", "antrieb", "sensoren", "medbay"]
## Sekunden je Schildschicht ohne Besatzung an der Konsole.
const SHIELD_RECHARGE := 3.0
## Bonus für eine besetzte Konsole und je Erfahrungsstufe (Ladezeit, Ausweichen).
const OPERATOR_BONUS := 0.1
const LEVEL_BONUS := 0.05
const EVASION_PER_ENGINE_BAR := 0.08
const MAX_EVASION := 0.6
## Sauerstoff je Sekunde und Raum pro Balken Lebenserhaltung.
const O2_REFILL_PER_LEVEL := 0.04
const O2_LOW := 0.1
const O2_FIRE_USE := 0.015
const O2_BREACH_LEAK := 0.15
const O2_VENT := 0.6
const O2_FLOW := 2.0
const FIRE_SPREAD := 0.06  # Wahrscheinlichkeit je Feuer und Sekunde
const FIRE_MIN_O2 := 0.25  # darunter breitet sich Feuer nicht aus
const FIRE_DIE_O2 := 0.12  # darunter erlischt Feuer
const FIRE_BURNOUT := 0.4
const FIRE_GROWTH := 0.2
const FIRE_SYSTEM_DAMAGE := 0.08  # Balken je Sekunde und Feuer
const EXTINGUISH := 0.7  # Löschen je Person und Sekunde
const BREACH_REPAIR_TIME := 5.0
const HP_FIRE_TILE := 5.0
const HP_FIRE_ROOM := 1.5
const HP_SUFFOCATE := 6.0
const HP_PER_HIT := 15.0
const HEAL_PER_LEVEL := 6.0
## Sekunden bis zum Sprung bei einem Balken Antrieb; zwei Balken laden doppelt so schnell.
const JUMP_TIME := 40.0
## Außerhalb des Kampfs: Sekunden ohne Energie im Antrieb, geteilt durch 1 + Balken.
const PEACE_JUMP_TIME := 15.0

var layout: ShipLayout
var crew: Array[CrewMember] = []
var hull := 0
var max_hull := 0
var systems: Dictionary = {}  # System-ID -> ShipSystem
var weapons: Array[Weapon] = []
var shield_layers := 0
var shield_progress := 0.0
var oxygen: Array[float] = []  # je Raum
var fires: Dictionary = {}  # Kachel -> Stärke (0..1)
var breaches: Dictionary = {}  # Kachel -> Reparaturfortschritt (0..1)
var door_open: Dictionary = {}  # Türschlüssel -> true, fehlt = zu
var airlock_open: Array[bool] = []
## Wahrscheinlichkeit für Feuer bzw. Hüllenbruch bei einem Treffer.
var fire_chance := 0.3
var breach_chance := 0.1
var rng := RandomNumberGenerator.new()
var had_crew := false
## Ladestand des Sprungantriebs (0..1).
var jump_charge := 0.0
## Im Kampf: Sprung lädt langsam, Waffen laden. Außerhalb: Sprung lädt schnell, Waffen nicht.
var in_combat := true
var _fire_damage := {}  # System-ID -> Fortschritt bis zum nächsten Brandschaden
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
	for i in layout.rooms.size():
		oxygen.append(1.0)
	for i in layout.airlocks.size():
		airlock_open.append(false)
	rng.seed = 1


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
	if op == null:
		return 1.0
	return 1.0 + (OPERATOR_BONUS + LEVEL_BONUS * op.level(system)) * op.console_factor(system) \
		+ (Species.SYSTEM_BONUS if (Species.value(op.species, "bonus", []) as Array).has(system) else 0.0)


func operator_of_system(system: String) -> CrewMember:
	var room := layout.room_of_system(system)
	return operator_of(room) if room >= 0 else null


## Treffer in einem Raum: Hüllenschaden, verletzte Crew und mit den Chancen der Waffe
## Systemschaden, Feuer und Hüllenbruch. Ohne Waffe (z. B. in Tests oder Ereignissen) trifft es
## das System immer, Feuer und Lecks mit fire_chance und breach_chance des Schiffs.
## Liefert den Schaden am System.
func take_hit(room_idx: int, amount: int, weapon: Weapon = null) -> int:
	hull = maxi(hull - amount, 0)
	var dealt := 0
	if room_idx >= 0:
		var sys: ShipSystem = systems.get(layout.rooms[room_idx].system)
		var sys_chance := weapon.system_chance if weapon else 1.0
		if sys and rng.randf() < sys_chance:
			dealt = sys.apply_damage(amount)
		for member: CrewMember in crew.duplicate():
			if layout.room_index_at(member.current_tile()) == room_idx:
				_hurt(member, HP_PER_HIT * amount)
		var tiles := layout.room_tiles(room_idx)
		if rng.randf() < (weapon.fire_chance if weapon else fire_chance):
			start_fire(tiles[rng.randi() % tiles.size()])
		if rng.randf() < (weapon.breach_chance if weapon else breach_chance):
			start_breach(tiles[rng.randi() % tiles.size()])
	_rebalance()
	return dealt


## Lädt der Sprungantrieb gerade? Braucht Antrieb mit Energie und eine Person im Cockpit.
func can_charge_jump() -> bool:
	return level("antrieb") > 0 and level("cockpit") > 0 and operator_of_system("cockpit") != null


func jump_ready() -> bool:
	return jump_charge >= 1.0 and operator_of_system("cockpit") != null


func is_destroyed() -> bool:
	return max_hull > 0 and hull <= 0


## Die ganze Besatzung ist tot (nur, wenn es überhaupt eine gab).
func is_crew_dead() -> bool:
	return had_crew and crew.is_empty()


func start_fire(tile: Vector2i) -> void:
	if layout.is_walkable(tile) and not fires.has(tile):
		fires[tile] = 0.5
		events.append({"type": "fire_started", "tile": tile, "room": layout.room_index_at(tile)})


func start_breach(tile: Vector2i) -> void:
	if layout.is_walkable(tile) and not breaches.has(tile):
		breaches[tile] = 0.0
		events.append({"type": "breach", "tile": tile, "room": layout.room_index_at(tile)})


func fires_in_room(room: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for t: Vector2i in fires:
		if layout.room_index_at(t) == room:
			result.append(t)
	return result


func breaches_in_room(room: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for t: Vector2i in breaches:
		if layout.room_index_at(t) == room:
			result.append(t)
	return result


func is_door_open(a: Vector2i, b: Vector2i) -> bool:
	return door_open.get(ShipLayout.door_key(a, b), false)


func set_door_open(a: Vector2i, b: Vector2i, open: bool) -> void:
	if layout.has_door(a, b):
		door_open[ShipLayout.door_key(a, b)] = open


func toggle_door(a: Vector2i, b: Vector2i) -> bool:
	set_door_open(a, b, not is_door_open(a, b))
	return is_door_open(a, b)


## Alle Türen auf oder zu.
func set_all_doors(open: bool) -> void:
	for pair: Array in layout.door_list():
		set_door_open(pair[0], pair[1], open)


func any_door_open() -> bool:
	return door_open.values().has(true)


func any_airlock_open() -> bool:
	return airlock_open.has(true)


func close_airlocks() -> void:
	for i in airlock_open.size():
		airlock_open[i] = false


func toggle_airlock(idx: int) -> bool:
	if idx < 0 or idx >= airlock_open.size():
		return false
	airlock_open[idx] = not airlock_open[idx]
	return airlock_open[idx]


func average_oxygen() -> float:
	if oxygen.is_empty():
		return 1.0
	var total := 0.0
	for o in oxygen:
		total += o
	return total / oxygen.size()


## Alle Personen im Raum löschen, flicken oder reparieren – in dieser Reihenfolge.
func _crew_work(delta: float) -> void:
	var idle := {}  # Raum -> [stehende Personen]
	for member in crew:
		member.activity = ""
		if not member.is_moving():
			var room := layout.room_index_at(member.tile)
			if room >= 0:
				if not idle.has(room):
					idle[room] = []
				idle[room].append(member)
	var busy := {}
	for room: int in idle:
		var workers: Array = idle[room]
		var room_fires := fires_in_room(room)
		if not room_fires.is_empty():
			busy[room] = true
			for i in workers.size():
				var t: Vector2i = room_fires[i % room_fires.size()]
				workers[i].set_activity("loeschen", t)
				if fires.has(t):
					fires[t] -= delta * EXTINGUISH * workers[i].repair_factor()
					if fires[t] <= 0.0:
						fires.erase(t)
						events.append({"type": "extinguished", "tile": t, "room": room})
			continue
		var room_breaches := breaches_in_room(room)
		if not room_breaches.is_empty():
			busy[room] = true
			var t: Vector2i = room_breaches[0]
			var power := 0.0
			for member: CrewMember in workers:
				member.set_activity("flicken", t)
				power += member.repair_factor()
			breaches[t] += delta * power / BREACH_REPAIR_TIME
			if breaches[t] >= 1.0:
				breaches.erase(t)
				events.append({"type": "breach_fixed", "tile": t, "room": room})
	for sys: ShipSystem in systems.values():
		var room := layout.room_of_system(sys.id)
		var workers := 0.0
		if sys.damage > 0 and room >= 0 and not busy.has(room) and idle.has(room):
			for member: CrewMember in idle[room]:
				workers += member.repair_factor()
				var console: Variant = layout.console_of(room)
				member.set_activity("reparieren", console if console != null and console != member.tile else layout.rooms[room].pos)
		if sys.repair(delta, workers):
			events.append({"type": "repaired", "system": sys.id, "room": room})


func _update_oxygen(delta: float) -> void:
	var refill := float(layout.stats.get("oxygen_regen", 0.0))
	if systems.has("lebenserhaltung"):
		refill = level("lebenserhaltung") * O2_REFILL_PER_LEVEL
	for r in oxygen.size():
		oxygen[r] += refill * delta
	for t: Vector2i in fires:
		oxygen[layout.room_index_at(t)] -= O2_FIRE_USE * delta
	for t: Vector2i in breaches:
		oxygen[layout.room_index_at(t)] -= O2_BREACH_LEAK * delta
	for i in airlock_open.size():
		if airlock_open[i]:
			oxygen[layout.room_index_at(layout.airlocks[i].tile)] -= O2_VENT * delta
	var share := minf(delta * O2_FLOW, 0.5)
	for pair: Array in layout.door_list():
		if not is_door_open(pair[0], pair[1]):
			continue
		var ra := layout.room_index_at(pair[0])
		var rb := layout.room_index_at(pair[1])
		var flow := (oxygen[ra] - oxygen[rb]) * share * 0.5
		oxygen[ra] -= flow
		oxygen[rb] += flow
	for r in oxygen.size():
		oxygen[r] = clampf(oxygen[r], 0.0, 1.0)


func _update_fires(delta: float) -> void:
	var spread: Array[Vector2i] = []
	for t: Vector2i in fires.keys():
		var room := layout.room_index_at(t)
		var o := oxygen[room]
		if o < FIRE_DIE_O2:
			fires[t] -= delta * FIRE_BURNOUT
			if fires[t] <= 0.0:
				fires.erase(t)
				events.append({"type": "extinguished", "tile": t, "room": room})
			continue
		fires[t] = minf(fires[t] + delta * FIRE_GROWTH, 1.0)
		if o > FIRE_MIN_O2 and rng.randf() < FIRE_SPREAD * delta:
			var options: Array[Vector2i] = []
			for n in layout.neighbors(t):
				if fires.has(n) or (layout.room_index_at(n) != room and not is_door_open(t, n)):
					continue
				options.append(n)
			if not options.is_empty():
				spread.append(options[rng.randi() % options.size()])
	for t in spread:
		start_fire(t)
	var per_room := {}
	for t: Vector2i in fires:
		var room := layout.room_index_at(t)
		per_room[room] = per_room.get(room, 0) + 1
	for room: int in per_room:
		var sys: ShipSystem = systems.get(layout.rooms[room].system)
		if not sys or sys.usable() <= 0:
			continue
		_fire_damage[sys.id] = _fire_damage.get(sys.id, 0.0) + delta * FIRE_SYSTEM_DAMAGE * per_room[room]
		if _fire_damage[sys.id] >= 1.0:
			_fire_damage[sys.id] = 0.0
			sys.apply_damage(1)


func _update_crew_health(delta: float) -> void:
	var medbay := layout.room_of_system("medbay")
	for member: CrewMember in crew.duplicate():
		var t := member.current_tile()
		var room := layout.room_index_at(t)
		var damage := 0.0
		if fires.has(t):
			damage += HP_FIRE_TILE * member.fire_factor()
		elif room >= 0 and not fires_in_room(room).is_empty():
			damage += HP_FIRE_ROOM * member.fire_factor()
		if room >= 0 and oxygen[room] < O2_LOW and member.breathes():
			damage += HP_SUFFOCATE
		var heal := member.medbay_factor()
		if room == medbay and room >= 0 and not member.is_moving() and level("medbay") > 0 and heal > 0.0:
			if member.hp < member.max_hp and member.activity == "":
				member.activity = "heilen"
			member.hp = minf(member.hp + level("medbay") * HEAL_PER_LEVEL * heal * delta, member.max_hp)
		if damage > 0.0:
			_hurt(member, damage * delta)


## Verletzt ein Crewmitglied (z. B. bei einem Außeneinsatz); bei 0 LP stirbt es.
func hurt(member: CrewMember, amount: float) -> void:
	_hurt(member, amount)


## Neue Crew auf die erste freie Kachel, bevorzugt in Räumen ohne System (Erweiterungen).
## Falsch, wenn das Schiff voll ist.
func add_crew_anywhere(p_name: String, species: String) -> CrewMember:
	var reserved := _reserved_tiles(null)
	for prefer_empty in [true, false]:
		for room in layout.rooms.size():
			if prefer_empty and layout.rooms[room].system != "":
				continue
			for t in layout.room_tiles(room):
				if layout.is_walkable(t) and not reserved.has(t):
					return add_crew(p_name, species, t)
	return null


func _hurt(member: CrewMember, amount: float) -> void:
	member.hp -= amount
	if member.hp <= 0.0 and crew.has(member):
		member.hp = 0.0
		crew.erase(member)
		events.append({"type": "crew_died", "name": member.display_name, "tile": member.tile_position(), "member": member})


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


func _update_combat(delta: float) -> void:
	_crew_work(delta)
	_update_oxygen(delta)
	_update_fires(delta)
	_update_crew_health(delta)
	_rebalance()
	if shield_layers < max_shield_layers():
		shield_progress += delta * skill_factor("schilde") / SHIELD_RECHARGE
		if shield_progress >= 1.0:
			shield_progress = 0.0
			shield_layers += 1
	else:
		shield_progress = 0.0
	if not in_combat:
		if level("cockpit") > 0 and operator_of_system("cockpit") != null:
			jump_charge = minf(jump_charge + delta * (1 + level("antrieb")) * skill_factor("antrieb") / PEACE_JUMP_TIME, 1.0)
	elif can_charge_jump():
		jump_charge = minf(jump_charge + delta * level("antrieb") * skill_factor("antrieb") / JUMP_TIME, 1.0)
	var speed := skill_factor("waffen")
	for weapon in weapons:
		var was_powered := weapon.powered
		if not in_combat:
			weapon.powered = false  # außerhalb des Kampfs laden Waffen nicht
		weapon.update(delta, speed)
		weapon.powered = was_powered


## Kampfende bzw. Sprung: nur was zum Kampf selbst gehört, wird zurückgesetzt. Waffen sind
## ungeladen und ohne Ziel, laufende Crew steht auf ihrem Ziel. Der Sprungantrieb behält seine
## Ladung (geleert wird er beim Sprung selbst, siehe RunState.jump_to).
## Nichts wird automatisch repariert oder aufgeladen: Hülle, Systemschäden, Lecks, Feuer, Luft,
## Schilde, Türen, Schleusen und verletzte Crew bleiben, bis die Crew sie behebt (im Kampf oder
## in der Zeit danach) oder eine Reparaturstation hilft.
func end_combat() -> void:
	in_combat = false
	for weapon in weapons:
		weapon.charge = 0.0
		weapon.target = -1
	for member in crew:
		if member.is_moving():
			member.tile = member.destination()
			member.path.clear()
		member.step_progress = 0.0
		member.activity = ""
	events.clear()
	_rebalance()


## Reparaturstation: alle Systeme heil, Lecks geflickt, Feuer gelöscht, Luft aufgefüllt.
func repair_systems() -> void:
	fires.clear()
	breaches.clear()
	_fire_damage.clear()
	for sys: ShipSystem in systems.values():
		sys.damage = 0
		sys.repair_progress = 0.0
	for r in oxygen.size():
		oxygen[r] = 1.0
	_rebalance()


## Beschädigte Systembalken insgesamt.
func system_damage() -> int:
	var total := 0
	for sys: ShipSystem in systems.values():
		total += sys.damage
	return total


func add_crew(p_name: String, species: String, tile: Vector2i, experience := {}) -> CrewMember:
	assert(layout.is_walkable(tile), "Crew-Startkachel %s liegt in keinem Raum" % tile)
	var member := CrewMember.new(p_name, species, tile)
	member.experience = experience.duplicate()
	crew.append(member)
	had_crew = true
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
