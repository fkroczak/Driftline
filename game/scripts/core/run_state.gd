class_name RunState
extends RefCounted
## Ein Run durch ein Universum: Sternenkarte, Position, eigenes Schiff. Reine Logik, keine Nodes.
##
## Das Schiff ist ein einziger ShipState, der von Kampf zu Kampf weitergereicht wird.
## Bleibender Schaden: Hülle, gefallene Crew und Erfahrung. Beim Sprung löscht und repariert
## die Crew alles andere (siehe ShipState.after_jump).
##
## Hüllenreparatur (Zwischenlösung bis Händler und Belohnungen kommen, Werte in data/run.json):
## nach einem Sieg Bergung aus dem Wrack, in einem leeren System Zeit zum Flicken.
##
## Gegner kommen aus data/enemies.json: Je Sprungnummer gilt die letzte Stufe, deren
## `from_jump` erreicht ist; daraus wird gewichtet ein Schiff gewürfelt, eventuell mit Hüllenbonus.

const PLAYER_SHIP := "res://data/ships/mensch_frachter.json"
const ENEMIES_PATH := "res://data/enemies.json"
const SHIPS_DIR := "res://data/ships/%s.json"
const RUN_PATH := "res://data/run.json"

var seed_value := 0
var map: StarMap
var ship: ShipState
## Aktueller Knoten (ID in map.nodes).
var current := 0
## Besuchte Knoten -> true.
var visited: Dictionary = {}
## Knoten, deren Kampf vorbei ist (gewonnen oder entkommen) -> Ergebnis.
var cleared: Dictionary = {}
## "" solange der Run läuft, sonst "geschafft" (Boss besiegt) oder "verloren".
var result := ""

## Zuletzt reparierte Hüllenpunkte (für die Anzeige).
var last_repair := 0

var _enemy_table: Dictionary = {}
var _rules: Dictionary = {}


func _init(p_seed := 0) -> void:
	seed_value = p_seed if p_seed != 0 else randi()
	map = StarMap.generate(seed_value)
	current = map.start_id()
	visited[current] = true
	ship = create_player_ship()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMIES_PATH))
	_enemy_table = data if typeof(data) == TYPE_DICTIONARY else {}
	data = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH))
	_rules = data if typeof(data) == TYPE_DICTIONARY else {}


static func create_player_ship() -> ShipState:
	var layout := ShipLayout.load_json(PLAYER_SHIP)
	for error in layout.validate():
		push_error("%s: %s" % [PLAYER_SHIP, error])
	var s := ShipState.new(layout)
	s.add_crew("Mara Voss", "mensch", Vector2i(9, 3), {"cockpit": 3.0, "waffen": 1.0})
	s.add_crew("Jonas Reil", "mensch", Vector2i(6, 6), {"waffen": 3.0, "schilde": 1.0})
	s.add_crew("Ilka Brandt", "mensch", Vector2i(6, 0), {"schilde": 2.0, "antrieb": 2.0})
	return s


func node() -> Dictionary:
	return map.node(current)


## Bisher gesprungen (= Spalte des aktuellen Knotens).
func jumps_done() -> int:
	return node().column


func can_jump_to(id: int) -> bool:
	return result == "" and not needs_battle() and node().links.has(id)


## Springt zum Knoten. Die Crew bringt das Schiff unterwegs in Ordnung.
func jump_to(id: int) -> bool:
	if not can_jump_to(id):
		return false
	ship.after_jump()
	current = id
	visited[id] = true
	last_repair = 0
	if node().type == "leer":
		_repair_hull(int(_rules.get("repair_empty_system", 0)))
	return true


func _repair_hull(amount: int) -> void:
	var before := ship.hull
	ship.hull = mini(ship.hull + amount, ship.max_hull)
	last_repair = ship.hull - before


## Am aktuellen Knoten wartet ein Gegner, der noch nicht besiegt oder abgehängt ist.
## Wer vor dem Boss flieht, bleibt vor ihm stehen: Der Boss wartet weiter.
func needs_battle() -> bool:
	var type: String = node().type
	return result == "" and (type == "kampf" or type == "boss") and not cleared.has(current)


## Ergebnis eines Kampfs am aktuellen Knoten: "sieg", "entkommen" oder "niederlage".
func finish_battle(outcome: String) -> void:
	match outcome:
		"niederlage":
			result = "verloren"
		"sieg":
			cleared[current] = outcome
			if node().type == "boss":
				result = "geschafft"
			ship.after_jump()  # Crew räumt nach dem Kampf auf
			_repair_hull(int(_rules.get("repair_after_victory", 0)))
		"entkommen":
			if node().type != "boss":
				cleared[current] = outcome
			ship.after_jump()  # Flucht ist auch ein Sprung


## Welcher Gegner am Knoten wartet: {ship (Pfad), name, hull_bonus}. Pro Knoten fest,
## damit ein neu geladener Kampf denselben Gegner zeigt.
func enemy_spec(id := -1) -> Dictionary:
	if id < 0:
		id = current
	var n := map.node(id)
	if n.type == "boss":
		var boss: Dictionary = _enemy_table.get("boss", {})
		return {
			"ship": SHIPS_DIR % boss.get("ship", "piraten_kutter_schwer"),
			"name": boss.get("name", ""),
			"hull_bonus": int(boss.get("hull_bonus", 0)),
		}
	var stage := {}
	for s: Dictionary in _enemy_table.get("stages", []):
		if n.column >= int(s.get("from_jump", 0)):
			stage = s
	var pool: Array = stage.get("pool", [["piraten_kutter", 1.0]])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, id])
	var total := 0.0
	for entry: Array in pool:
		total += float(entry[1])
	var roll := rng.randf() * total
	var pick: String = pool[0][0]
	for entry: Array in pool:
		roll -= float(entry[1])
		if roll <= 0.0:
			pick = entry[0]
			break
	return {"ship": SHIPS_DIR % pick, "name": "", "hull_bonus": int(stage.get("hull_bonus", 0))}


## Baut das Gegnerschiff für den Knoten samt Besatzung (Kapitänin, Schütze, Mechaniker).
func create_enemy(id := -1) -> ShipState:
	var spec := enemy_spec(id)
	var layout := ShipLayout.load_json(spec.ship)
	for error in layout.validate():
		push_error("%s: %s" % [spec.ship, error])
	if spec.name != "":
		layout.display_name = spec.name
	var enemy := ShipState.new(layout)
	enemy.max_hull += spec.hull_bonus
	enemy.hull = enemy.max_hull
	for crew_spec in [["Kapitänin", "cockpit"], ["Schütze", "waffen"], ["Mechaniker", "schilde"]]:
		var console: Vector2i = layout.console_of(layout.room_index_by_id(crew_spec[1]))
		enemy.add_crew(crew_spec[0], "mensch", console, {crew_spec[1]: 1.0})
	return enemy
