class_name Battle
extends RefCounted
## Raumkampf zwischen eigenem Schiff und einem Gegner. Reine Logik, keine Nodes.
##
## Ablauf eines Schusses: Eine geladene Waffe feuert auf ihren eigenen Zielraum (Spieler:
## je Waffe angetippt, Gegner: je Waffe zufällig ein Raum mit System). Das Geschoss fliegt FLIGHT_TIME Sekunden.
## Beim Einschlag wird entschieden: Ausweichen (Antrieb + besetztes Cockpit), sonst
## Schild (eine Schicht fällt), sonst Treffer (Hülle und System im Raum).
##
## Alles, was die Darstellung animieren soll, landet in `events`:
## - fire, miss, shield, hit: from_player (Spieler hat geschossen), projectile, room
## - repaired, destroyed: own_ship (betrifft das Schiff des Spielers)
## - target: weapon, room (Zielwechsel einer Spielerwaffe)
## - fire_started, extinguished, breach, breach_fixed, crew_died: own_ship, tile, room
## Kampfende: Hülle auf 0 oder ganze Besatzung tot (destroyed mit reason "hull"/"crew").

const FLIGHT_TIME := 0.9
## Abstand zwischen den Schüssen einer Salve.
const SALVO_GAP := 0.18
## Gegner wählt nach so vielen Sekunden frühestens ein neues Ziel.
const ENEMY_RETARGET := 6.0

var player: ShipState
var enemy: ShipState
var projectiles: Array[Dictionary] = []
var events: Array[Dictionary] = []
## "" solange gekämpft wird, sonst "sieg", "niederlage" oder "entkommen" (Fluchtsprung).
var outcome := ""

var _rng := RandomNumberGenerator.new()
var _enemy_retarget := 0.0
var _id_counter := 0


func _init(p_player: ShipState, p_enemy: ShipState, rng_seed := 0) -> void:
	player = p_player
	enemy = p_enemy
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	player.rng.seed = _rng.randi()
	enemy.rng.seed = _rng.randi()


## Ziel einer einzelnen Spielerwaffe; -1 hebt das Ziel auf (Waffe hält das Feuer).
func set_weapon_target(weapon_idx: int, room_idx: int) -> void:
	if weapon_idx < 0 or weapon_idx >= player.weapons.size():
		return
	player.weapons[weapon_idx].target = room_idx
	_emit({"type": "target", "weapon": weapon_idx, "room": room_idx})


## Alle Spielerwaffen auf denselben Raum.
func set_all_targets(room_idx: int) -> void:
	for i in player.weapons.size():
		set_weapon_target(i, room_idx)


## Fluchtsprung des Spielers. Falsch, wenn der Antrieb noch nicht geladen ist.
func player_jump() -> bool:
	if outcome != "" or not player.jump_ready():
		return false
	outcome = "entkommen"
	projectiles.clear()
	_emit({"type": "jumped"})
	return true


func player_has_target() -> bool:
	for w in player.weapons:
		if w.target >= 0:
			return true
	return false


func update(delta: float) -> void:
	if outcome != "":
		return
	player.update(delta)
	enemy.update(delta)
	_collect_ship_events(player, true)
	_collect_ship_events(enemy, false)
	_enemy_ai(delta)
	_fire_ready(player, true)
	_fire_ready(enemy, false)
	_move_projectiles(delta)
	if enemy.is_destroyed() or enemy.is_crew_dead():
		outcome = "sieg"
		_emit({"type": "destroyed", "own_ship": false, "reason": "hull" if enemy.is_destroyed() else "crew"})
	elif player.is_destroyed() or player.is_crew_dead():
		outcome = "niederlage"
		_emit({"type": "destroyed", "own_ship": true, "reason": "hull" if player.is_destroyed() else "crew"})


## Holt alle Ereignisse ab und leert die Liste.
func take_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


func _emit(event: Dictionary) -> void:
	events.append(event)


func _collect_ship_events(ship: ShipState, is_player: bool) -> void:
	for e in ship.events:
		e["own_ship"] = is_player
		_emit(e)
	ship.events.clear()


func _fire_ready(ship: ShipState, is_player: bool) -> void:
	for i in ship.weapons.size():
		var weapon := ship.weapons[i]
		var target_room := weapon.target
		if target_room < 0 or not weapon.is_ready():
			continue
		weapon.charge = 0.0
		for shot in weapon.shots:
			_id_counter += 1
			projectiles.append({
				"id": _id_counter,
				"player": is_player,  # vom Spieler abgefeuert
				"weapon": i,
				"damage": weapon.damage,
				"room": target_room,
				"delay": shot * SALVO_GAP,
				"time": 0.0,
				"duration": FLIGHT_TIME,
				"fired": false,
			})


func _move_projectiles(delta: float) -> void:
	var landed: Array[Dictionary] = []
	for p in projectiles:
		if p.delay > 0.0:
			p.delay -= delta
			continue
		if not p.fired:
			p.fired = true
			_emit({"type": "fire", "from_player": p.player, "weapon": p.weapon, "projectile": p.id, "room": p.room})
		p.time += delta
		if p.time >= p.duration:
			landed.append(p)
	for p in landed:
		projectiles.erase(p)
		_resolve(p)


func _resolve(p: Dictionary) -> void:
	var defender := enemy if p.player else player
	var event := {"projectile": p.id, "from_player": p.player, "room": p.room, "damage": p.damage}
	if _rng.randf() < defender.evasion():
		event["type"] = "miss"
	elif defender.shield_layers > 0:
		defender.shield_layers -= 1
		defender.shield_progress = 0.0
		event["type"] = "shield"
	else:
		event["type"] = "hit"
		event["system_damage"] = defender.take_hit(p.room, p.damage)
	_emit(event)


## Gegner: Ziel alle paar Sekunden neu wählen, Crew repariert Schäden und kehrt
## danach an ihre Konsole zurück.
func _enemy_ai(delta: float) -> void:
	_enemy_retarget -= delta
	var untargeted := enemy.weapons.any(func(w: Weapon) -> bool: return w.target < 0)
	if untargeted or (_enemy_retarget <= 0.0 and _no_enemy_shots_pending()):
		var rooms := []
		for i in player.layout.rooms.size():
			if player.systems.has(player.layout.rooms[i].system):
				rooms.append(i)
		for w in enemy.weapons:
			w.target = rooms[_rng.randi() % rooms.size()] if not rooms.is_empty() else -1
		_enemy_retarget = ENEMY_RETARGET
	_enemy_crew()


func _no_enemy_shots_pending() -> bool:
	for p in projectiles:
		if not p.player:
			return false
	return true


## Wichtigster Einsatzort für die Gegner-Crew: Feuer, dann Hüllenbruch, dann Systemschaden.
func _enemy_trouble_room() -> int:
	for t: Vector2i in enemy.fires:
		return enemy.layout.room_index_at(t)
	for t: Vector2i in enemy.breaches:
		return enemy.layout.room_index_at(t)
	for sys: ShipSystem in enemy.systems.values():
		if sys.damage > 0:
			return enemy.layout.room_of_system(sys.id)
	return -1


func _enemy_crew() -> void:
	var damaged := _enemy_trouble_room()
	# Die Person an der unwichtigsten Konsole (letzte im Crew-Array) repariert.
	if enemy.crew.is_empty():
		return
	var engineer: CrewMember = enemy.crew.back()
	if engineer.is_moving():
		return
	var here := enemy.layout.room_index_at(engineer.tile)
	if damaged >= 0 and here != damaged:
		enemy.order_move(engineer, damaged)
	elif damaged < 0 and engineer.home_tile != Vector2i(-1, -1) and engineer.tile != engineer.home_tile:
		enemy.order_move_to_tile(engineer, engineer.home_tile)
