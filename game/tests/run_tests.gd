extends SceneTree
## Logiktests ohne Fenster:
##   godot --headless --path game --script res://tests/run_tests.gd
## Jede Methode, die mit test_ beginnt, wird ausgeführt. Exit-Code 1 bei Fehlern.

const LAYOUT_PATH := "res://data/ships/mensch_frachter.json"

var _failures := 0
var _current := ""


func _init() -> void:
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
	check(member.level("cockpit") == 1, "Nach einer Minute an der Konsole keine Stufe 1")
	for i in 600:
		state.update(1.0)
	check(member.level("cockpit") == int(CrewMember.MAX_EXPERIENCE), "Erfahrung nicht gedeckelt")


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
	check(state.reactor_output() == 6, "Reaktor sollte 6 liefern, liefert %d" % state.reactor_output())
	check(state.power_used() == 6, "Startverteilung sollte den Reaktor ausschöpfen, belegt %d" % state.power_used())
	check(state.level("antrieb") == 0, "Antrieb sollte am Start aus sein (Energie ist knapp)")
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
	check(state.reactor_output() == 4, "Reaktorschaden senkt die Leistung nicht")
	check(state.power_used() <= 4, "Systeme verbrauchen mehr als der Reaktor liefert")
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
	check(battle.player_jump() and battle.outcome == "entkommen", "Geladener Sprung beendet den Kampf nicht")


func test_heavy_enemy_layout_is_valid() -> void:
	var layout := ShipLayout.load_json("res://data/ships/piraten_kutter_schwer.json")
	check(layout.validate().is_empty(), "Schwerer Kutter: Layout-Fehler")
	var ship := ShipState.new(layout)
	check(ship.max_shield_layers() == 1, "Schwerer Kutter: eine Schildschicht (zwei sind mit 6 Reaktorbalken kaum zu knacken)")
	check(ship.weapons.size() == 3 and ship.weapons.all(func(w: Weapon) -> bool: return w.powered), "Schwerer Kutter: drei Waffen mit Energie")


# --- Sternenkarte und Run ---


func test_star_map_always_leads_to_boss() -> void:
	for s in range(1, 60):
		var map := StarMap.generate(s)
		check(map.columns.size() == StarMap.JUMPS + 1, "Seed %d: falsche Spaltenzahl" % s)
		check(map.node(map.boss_id()).type == "boss" and map.node(map.start_id()).type == "start", "Seed %d: Start oder Boss fehlt" % s)
		for n in map.nodes:
			if n.type != "boss":
				check(not n.links.is_empty(), "Seed %d: Knoten %d ist eine Sackgasse" % [s, n.id])
			if n.type != "start":
				check(not map.incoming(n.id).is_empty(), "Seed %d: Knoten %d ist unerreichbar" % [s, n.id])
			for to: int in n.links:
				check(map.node(to).column == n.column + 1, "Seed %d: Verbindung überspringt eine Spalte" % s)
		# Verbindungen zwischen zwei Spalten kreuzen sich nicht
		for c in StarMap.JUMPS:
			var pairs := []
			for i in map.columns[c].size():
				for to: int in map.node(map.columns[c][i]).links:
					pairs.append([i, map.columns[c + 1].find(to)])
			for p: Array in pairs:
				for q: Array in pairs:
					check(not (p[0] < q[0] and p[1] > q[1]), "Seed %d: Verbindungen kreuzen sich in Spalte %d" % [s, c])


func test_star_map_is_deterministic() -> void:
	var a := StarMap.generate(1234)
	var b := StarMap.generate(1234)
	check(a.nodes.size() == b.nodes.size(), "Gleicher Seed, andere Knotenzahl")
	for i in a.nodes.size():
		check(a.nodes[i].pos == b.nodes[i].pos and a.nodes[i].type == b.nodes[i].type and a.nodes[i].links == b.nodes[i].links,
			"Gleicher Seed, anderer Knoten %d" % i)


func test_run_jumps_only_along_links() -> void:
	var run := RunState.new(77)
	var linked: int = run.node().links[0]
	var far: int = run.map.columns[2][0]
	check(not run.jump_to(far), "Sprung über zwei Spalten möglich")
	check(run.jump_to(linked) and run.current == linked and run.jumps_done() == 1, "Sprung zum verbundenen Knoten klappt nicht")
	if run.needs_battle():
		var next: int = run.node().links[0]
		check(not run.jump_to(next), "Weiterspringen trotz wartendem Gegner")
		run.finish_battle("sieg")
		check(run.jump_to(next), "Nach dem Sieg geht es nicht weiter")


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


func test_enemy_stages_follow_jump_number() -> void:
	var run := RunState.new(9)
	for id: int in run.map.columns[1]:
		var spec := run.enemy_spec(id)
		check(spec.ship.ends_with("piraten_kutter.json") and spec.hull_bonus == 0, "Sprung 1: nur der einfache Kutter")
	var boss := run.create_enemy(run.map.boss_id())
	check(boss.layout.display_name == "Piraten-Flaggschiff", "Boss heißt nicht Piraten-Flaggschiff")
	check(boss.max_hull == 24 and boss.hull == 24, "Boss hat nicht 18 + 6 Hülle: %d" % boss.max_hull)
	check(boss.crew.size() == 3, "Boss ohne Besatzung")
	check(run.enemy_spec(run.map.columns[5][0]) == run.enemy_spec(run.map.columns[5][0]), "Gegner am Knoten ist nicht fest")


func test_defeat_ends_run_and_boss_victory_wins() -> void:
	var run := RunState.new(3)
	run.jump_to(run.node().links[0])
	run.finish_battle("niederlage")
	check(run.result == "verloren", "Niederlage beendet den Run nicht")
	check(not run.can_jump_to(run.node().links[0]), "Nach der Niederlage geht es weiter")
	run = RunState.new(3)
	run.current = run.map.boss_id()
	check(run.needs_battle(), "Boss wartet nicht")
	run.finish_battle("entkommen")
	check(run.needs_battle() and run.result == "", "Nach der Flucht vor dem Boss ist der Boss weg")
	run.finish_battle("sieg")
	check(run.result == "geschafft", "Sieg über den Boss beendet den Run nicht")


## Run mit offenem Ereignis (ohne Sprung), für Ereignistests.
func _event_run(id: String) -> RunState:
	var run := RunState.new(5)
	run._open_event(id)
	return run


func test_stations_on_every_map() -> void:
	for s in range(1, 40):
		var map := StarMap.generate(s)
		check(map.count_type("haendler") == 2 and map.count_type("reparatur") == 1, "Seed %d: nicht 2 Händler und 1 Reparaturstation" % s)
		var run := RunState.new(s)
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
