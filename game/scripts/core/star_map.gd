class_name StarMap
extends RefCounted
## Sprungkarte eines Universums. Reine Logik, keine Nodes.
##
## Die Knoten liegen in Spalten von links (Start, Spalte 0) nach rechts (Boss, Spalte JUMPS).
## Ein Sprung führt immer in die nächste Spalte, also braucht jeder Weg genau JUMPS Sprünge.
## Die Verbindungen zwischen zwei Spalten kreuzen sich nicht, und jeder Knoten hat mindestens
## einen Vorgänger und einen Nachfolger: Von jedem Knoten aus ist der Boss erreichbar.
##
## Knotentypen: "start", "kampf", "leer", "boss".

const JUMPS := 10
const MIN_PER_COLUMN := 2
const MAX_PER_COLUMN := 3
const EMPTY_CHANCE := 0.35

## Jeder Knoten: {id, column, pos: Vector2 (0..1 in beiden Achsen), type, links: Array[int]}
var nodes: Array[Dictionary] = []
## Knoten-IDs je Spalte, von oben nach unten sortiert.
var columns: Array[Array] = []
var seed_value := 0


static func generate(p_seed: int) -> StarMap:
	var map := StarMap.new()
	map.seed_value = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	for c in JUMPS + 1:
		var count := 1 if c == 0 or c == JUMPS else rng.randi_range(MIN_PER_COLUMN, MAX_PER_COLUMN)
		var ids: Array[int] = []
		for i in count:
			var band := 1.0 / count
			var y := 0.5 if count == 1 else band * (i + rng.randf_range(0.25, 0.75))
			var x := float(c) / JUMPS
			if c > 0 and c < JUMPS:
				x += rng.randf_range(-0.025, 0.025)
			var type := "kampf"
			if c == 0:
				type = "start"
			elif c == JUMPS:
				type = "boss"
			elif rng.randf() < EMPTY_CHANCE:
				type = "leer"
			ids.append(map.nodes.size())
			map.nodes.append({"id": map.nodes.size(), "column": c, "pos": Vector2(x, y), "type": type, "links": [] as Array[int]})
		map.columns.append(ids)
	for c in JUMPS:
		map._link_columns(map.columns[c], map.columns[c + 1], rng)
	return map


## Treppe von oben nach unten: Beide Spalten werden gleichzeitig abgelaufen, immer der
## Knoten mit dem kleineren nächsten y rückt vor. Ergibt kreuzungsfreie Verbindungen,
## an denen jeder Knoten beider Spalten hängt.
func _link_columns(a: Array, b: Array, rng: RandomNumberGenerator) -> void:
	var i := 0
	var j := 0
	_link(a[i], b[j])
	while i < a.size() - 1 or j < b.size() - 1:
		if i == a.size() - 1:
			j += 1
		elif j == b.size() - 1:
			i += 1
		else:
			var ya: float = nodes[a[i + 1]].pos.y
			var yb: float = nodes[b[j + 1]].pos.y
			if absf(ya - yb) < 0.08 and rng.randf() < 0.5:
				i += 1  # beide fast gleich hoch: gerade Verbindung statt Diagonale
				j += 1
			elif ya < yb:
				i += 1
			else:
				j += 1
		_link(a[i], b[j])


func _link(from: int, to: int) -> void:
	if not nodes[from].links.has(to):
		nodes[from].links.append(to)


func node(id: int) -> Dictionary:
	return nodes[id]


func start_id() -> int:
	return columns[0][0]


func boss_id() -> int:
	return columns[JUMPS][0]


## Vorgänger eines Knotens (für Tests und die Darstellung).
func incoming(id: int) -> Array[int]:
	var result: Array[int] = []
	for n in nodes:
		if n.links.has(id):
			result.append(n.id)
	return result
