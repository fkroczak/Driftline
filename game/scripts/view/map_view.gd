class_name MapView
extends Control
## Sternenkarte: Nebel, Sprungziele mit gestrichelten Verbindungen und das eigene Schiff.
## Oben eine Leiste mit Sprüngen, Hülle und Crew, unten eine Infozeile.
## Besucht = grün, erreichbar = gelb (pulsiert), unbekannt = weiß, Boss = roter Rhombus.

signal node_tapped(id: int)
signal background_tapped

const TOP_BAR := 14.0
const MAP_TOP := 34.0
const MAP_BOTTOM := 190.0
const SIDE := 24.0
## Großzügig, damit auch knapp daneben trifft (12 px = 60 px auf einem 1080p-Handy).
const TAP_RADIUS := 12.0
const FONT_SIZE := 8

const COLOR_BAR := Color("#0A0B16", 0.92)
const COLOR_BAR_LINE := Color("#185FA5")
const COLOR_TEXT := Color("#C4CAD3")
const COLOR_DIM := Color("#747D8A")
const COLOR_LINK := Color("#424A56")
const COLOR_VISITED := Color("#5DCAA5")
const COLOR_REACH := Color("#FAC775")
const COLOR_UNKNOWN := Color("#C4CAD3")
const COLOR_BOSS := Color("#E24B4A")
const COLOR_JUMPS := Color("#F09595")
const COLOR_SECTOR := Color("#85B7EB")
const COLOR_WARN := Color("#FAC775")
const COLOR_BOX := Color("#0A0B16", 0.9)
const COLOR_SHIP := Color("#E6EAF0")
const COLOR_OUTLINE := Color("#0A0B16")
const NEBULA_COLORS := [Color("#3C3489"), Color("#0F6E56"), Color("#72243E"), Color("#185FA5")]

var run: RunState
var selected := -1
var hint := ""
## Schiffssymbol: fliegt von ship_from nach ship_to, ship_t von 0 bis 1.
var ship_from := 0
var ship_to := 0
var ship_t := 1.0
var _time := 0.0
var _nebula: Array[Dictionary] = []  # {pos (0..1), radius (0..1), color}


func setup(p_run: RunState) -> void:
	run = p_run
	ship_from = run.current
	ship_to = run.current
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = run.seed_value
	_nebula.clear()
	for i in 5:
		_nebula.append({
			"pos": Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.2, 0.8)),
			"radius": Vector2(rng.randf_range(0.14, 0.28), rng.randf_range(0.18, 0.34)),
			"color": NEBULA_COLORS[rng.randi() % NEBULA_COLORS.size()],
		})


func set_ship_t(t: float) -> void:
	ship_t = t


func node_screen_pos(id: int) -> Vector2:
	var p: Vector2 = run.map.node(id).pos
	return Vector2(SIDE + p.x * (size.x - 2.0 * SIDE), MAP_TOP + p.y * (MAP_BOTTOM - MAP_TOP)).round()


## Nächster Knoten im Tippradius oder -1.
func node_at(pos: Vector2) -> int:
	var best := -1
	var best_dist := TAP_RADIUS
	for n in run.map.nodes:
		var d := node_screen_pos(n.id).distance_to(pos)
		if d <= best_dist:
			best = n.id
			best_dist = d
	return best


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := node_at(event.position)
		if id >= 0:
			node_tapped.emit(id)
		else:
			background_tapped.emit()
		accept_event()


func _draw() -> void:
	if not run:
		return
	_draw_nebula()
	_draw_links()
	for n in run.map.nodes:
		_draw_node(n)
	_draw_ship()
	_draw_labels()
	if selected >= 0:
		_draw_info_box(selected)
	_draw_top_bar()
	_draw_hint()


## Weiche Nebel aus mehreren übereinanderliegenden Ellipsen.
func _draw_nebula() -> void:
	var area := Vector2(size.x, MAP_BOTTOM - MAP_TOP + 40.0)
	for blob in _nebula:
		var center := Vector2(blob.pos.x * size.x, MAP_TOP - 20.0 + blob.pos.y * area.y)
		var radius := Vector2(blob.radius.x * size.x, blob.radius.y * area.y)
		for step in 4:
			var k := 1.0 - step * 0.22
			draw_set_transform(center, 0.0, radius * k / 10.0)
			draw_circle(Vector2.ZERO, 10.0, Color(blob.color, 0.07))
	draw_set_transform(Vector2.ZERO)


func _draw_links() -> void:
	for n in run.map.nodes:
		var from := node_screen_pos(n.id)
		for to_id: int in n.links:
			var to := node_screen_pos(to_id)
			if run.visited.has(n.id) and run.visited.has(to_id):
				draw_line(from, to, Color(COLOR_VISITED, 0.8), 1.0)
			elif n.id == run.current and run.can_jump_to(to_id):
				draw_dashed_line(from, to, COLOR_REACH, 1.0, 3.0)
			else:
				draw_dashed_line(from, to, COLOR_LINK, 1.0, 2.0)


func _draw_node(n: Dictionary) -> void:
	var p := node_screen_pos(n.id)
	var reachable := run.can_jump_to(n.id)
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	if reachable:
		draw_arc(p, 5.0 + pulse, 0.0, TAU, 16, Color(COLOR_REACH, 0.4 + 0.4 * pulse), 1.0)
	if n.id == run.current and run.needs_battle():
		draw_arc(p, 6.0 + pulse, 0.0, TAU, 16, Color(COLOR_BOSS, 0.5 + 0.5 * pulse), 1.0)
	if n.type == "boss":
		var r := 4.0
		var pts := PackedVector2Array([p + Vector2(0, -r - 1), p + Vector2(r + 1, 0), p + Vector2(0, r + 1), p + Vector2(-r - 1, 0)])
		draw_colored_polygon(pts, COLOR_OUTLINE)
		pts = PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		draw_colored_polygon(pts, COLOR_BOSS)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color("#F7C1C1"))
		return
	var color := COLOR_UNKNOWN
	var radius := 2.0
	if run.visited.has(n.id):
		color = COLOR_VISITED
		radius = 2.5
	elif reachable:
		color = COLOR_REACH
		radius = 3.0
	draw_circle(p, radius + 1.0, COLOR_OUTLINE)
	draw_circle(p, radius, color)


## Pfeil in Flugrichtung, beim Sprung mit kurzem Lichtschweif.
func _draw_ship() -> void:
	var a := node_screen_pos(ship_from)
	var b := node_screen_pos(ship_to)
	var t := ease(ship_t, -2.0)
	var p := a.lerp(b, t)
	var dir := (b - a).normalized() if a != b else Vector2.RIGHT
	if ship_t < 1.0:
		draw_line(p - dir * 14.0 * sin(PI * ship_t), p, Color(COLOR_SHIP, 0.5), 1.0)
	var pts := PackedVector2Array()
	for v: Vector2 in [Vector2(6, 0), Vector2(-3, -4), Vector2(-1, 0), Vector2(-3, 4)]:
		pts.append(p + v.rotated(dir.angle()) + Vector2(0, -7))
	var outline := PackedVector2Array()
	for v: Vector2 in [Vector2(8, 0), Vector2(-4, -6), Vector2(-2, 0), Vector2(-4, 6)]:
		outline.append(p + v.rotated(dir.angle()) + Vector2(0, -7))
	draw_colored_polygon(outline, COLOR_OUTLINE)
	draw_colored_polygon(pts, COLOR_SHIP)


func _draw_labels() -> void:
	var boss := run.map.boss_id()
	_draw_tag(node_screen_pos(boss) + Vector2(0, -16), "BOSS", COLOR_BOSS, true)
	_draw_tag(node_screen_pos(run.map.start_id()) + Vector2(0, 8), "START", COLOR_VISITED, true)


## Beschriftung mit Rahmen; `centered` richtet sie mittig über/unter dem Punkt aus.
func _draw_tag(pos: Vector2, text: String, color: Color, centered: bool) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var rect := Rect2(pos - Vector2(w / 2.0 + 3.0 if centered else 0.0, 0), Vector2(w + 6.0, 11.0))
	rect.position.x = clampf(rect.position.x, 2.0, size.x - rect.size.x - 2.0)
	rect.position = rect.position.round()
	draw_rect(rect, COLOR_BOX)
	draw_rect(rect.grow(-0.5), color, false, 1.0)
	draw_string(font, rect.position + Vector2(3, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## Infofeld neben dem ausgewählten Ziel (GDD: Antippen zeigt Infos, zweites Antippen springt).
func _draw_info_box(id: int) -> void:
	var n := run.map.node(id)
	var title := "Unerforschtes System"
	if n.type == "boss":
		title = "Flaggschiff der Piraten"
	var line := "1 Sprung · nochmal antippen"
	var font := ThemeDB.fallback_font
	var w := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x,
		font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var p := node_screen_pos(id)
	var rect := Rect2(p + Vector2(8, -26), Vector2(w + 8.0, 22.0))
	if rect.end.x > size.x - 2.0:
		rect.position.x = p.x - 8.0 - rect.size.x
	rect.position.y = clampf(rect.position.y, TOP_BAR + 2.0, MAP_BOTTOM - rect.size.y)
	rect.position = rect.position.round()
	draw_rect(rect, COLOR_BOX)
	draw_rect(rect.grow(-0.5), COLOR_REACH, false, 1.0)
	draw_string(font, rect.position + Vector2(4, 9), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_SHIP)
	draw_string(font, rect.position + Vector2(4, 19), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_REACH)


func _draw_top_bar() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, size.x, TOP_BAR), COLOR_BAR)
	draw_rect(Rect2(0, TOP_BAR, size.x, 1), COLOR_BAR_LINE)
	var ship := run.ship
	var ratio := float(ship.hull) / maxf(ship.max_hull, 1)
	var hull_color := COLOR_VISITED if ratio > 0.5 else (COLOR_WARN if ratio > 0.25 else COLOR_BOSS)
	var items := [
		["SPRÜNGE %d/%d" % [run.jumps_done(), StarMap.JUMPS], COLOR_JUMPS],
		["HÜLLE %d/%d" % [ship.hull, ship.max_hull], hull_color],
		["CREW %d" % ship.crew.size(), COLOR_TEXT],
	]
	var x := 6.0
	for item: Array in items:
		draw_string(font, Vector2(x, 10), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, item[1])
		x += font.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 14.0
	var sector := "UNIVERSUM 1"
	var w := font.get_string_size(sector, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(size.x - w - 6.0, 10), sector, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_SECTOR)


func _draw_hint() -> void:
	if hint == "":
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, size.y - 14.0, size.x, 14.0), COLOR_BAR)
	draw_string(font, Vector2(6, size.y - 4.0), hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, FONT_SIZE, COLOR_DIM.lightened(0.3))
