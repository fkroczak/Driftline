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
	check(fled > 4 and fled < 20, "Gegner flieht nie oder immer (%d von 20)" % fled)


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
	check(state.reactor_output() == 7, "Reaktor sollte 7 liefern, liefert %d" % state.reactor_output())
	check(state.power_used() == 7, "Startverteilung sollte den Reaktor ausschöpfen, belegt %d" % state.power_used())
	check(state.level("antrieb") == 1, "Antrieb sollte am Start 1 Balken haben (Sprung braucht Energie)")
	check(state.weapons[0].powered and state.weapons[1].powered, "Beide Waffen sollten Energie haben")
	check(state.shield_layers == 1, "Eine Schildschicht erwartet")


func test_power_is_limited() -> void:
	var state := ShipState.new(_layout())
	check(not state.add_power("antrieb"), "Mehr Energie verteilt, als der Reaktor hat")
	check(state.remove_power("schilde"), "Schilde ließen sich nicht herunterfahren")
	check(state.add_power("sensoren"), "Freie Energie nicht nutzbar")
	check(not state.add_power("sensoren"), "Mehr Energie als Stufen im System")
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
	check(state.reactor_output() == 5, "Reaktorschaden senkt die Leistung nicht")
	check(state.power_used() <= 5, "Systeme verbrauchen mehr als der Reaktor liefert")
	check(state.level("lebenserhaltung") == 1 and state.level("schilde") == 2, "Wichtige Systeme zuerst versorgen")


func test_shields_recharge() -> void:
	var state := ShipState.new(_layout())
	state.shield_layers = 0
	_settle(state, 2.0)
	check(state.shield_layers == 0, "Schildwand steht zu schnell wieder (unter 3 s)")
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
			check(spec.ship.ends_with("piraten_kutter.json") and spec.hull_bonus == 0, "Vorne auf der Karte nur der einfache Kutter")
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
	check(run.sector == 2 and run.current == run.map.start_id() and run.score() == 2, "Ausgang führt nicht in Sektor 2")


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

