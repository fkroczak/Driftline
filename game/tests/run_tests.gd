extends SceneTree
## Logiktests ohne Fenster:
##   godot --headless --path game --script res://tests/run_tests.gd
## Jede Methode, die mit test_ beginnt, wird ausgeführt. Exit-Code 1 bei Fehlern.

const LAYOUT_PATH := "res://data/ships/mensch_frachter.json"

var _failures := 0
var _current := ""


func _init() -> void:
	Loc.set_language("de")  # Tests prüfen deutsche Texte, unabhängig von der Systemsprache
	var tests := get_method_list().filter(func(m): return m.name.begins_with("test_"))
	for m in tests:
		_current = m.name
		call(m.name)
	print("%d Tests, %d Fehler" % [tests.size(), _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FEHLER in %s: %s" % [_current, message])


func _layout() -> ShipLayout:
	return ShipLayout.load_json(LAYOUT_PATH)


func test_layout_is_valid() -> void:
	var layout := _layout()
	check(layout != null, "Layout lädt nicht")
	check(layout.rooms.size() == 12, "12 Räume erwartet, %d gefunden" % layout.rooms.size())
	var errors := layout.validate()
	check(errors.is_empty(), "Layout-Fehler: %s" % ", ".join(errors))


func test_walls_block_movement() -> void:
	var layout := _layout()
	# Lebenserhaltung (5,0) und Schilde (6,0) teilen eine Wand ohne Tür in Zeile 0.
	check(not layout.neighbors(Vector2i(5, 0)).has(Vector2i(6, 0)), "Wand ohne Tür ist durchlässig")
	check(layout.neighbors(Vector2i(5, 1)).has(Vector2i(6, 1)), "Tür in Zeile 1 fehlt")


func test_path_from_engine_to_cockpit() -> void:
	var layout := _layout()
	var path := layout.find_path(Vector2i(0, 0), Vector2i(9, 3))
	check(not path.is_empty(), "Kein Weg vom Antrieb ins Cockpit")
	check(path.back() == Vector2i(9, 3), "Pfad endet nicht am Ziel")
	var prev := Vector2i(0, 0)
	for step in path:
		check(layout.neighbors(prev).has(step), "Ungültiger Schritt %s → %s" % [prev, step])
		prev = step


func test_shuttle_bay_is_not_walkable() -> void:
	var layout := _layout()
	check(not layout.is_walkable(Vector2i(2, 3)), "Shuttlebucht darf nicht begehbar sein")
	check(layout.find_path(Vector2i(0, 0), Vector2i(2, 3)).is_empty(), "Weg in die Shuttlebucht gefunden")


func test_crew_walks_to_room() -> void:
	var state := ShipState.new(_layout())
	var member := state.add_crew("Test", "mensch", Vector2i(9, 3))
	var medbay := state.layout.room_index_by_id("medbay")
	check(state.order_move(member, medbay), "Befehl abgelehnt")
	for i in 300:
		state.update(0.1)
	check(not member.is_moving(), "Crew läuft nach 30 s noch")
	check(state.layout.room_index_at(member.tile) == medbay, "Crew ist nicht in der Medbay")


func test_crew_gets_distinct_tiles() -> void:
	var state := ShipState.new(_layout())
	var room := state.layout.room_index_by_id("schilde")
	var members: Array[CrewMember] = []
	for i in 5:
		members.append(state.add_crew("C%d" % i, "mensch", Vector2i(8, 1 + i)))
	for i in 4:
		check(state.order_move(members[i], room), "Platz %d abgelehnt" % i)
	check(not state.order_move(members[4], room), "Fünfte Figur passt nicht in einen 2×2-Raum")
	var targets := {}
	for i in 4:
		targets[members[i].destination()] = true
	check(targets.size() == 4, "Zwei Figuren haben dasselbe Ziel")


func test_redirect_mid_step() -> void:
	var state := ShipState.new(_layout())
	var member := state.add_crew("Test", "mensch", Vector2i(8, 3))
	state.order_move(member, state.layout.room_index_by_id("cockpit"))
	state.update(0.2)  # halber Schritt Richtung Cockpit
	var next := member.path[0]
	state.order_move(member, state.layout.room_index_by_id("waffen"))
	check(member.path[0] == next, "Angefangener Schritt wurde abgebrochen")
	for i in 300:
		state.update(0.1)
	check(state.layout.rooms[state.layout.room_index_at(member.tile)].id == "waffen", "Crew nicht im Waffenraum")


func _settle(state: ShipState, seconds := 30.0) -> void:
	for i in int(seconds * 10):
		state.update(0.1)


func test_exact_tile_placement() -> void:
	var state := ShipState.new(_layout())
	var member := state.add_crew("A", "mensch", Vector2i(8, 1))
	check(state.order_move_to_tile(member, Vector2i(2, 7)), "Befehl abgelehnt")
	_settle(state)
	check(member.tile == Vector2i(2, 7), "Nicht auf der gewählten Kachel, sondern %s" % member.tile)


func test_occupant_makes_room() -> void:
	var state := ShipState.new(_layout())
	var console: Vector2i = state.layout.console_of(state.layout.room_index_by_id("schilde"))
	var sitter := state.add_crew("Sitzt", "mensch", console)
	var newcomer := state.add_crew("Neu", "mensch", Vector2i(8, 4))
	check(state.order_move_to_tile(newcomer, console), "Befehl abgelehnt")
	check(sitter.destination() != console, "Sitzende Person macht keinen Platz")
	check(state.layout.room_index_at(sitter.destination()) == state.layout.room_index_by_id("schilde"),
		"Sitzende Person verlässt den Raum, obwohl Platz ist")
	_settle(state)
	check(newcomer.tile == console, "Neue Person sitzt nicht an der Konsole")
	check(state.operator_of(state.layout.room_index_by_id("schilde")) == newcomer, "Falsche Person bedient")


func test_free_console_gets_staffed() -> void:
	var state := ShipState.new(_layout())
	var waffen := state.layout.room_index_by_id("waffen")
	var member := state.add_crew("A", "mensch", Vector2i(6, 6))
	_settle(state, 5.0)
	check(state.operator_of(waffen) == member, "Freie Konsole wird nicht besetzt")


func test_most_experienced_takes_console() -> void:
	var state := ShipState.new(_layout())
	var waffen := state.layout.room_index_by_id("waffen")
	var console: Vector2i = state.layout.console_of(waffen)
	var rookie := state.add_crew("Neuling", "mensch", console, {"waffen": 0.0})
	var veteran := state.add_crew("Profi", "mensch", Vector2i(8, 1), {"waffen": 3.0})
	state.order_move(veteran, waffen)
	_settle(state)
	check(state.operator_of(waffen) == veteran, "Erfahrenere Person übernimmt nicht")
	check(state.layout.room_index_at(rookie.tile) == waffen, "Neuling hat den Raum verlassen")


func test_explicit_console_order_is_respected() -> void:
	var state := ShipState.new(_layout())
	var waffen := state.layout.room_index_by_id("waffen")
	var console: Vector2i = state.layout.console_of(waffen)
	var veteran := state.add_crew("Profi", "mensch", console, {"waffen": 3.0})
	var rookie := state.add_crew("Neuling", "mensch", Vector2i(8, 1), {"waffen": 0.0})
	state.order_move_to_tile(rookie, console)
	_settle(state)
	check(state.operator_of(waffen) == rookie, "Ausdrücklicher Befehl wurde überstimmt")
	check(state.layout.room_index_at(veteran.tile) == waffen, "Profi hat den Raum verlassen")


func test_console_builds_experience() -> void:
	var state := ShipState.new(_layout())
	var cockpit := state.layout.room_index_by_id("cockpit")
	var member := state.add_crew("A", "mensch", state.layout.console_of(cockpit))
	_settle(state, 61.0)
	check(member.level("cockpit") == 0, "Lernen an der Konsole zu schnell (Stufe 1 nach einer Minute)")
	_settle(state, 40.0)  # Mensch: 2 min / 1,25 = 96 s je Stufe
	check(member.level("cockpit") == 1, "Nach gut 1,5 Minuten an der Konsole keine Stufe 1")
	for i in 1200:
		state.update(1.0)
	check(member.level("cockpit") == int(CrewMember.MAX_EXPERIENCE), "Erfahrung nicht gedeckelt")


func test_repairing_builds_skill_and_speed() -> void:
	var state := _quiet_state()
	var schilde := state.layout.room_index_by_id("schilde")
	var member := state.add_crew("A", "mensch", state.layout.rooms[schilde].pos)
	var base := member.repair_factor()
	for i in 70:
		state.take_hit(schilde, 0)
		state.get_system("schilde").damage = 2
		state.update(1.0)
	check(member.level(CrewMember.REPAIR_SKILL) >= 1, "Reparieren bringt keine Erfahrung")
	check(member.repair_factor() > base, "Erfahrene Crew repariert nicht schneller")
	check(member.best_system() != CrewMember.REPAIR_SKILL, "Reparatur zählt als Konsolen-System")


func _flee_battle() -> Battle:
	var player := _quiet_state()
	var enemy := _enemy_ship()
	var battle := Battle.new(player, enemy, 3)
	for w in enemy.weapons:
		w.powered = false
	enemy.hull = 1
	return battle


func test_enemy_flees_with_engine_and_pilot() -> void:
	var fled := 0
	for seed_value in range(1, 21):
		var battle := _flee_battle()
		battle._rng.seed = seed_value
		for i in 600:
			battle.update(0.1)
			if battle.outcome != "":
				break
		if battle.outcome == "gegner_entkommen":
			fled += 1
	check(fled >= 2 and fled <= 14, "Gegner flieht nie oder zu oft (%d von 20, erwartet etwa jeder dritte)" % fled)


func test_enemy_cannot_flee_without_engine() -> void:
	var battle := _flee_battle()
	battle.enemy_fleeing = true
	battle._flee_decided = true
	while battle.enemy.remove_power("antrieb"):
		pass
	for i in 900:
		battle.update(0.1)
	check(battle.outcome == "" and battle.enemy.jump_charge == 0.0, "Gegner lädt ohne Energie im Antrieb")


func test_boss_never_flees() -> void:
	var battle := _flee_battle()
	battle.enemy_may_flee = false
	for i in 900:
		battle.update(0.1)
	check(not battle.enemy_fleeing and battle.outcome == "", "Boss flieht")


func test_enemy_escape_gives_no_loot() -> void:
	var run := RunState.new(4)
	var scrap := run.scrap
	run.finish_battle("gegner_entkommen")
	check(run.scrap == scrap and run.result == "" and run.cleared.has(run.current), "Flucht des Gegners falsch verbucht")


func test_crew_hit_is_forgiving() -> void:
	var state := ShipState.new(_layout())
	var member := state.add_crew("A", "mensch", Vector2i(9, 3))
	check(state.crew_near(Vector2(9.6, 3.3), 0.75) == member, "Knapper Treffer neben der Figur zählt nicht")
	check(state.crew_near(Vector2(10.5, 3.0), 0.75) == null, "Treffer zu weit entfernt zählt")


func test_occupied_tile_needs_displace() -> void:
	var state := ShipState.new(_layout())
	var sitter := state.add_crew("Sitzt", "mensch", Vector2i(7, 7))
	var other := state.add_crew("Neu", "mensch", Vector2i(8, 1))
	check(not state.order_move_to_tile(other, Vector2i(7, 7), false), "Besetzte Kachel ohne Verdrängen angenommen")
	check(sitter.destination() == Vector2i(7, 7) and not other.is_moving(), "Abgelehnter Befehl hat etwas verändert")


# --- Energie, Schaden, Kampf ---

const ENEMY_PATH := "res://data/ships/piraten_kutter.json"


func _enemy_ship() -> ShipState:
	var layout := ShipLayout.load_json(ENEMY_PATH)
	var ship := ShipState.new(layout)
	ship.add_crew("Pilot", "mensch", layout.console_of(layout.room_index_by_id("cockpit")))
	ship.add_crew("Schütze", "mensch", layout.console_of(layout.room_index_by_id("waffen")))
	ship.add_crew("Technik", "mensch", layout.console_of(layout.room_index_by_id("schilde")))
	return ship


func test_airlocks_lead_outside() -> void:
	var layout := _layout()
	check(layout.airlocks.size() == 2, "Frachter sollte 2 Luftschleusen haben")
	var rooms := layout.rooms_with_airlock()
	check(rooms.has(layout.room_index_by_id("erweiterung_1")) and rooms.has(layout.room_index_by_id("erweiterung_2")),
		"Luftschleusen in den falschen Räumen")
	var bad := ShipLayout.from_dict({"grid_size": [4, 2], "rooms": [
		{"id": "a", "pos": [0, 0]}, {"id": "b", "pos": [2, 0]}],
		"doors": [[[1, 0], [2, 0]]], "airlocks": [[[1, 0], [1, 0]], [[0, 0], [0, -1]]]})
	var errors := bad.validate()
	check(errors.size() == 1 and "nach draußen" in errors[0], "Schleuse in einen Nachbarraum nicht erkannt: %s" % errors)


func test_enemy_layout_is_valid() -> void:
	var layout := ShipLayout.load_json(ENEMY_PATH)
	var errors := layout.validate()
	check(errors.is_empty(), "Layout-Fehler: %s" % ", ".join(errors))


func test_start_power_fits_reactor() -> void:
	var state := ShipState.new(_layout())
	check(state.reactor_output() == 8, "Reaktor sollte 8 liefern, liefert %d" % state.reactor_output())
	check(state.level("sensoren") == 1, "Sensoren sollten am Start 1 Balken haben (Räume des Gegners sehen)")
	check(state.power_used() == 8, "Startverteilung sollte den Reaktor ausschöpfen, belegt %d" % state.power_used())
	check(state.level("antrieb") == 1, "Antrieb sollte am Start 1 Balken haben (Sprung braucht Energie)")
	check(state.weapons[0].powered and state.weapons[1].powered, "Beide Waffen sollten Energie haben")
	check(state.shield_layers == 1, "Eine Schildschicht erwartet")


func test_power_is_limited() -> void:
	var state := ShipState.new(_layout())
	check(not state.add_power("antrieb"), "Mehr Energie verteilt, als der Reaktor hat")
	check(state.remove_power("schilde"), "Schilde ließen sich nicht herunterfahren")
	check(state.add_power("medbay"), "Freie Energie nicht nutzbar")
	check(not state.add_power("medbay"), "Mehr Energie als Stufen im System")
	check(state.power_free() == 0, "Rechnung stimmt nicht")


func test_weapon_power_toggles_weapons() -> void:
	var state := ShipState.new(_layout())
	check(state.remove_power("waffen"), "Waffe ließ sich nicht abschalten")
	check(state.weapons[0].powered and not state.weapons[1].powered, "Falsche Waffe abgeschaltet")
	check(state.power_free() == 2, "Schwerer Laser sollte 2 Energie freigeben")
	check(state.set_weapon_wanted(1, true), "Waffe ließ sich nicht wieder einschalten")


func test_damage_cuts_power_and_repair_restores_it() -> void:
	var state := ShipState.new(_layout())
	state.fire_chance = 0.0
	state.breach_chance = 0.0
	var schilde := state.layout.room_index_by_id("schilde")
	check(state.take_hit(schilde, 1) == 1, "Systemschaden fehlt")
	check(state.get_system("schilde").power == 1, "Beschädigtes System behält volle Energie")
	check(state.shield_layers == 0, "Schild hält trotz Schaden")
	check(state.hull == state.max_hull - 1, "Hüllenschaden fehlt")
	var member := state.add_crew("Technik", "mensch", Vector2i(6, 0))
	_settle(state, 6.0)
	check(state.get_system("schilde").damage == 0, "Crew im Raum repariert nicht")
	check(state.get_system("schilde").power == 2, "Energie kehrt nach der Reparatur nicht zurück")
	check(member != null, "")


func test_reactor_damage_lowers_output() -> void:
	var state := ShipState.new(_layout())
	state.take_hit(state.layout.room_index_by_id("reaktor"), 2)
	check(state.reactor_output() == 6, "Reaktorschaden senkt die Leistung nicht")
	check(state.power_used() <= 6, "Systeme verbrauchen mehr als der Reaktor liefert")
	check(state.level("lebenserhaltung") == 1 and state.level("schilde") == 2, "Wichtige Systeme zuerst versorgen")


func test_shields_recharge() -> void:
	var state := ShipState.new(_layout())
	state.shield_layers = 0
	_settle(state, 2.0)
	check(state.shield_layers == 0, "Schildwand steht zu schnell wieder (unter 2,6 s)")
	_settle(state, 1.1)
	check(state.shield_layers == 1, "Schild lädt nicht nach")


func test_half_shield_pair_gives_no_layer() -> void:
	var state := _quiet_state()
	state.remove_power("schilde")
	check(state.get_system("schilde").power == 1 and state.max_shield_layers() == 0, "Ein Balken allein ergibt eine Schicht")
	state.add_power("schilde")
	state.take_hit(state.layout.room_index_by_id("schilde"), 1)
	check(state.max_shield_layers() == 0, "Beschädigter Partnerbalken: Schicht hält trotzdem")


func test_evasion_needs_pilot() -> void:
	var state := ShipState.new(_layout())
	state.remove_power("waffen")
	state.add_power("antrieb")
	check(state.evasion() == 0.0, "Ausweichen ohne Pilot")
	state.add_crew("Pilot", "mensch", Vector2i(10, 3))
	check(state.evasion() > 0.0, "Kein Ausweichen mit Pilot und Antrieb")


func test_weapons_fire_and_damage_enemy() -> void:
	var battle := Battle.new(ShipState.new(_layout()), _enemy_ship(), 42)
	var target := battle.enemy.layout.room_index_by_id("waffen")
	battle.set_all_targets(target)
	var seen := {}
	for i in 400:  # 40 s
		battle.update(0.1)
		for e in battle.take_events():
			seen[e.type] = true
	check(seen.has("fire"), "Keine Schüsse")
	check(seen.has("shield"), "Schild des Gegners hat nichts abgefangen")
	check(battle.enemy.hull < battle.enemy.max_hull, "Gegner hat keinen Schaden")


func test_no_target_no_fire() -> void:
	var battle := Battle.new(ShipState.new(_layout()), _enemy_ship(), 1)
	for i in 150:
		battle.update(0.1)
	for p in battle.projectiles:
		check(not p.player, "Spieler feuert ohne Ziel")
	check(battle.enemy.hull == battle.enemy.max_hull, "Gegner beschädigt ohne Ziel")


func test_battle_ends_in_victory() -> void:
	var player := ShipState.new(_layout())
	player.add_crew("Mara", "mensch", Vector2i(7, 7), {"waffen": 3.0})
	var battle := Battle.new(player, _enemy_ship(), 7)
	battle.enemy.hull = 4  # prüft das Kampfende, nicht die Balance
	while battle.enemy.remove_power("waffen"):
		pass
	battle.set_all_targets(battle.enemy.layout.room_index_by_id("schilde"))
	for i in 3000:
		battle.update(0.1)
		if battle.outcome != "":
			break
	check(battle.outcome == "sieg", "Kampf endet nicht mit Sieg, sondern '%s'" % battle.outcome)


func test_enemy_crew_repairs() -> void:
	var battle := Battle.new(ShipState.new(_layout()), _enemy_ship(), 3)
	var antrieb := battle.enemy.layout.room_index_by_id("antrieb")
	battle.enemy.take_hit(antrieb, 1)
	for i in 150:
		battle.update(0.1)
	check(battle.enemy.get_system("antrieb").damage == 0, "Gegner-Crew repariert nicht")


func _lone_flee_battle() -> Battle:
	var battle := _flee_battle()
	battle.enemy_fleeing = true
	battle._flee_decided = true
	while battle.enemy.crew.size() > 1:
		battle.enemy.crew.pop_back()
	for w in battle.player.weapons:
		w.powered = false
	return battle


func test_lone_fleeing_enemy_repairs_engine() -> void:
	# Nur noch ein Crewmitglied auf der Flucht: Antrieb reparieren, nicht im Cockpit pendeln.
	var battle := _lone_flee_battle()
	battle.enemy.take_hit(battle.enemy.layout.room_index_by_id("antrieb"), 1)
	battle.enemy.hull = 1
	for i in 300:
		battle.update(0.1)
		if battle.outcome != "":
			break
	check(battle.enemy.get_system("antrieb").damage == 0, "Einzelner Gegner repariert den Antrieb auf der Flucht nicht")


func test_lone_fleeing_enemy_ignores_weapons() -> void:
	# Waffenschaden hält die Flucht nicht auf: Die Person bleibt im Cockpit und springt.
	var battle := _lone_flee_battle()
	battle.enemy.take_hit(battle.enemy.layout.room_index_by_id("waffen"), 1)
	battle.enemy.hull = 1
	for i in 900:
		battle.update(0.1)
		if battle.outcome != "":
			break
	check(battle.outcome == "gegner_entkommen", "Einzelner Gegner flieht nicht trotz Waffenschaden ('%s')" % battle.outcome)
	check(battle.enemy.get_system("waffen").damage > 0, "Einzelner Gegner repariert auf der Flucht die Waffen")


# --- Waffenziele, Sauerstoff, Feuer, Crew-Gesundheit, Türen ---

func _quiet_state() -> ShipState:
	var state := ShipState.new(_layout())
	state.fire_chance = 0.0
	state.breach_chance = 0.0
	return state


func test_weapons_have_independent_targets() -> void:
	var battle := Battle.new(ShipState.new(_layout()), _enemy_ship(), 5)
	var schilde := battle.enemy.layout.room_index_by_id("schilde")
	var waffen := battle.enemy.layout.room_index_by_id("waffen")
	while battle.enemy.remove_power("waffen"):
		pass  # Gegner feuert nicht, damit keine eigene Waffe ausfällt
	battle.set_weapon_target(0, schilde)
	battle.set_weapon_target(1, waffen)
	var rooms_by_weapon := {}
	for i in 150:
		battle.update(0.1)
		for p in battle.projectiles:
			if p.player:
				rooms_by_weapon[p.weapon] = p.room
	check(rooms_by_weapon.get(0, -1) == schilde, "Waffe 1 schießt nicht auf die Schilde")
	check(rooms_by_weapon.get(1, -1) == waffen, "Waffe 2 schießt nicht auf die Waffen")


func test_weapon_without_target_holds_fire() -> void:
	var battle := Battle.new(ShipState.new(_layout()), _enemy_ship(), 5)
	battle.set_weapon_target(1, battle.enemy.layout.room_index_by_id("waffen"))
	for i in 150:
		battle.update(0.1)
		for p in battle.projectiles:
			check(not p.player or p.weapon == 1, "Waffe ohne Ziel feuert")
	check(battle.player.weapons[0].is_ready(), "Waffe ohne Ziel sollte geladen warten")


func test_airlock_vents_room_and_life_support_refills() -> void:
	var state := _quiet_state()
	var room := state.layout.room_index_at(state.layout.airlocks[0].tile)
	state.toggle_airlock(0)
	_settle(state, 3.0)
	check(state.oxygen[room] < 0.05, "Offene Schleuse lässt keinen Sauerstoff ab: %.2f" % state.oxygen[room])
	state.toggle_airlock(0)
	_settle(state, 10.0)
	check(state.oxygen[room] > 0.3, "Lebenserhaltung füllt nicht nach")


func test_doors_control_airflow() -> void:
	var state := _quiet_state()
	state.remove_power("lebenserhaltung")
	var vented := state.layout.room_index_at(state.layout.airlocks[0].tile)  # Erweiterung 1
	var neighbor := state.layout.room_index_by_id("antrieb")
	state.toggle_airlock(0)
	_settle(state, 3.0)
	check(state.oxygen[neighbor] > 0.99, "Geschlossene Tür lässt Luft durch")
	check(state.toggle_door(Vector2i(1, 1), Vector2i(2, 1)), "Tür lässt sich nicht öffnen")
	_settle(state, 4.0)
	check(state.oxygen[neighbor] < 0.3, "Offene Tür gleicht nicht aus: %.2f" % state.oxygen[neighbor])
	check(state.oxygen[vented] < 0.3, "")


func test_fire_dies_without_oxygen() -> void:
	var state := _quiet_state()
	var tile: Vector2i = state.layout.airlocks[0].tile
	state.start_fire(tile)
	state.toggle_airlock(0)
	_settle(state, 6.0)
	check(state.fires.is_empty(), "Feuer brennt ohne Sauerstoff weiter")


func test_fire_damages_system_and_crew_extinguishes() -> void:
	var state := _quiet_state()
	var schilde := state.layout.room_index_by_id("schilde")
	state.start_fire(Vector2i(6, 1))
	_settle(state, 13.0)
	check(state.get_system("schilde").damage > 0, "Feuer beschädigt das System nicht")
	var member := state.add_crew("Löscher", "mensch", Vector2i(6, 0))
	_settle(state, 20.0)
	check(state.fires_in_room(schilde).is_empty(), "Crew löscht das Feuer nicht")
	check(member.hp < CrewMember.MAX_HP, "Feuer verletzt die Crew nicht")


func test_fire_spreads_only_through_open_doors() -> void:
	var state := _quiet_state()
	state.start_fire(Vector2i(0, 0))
	state.start_fire(Vector2i(1, 0))
	state.start_fire(Vector2i(0, 1))
	state.start_fire(Vector2i(1, 1))
	_settle(state, 60.0)
	for t: Vector2i in state.fires:
		check(state.layout.room_index_at(t) == state.layout.room_index_by_id("antrieb"), "Feuer springt durch eine geschlossene Tür")


func test_breach_leaks_until_repaired() -> void:
	var state := _quiet_state()
	var medbay := state.layout.room_index_by_id("medbay")
	state.start_breach(Vector2i(2, 6))
	_settle(state, 3.0)
	check(state.oxygen[medbay] < 0.8, "Hüllenbruch lässt keine Luft entweichen")
	state.add_crew("Flicker", "mensch", Vector2i(3, 7))
	_settle(state, 6.0)
	check(state.breaches.is_empty(), "Crew flickt den Hüllenbruch nicht")


func test_suffocation_kills_and_reports() -> void:
	var state := _quiet_state()
	var member := state.add_crew("Pech", "mensch", Vector2i(3, 1))
	state.toggle_airlock(0)
	var died := false
	for i in 300:
		state.update(0.1)
		for e in state.events:
			if e.type == "crew_died":
				died = true
		state.events.clear()
	check(died and not state.crew.has(member), "Crew erstickt nicht")
	check(state.is_crew_dead(), "Ganze Crew tot wird nicht erkannt")


func test_medbay_heals() -> void:
	var state := _quiet_state()
	state.remove_power("waffen")
	check(state.add_power("medbay"), "Medbay bekommt keine Energie")
	var member := state.add_crew("Patient", "mensch", Vector2i(2, 7))
	member.hp = 40.0
	_settle(state, 5.0)
	check(member.hp > 60.0, "Medbay heilt nicht")


func test_hit_hurts_crew_in_room() -> void:
	var state := _quiet_state()
	var member := state.add_crew("Pech", "mensch", Vector2i(6, 6))
	state.take_hit(state.layout.room_index_by_id("waffen"), 2)
	check(member.hp == CrewMember.MAX_HP - 2 * ShipState.HP_PER_HIT, "Treffer verletzt Crew im Raum nicht")


func test_enemy_crew_wipe_is_victory() -> void:
	var battle := Battle.new(ShipState.new(_layout()), _enemy_ship(), 9)
	battle.player.add_crew("Mara", "mensch", Vector2i(10, 3))
	for i in range(battle.enemy.airlock_open.size()):
		battle.enemy.toggle_airlock(i)
	for pair: Array in battle.enemy.layout.door_list():
		battle.enemy.set_door_open(pair[0], pair[1], true)
	for i in 600:
		battle.update(0.1)
		if battle.outcome != "":
			break
	check(battle.outcome == "sieg", "Erstickte Gegner-Crew beendet den Kampf nicht: '%s'" % battle.outcome)


func test_crew_shows_activity() -> void:
	var state := _quiet_state()
	var member := state.add_crew("Löscher", "mensch", Vector2i(7, 0))  # Schildkonsole
	state.start_fire(Vector2i(6, 0))
	state.update(0.1)
	check(member.activity == "loeschen" and member.activity_tile == Vector2i(6, 0), "Löschen nicht als Tätigkeit sichtbar")
	check(member.facing == Vector2i.LEFT, "Figur schaut nicht zum Feuer")
	state.fires.clear()
	state.take_hit(state.layout.room_index_by_id("schilde"), 1)
	state.update(0.1)
	check(member.activity == "reparieren", "Reparieren nicht als Tätigkeit sichtbar: '%s'" % member.activity)


func test_jump_needs_engine_and_pilot() -> void:
	var state := _quiet_state()
	_settle(state, 5.0)
	check(state.jump_charge == 0.0, "Sprung lädt ohne Antrieb")
	state.remove_power("waffen")
	state.add_power("antrieb")
	_settle(state, 5.0)
	check(state.jump_charge == 0.0, "Sprung lädt ohne Pilot")
	state.add_crew("Pilot", "mensch", Vector2i(10, 3))
	_settle(state, 10.0)
	check(state.jump_charge > 0.0 and not state.jump_ready(), "Sprung lädt nicht oder ist zu schnell fertig")
	_settle(state, 40.0)
	check(state.jump_ready(), "Sprung nach 50 s mit 2 Balken Antrieb nicht bereit")


func test_jump_ends_battle() -> void:
	var player := ShipState.new(_layout())
	player.add_crew("Pilot", "mensch", Vector2i(10, 3))
	var battle := Battle.new(player, _enemy_ship(), 4)
	check(not battle.player_jump(), "Sprung ohne Ladung möglich")
	player.jump_charge = 1.0
	while player.remove_power("antrieb"):
		pass
	check(not battle.player_jump(), "Sprung ohne Energie im Antrieb möglich")
	player.add_power("antrieb")
	check(battle.player_jump() and battle.outcome == "entkommen", "Geladener Sprung beendet den Kampf nicht")


func test_heavy_enemy_layout_is_valid() -> void:
	var layout := ShipLayout.load_json("res://data/ships/piraten_kutter_schwer.json")
	check(layout.validate().is_empty(), "Schwerer Kutter: Layout-Fehler")
	var ship := ShipState.new(layout)
	check(ship.max_shield_layers() == 1, "Schwerer Kutter: eine Schildschicht (zwei sind mit 6 Reaktorbalken kaum zu knacken)")
	check(ship.weapons.size() == 3 and ship.weapons.all(func(w: Weapon) -> bool: return w.powered), "Schwerer Kutter: drei Waffen mit Energie")


# --- Sternenkarte und Run ---


func test_star_map_is_connected_and_planar() -> void:
	for seed_value in range(1, 60):
		var map := StarMap.generate(seed_value)
		var count := map.nodes.size()
		check(count >= StarMap.MIN_NODES and count <= StarMap.MAX_NODES, "Seed %d: %d Systeme" % [seed_value, count])
		check(map.node(map.start_id()).type == "start" and map.node(map.boss_id()).type == "boss", "Seed %d: Start oder Boss fehlt" % seed_value)
		var steps := map.distance(map.start_id(), map.boss_id())
		check(steps >= StarMap.MIN_PATH and steps <= StarMap.MAX_PATH, "Seed %d: kürzester Weg %d Sprünge" % [seed_value, steps])
		for n in map.nodes:
			check(map.distance(map.start_id(), n.id) >= 0, "Seed %d: Knoten %d unerreichbar" % [seed_value, n.id])
			check(not n.links.has(n.id), "Seed %d: Knoten %d mit sich selbst verbunden" % [seed_value, n.id])
			for to: int in n.links:
				check(map.node(to).links.has(n.id), "Seed %d: Verbindung %d→%d nur in eine Richtung" % [seed_value, n.id, to])
		# Verbindungen kreuzen sich nicht
		var segs := []
		for n in map.nodes:
			for to: int in n.links:
				if to > n.id:
					segs.append([n.id, to])
		for i in segs.size():
			for j in range(i + 1, segs.size()):
				var p: Array = segs[i]
				var q: Array = segs[j]
				if p[0] in q or p[1] in q:
					continue
				var hit: Variant = Geometry2D.segment_intersects_segment(map.node(p[0]).pos, map.node(p[1]).pos, map.node(q[0]).pos, map.node(q[1]).pos)
				check(hit == null, "Seed %d: Verbindungen %s und %s kreuzen sich" % [seed_value, p, q])


func test_star_maps_differ() -> void:
	var a := StarMap.generate(11)
	var b := StarMap.generate(12)
	var same := a.nodes.size() == b.nodes.size()
	if same:
		for i in a.nodes.size():
			same = same and a.nodes[i].pos.is_equal_approx(b.nodes[i].pos)
	check(not same, "Zwei Seeds ergeben dieselbe Karte")
	var run := RunState.new(5)
	var first := run.map.nodes.duplicate(true)
	run.next_sector()
	check(run.map.nodes != first, "Nächster Sektor hat dieselbe Karte")


func test_star_map_is_deterministic() -> void:
	var a := StarMap.generate(1234)
	var b := StarMap.generate(1234)
	check(a.nodes.size() == b.nodes.size(), "Gleicher Seed, andere Knotenzahl")
	for i in a.nodes.size():
		check(a.nodes[i].pos == b.nodes[i].pos and a.nodes[i].type == b.nodes[i].type and a.nodes[i].links == b.nodes[i].links,
			"Gleicher Seed, anderer Knoten %d" % i)


## Ein Knoten, der nicht mit `id` verbunden ist.
func _unlinked(run: RunState, id: int) -> int:
	for n in run.map.nodes:
		if n.id != id and not run.map.node(id).links.has(n.id):
			return n.id
	return -1


func test_run_jumps_only_along_links_and_back() -> void:
	var run := RunState.new(77)
	run.front = -5.0  # Jäger aus dem Spiel lassen
	var start := run.current
	var linked: int = run.node().links[0]
	run.map.node(linked).type = "leer"
	check(not run.jump_to(_unlinked(run, start)), "Sprung zu einem nicht verbundenen System möglich")
	check(run.jump_to(linked) and run.current == linked and run.jumps_done() == 1, "Sprung zum verbundenen Knoten klappt nicht")
	check(run.can_jump_to(start) and run.jump_to(start) and run.jumps_done() == 2, "Zurückspringen geht nicht")
	check(run.dialog.is_empty() and not run.needs_battle(), "Besuchtes System löst erneut etwas aus")
	run.map.node(linked).type = "kampf"
	run.visited.erase(linked)
	run.jump_to(linked)
	if run.needs_battle():
		check(not run.jump_to(start), "Weiterspringen trotz wartendem Gegner")
		run.finish_battle("sieg")
		check(run.jump_to(start), "Nach dem Sieg geht es nicht weiter")


func test_hull_and_dead_crew_persist_across_jumps() -> void:
	var run := RunState.new(5)
	var ship := run.ship
	var shields := ship.layout.room_index_by_id("schilde")
	ship.take_hit(shields, 2)
	ship.start_fire(Vector2i(6, 0))
	ship.start_breach(Vector2i(7, 1))
	ship.toggle_airlock(0)
	ship.crew[0].hp = 30.0
	var victim := ship.crew[2]
	ship._hurt(victim, 200.0)
	ship.jump_charge = 0.7
	var hull := ship.hull
	check(hull == ship.max_hull - 2, "Treffer hat die Hülle nicht beschädigt")
	var next: int = run.node().links[0]
	run.map.node(next).type = "kampf"  # leere Systeme flicken die Hülle
	run.jump_to(next)
	check(run.ship == ship, "Run hat ein neues Schiff gebaut")
	check(ship.hull == hull, "Hüllenschaden ist nach dem Sprung weg")
	check(ship.crew.size() == 2 and not ship.crew.has(victim), "Gefallene Crew ist wieder da")
	check(ship.jump_charge == 0.0, "Sprungantrieb bleibt geladen")


func test_nothing_repairs_itself_between_fights() -> void:
	var run := RunState.new(5)
	var ship := run.ship
	ship.take_hit(ship.layout.room_index_by_id("medbay"), 1)  # dort steht niemand
	ship.start_fire(Vector2i(6, 0))
	ship.start_breach(ship.layout.room_tiles(ship.layout.room_index_by_id("medbay"))[1])  # niemand dort
	ship.crew[0].hp = 30.0
	var damage := ship.get_system("medbay").damage
	check(damage > 0, "Treffer hat die Medbay nicht beschädigt")
	var next: int = run.node().links[0]
	run.map.node(next).type = "kampf"
	run.jump_to(next)
	check(ship.get_system("medbay").damage == damage, "Systemschaden repariert sich beim Sprung von selbst")
	check(not ship.breaches.is_empty(), "Leck verschwindet beim Sprung")
	check(ship.crew[0].hp == 30.0, "Crew heilt beim Sprung von selbst")
	run.finish_battle("sieg")
	check(ship.get_system("medbay").damage == damage, "Systemschaden repariert sich nach dem Sieg von selbst")
	# Nachbereitung: Wer im Raum steht, repariert, solange Zeit läuft
	var medbay := ship.layout.room_index_by_id("medbay")
	ship.order_move(ship.crew[1], medbay)
	for i in 300:
		ship.update(0.1)
	check(ship.get_system("medbay").damage == 0, "Crew repariert in der Nachbereitung nicht")


func test_energy_setting_survives_jump() -> void:
	var run := RunState.new(5)
	var ship := run.ship
	ship.remove_power("waffen")
	ship.add_power("antrieb")
	var engine := ship.get_system("antrieb").power
	ship.end_combat()
	check(ship.get_system("antrieb").power == engine and engine > 0, "Energieverteilung geht beim Sprung verloren")


func test_enemy_stages_follow_progress() -> void:
	var run := RunState.new(9)
	for n in run.map.nodes:
		if n.column <= 3 and n.type != "start":
			var spec := run.enemy_spec(n.id)
			check((spec.ship.ends_with("piraten_kutter.json") or spec.ship.ends_with("pluenderer.json")) and spec.hull_bonus == 0, "Vorne auf der Karte nur Kutter und Plünderer")
	var boss := run.create_enemy(run.map.boss_id())
	check(boss.layout.display_name == "Piraten-Flaggschiff", "Boss heißt nicht Piraten-Flaggschiff")
	check(boss.max_hull == 24 and boss.hull == 24, "Boss hat nicht 18 + 6 Hülle: %d" % boss.max_hull)
	check(boss.crew.size() == 3, "Boss ohne Besatzung")
	var some: int = run.map.nodes[run.map.nodes.size() / 2].id
	check(run.enemy_spec(some) == run.enemy_spec(some), "Gegner am Knoten ist nicht fest")
	run.sector = 2
	check(run.create_enemy(run.map.boss_id()).max_hull == 28, "Boss wird im zweiten Sektor nicht stärker")


func test_defeat_ends_run_and_boss_leads_to_next_sector() -> void:
	var run := RunState.new(3)
	run.jump_to(run.node().links[0])
	run.pending_battle[run.current] = {}
	run.finish_battle("niederlage")
	check(run.result == "verloren", "Niederlage beendet den Run nicht")
	check(not run.can_jump_to(run.node().links[0]), "Nach der Niederlage geht es weiter")
	run = RunState.new(3)
	run.current = run.map.boss_id()
	check(run.needs_battle() and run.is_boss_battle(), "Boss wartet nicht")
	run.finish_battle("entkommen")
	check(run.fleeing and not run.needs_battle() and run.can_jump_to(run.node().links[0]), "Nach der Flucht geht der Sprung nicht")
	run.fleeing = false  # wie nach Weg- und Zurückspringen
	check(run.needs_battle() and run.result == "", "Nach der Flucht vor dem Boss ist der Boss weg")
	var fuel := run.fuel
	run.finish_battle("sieg")
	check(run.sector_cleared and run.result == "" and run.fuel > fuel, "Boss-Sieg führt nicht in den nächsten Sektor oder bringt keinen Treibstoff")
	check(not run.needs_battle() and not run.can_jump_to(run.node().links[0]), "Nach dem Boss geht es auf der alten Karte weiter")
	run.next_sector()
	check(run.sector == 2 and run.current == run.map.start_id() and run.jumps_done() == 0 and not run.sector_cleared, "Nächster Sektor beginnt nicht am Start")
	check(run.front == RunState.FRONT_START, "Jägerfront beginnt nicht von vorn")
	run.sector = RunState.HUNT_SECTORS
	run.current = run.map.boss_id()
	run.finish_battle("sieg")
	check(run.result == "geschafft", "Sieg über den letzten Boss beendet den Run nicht")


func test_hunter_front_advances_and_attacks() -> void:
	var run := RunState.new(21)
	run.fuel = 50
	var start := run.current
	var next: int = run.node().links[0]
	run.map.node(next).type = "leer"
	run.jump_to(next)
	check(is_equal_approx(run.front, RunState.FRONT_START + RunState.FRONT_STEP), "Front rückt nicht vor")
	check(not run.needs_battle(), "Leeres System vor der Front löst einen Kampf aus")
	# Hin und her springen, bis die Front die Systeme erreicht
	var guard := 0
	while not run.is_overrun(start) and guard < 20:
		run.jump_to(start if run.current != start else next)
		if run.needs_battle():
			run.finish_battle("sieg")
		guard += 1
	check(run.is_overrun(start), "Front erreicht den Start nie")
	var target := start if run.current != start else next
	if run.current == start:
		run.front += 1.0  # beide Systeme sicher hinter der Front
	run.jump_to(target)
	check(run.hunter_battle and run.needs_battle(), "Hinter der Front greifen die Jäger nicht an")
	check(run.create_enemy().layout.display_name == "Jäger-Fregatte", "Gegner hinter der Front ist nicht die Jäger-Fregatte")
	var scrap := run.scrap
	run.finish_battle("sieg")
	check(not run.hunter_battle and not run.needs_battle() and run.scrap > scrap, "Sieg über die Jäger bringt keine Beute oder endet nicht")
	check(run.jumps_until_overrun(run.map.boss_id()) == 0 or run.jumps_until_overrun(run.map.boss_id()) > 0, "Vorwarnung für die Front fehlt")
	var fresh := RunState.new(21)
	var hits := 0
	for k in RunState.HUNT_JUMPS:
		if fresh.is_overrun(fresh.map.boss_id(), RunState.FRONT_START + k * RunState.FRONT_STEP):
			hits += 1
	check(hits == 0, "Front erreicht den Boss vor %d Sprüngen" % RunState.HUNT_JUMPS)
	check(fresh.is_overrun(fresh.map.boss_id(), RunState.FRONT_START + (RunState.HUNT_JUMPS + 1) * RunState.FRONT_STEP), "Front erreicht den Boss nach 11 Sprüngen nicht")


func test_endless_mode_has_exit_and_no_front() -> void:
	var run := RunState.new(31, RunState.MODE_ENDLESS)
	check(run.map.count_type("boss") == 0 and run.map.node(run.map.exit_id()).type == "ausgang", "Endlos-Karte ohne Ausgang oder mit Boss")
	run.front = 5.0
	check(not run.is_overrun(run.map.exit_id()), "Front im Endlos-Modus")
	# Direkt neben den Ausgang stellen und hineinspringen
	var exit_id := run.map.exit_id()
	run.current = run.map.node(exit_id).links[0]
	run.map.node(run.current).type = "leer"
	run.fuel = 5
	check(run.jump_to(exit_id), "Sprung zum Ausgang nicht möglich")
	# Erst ankommen, dann mit eigenem Sprung in den nächsten Sektor
	check(run.sector == 1 and run.current == exit_id and run.sector_cleared, "Am Ausgang nicht angekommen oder Sektor nicht geschafft")
	check(not run.can_jump_to(run.node().links[0]), "Am geschafften Ausgang noch Sprünge auf der alten Karte möglich")
	# Auch dieser Sprung kostet Treibstoff; ohne Treibstoff hilft das Notsignal
	run.fuel = 0
	check(not run.leave_sector() and run.sector == 1, "Sektorsprung ohne Treibstoff möglich")
	check(run.can_send_distress(), "Am Ausgang ohne Treibstoff kein Notsignal")
	run.fuel = 2
	check(run.leave_sector(), "Sektorsprung mit Treibstoff nicht möglich")
	check(run.fuel == 1, "Sektorsprung kostet keinen Treibstoff")
	check(run.sector == 2 and run.current == run.map.start_id() and run.score() == 2 and not run.sector_cleared, "Sprung führt nicht in Sektor 2")


func test_hits_damage_systems_only_by_chance() -> void:
	var ship := _quiet_state()
	var room := ship.layout.room_index_by_id("waffen")
	var laser := Weapon.create("pulslaser")
	var heavy := Weapon.create("schwerer_laser")
	check(laser.system_chance < heavy.system_chance, "Schwerlaser trifft Systeme nicht häufiger als der Pulslaser")
	var damaged := 0
	for i in 200:
		ship.systems["waffen"].damage = 0
		ship.hull = ship.max_hull
		if ship.take_hit(room, 1, laser) > 0:
			damaged += 1
	check(ship.hull == ship.max_hull - 1, "Treffer kostet keine Hülle")
	check(damaged > 30 and damaged < 100, "Pulslaser beschädigt das System %d von 200 Mal (erwartet etwa 60)" % damaged)


func test_species_change_crew() -> void:
	var ship := _quiet_state()
	var human := ship.add_crew("Mensch", "mensch", Vector2i(6, 6))
	var rock := ship.add_crew("Stein", "petrani", Vector2i(6, 7))
	var bot := ship.add_crew("Bot", "androide", Vector2i(8, 1))
	check(rock.max_hp == 140.0 and rock.hp == 140.0 and rock.speed < human.speed, "Petrani-Werte fehlen")
	check(bot.repair_factor() > human.repair_factor() and not bot.breathes(), "Androiden-Werte fehlen")
	check(CrewMember.new("X", "gibtsnicht", Vector2i.ZERO).species == "mensch", "Unbekannte Spezies wird nicht zum Menschen")
	# Feuer und Luft
	var room := ship.layout.room_index_at(rock.tile)
	ship.oxygen[room] = 0.0
	for t in ship.layout.room_tiles(room):
		ship.fires[t] = 1.0
	ship._update_crew_health(1.0)
	check(rock.hp == 140.0, "Petrani nehmen Schaden durch Feuer oder Luftmangel")
	check(human.hp < CrewMember.MAX_HP, "Mensch nimmt keinen Schaden")
	check(Species.ids().size() == 6, "Nicht sechs Spezies")
	for id in Species.ids():
		check(not Species.traits(id).is_empty() and (Species.value(id, "names", []) as Array).size() >= 3, "%s ohne Texte oder Namen" % id)


func test_captain_is_marked() -> void:
	var run := RunState.new(4)
	var captains := run.ship.crew.filter(func(m: CrewMember) -> bool: return m.is_captain())
	check(captains.size() == 1 and captains[0].display_name == "Mara Voss", "Captain nicht markiert")
	check(run.ship.crew[1].best_system() == "waffen", "Bestes System falsch")


func test_drive_charges_faster_outside_combat() -> void:
	var run := RunState.new(4)
	var ship := run.ship
	check(not ship.in_combat, "Schiff startet im Kampfmodus")
	while ship.remove_power("antrieb"):
		pass
	for i in 30:
		ship.update(0.1)
	check(ship.jump_charge == 0.0, "Antrieb lädt ohne Energie")
	ship.add_power("antrieb")
	for i in 100:
		ship.update(0.1)
	check(ship.jump_charge >= 0.6, "Antrieb lädt außerhalb des Kampfs nicht (%.2f nach 10 s)" % ship.jump_charge)
	check(ship.weapons.all(func(w: Weapon) -> bool: return w.charge == 0.0), "Waffen laden außerhalb des Kampfs")
	var enemy := run.create_enemy(run.map.boss_id())
	Battle.new(ship, enemy, 1)
	check(ship.in_combat, "Kampf schaltet nicht in den Kampfmodus")
	run.finish_battle("entkommen")
	check(not ship.in_combat, "Nach dem Kampf bleibt der Kampfmodus")


## Run mit offenem Ereignis (ohne Sprung), für Ereignistests.
func _event_run(id: String) -> RunState:
	var run := RunState.new(5)
	run._open_event(id)
	return run


func test_stations_on_every_map() -> void:
	for s in range(1, 40):
		var run := RunState.new(s)
		var map := run.map
		check(map.count_type("haendler") == 2 and map.count_type("reparatur") == 1, "Seed %d: nicht 2 Händler und 1 Reparaturstation" % s)
		for n in map.nodes:
			if n.type == "ereignis":
				check(run.node_events.get(n.id, "") != "", "Seed %d: Ereignisknoten %d ohne Ereignis" % [s, n.id])


func test_events_are_valid() -> void:
	var book := EventBook.load_default()
	check(book.validate().is_empty(), "Ereignisfehler: %s" % ", ".join(book.validate()))
	check(book.ids_in_pool("ereignis").size() >= 10, "Zu wenige Ereignisse")
	check(book.ids_in_pool("notsignal").size() >= 2, "Zu wenige Notsignal-Ereignisse")


func test_jump_costs_fuel_and_distress_without_fuel() -> void:
	var run := RunState.new(21)
	var next: int = run.node().links[0]
	run.map.node(next).type = "leer"
	var fuel := run.fuel
	check(run.jump_to(next) and run.fuel == fuel - 1, "Sprung kostet keinen Treibstoff")
	run.fuel = 0
	check(not run.can_jump_to(run.node().links[0]), "Sprung ohne Treibstoff möglich")
	check(run.can_send_distress() and run.send_distress(), "Kein Notsignal ohne Treibstoff")
	check(not run.dialog.is_empty(), "Notsignal öffnet keinen Dialog")


func test_event_choice_applies_effects() -> void:
	var run := _event_run("wrack_frachter")
	check(run.dialog.choices.size() == 3, "Wrack: 3 Optionen erwartet")
	var fuel := run.fuel
	check(run.choose(1), "Option nicht wählbar")
	check(run.fuel == fuel + 2, "Tanks abzapfen bringt keine 2 Treibstoff")
	check(run.dialog.choices.size() == 1 and "+2 Treibstoff" in run.dialog.text, "Ergebnis zeigt den Effekt nicht")
	run.choose(0)
	check(run.dialog.is_empty() and not run.needs_battle(), "Ergebnis schließt nicht")


func test_event_costs_and_requirements() -> void:
	var run := _event_run("kolonie_reaktor")
	run.scrap = 3
	run._open_event("kolonie_reaktor")
	check(not run.dialog.choices[0].enabled and not run.choose(0), "Spende ohne genug Rohstoffe möglich")
	run.scrap = 12
	run._open_event("kolonie_reaktor")
	check(run.choose(0) and run.scrap == 2 and run.flags.has("kolonie_dank"), "Spende kostet nicht 10 oder setzt kein Ansehen")
	run = _event_run("notsignal_patrouille")
	check(run.dialog.choices.size() == 1, "Gildenoption sichtbar ohne Gildenbrief")
	run.flags["gilde_freund"] = true
	run._open_event("notsignal_patrouille")
	check(run.dialog.choices.size() == 2 and run.dialog.choices[0].special, "Gildenoption fehlt mit Gildenbrief")


func test_event_battle_and_victory_reward() -> void:
	var run := _event_run("piratenzoll")
	run.choose(1)  # Kämpfen
	check(not run.needs_battle(), "Kampf startet vor dem Weiter")
	run.choose(0)
	check(run.needs_battle(), "Ereignis löst keinen Kampf aus")
	var scrap := run.scrap
	run.finish_battle("sieg")
	check(not run.needs_battle() and run.scrap >= scrap + 4, "Siegbeute fehlt: %d -> %d" % [scrap, run.scrap])
	check(run.last_reward != "", "Beute nicht als Text")


func test_shop_prices_and_guild_discount() -> void:
	var run := RunState.new(8)
	run._open_shop()
	run.scrap = 20
	run.fuel = 1
	run._open_shop()
	check(not run.dialog.choices[1].enabled, "Hüllenreparatur bei voller Hülle möglich")
	check(run.choose(0) and run.fuel == 2 and run.scrap == 17, "Treibstoff kostet nicht 3 Rohstoffe")
	run.flags["gilde_freund"] = true
	run.ship.hull -= 10
	run._open_shop()
	check(run.choose(1) and run.scrap == 11 and run.ship.hull == run.ship.max_hull - 5, "Hülle +5 mit Rabatt kostet nicht 6")
	check(run.choose(2) and run.fuel == 1 and run.ship.hull == run.ship.max_hull - 2, "Hülle gegen Treibstoff klappt nicht")
	check(run.choose(run.dialog.choices.size() - 1) and run.dialog.is_empty(), "Ablegen schließt den Händler nicht")


func test_repair_station_goodwill() -> void:
	var run := RunState.new(8)
	run.ship.hull = 10
	run.scrap = 0
	run.flags["kolonie_dank"] = true
	run._open_repair()
	check(run.dialog.choices[0].special and run.dialog.choices[0].enabled, "Gratisreparatur der Kolonie fehlt")
	check(run.choose(0) and run.ship.hull == run.ship.max_hull, "Gratisreparatur repariert nicht komplett")
	check(not run.flags.has("kolonie_dank"), "Gratisreparatur lässt sich mehrfach nutzen")
	run.ship.hull = 20
	run.scrap = 15
	run._open_repair()
	check(run.choose(0) and run.scrap == 5 and run.ship.hull == run.ship.max_hull, "Komplettreparatur kostet nicht 1 je Punkt")


func test_repair_station_fixes_systems() -> void:
	var run := RunState.new(8)
	var ship := run.ship
	ship.take_hit(ship.layout.room_index_by_id("waffen"), 2)
	ship.fires.clear()
	ship.breaches.clear()
	ship.start_breach(Vector2i(7, 1))
	var count := run.ship_damage_count()
	check(count == ship.system_damage() + 1 and count >= 2, "Schäden falsch gezählt: %d" % count)
	ship.hull = ship.max_hull
	run.scrap = 20
	run._open_repair()
	check(run.dialog.choices[1].enabled and not run.dialog.choices[2].enabled, "Systemreparatur nicht wählbar oder Hüllenreparatur bei voller Hülle")
	check(run.choose(1) and run.scrap == 20 - count * 2, "Systemreparatur kostet nicht 2 je Schaden")
	check(run.ship_damage_count() == 0 and ship.breaches.is_empty(), "Station repariert Systeme oder Lecks nicht")


func test_crew_join_and_loss_from_events() -> void:
	var run := RunState.new(8)
	run._apply({"crew_add": 1})
	check(run.ship.crew.size() == 4, "Neue Crew kommt nicht an Bord")
	check(Species.known(run.ship.crew[3].species), "Neue Crew ohne gültige Spezies")
	var tiles := {}
	for m in run.ship.crew:
		tiles[m.tile] = true
	check(tiles.size() == 4, "Neue Crew steht auf einer besetzten Kachel")
	run._apply({"crew_lose": 1})
	check(run.ship.crew.size() == 3 and run.result == "", "Crew-Verlust klappt nicht")
	run._apply({"crew_lose": 3})
	check(run.result == "verloren", "Ohne Crew ist der Run nicht verloren")



func test_fire_keeps_burning_during_jump() -> void:
	var run := RunState.new(5)
	var ship := run.ship
	var room := ship.layout.room_index_by_id("medbay")  # dort steht niemand
	var tiles := ship.layout.room_tiles(room)
	ship.start_fire(tiles[0])
	ship.fires[tiles[0]] = 1.0
	for t in tiles:
		check(ship.crew.all(func(m: CrewMember) -> bool: return m.tile != t), "Testannahme: Medbay ist leer")
	var next: int = run.node().links[0]
	run.map.node(next).type = "kampf"
	run.jump_to(next)
	check(ship.fires.has(tiles[0]), "Feuer geht beim Sprung von selbst aus")
	check(ship.fires[tiles[0]] >= 1.0, "Feuer wird beim Sprung schwächer, obwohl niemand löscht")


# --- Spielstand ---


func _save_paths() -> void:
	SaveGame.path = "user://test_savegame.json"
	SaveGame.backup = "user://test_savegame.bak.json"
	SaveGame.clear()


func _played_run() -> RunState:
	var run := RunState.new(4242)
	var target: int = run.node().links[0]
	run.jump_to(target)
	run.fuel = 3
	run.scrap = 17
	run.flags["gilde_freund"] = true
	run.ship.hull -= 5
	run.ship.systems["schilde"].damage = 1
	run.ship.crew[0].hp = 40.0
	run.ship.crew[0].experience["waffen"] = 2.5
	run.ship.start_breach(run.ship.crew[1].tile)
	run.ship.oxygen[2] = 0.3
	run.cleared[target] = "sieg"
	return run


func test_save_and_load_round_trip() -> void:
	_save_paths()
	var run := _played_run()
	check(SaveGame.save(run), "Speichern fehlgeschlagen")
	var loaded := SaveGame.load_run()
	check(loaded != null, "Spielstand lädt nicht")
	if loaded == null:
		return
	check(loaded.current == run.current, "Position falsch")
	check(loaded.fuel == 3 and loaded.scrap == 17, "Ressourcen falsch")
	check(loaded.flags.has("gilde_freund"), "Ansehen fehlt")
	check(loaded.cleared.get(run.current, "") == "sieg", "Erledigte Systeme fehlen")
	check(loaded.ship.hull == run.ship.hull, "Hülle falsch")
	check(loaded.ship.systems["schilde"].damage == 1, "Systemschaden fehlt")
	check(loaded.ship.crew.size() == run.ship.crew.size(), "Crew-Zahl falsch")
	check(is_equal_approx(loaded.ship.crew[0].hp, 40.0), "Lebenspunkte falsch")
	check(loaded.ship.crew[0].level("waffen") == 2, "Erfahrung fehlt")
	check(loaded.ship.breaches.size() == 1, "Leck fehlt")
	check(is_equal_approx(loaded.ship.oxygen[2], 0.3), "Luft falsch")
	check(loaded.map.nodes.size() == run.map.nodes.size(), "Karte falsch")
	check(loaded.node().links == run.node().links, "Verbindungen falsch")
	check(loaded.enemy_spec(run.node().links[0]) == run.enemy_spec(run.node().links[0]), "Gegner geändert")
	# Zufall läuft gleich weiter
	check(loaded._rng.randi() == run._rng.randi(), "Zufallszustand nicht gespeichert")
	SaveGame.clear()


func test_save_keeps_open_dialog() -> void:
	_save_paths()
	var run := RunState.new(77)
	run._open_shop()
	SaveGame.save(run)
	var loaded := SaveGame.load_run()
	check(loaded != null and loaded.dialog.title == "Händler", "Dialog nicht gespeichert")
	check(loaded != null and loaded.choose(loaded.dialog.choices.size() - 1) and loaded.dialog.is_empty(), "Dialog nach Laden nicht bedienbar")
	SaveGame.clear()


func test_older_save_without_new_fields_loads() -> void:
	_save_paths()
	var data := SaveGame.to_dict(_played_run())
	# So könnte ein Stand aus einer älteren Version aussehen: Felder fehlen
	data.run.erase("flags")
	data.run.erase("rng")
	data.ship.erase("fires")
	data.ship.erase("doors")
	data.ship.systems["gibtsnicht"] = {"damage": 2}
	data.ship.weapons.append({"id": "alte_waffe", "wanted": true})
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(JSON.from_native(data)))
	f.close()
	var loaded := SaveGame.load_run()
	check(loaded != null, "Älterer Stand lädt nicht")
	check(loaded != null and loaded.flags.is_empty(), "Fehlende Felder nicht ersetzt")
	check(loaded != null and loaded.ship.weapons.size() == data.ship.weapons.size() - 1, "Unbekannte Waffe nicht übersprungen")
	SaveGame.clear()


func test_broken_or_newer_save_is_never_overwritten() -> void:
	_save_paths()
	var run := _played_run()
	SaveGame.save(run)
	SaveGame.save(run)  # jetzt gibt es auch eine Sicherung
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string("{kaputt")
	f.close()
	var loaded := SaveGame.load_run()
	check(loaded != null and loaded.scrap == 17, "Sicherung nicht als Rückfall genutzt")
	# Stand aus einem neueren Build: nicht laden, aber beiseitelegen statt löschen
	var data := SaveGame.to_dict(run)
	data.version = SaveGame.VERSION + 1
	f = FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(JSON.from_native(data)))
	f.close()
	DirAccess.remove_absolute(SaveGame.backup)
	check(SaveGame.load_run() == null, "Neuerer Stand wurde geladen")
	var kept := Array(DirAccess.get_files_at("user://")).filter(func(n: String) -> bool: return n.begins_with("savegame-"))
	check(kept.size() == 2, "Kaputter und neuerer Stand nicht beide beiseitegelegt (%d)" % kept.size())
	for n: String in kept:
		DirAccess.remove_absolute("user://" + n)
	SaveGame.clear()


func test_version_1_save_is_migrated() -> void:
	_save_paths()
	var run := _played_run()
	var data := SaveGame.to_dict(run)
	# So sah ein Stand der Version 1 aus: Spalten, Verbindungen nur nach rechts, kein Modus
	data.version = 1
	for key in ["mode", "sector", "jumps", "total_jumps", "front", "hunter_battle", "sector_cleared"]:
		data.run.erase(key)
	for n: Dictionary in data.run.map.nodes:
		n.column = 3
		n.links = n.links.filter(func(to: int) -> bool: return to > n.id)
	for c: Dictionary in data.ship.crew:
		c.erase("role")
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(JSON.from_native(data)))
	f.close()
	var loaded := SaveGame.load_run()
	check(loaded != null, "Stand der Version 1 lädt nicht")
	if loaded == null:
		return
	check(loaded.mode == RunState.MODE_HUNT and loaded.sector == 1 and loaded.jumps_done() == 3, "Modus, Sektor oder Sprünge nicht ergänzt")
	check(is_equal_approx(loaded.front, RunState.FRONT_START + 3 * RunState.FRONT_STEP), "Front nicht aus den Sprüngen berechnet")
	for n in loaded.map.nodes:
		for to: int in n.links:
			check(loaded.map.node(to).links.has(n.id), "Verbindungen nach der Migration nur in eine Richtung")
	check(loaded.ship.crew[0].is_captain(), "Captain nach der Migration nicht markiert")
	SaveGame.clear()


func test_each_mode_has_its_own_slot() -> void:
	_save_paths()
	var hunt := _played_run()
	var endless := RunState.new(99, RunState.MODE_ENDLESS)
	endless.scrap = 55
	check(SaveGame.save(hunt) and SaveGame.save(endless), "Speichern fehlgeschlagen")
	var a := SaveGame.load_run(RunState.MODE_HUNT)
	var b := SaveGame.load_run(RunState.MODE_ENDLESS)
	check(a != null and a.mode == RunState.MODE_HUNT and a.scrap == 17, "Jagd-Slot falsch")
	check(b != null and b.mode == RunState.MODE_ENDLESS and b.scrap == 55, "Endlos-Slot falsch")
	check(SaveGame.summary(RunState.MODE_ENDLESS).get("sector", 0) == 1, "Kurzbeschreibung fehlt")
	SaveGame.clear(RunState.MODE_ENDLESS)
	check(not SaveGame.exists(RunState.MODE_ENDLESS) and SaveGame.exists(RunState.MODE_HUNT), "Löschen trifft den falschen Slot")
	SaveGame.clear()


func test_codex_lists_all_ships_and_species() -> void:
	var ships := Codex.ship_ids()
	check(ships.size() >= 4 and ships[0] == "mensch_frachter", "Lexikon: eigenes Schiff nicht zuerst oder Schiffe fehlen")
	check(Codex.species_ids()[0] == Species.DEFAULT and Codex.species_ids().size() == Species.ids().size(), "Lexikon: Spezies fehlen")
	check(Codex.is_known(Codex.KIND_SHIP, "mensch_frachter") and Codex.is_known(Codex.KIND_SPECIES, "mensch"), "Startereinträge nicht bekannt")
	check(not Codex.discover(Codex.KIND_SPECIES, "mensch"), "Bekannter Eintrag als neu gemeldet")
	for id in ships:
		check(str(Codex.ship(id).get("description", "")) != "", "Schiff ohne Beschreibung: %s" % id)
	for id in Codex.species_ids():
		check(str(Species.value(id, "lore", "")) != "", "Spezies ohne Beschreibung: %s" % id)


func test_settings_have_defaults() -> void:
	for key: String in Settings.DEFAULTS:
		check(typeof(Settings.get_value(key)) == typeof(Settings.DEFAULTS[key]), "Einstellung %s hat falschen Typ" % key)
	check(Settings.speed() > 0.0, "Spieltempo muss positiv sein")
	check(str(Settings.DEFAULTS["music_track"]) == "auto", "Musik steht anfangs auf Auto")


# --- Mehrsprachigkeit ---


func test_loc_german_returns_source_text() -> void:
	Loc.set_language("de")
	check(Loc.t("Händler") == "Händler", "Deutsch muss den Schlüssel selbst liefern")
	check(Loc.t("") == "", "Leerer Text bleibt leer")


func test_loc_english_translates_and_falls_back() -> void:
	Loc.set_language("en")
	check(Loc.t("Händler") == "Trader", "Händler nicht übersetzt: %s" % Loc.t("Händler"))
	check(Loc.t("Sektor %d") % 3 == "Sector 3", "Format nach Übersetzung falsch")
	check(Loc.t("Gibt es nicht 123") == "Gibt es nicht 123", "Fehlende Übersetzung muss den deutschen Text liefern")
	check(Species.display_name("androide") == "Android", "Speziesname nicht übersetzt")
	check(SystemInfo.display_name("schilde") == "Shields", "Systemname nicht übersetzt")
	Loc.set_language("de")


func test_loc_unknown_language_uses_system_language() -> void:
	Loc.set_language("xx")
	check(Loc.LANGUAGES.has(Loc.language()), "Unbekannte Sprache: %s" % Loc.language())
	Loc.set_language("de")


func test_loc_english_table_is_consistent() -> void:
	Loc.set_language("en")
	var table := Loc.table()
	check(table.size() > 300, "Englische Tabelle fehlt oder ist zu klein: %d" % table.size())
	var placeholder := RegEx.create_from_string("%[+\\-0-9.]*[dsf%]")
	for key: String in table:
		var a := placeholder.search_all(key).map(func(m: RegExMatch) -> String: return m.get_string())
		var b := placeholder.search_all(table[key]).map(func(m: RegExMatch) -> String: return m.get_string())
		a.sort()
		b.sort()
		check(a == b, "Platzhalter passen nicht: %s -> %s" % [key, table[key]])
	Loc.set_language("de")


func test_run_dialogs_follow_language() -> void:
	Loc.set_language("en")
	var run := RunState.new(7)
	run._open_shop()
	check(run.dialog.title == "Trader", "Händler-Dialog nicht übersetzt: %s" % run.dialog.title)
	check(run.dialog.choices.back().text == "Undock", "Ablegen nicht übersetzt")
	Loc.set_language("de")



# --- Schiffsausbau ---


func test_system_upgrade_costs_and_limits() -> void:
	var run := RunState.new(5)
	run.scrap = 1000
	var shields := run.ship.get_system("schilde")
	var first := run.system_upgrade_price("schilde")
	check(first == 25, "Erster Schildbalken kostet nicht 25, sondern %d" % first)
	check(run.upgrade_system("schilde") and shields.capacity == 3 and run.scrap == 975, "Schildausbau klappt nicht")
	check(run.system_upgrade_price("schilde") == 35, "Zweiter Balken kostet nicht base + step")
	while run.upgrade_system("schilde"):
		pass
	check(shields.capacity == 8 and run.system_upgrade_price("schilde") == -1, "Schilde gehen über das Maximum")
	check(run.system_upgrade_price("sensoren") == 15, "Sensoren nicht für 15 ausbaubar")
	var free := run.ship.power_free()
	check(run.upgrade_system("reaktor") and run.ship.power_free() == free + 1, "Reaktorausbau bringt keine Energie")
	run.scrap = 0
	check(not run.upgrade_system("antrieb"), "Ausbau ohne Rohstoffe möglich")


func test_no_refit_in_combat() -> void:
	var run := RunState.new(5)
	run.scrap = 1000
	var enemy := run.create_enemy(run.node().links[0])
	var _battle := Battle.new(run.ship, enemy)
	check(not run.can_refit() and not run.upgrade_system("antrieb") and not run.buy_perk("panzerung"), "Ausbau im Kampf möglich")
	run.ship.end_combat()
	check(run.upgrade_system("antrieb"), "Ausbau nach dem Kampf nicht möglich")


func test_perks() -> void:
	var run := RunState.new(5)
	run.scrap = 1000
	var hull := run.ship.max_hull
	check(run.buy_perk("panzerung") and run.ship.max_hull == hull + 6 and run.ship.hull == hull + 6, "Panzerung erhöht die Hülle nicht")
	check(not run.buy_perk("panzerung"), "Perk zweimal kaufbar")
	check(run.buy_perk("zielcomputer") and is_equal_approx(run.ship.perk_value("weapon_speed"), 0.15), "Zielcomputer wirkt nicht")
	check(run.buy_perk("brandschutz") and is_equal_approx(run.ship.fire_factor(), 0.5), "Brandschutz wirkt nicht")
	# Reparaturdrohne: Schaden ohne Crew im Raum wird langsam behoben
	var drone := RunState.new(5)
	drone.scrap = 100
	var sys := drone.ship.get_system("medbay")
	sys.damage = 1
	for i in 100:
		drone.ship.update(0.1)
	check(sys.damage == 1, "Ohne Drohne repariert sich die Medbay selbst")
	check(drone.buy_perk("reparaturdrohne"), "Drohne nicht kaufbar")
	for i in 200:
		drone.ship.update(0.1)
	check(sys.damage == 0, "Drohne repariert die Medbay nicht")


func test_salvage_and_fuel_recycler() -> void:
	var run := RunState.new(5)
	run.scrap = 1000
	run.buy_perk("bergungsgreifer")
	var loot := run._roll_loot({"scrap": [20, 20]})
	check(loot.scrap == 25, "Bergungsgreifer bringt nicht +25 %%: %d" % loot.scrap)
	run.buy_perk("treibstoffrecycler")
	run.fuel = 100
	var free := 0
	for i in 200:
		var before := run.fuel
		run._pay_jump()
		if run.fuel == before:
			free += 1
	check(free > 25 and free < 80, "Treibstoffrecycler spart nicht etwa jeden 4. Sprung: %d von 200" % free)


func test_weapon_slots_and_storage() -> void:
	var ship := RunState.create_player_ship()
	check(ship.weapon_slots() == 3, "Frachter hat nicht 3 Waffenplätze")
	check(ship.add_weapon("bordkanone") and ship.weapons.size() == 3, "Freier Platz wird nicht genutzt")
	check(ship.add_weapon("brandkanone") and ship.stored_weapons == ["brandkanone"], "Volle Plätze: Waffe nicht im Lager")
	check(ship.add_weapon("salvenlaser") and not ship.add_weapon("pulslaser"), "Lager hat nicht 2 Plätze")
	check(not ship.install_weapon(0), "Einbau ohne freien Platz möglich")
	check(ship.store_weapon(0) == false, "Lager voll, trotzdem ausgebaut")
	ship.remove_weapon_at(4)  # Salvenlaser aus dem Lager
	check(ship.store_weapon(0) and ship.weapons.size() == 2 and ship.stored_weapons.size() == 2, "Ausbau ins Lager klappt nicht")
	check(ship.install_weapon(0) and ship.weapons.back().id == "brandkanone", "Einbau aus dem Lager klappt nicht")


func test_shop_weapons_and_crew() -> void:
	var run := RunState.new(12)
	run.scrap = 500
	run._open_shop()
	check(run.is_shop_open(), "Händler nicht offen")
	var goods := run.shop_goods()
	check(goods.weapons.size() == 3, "Nicht 3 Waffen im Angebot: %d" % goods.weapons.size())
	var id: String = goods.weapons[0]
	var before := run.scrap
	check(run.shop_buy_weapon(0) != "" and run.scrap == before - Weapon.price_of(id) and run.ship.all_weapon_ids().has(id), "Waffenkauf klappt nicht")
	check(run.shop_goods().weapons.size() == 2, "Gekaufte Waffe bleibt im Angebot")
	var owned := run.ship.all_weapon_ids()
	before = run.scrap
	check(run.shop_sell_weapon(0) != "" and run.scrap == before + run.sell_price(owned[0]), "Verkauf bringt nicht den halben Preis")
	check(run.ship.all_weapon_ids().size() == owned.size() - 1, "Verkaufte Waffe noch an Bord")
	var crew_before := run.ship.crew.size()
	var hire: Dictionary = run.shop_goods().crew[0]
	check(run.shop_hire(0) != "" and run.ship.crew.size() == crew_before + 1, "Anheuern klappt nicht")
	check(run.ship.crew.back().display_name == hire.name and run.ship.crew.back().species == hire.species, "Falsche Person an Bord")
	run.close_shop()
	check(run.dialog.is_empty() and not run.is_shop_open(), "Ablegen klappt nicht")


func test_shop_sells_random_perks_and_battery() -> void:
	var offered := {}
	var battery := 0
	for s in range(1, 40):
		var run := RunState.new(s)
		run._open_shop()
		var goods := run.shop_goods()
		check(goods.perks.size() == 2, "Nicht 2 Perks im Angebot")
		for p: String in goods.perks:
			offered[p] = true
		if goods.battery:
			battery += 1
	# Array in [] einpacken: sonst gilt es bei % als Argumentliste (Formatfehler ab 2 Einträgen)
	check(offered.size() == Upgrades.perk_ids().size(), "Nicht alle Perks kommen vor: %s" % [offered.keys()])
	check(battery > 5 and battery < 30, "Batterie zu oft oder nie im Angebot: %d von 39" % battery)
	var run := RunState.new(3)
	run.scrap = 500
	run._open_shop()
	var perk: String = run.shop_goods().perks[0]
	check(run.shop_buy_perk(0) != "" and run.ship.has_perk(perk) and run.scrap == 500 - run.perk_price(perk), "Perk-Kauf klappt nicht")
	run.shop_goods().battery = true
	check(run.shop_buy_battery() != "" and run.ship.get_system("batterie") != null, "Batteriekauf klappt nicht")
	check(not run.shop_can_buy_battery(), "Zweite Batterie kaufbar")


func test_last_weapon_cannot_be_sold() -> void:
	var run := RunState.new(12)
	run.ship.remove_weapon_at(0)
	run._open_shop("weapons")
	var stock: int = run._stock().weapons.size()
	check(not run.dialog.choices[stock].enabled, "Letzte Waffe verkaufbar")


func test_save_keeps_refit() -> void:
	_save_paths()
	var run := RunState.new(31)
	run.scrap = 500
	run.upgrade_system("schilde")
	run.upgrade_system("reaktor")
	run.buy_perk("panzerung")
	run.ship.add_weapon("bordkanone")
	run.ship.add_weapon("brandkanone")
	run._open_shop("weapons")
	run.choose(0)
	SaveGame.save(run)
	var loaded := SaveGame.load_run()
	check(loaded != null, "Stand lädt nicht")
	if loaded == null:
		return
	check(loaded.ship.get_system("schilde").capacity == 3 and loaded.ship.get_system("reaktor").capacity == 9, "Ausbau verloren")
	check(loaded.ship.perks == ["panzerung"] and loaded.ship.max_hull == run.ship.max_hull, "Perk verloren")
	check(loaded.ship.all_weapon_ids() == run.ship.all_weapon_ids(), "Waffen oder Lager verloren")
	check(loaded._stock().weapons == run._stock().weapons, "Händlerwaren verloren")
	SaveGame.clear()


func test_scrap_gain_from_loot_and_events() -> void:
	var run := RunState.new(5)
	check(is_equal_approx(float(run.rules.get("scrap_gain", 1.0)), 1.15), "scrap_gain ist nicht 1,15")
	var scrap := run.scrap
	run._apply({"scrap": 12})
	check(run.scrap == scrap + 14, "+12 Rohstoffe werden nicht zu +14: %d" % (run.scrap - scrap))
	scrap = run.scrap
	run._apply({"scrap": -4})
	check(run.scrap == scrap - 4, "Verluste werden mit vervielfacht")
	run._open_shop()
	run.scrap = 20
	run._open_shop()
	run.choose(0)
	check(run.scrap == 17, "Kaufpreise ändern sich mit scrap_gain")


func test_player_shield_recharges_faster() -> void:
	var player := RunState.create_player_ship()
	check(is_equal_approx(player.shield_recharge, 2.6), "Frachter lädt Schilde nicht in 2,6 s")
	var enemy := ShipState.new(ShipLayout.load_json("res://data/ships/piraten_kutter.json"))
	check(is_equal_approx(enemy.shield_recharge, ShipState.SHIELD_RECHARGE), "Gegner lädt Schilde schneller")


func test_every_species_has_crew_art() -> void:
	for id in Species.ids():
		check(ResourceLoader.exists(CrewArt.SHEET % id), "Figur fehlt: %s" % id)
		check(ResourceLoader.exists(CrewArt.PORTRAIT % id), "Porträt fehlt: %s" % id)
		var crop := CrewArt.square_crop(id)
		check(Rect2(0, 0, 40, 44).encloses(crop) and Rect2(0, 0, 40, 44).encloses(CrewArt.head_crop(id)), "Porträtausschnitt ragt heraus: %s" % id)
	check(CrewArt.sheet("unbekannt") == CrewArt.sheet("mensch"), "Unbekannte Spezies ohne Rückfall")


## Run mit offenem Auftrag: Auftraggeber öffnen und annehmen.
func _quest_run(giver: String, seed := 5) -> RunState:
	var run := RunState.new(seed)
	run.scrap = 50
	run._open_event(giver)
	run.choose(0)
	run.choose(0)
	return run


func test_quest_marks_target_and_concludes_there() -> void:
	var run := _quest_run("auftrag_sonde")
	check(run.quests.size() == 1, "Auftrag nicht vergeben")
	if run.quests.is_empty():
		return
	var target: int = run.quests.keys()[0]
	check(target != run.current and run.map.node(target).type in ["ereignis", "leer"], "Ziel ist kein Ereignis- oder leeres System")
	check(run.is_quest_target(target) and not run.is_overrun(target), "Ziel nicht markiert oder überrannt")
	var d := run.map.distance(run.current, target)
	check(d >= 1, "Ziel nicht erreichbar")
	# direkt hinspringen (Verbindung erzwingen, damit der Test nicht vom Weg abhängt)
	run.map.node(run.current).links.append(target)
	run.fuel = 5
	check(run.jump_to(target), "Sprung zum Ziel klappt nicht")
	check(run.dialog.get("title", "") == "Die verschollene Sonde", "Abschluss öffnet sich nicht: %s" % run.dialog.get("title", ""))
	check(not run.is_quest_target(target), "Auftrag bleibt nach dem Abschluss offen")


func test_quest_chain_with_species_option_and_weapon() -> void:
	var run := _quest_run("auftrag_sonde")
	run._open_event("sonde_abschluss")
	var labels: Array = run.dialog.choices.map(func(c: Dictionary) -> String: return c.text)
	check(not labels.any(func(t: String) -> bool: return t.begins_with("[Veyari]")), "Veyari-Option ohne Veyari sichtbar")
	run.ship.add_crew_anywhere("Ylen", "veyari")
	run._open_event("sonde_abschluss")
	var idx := -1
	for i in run.dialog.choices.size():
		if run.dialog.choices[i].text.begins_with("[Veyari]"):
			idx = i
	check(idx >= 0 and run.dialog.choices[idx].special, "Veyari-Option fehlt oder ist nicht hervorgehoben")
	run.choose(idx)
	run.choose(0)  # Weiter -> Datenkern
	check(run.dialog.get("title", "") == "Der Datenkern", "Folgestufe fehlt")
	var weapons := run.ship.all_weapon_ids().size()
	run.choose(0)
	check(run.ship.all_weapon_ids().size() == weapons + 1 and run.ship.all_weapon_ids().has("salvenlaser"), "Belohnungswaffe fehlt")
	check(run.flags.has("gilde_freund"), "Gildenbrief fehlt")


func test_quest_battle_gives_victory_reward() -> void:
	var run := _quest_run("auftrag_kopfgeld")
	check(run.quests.size() == 1, "Kopfgeld vergeben")
	run._open_event("kopfgeld_versteck")
	run.choose(0)  # sofort angreifen
	run.choose(0)  # Kampf!
	check(run.needs_battle(), "Auftragskampf startet nicht")
	var scrap := run.scrap
	run.finish_battle("sieg")
	check(run.scrap >= scrap + 37, "Kopfgeld zu klein: %d" % (run.scrap - scrap))


func test_quest_lost_when_front_overruns_or_sector_ends() -> void:
	var run := _quest_run("auftrag_mine")
	check(run.quests.size() == 1, "Auftrag nicht vergeben")
	var target: int = run.quests.keys()[0]
	run.front = run.map.node(target).pos.x + 0.5
	run._drop_overrun_quests()
	check(run.quests.is_empty() and run.quest_note != "", "Überranntes Ziel bleibt Auftrag")
	run = _quest_run("auftrag_mine")
	run.next_sector()
	check(run.quests.is_empty() and run.quest_note != "", "Auftrag überlebt den Sektorwechsel")


func test_save_keeps_quests() -> void:
	_save_paths()
	var run := _quest_run("auftrag_konvoi")
	SaveGame.save(run)
	var loaded := SaveGame.load_run()
	check(loaded != null and loaded.quests == run.quests, "Auftrag nicht gespeichert")
	SaveGame.clear()


func test_quest_givers_are_in_event_pool() -> void:
	var book := EventBook.load_default()
	var pool := book.ids_in_pool("ereignis")
	for giver in ["auftrag_sonde", "auftrag_kopfgeld", "auftrag_konvoi", "auftrag_mine"]:
		check(pool.has(giver), "Auftraggeber fehlt im Pool: %s" % giver)
	check(not book.ids_in_pool("auftrag").is_empty(), "Keine Abschlussereignisse")
	for id in book.ids_in_pool("auftrag"):
		check(not pool.has(id), "Abschluss im normalen Pool: %s" % id)


func test_quest_deadline_fails_with_consequence() -> void:
	var run := _quest_run("auftrag_seuche")
	check(run.quests.size() == 1, "Fieberschiff vergibt keinen Auftrag")
	if run.quests.is_empty():
		return
	var target: int = run.quests.keys()[0]
	check(run.quest_jumps_left(target) == 3, "Frist nicht 3 Sprünge: %d" % run.quest_jumps_left(target))
	check(run.map.distance(run.current, target) <= 3, "Ziel nicht in der Frist erreichbar")
	var hp := run.ship.crew.map(func(m: CrewMember) -> float: return m.hp)
	run.jumps += 2
	run._expire_quests(-1)
	check(run.quests.size() == 1, "Frist läuft zu früh ab")
	run.jumps += 1  # dritter Sprung, aber nicht ans Ziel
	run._expire_quests(-1)
	check(run.quests.is_empty() and "Frist" in run.quest_note, "Frist läuft nicht ab")
	var after := run.ship.crew.map(func(m: CrewMember) -> float: return m.hp)
	check(after != hp, "Scheitern hat keine Folgen (fail)")


func test_quest_deadline_allows_arrival_on_last_jump() -> void:
	var run := _quest_run("auftrag_ueberlaeufer")
	if run.quests.is_empty():
		check(false, "Überläufer vergibt keinen Auftrag")
		return
	var target: int = run.quests.keys()[0]
	run.jumps += 2  # zwei Umwege, der dritte Sprung muss ans Ziel
	run.map.node(run.current).links.append(target)
	run.fuel = 5
	check(run.jump_to(target) and run.dialog.get("title", "") == "Das Beutelager", "Ankunft mit dem letzten Sprung zählt nicht")


func test_bad_reputation_raises_prices() -> void:
	var run := RunState.new(8)
	run.flags["ruf_schlecht"] = true
	run.scrap = 20
	run._open_shop()
	check(run._price(3) == 3 and run._price(20) == 23, "Aufschlag falsch: %d" % run._price(20))
	check(run._price(8) == 9, "Schlechter Ruf macht Hülle +5 nicht teurer: %d" % run._price(8))
	run.flags["gilde_freund"] = true
	check(run._price(8) == 7, "Gildenbrief und schlechter Ruf verrechnen sich nicht: %d" % run._price(8))


# --- Startausrüstung (Loadout) ---


func test_loadout_empty_is_classic_start() -> void:
	var run := RunState.new(3)
	check(run.ship.max_hull == 30 and run.ship.get_system("reaktor").capacity == 8, "Standardstart: Hülle oder Reaktor falsch")
	check(run.ship.weapons.map(func(w: Weapon) -> String: return w.id) == ["pulslaser", "schwerer_laser"], "Standardstart: Waffen falsch")
	check(run.ship.weapons.all(func(w: Weapon) -> bool: return w.powered), "Standardstart: Waffen ohne Energie")
	var names := run.ship.crew.map(func(m: CrewMember) -> String: return m.display_name)
	check(names == ["Mara Voss", "Jonas Reil", "Ilka Brandt"], "Standardstart: Crew falsch: %s" % [names])
	check(run.scrap == 10 and run.fuel == 6, "Standardstart: Rohstoffe oder Treibstoff falsch")
	check(run.loadout.ship == "frachter" and run.loadout.difficulty == "normal", "Standardstart: Auswahl falsch")


func test_loadout_points_rules() -> void:
	var cfg := Loadout.default_config()
	check(Loadout.cost(cfg) == 11 and Loadout.budget(cfg) == 14, "Standardauswahl kostet nicht 11 von 14: %d" % Loadout.cost(cfg))
	check(Loadout.is_valid(cfg, false), "Standardauswahl ungültig: %s" % [Loadout.problems(cfg, false)])
	cfg.perks = ["panzerung", "brandschutz"]
	check(Loadout.remaining(cfg) == -2 and not Loadout.is_valid(cfg, false), "Überzogenes Budget wird nicht erkannt")
	cfg.difficulty = "schwer"
	check(Loadout.is_valid(cfg, false), "Schwer: 17 Punkte reichen nicht")
	cfg.perks = ["panzerung", "brandschutz", "zielcomputer"]
	check(not Loadout.is_valid(cfg, false), "Mehr als 2 Perks erlaubt")
	cfg.perks = []
	cfg.weapons = ["pulslaser", "bordkanone", "bordkanone", "bordkanone"]
	check(not Loadout.is_valid(cfg, false), "Mehr Waffen als Plätze erlaubt")
	cfg.weapons = []
	check(not Loadout.is_valid(cfg, false), "Ohne Waffe erlaubt")
	cfg = Loadout.default_config()
	cfg.crew = ["mensch", "mensch", "mensch"]
	check(Loadout.cost(cfg) == 11 + 2 + 1, "Dritte Person ohne Aufschlag")
	cfg.crew = ["mensch", "mensch", "mensch", "mensch", "mensch"]
	check(not Loadout.is_valid(cfg, false), "Mehr als 4 Crew neben dem Captain erlaubt")


## Fair: Jedes Schiff ist mit seinen Startwaffen und zwei Leuten auf Normal startklar, aber kein
## stärkeres Schiff lässt mehr Punkte übrig als der Frachter (außer dem schwächeren Bergungsfrachter).
func test_loadout_every_ship_fits_normal_budget() -> void:
	var base := Loadout.remaining(Loadout.default_config("frachter"))
	for id in Loadout.ship_ids():
		var cfg := Loadout.default_config(id)
		check(Loadout.is_valid(cfg, false), "%s: Standardauswahl ungültig: %s" % [id, Loadout.problems(cfg, false)])
		var ship := RunState.create_player_ship(cfg)
		check(ship.layout.validate().is_empty(), "%s: Layout ungültig" % id)
		check(ship.reactor_output() >= ship.power_used(), "%s: Startenergie größer als Reaktor" % id)
		check(ship.weapons.all(func(w: Weapon) -> bool: return w.powered), "%s: Startwaffen ohne Energie" % id)
	check(Loadout.remaining(Loadout.default_config("kanone")) < base, "Kanonenfrachter lässt zu viele Punkte übrig")


func test_loadout_variant_crew_and_perks() -> void:
	var cfg := Loadout.default_config("kanone", "schwer")
	cfg.crew = ["mensch", "ormok", "androide"]
	cfg.perks = ["panzerung"]
	var run := RunState.new(5, RunState.MODE_HUNT, cfg)
	var s := run.ship
	check(s.max_hull == 24 + 6 and s.hull == s.max_hull, "Kanonenfrachter mit Panzerung: Hülle falsch: %d" % s.max_hull)
	check(s.get_system("reaktor").capacity == 9 and s.get_system("waffen").capacity == 4, "Kanonenfrachter: Systeme falsch")
	check(s.layout.stats.get("tint", "") == "#f0b8a8", "Kanonenfrachter: Farbe fehlt")
	check(s.crew.size() == 4 and s.crew[0].role == CrewMember.ROLE_CAPTAIN, "Crew-Anzahl oder Captain falsch")
	check(s.crew[2].species == "ormok" and s.crew[3].species == "androide", "Spezies der Crew falsch")
	var names := {}
	for m in s.crew:
		names[m.display_name] = true
	check(names.size() == 4, "Crew-Namen doppelt")
	check(s.has_perk("panzerung"), "Perk aus der Startauswahl fehlt")
	check(run.fuel == 5, "Schwer: Treibstoff nicht 6 - 1")
	check(run.scrap == 10 + Loadout.leftover_scrap(cfg), "Übrige Punkte werden nicht zu Rohstoffen")
	check(run.system_upgrade_price("reaktor") == 10, "Ausbaupreis zählt nicht ab dem Start der Variante")


func test_difficulty_changes_enemies_and_loot() -> void:
	var normal := RunState.new(77, RunState.MODE_HUNT, Loadout.default_config())
	var hard := RunState.new(77, RunState.MODE_HUNT, Loadout.default_config("frachter", "schwer"))
	var easy := RunState.new(77, RunState.MODE_HUNT, Loadout.default_config("frachter", "leicht"))
	for n: Dictionary in normal.map.nodes:
		if n.type == "kampf" or n.type == "boss":
			var a: int = normal.enemy_spec(n.id).hull_bonus
			# Die Gegnerstufe verschiebt sich mit, darum mindestens ±3 (spätere Stufen bringen mehr Hülle)
			check(hard.enemy_spec(n.id).hull_bonus >= a + 3 and easy.enemy_spec(n.id).hull_bonus <= a - 3, "Gegnerhülle folgt nicht der Schwierigkeit")
	check(hard._depth(5) == normal._depth(5) + 2 and easy._depth(1) == 0, "Gegnerstufe folgt nicht der Schwierigkeit")
	check(is_equal_approx(easy.scrap_gain(), 1.15 * 1.2) and is_equal_approx(hard.scrap_gain(), 1.15 * 0.85), "Beute-Faktor falsch")
	check(easy.fuel == 8, "Leicht: Treibstoff nicht 6 + 2")


func test_loadout_survives_save_and_load() -> void:
	SaveGame.path = "user://test_savegame.json"
	SaveGame.backup = "user://test_savegame.bak.json"
	var cfg := Loadout.default_config("bergung", "schwer")
	var run := RunState.new(9, RunState.MODE_HUNT, cfg)
	check(run.ship.get_system("reaktor").capacity == 7 and run.ship.max_hull == 34, "Bergungsfrachter: Werte falsch")
	check(SaveGame.save(run), "Speichern scheitert")
	var loaded := SaveGame.load_run(RunState.MODE_HUNT)
	check(loaded != null, "Laden scheitert")
	if loaded:
		check(loaded.loadout.ship == "bergung" and loaded.loadout.difficulty == "schwer", "Auswahl nicht gespeichert")
		check(loaded.ship.get_system("reaktor").capacity == 7, "Reaktor der Variante nach dem Laden falsch")
		check(loaded.ship.layout.stats.get("tint", "") == "#e8d8b0", "Farbe der Variante nach dem Laden weg")
		check(loaded.scrap == run.scrap, "Rohstoffe nach dem Laden falsch")
	SaveGame.clear(RunState.MODE_HUNT)


func test_piercing_weapons_pass_shields() -> void:
	var player := ShipState.new(_layout())
	var enemy := _enemy_ship()
	var battle := Battle.new(player, enemy, 3)
	enemy.shield_layers = 1
	var laser := Weapon.create("durchschlaglaser")
	check(laser.pierce == 1 and Weapon.create("torpedo").pierce >= 9, "Durchschlag fehlt in den Waffenwerten")
	player.weapons.append(laser)
	var room := enemy.layout.room_index_by_id("waffen")
	battle._resolve({"id": 1, "player": true, "weapon": player.weapons.size() - 1, "room": room, "damage": 2})
	var events := battle.take_events()
	var hit := events.filter(func(e: Dictionary) -> bool: return e.get("type", "") == "hit")
	check(hit.size() == 1 and hit[0].get("pierced", false), "Durchschlaglaser kommt nicht durch eine Schicht")
	check(enemy.shield_layers == 1, "Durchschlag verbraucht die Schildschicht")
	enemy.shield_layers = 2
	battle._resolve({"id": 2, "player": true, "weapon": player.weapons.size() - 1, "room": room, "damage": 2})
	check(enemy.shield_layers == 1, "Zwei Schichten halten den Durchschlaglaser nicht auf")


func test_enemies_get_stronger_deep_in_the_universe() -> void:
	var run := RunState.new(12, RunState.MODE_ENDLESS)
	check(is_equal_approx(run.create_enemy().repair_speed, 0.9), "Gegner reparieren nicht 10 % langsamer")
	run.sector = 7  # Tiefe ab 18: Durchschlaglaser und eine Schildschicht mehr
	var spec := run.enemy_spec(run.map.start_id())
	check(spec.weapons.has("durchschlaglaser") and spec.shield_bonus == 2, "Tiefe Gegner ohne Zusatzwaffe oder Schild: %s" % spec)
	var enemy := run.create_enemy(run.map.start_id())
	check(enemy.max_shield_layers() == 2, "Zusatzschild ohne Energie")
	for w in enemy.weapons:
		check(w.powered, "Zusatzwaffe %s ohne Energie" % w.id)
	var hunt := RunState.new(12)
	hunt.sector = 4
	var boss := hunt.enemy_spec(hunt.map.exit_id())
	check(boss.weapons.has("torpedo") and boss.weapons.has("durchschlaglaser") and boss.shield_bonus == 2, "Boss in Sektor 4 nicht aufgerüstet")


func test_sensors_reveal_enemy_step_by_step() -> void:
	check(not Sensors.shows_rooms(0) and not Sensors.shows_crew(0) and not Sensors.shows_power(0), "Ohne Sensoren sichtbar")
	check(Sensors.shows_rooms(1) and not Sensors.shows_crew(1), "Stufe 1 zeigt nicht nur die Räume")
	check(Sensors.shows_crew(2) and not Sensors.shows_power(2), "Stufe 2 zeigt nicht die Crew")
	check(Sensors.shows_power(3), "Stufe 3 zeigt keine Energie")
	var run := RunState.new(5)
	run.ship.get_system("sensoren").damage = 1
	run.ship._rebalance()
	check(run.ship.level("sensoren") == 0, "Beschädigte Sensoren zeigen weiter alles")


func test_reactor_goes_to_20() -> void:
	var run := RunState.new(31)
	run.scrap = 10000
	while run.upgrade_system("reaktor"):
		pass
	check(run.ship.get_system("reaktor").capacity == 20, "Reaktor nicht bis 20: %d" % run.ship.get_system("reaktor").capacity)
	check(run.scrap == 10000 - 318, "Reaktor 8 → 20 kostet nicht 318: %d" % (10000 - run.scrap))


func test_all_enemy_ships_are_valid_and_crewable() -> void:
	for id in ["piraten_kutter", "piraten_kutter_schwer", "pluenderer", "kanonenboot", "jaeger_fregatte"]:
		var path := "res://data/ships/%s.json" % id
		var layout := ShipLayout.load_json(path)
		check(layout.validate().is_empty(), "%s: %s" % [id, ", ".join(layout.validate())])
		check(ResourceLoader.exists(layout.sprite_path), "%s: Grafik fehlt" % id)
		for room in ["cockpit", "waffen", "schilde", "antrieb", "reaktor"]:
			check(layout.room_index_by_id(room) >= 0, "%s: Raum %s fehlt" % [id, room])
		for room in ["cockpit", "waffen", "schilde"]:
			check(layout.console_of(layout.room_index_by_id(room)) != null, "%s: keine Konsole in %s" % [id, room])
		var ship := ShipState.new(layout)
		for w in ship.weapons:
			check(w.powered, "%s: %s ohne Energie" % [id, w.id])
		check(ship.max_shield_layers() == 1, "%s: nicht genau eine Schildschicht" % id)
		check(ship.level("antrieb") > 0, "%s: Antrieb ohne Energie (kann nicht fliehen)" % id)


func test_enemy_variety_on_the_map() -> void:
	var seen := {}
	for s in range(1, 30):
		var run := RunState.new(s, RunState.MODE_ENDLESS)
		run.sector = 3
		for n in run.map.nodes:
			if n.type == "kampf":
				seen[str(run.enemy_spec(n.id).ship).get_file().get_basename()] = true
	for id in ["piraten_kutter", "piraten_kutter_schwer", "pluenderer", "kanonenboot"]:
		check(seen.has(id), "%s kommt nie vor" % id)


func test_enemy_rooms_are_shuffled_but_fixed_per_node() -> void:
	var layouts := {}
	for s in range(1, 12):
		var run := RunState.new(s)
		var enemy := run.create_enemy(run.map.node(run.current).links[0])
		check(enemy.layout.validate().is_empty(), "Gemischtes Layout ungültig: %s" % ", ".join(enemy.layout.validate()))
		for sys in ["cockpit", "waffen", "schilde"]:
			var room := enemy.layout.room_of_system(sys)
			check(room >= 0 and enemy.layout.console_of(room) != null and enemy.layout.room_index_at(enemy.layout.console_of(room)) == room, "%s ohne Konsole im eigenen Raum" % sys)
		check(enemy.layout.console_of(enemy.layout.room_of_system("reaktor")) == null, "Reaktor mit Konsole")
		check(enemy.crew.size() == 3, "Crew fehlt")
		layouts[str(enemy.layout.room_of_system("schilde"))] = true
		var again := run.create_enemy(run.map.node(run.current).links[0])
		check(again.layout.room_of_system("schilde") == enemy.layout.room_of_system("schilde"), "Raumverteilung nicht fest je Knoten")
	check(layouts.size() >= 3, "Schilde sitzen fast immer im selben Raum: %s" % [layouts.keys()])


func test_petrani_heal_by_themselves() -> void:
	var state := ShipState.new(_layout())
	var rock := state.add_crew("Quarz-Aun", "petrani", Vector2i(8, 1))
	rock.hp = 50.0
	_settle(state, 20.0)
	check(rock.hp >= 59.0, "Petrani heilen nicht von selbst: %.1f" % rock.hp)


func test_battery_adds_power_and_survives_save() -> void:
	_save_paths()
	var run := RunState.new(31)
	var before := run.ship.reactor_output()
	check(run.ship.install_battery(2), "Batterie lässt sich nicht einbauen")
	check(not run.ship.install_battery(2), "Zweite Batterie eingebaut")
	check(run.ship.reactor_output() == before + 2, "Batterie bringt keine 2 Energie")
	var room := run.ship.layout.room_of_system("batterie")
	check(room >= 0 and str(run.ship.layout.rooms[room].id).begins_with("erweiterung"), "Batterie nicht im Erweiterungsraum")
	run.scrap = 100
	check(run.system_upgrade_price("batterie") == 30 and run.upgrade_system("batterie"), "Batterie nicht für 30 erweiterbar")
	run.ship.take_hit(room, 1)
	run.ship._rebalance()
	check(run.ship.get_system("batterie").damage >= 0, "Batterie nicht beschädigbar")
	SaveGame.save(run)
	var loaded := SaveGame.load_run()
	check(loaded != null and loaded.ship.get_system("batterie") != null and loaded.ship.get_system("batterie").capacity == 3, "Batterie nach Laden weg")
	check(loaded != null and loaded.ship.battery_room_id() == run.ship.battery_room_id(), "Batterie in anderem Raum")
	SaveGame.clear()
	var quest := _event_run("konvoi_dank")
	quest.choose(quest.dialog.choices.size() - 1)
	check(quest.ship.get_system("batterie") != null, "Auftrag bringt keine Batterie")


func test_crew_has_gender_and_look() -> void:
	var run := RunState.new(5)
	var genders := run.ship.crew.map(func(m: CrewMember) -> String: return m.gender)
	check(genders == ["w", "m", "w"], "Startcrew Mara/Jonas/Ilka hat falsches Geschlecht: %s" % [genders])
	var seen := {}
	for id in Species.ids():
		for n: String in Species.value(id, "names", []):
			var m := CrewMember.new(n, id, Vector2i.ZERO)
			check(m.look >= 0 and m.look < 3, "Variante außerhalb 0–2")
			check(m.gender == ("w" if (Species.value(id, "names_w", []) as Array).has(n) else "m"), "Geschlecht passt nicht zum Namen %s" % n)
			check(ResourceLoader.exists(CrewArt.SHEET % ("%s_%s%d" % [id, m.gender, m.look])), "Grafik fehlt für %s" % n)
			seen["%s_%s" % [id, m.gender]] = true
	check(seen.size() == Species.ids().size() * 2, "Nicht jede Spezies hat Frauen und Männer")


func test_shop_goods_stay_the_same_on_revisits() -> void:
	_save_paths()
	var run := RunState.new(21, RunState.MODE_ENDLESS)  # ohne Jägerfront, die den Rückweg besetzen würde
	var shop := -1
	for n in run.map.nodes:
		if n.type == "haendler":
			shop = n.id
	var home := run.current
	run.map.node(home).links.append(shop)
	run.map.node(shop).links.append(home)
	run.fuel = 20
	run.scrap = 500
	check(run.jump_to(shop) and run.is_shop_open(), "Händler öffnet nicht")
	var first := run.shop_goods().duplicate(true)
	run.shop_buy_weapon(0)
	var after_buy := run.shop_goods().duplicate(true)
	run.close_shop()
	for i in 3:  # weg und wieder hin, mehrmals
		run.jump_to(home)
		run.close_shop()
		run.jump_to(shop)
		check(run.is_shop_open(), "Händler beim Wiederbesuch zu")
		check(run.shop_goods().weapons == after_buy.weapons and run.shop_goods().perks == after_buy.perks \
			and run.shop_goods().crew == after_buy.crew, "Waren ändern sich beim Wiederbesuch")
		run.close_shop()
	check(after_buy.weapons.size() == first.weapons.size() - 1, "Gekaufte Waffe nicht weg")
	SaveGame.save(run)
	var loaded := SaveGame.load_run(RunState.MODE_ENDLESS)
	check(loaded != null and loaded._stock().weapons == after_buy.weapons, "Waren nach dem Laden anders")
	SaveGame.clear(RunState.MODE_ENDLESS)
	# Perk woanders gekauft: verschwindet aus diesem Angebot
	run.jump_to(shop)
	var perk: String = run.shop_goods().perks[0]
	run.ship.perks.append(perk)
	check(not run.shop_goods().perks.has(perk), "Perk an Bord noch im Angebot")
	run.close_shop()
	run.next_sector()
	check(run.shop_stock.is_empty(), "Neuer Sektor behält alte Waren")


func test_update_version_compare() -> void:
	check(UpdateCheck.is_newer("0.3.23", "0.3.22"), "0.3.23 nicht neuer als 0.3.22")
	check(UpdateCheck.is_newer("0.3.100", "0.3.99"), "Build-Nummer als Text verglichen")
	check(UpdateCheck.is_newer("0.4.1", "0.3.40"), "Neuer Meilenstein nicht neuer")
	check(not UpdateCheck.is_newer("0.3.22", "0.3.22"), "Gleiche Version gilt als neuer")
	check(not UpdateCheck.is_newer("0.3.21", "0.3.22"), "Ältere Version gilt als neuer")
	check(UpdateCheck.can_check("0.3.22"), "Release-Build prüft nicht")
	check(not UpdateCheck.can_check("0.3"), "Editor-Build ohne Build-Nummer prüft")
	check(not UpdateCheck.can_check(""), "Leere Version prüft")


func test_update_picks_newest_release_file() -> void:
	# So liefert die GitHub-API die Releases (Zahlen als float, Reihenfolge nicht sortiert)
	var releases := [
		{"tag_name": "release-build-22", "html_url": "https://r/22", "assets": [
			{"name": "hullbound-0.3.22-debug.apk", "browser_download_url": "https://d/22.apk", "size": 100.0},
			{"name": "hullbound-0.3.22-unsigned.ipa", "browser_download_url": "https://d/22.ipa", "size": 50.0}]},
		{"tag_name": "release-build-23", "html_url": "https://r/23", "assets": [
			{"name": "hullbound-0.3.23-debug.apk", "browser_download_url": "https://d/23.apk", "size": 101.0}]},
		{"tag_name": "ipa-build-30", "html_url": "https://r/i30", "assets": [  # eigene iOS-Nummern
			{"name": "hullbound-0.3.30-unsigned.ipa", "browser_download_url": "https://d/i30.ipa", "size": 51.0}]},
		{"tag_name": "apk-build-9", "html_url": "https://r/9", "assets": [  # alter Name mit Commit
			{"name": "hullbound-9698ee6-debug.apk", "browser_download_url": "https://d/9.apk", "size": 99.0}]},
		{"tag_name": "release-build-99", "draft": true, "html_url": "https://r/99", "assets": [
			{"name": "hullbound-0.3.99-debug.apk", "browser_download_url": "https://d/99.apk", "size": 1.0}]},
		{"tag_name": "release-build-40", "html_url": "https://r/40", "assets": [  # kein HTTPS, keine Größe
			{"name": "hullbound-0.3.40-debug.apk", "browser_download_url": "http://d/40.apk", "size": 1.0},
			{"name": "hullbound-0.3.41-debug.apk", "browser_download_url": "https://d/41.apk", "size": 0.0}]},
	]
	var apk := UpdateCheck.find_update(releases, "android", "0.3.21")
	check(apk != null and apk.version == "0.3.23", "Android: 0.3.23 erwartet")
	if apk:
		check(apk.url == "https://d/23.apk" and apk.size == 101 and apk.file == "hullbound-0.3.23-debug.apk"
			and apk.page == "https://r/23", "Android: falsche Datei %s" % apk.url)
	check(UpdateCheck.find_update(releases, "android", "0.3.23") == null, "Android: Update obwohl aktuell")
	var ipa := UpdateCheck.find_update(releases, "ios", "0.3.21")
	check(ipa != null and ipa.version == "0.3.22" and ipa.page == "https://r/22", "iOS: 0.3.22 erwartet")
	check(UpdateCheck.find_update(releases, "", "0.3.1") == null, "Update für unbekannte Plattform")


func test_music_tracks_exist() -> void:
	var music := preload("res://scripts/music.gd")
	check(music.TRACKS.size() == 5, "Fünf Musikstücke")
	for track: String in music.TRACKS:
		check(ResourceLoader.exists(music.DIR + track + ".ogg"), "Musik %s fehlt" % track)
		check(music.TITLES.has(track), "Titel für %s fehlt" % track)
	for situation: String in music.AUTO:
		var track := str(music.AUTO[situation])
		check(track == "" or track in music.TRACKS, "Auto-Stück %s unbekannt" % track)
