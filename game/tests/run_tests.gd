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
