class_name StarMap
extends RefCounted
## Sprungkarte eines Sektors. Reine Logik, keine Nodes.
##
## 20–25 Systeme liegen frei verteilt (Mindestabstand) auf der Karte, Start ganz links,
## Ausgang ganz rechts (im Jagd-Modus mit Boss, im Endlos-Modus nur der Ausgang). Jede Karte
## sieht anders aus: Lage, Zahl und Verbindungen der Systeme hängen am Seed.
##
## Verbindungen: Delaunay-Dreiecke über alle Systeme (kreuzungsfrei), davon bleiben der
## minimale Spannbaum (alles ist erreichbar) und die kurzen Kanten; ein Teil der übrigen fällt
## zufällig weg. Verbindungen gelten in beide Richtungen, man kann also auch zurückspringen.
## Der kürzeste Weg vom Start zum Ausgang braucht MIN_PATH bis MAX_PATH Sprünge.
##
## Knotentypen: "start", "boss" bzw. "ausgang", "kampf", "ereignis" (Textentscheidung), "leer",
## "haendler" und "reparatur" (Reparaturstation). Je Karte zwei Händler (einer in der linken,
## einer in der rechten Hälfte) und eine Reparaturstation (Mitte); sie sind auf der Karte sichtbar.
##
## Jeder Knoten: {id, column, pos: Vector2 (0..1 in beiden Achsen), type, links: Array[int]}.
## `column` ist der Fortschritt von links nach rechts (0..10) und bestimmt die Gegnerstufe.

const MIN_NODES := 20
const MAX_NODES := 25
## Seitenverhältnis der Kartenfläche (Breite : Höhe), damit Abstände auf dem Bildschirm stimmen.
const ASPECT := 2.5
const MIN_DIST := 0.3
## Längere Kanten (im Seitenverhältnis gemessen) fallen weg, außer sie halten die Karte zusammen.
const MAX_LINK := 0.62
## Anteil der übrigen Kanten (nicht im Spannbaum), der zufällig wegfällt.
const DROP_LINKS := 0.3
const MIN_PATH := 5
const MAX_PATH := 8
const PROGRESS_STEPS := 10
## Anteile der übrigen Systeme.
const TYPE_WEIGHTS := {"kampf": 0.45, "ereignis": 0.42, "leer": 0.13}
## Feste Stationen: [Typ, linker Rand, rechter Rand] (x von 0 bis 1).
const STATIONS := [["haendler", 0.15, 0.5], ["haendler", 0.5, 0.88], ["reparatur", 0.3, 0.8]]

var nodes: Array[Dictionary] = []
var seed_value := 0
var exit_type := "boss"


static func generate(p_seed: int, p_exit_type := "boss") -> StarMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var map := StarMap.new()
	for attempt in 30:
		map = StarMap.new()
		map.seed_value = p_seed
		map.exit_type = p_exit_type
		map._build(rng)
		var steps := map.distance(map.start_id(), map.exit_id())
		if steps >= MIN_PATH and steps <= MAX_PATH:
			break
	return map


func _build(rng: RandomNumberGenerator) -> void:
	var points: Array[Vector2] = []
	points.append(Vector2(0.02, rng.randf_range(0.3, 0.7)))
	points.append(Vector2(0.98, rng.randf_range(0.3, 0.7)))
	var target := rng.randi_range(MIN_NODES, MAX_NODES)
	var min_dist := MIN_DIST
	var tries := 0
	while points.size() < target:
		var p := Vector2(rng.randf_range(0.09, 0.91), rng.randf_range(0.05, 0.95))
		var ok := true
		for q in points:
			if _scaled(p).distance_to(_scaled(q)) < min_dist:
				ok = false
				break
		if ok:
			points.append(p)
		tries += 1
		if tries % 400 == 0:
			min_dist *= 0.92  # zu eng: Abstand etwas lockern
	# Start = 0, dann von links nach rechts sortiert, Ausgang zuletzt.
	var exit_point := points[1]
	points.remove_at(1)
	var inner := points.slice(1)
	inner.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var ordered: Array[Vector2] = [points[0]]
	ordered.append_array(inner)
	ordered.append(exit_point)
	points = ordered
	for i in points.size():
		var type := "kampf"
		if i == 0:
			type = "start"
		elif i == points.size() - 1:
			type = exit_type
		else:
			type = _roll_type(rng)
		nodes.append({"id": i, "column": roundi(points[i].x * PROGRESS_STEPS), "pos": points[i], "type": type,
			"links": [] as Array[int]})
	_connect(points, rng)
	_place_stations(rng)


static func _scaled(p: Vector2) -> Vector2:
	return Vector2(p.x * ASPECT, p.y)


static func _roll_type(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	for type: String in TYPE_WEIGHTS:
		roll -= TYPE_WEIGHTS[type]
		if roll <= 0.0:
			return type
	return "kampf"


func _connect(points: Array[Vector2], rng: RandomNumberGenerator) -> void:
	var scaled := PackedVector2Array()
	for p in points:
		scaled.append(_scaled(p))
	var tris := Geometry2D.triangulate_delaunay(scaled)
	var edges := {}  # Vector2i(a, b) mit a < b -> Länge
	for t in range(0, tris.size(), 3):
		for k in 3:
			var a := tris[t + k]
			var b := tris[t + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			edges[key] = scaled[a].distance_to(scaled[b])
	var sorted: Array = edges.keys()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return edges[a] < edges[b])
	# Minimaler Spannbaum (Kruskal): hält alles zusammen
	var parent := range(points.size())
	var tree := {}
	for e: Vector2i in sorted:
		var ra := _root(parent, e.x)
		var rb := _root(parent, e.y)
		if ra != rb:
			parent[ra] = rb
			tree[e] = true
	for e: Vector2i in sorted:
		var keep: bool = tree.has(e) or (edges[e] <= MAX_LINK and rng.randf() >= DROP_LINKS)
		if keep:
			_link(e.x, e.y)


static func _root(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


## Händler und Reparaturstation auf zufällige Knoten ihres Bereichs, nie zwei auf denselben.
func _place_stations(rng: RandomNumberGenerator) -> void:
	var taken := {}
	for station: Array in STATIONS:
		var options: Array[int] = []
		for n in nodes:
			if n.type in ["start", "boss", "ausgang"] or taken.has(n.id):
				continue
			if n.pos.x >= station[1] and n.pos.x <= station[2]:
				options.append(n.id)
		if options.is_empty():
			continue
		var id: int = options[rng.randi() % options.size()]
		nodes[id].type = station[0]
		taken[id] = true


func _link(a: int, b: int) -> void:
	if a == b:
		return
	if not nodes[a].links.has(b):
		nodes[a].links.append(b)
	if not nodes[b].links.has(a):
		nodes[b].links.append(a)


## Verbindungen in beide Richtungen (auch für Karten aus älteren Spielständen).
func make_links_mutual() -> void:
	for n in nodes:
		for to: int in n.links.duplicate():
			if to >= 0 and to < nodes.size() and not nodes[to].links.has(n.id):
				nodes[to].links.append(n.id)


func count_type(type: String) -> int:
	return nodes.filter(func(n: Dictionary) -> bool: return n.type == type).size()


func node(id: int) -> Dictionary:
	return nodes[id]


func start_id() -> int:
	for n in nodes:
		if n.type == "start":
			return n.id
	return 0


## Ausgang des Sektors (Boss im Jagd-Modus).
func exit_id() -> int:
	for n in nodes:
		if n.type == "boss" or n.type == "ausgang":
			return n.id
	return nodes.size() - 1


func boss_id() -> int:
	return exit_id()


## Kürzeste Zahl Sprünge zwischen zwei Knoten (-1 = nicht verbunden).
func distance(from: int, to: int) -> int:
	var dist := {from: 0}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if id == to:
			return dist[id]
		for n: int in nodes[id].links:
			if not dist.has(n):
				dist[n] = dist[id] + 1
				queue.append(n)
	return -1
