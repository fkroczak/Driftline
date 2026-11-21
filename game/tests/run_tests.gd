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
	check(state.reactor_output() == 8, "Reaktor sollte 8 liefern, liefert %d" % state.reactor_output())
	check(state.power_used() == 8, "Startverteilung sollte den Reaktor ausschöpfen, belegt %d" % state.power_used())
	check(state.weapons[0].powered and state.weapons[1].powered, "Beide Waffen sollten Energie haben")
	check(state.shield_layers == 1, "Eine Schildschicht erwartet")


func test_power_is_limited() -> void:
	var state := ShipState.new(_layout())
	check(not state.add_power("sensoren"), "Mehr Energie verteilt, als der Reaktor hat")
	check(state.remove_power("antrieb"), "Antrieb ließ sich nicht herunterfahren")
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
	_settle(state, 2.1)
	check(state.shield_layers == 1, "Schild lädt nicht nach")


func test_evasion_needs_pilot() -> void:
	var state := ShipState.new(_layout())
	check(state.evasion() == 0.0, "Ausweichen ohne Pilot")
	state.add_crew("Pilot", "mensch", Vector2i(10, 3))
	check(state.evasion() > 0.0, "Kein Ausweichen mit Pilot und Antrieb")


func test_weapons_fire_and_damage_enemy() -> void:
	var battle := Battle.new(ShipState.new(_layout()), _enemy_ship(), 42)
	var target := battle.enemy.layout.room_index_by_id("waffen")
	battle.set_player_target(target)
	var seen := {}
	for i in 200:  # 20 s
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
	battle.set_player_target(battle.enemy.layout.room_index_by_id("schilde"))
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
