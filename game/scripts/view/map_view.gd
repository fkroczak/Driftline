class_name MapView
extends Control
## Sternenkarte als Überlagerung über dem Schiff (Mockup art/pixel/sprungkarte_pixel.png):
## Nebel, Sprungziele mit gestrichelten Verbindungen, das eigene Schiff, im Jagd-Modus die rote
## Jägerfront von links. Oben eine Leiste mit Treibstoff, Rohstoffen, Hülle, Crew, Sprüngen und
## Sektor, unten eine Infozeile und die Knöpfe ZURÜCK und (ohne Treibstoff) NOTSIGNAL.
##
## Besucht = grün, erreichbar = gelb (pulsiert, nur wenn der Antrieb geladen ist), unbekannt = weiß,
## von Jägern besetzt = rot, Boss = roter Rhombus, Ausgang = blauer Ring, Händler = oranges und
## Reparaturstation = blaues Quadrat (immer sichtbar), Notruf = roter Ring (SENSOR_RANGE Sprünge weit),
## Auftragsziel = violettes Banner mit „!“ und Beschriftung AUFTRAG (immer sichtbar).

signal node_tapped(id: int)
signal background_tapped
signal distress_pressed
signal closed

const TOP_BAR := 14.0
const MAP_TOP := 30.0
const MAP_BOTTOM := 190.0
const SIDE := 24.0
## Großzügig, damit auch knapp daneben trifft (12 px = 60 px auf einem 1080p-Handy).
const TAP_RADIUS := 12.0
## So viele Sprünge weit sind Notrufe zu sehen (später abhängig vom Sensorsystem).
const SENSOR_RANGE := 2
const FONT_SIZE := 8

const COLOR_BG := Color("#07080F", 0.97)
const COLOR_BAR := Color("#0A0B16", 0.92)
const COLOR_BAR_LINE := Color("#185FA5")
const COLOR_TEXT := Color("#C4CAD3")
const COLOR_DIM := Color("#747D8A")
const COLOR_LINK := Color("#424A56")
const COLOR_VISITED := Color("#5DCAA5")
const COLOR_REACH := Color("#FAC775")
const COLOR_UNKNOWN := Color("#C4CAD3")
const COLOR_BOSS := Color("#E24B4A")
const COLOR_FUEL := Color("#EF9F27")
const COLOR_SCRAP := Color("#A9B0BB")
const COLOR_SHOP := Color("#EF9F27")
const COLOR_REPAIR := Color("#85B7EB")
const COLOR_EXIT := Color("#85B7EB")
const COLOR_QUEST := Color("#A6A0EA")
const COLOR_WARN := Color("#FAC775")
const COLOR_BOX := Color("#0A0B16", 0.9)
const COLOR_SHIP := Color("#E6EAF0")
const COLOR_OUTLINE := Color("#0A0B16")
const COLOR_FRONT := Color("#3A1218")
const COLOR_FRONT_EDGE := Color("#E24B4A")
const NEBULA_COLORS := [Color("#3C3489"), Color("#0F6E56"), Color("#72243E"), Color("#185FA5")]

var run: RunState
var selected := -1
var hint := ""
## Antrieb geladen: Ziele sind wählbar. Sonst zeigt die Karte nur, wohin es gehen kann.
var can_jump := true
## Schiffssymbol: fliegt von ship_from nach ship_to, ship_t von 0 bis 1.
var ship_from := 0
var ship_to := 0
var ship_t := 1.0
var _time := 0.0
var _nebula: Array[Dictionary] = []  # {pos (0..1), radius (0..1), color}
var _stars: Array[Vector2] = []
var _seed := -1


func setup(p_run: RunState) -> void:
	run = p_run
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


## Nach einem Sprung oder Sektorwechsel: Schiff an seinen Platz, neuer Nebel für eine neue Karte.
func refresh() -> void:
	ship_from = run.current
	ship_to = run.current
	ship_t = 1.0
	selected = -1
	var seed_value: int = run.map.seed_value
	if seed_value == _seed:
		return
	_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_nebula.clear()
	for i in 6:
		_nebula.append({
			"pos": Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.15, 0.85)),
			"radius": Vector2(rng.randf_range(0.12, 0.26), rng.randf_range(0.18, 0.36)),
			"color": NEBULA_COLORS[rng.randi() % NEBULA_COLORS.size()],
		})
	_stars.clear()
	for i in 90:
		_stars.append(Vector2(rng.randf(), rng.randf()))


func set_ship_t(t: float) -> void:
	ship_t = t


func node_screen_pos(id: int) -> Vector2:
	var p: Vector2 = run.map.node(id).pos
	return Vector2(SIDE + p.x * (size.x - 2.0 * SIDE), MAP_TOP + 6.0 + p.y * (MAP_BOTTOM - MAP_TOP - 12.0)).round()


## x auf dem Bildschirm zu einer Lage auf der Karte (für die Jägerfront).
func _map_x(x: float) -> float:
	return SIDE + x * (size.x - 2.0 * SIDE)


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


func reachable(id: int) -> bool:
	return can_jump and run.can_jump_to(id)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func back_rect() -> Rect2:
	return Rect2(size.x - 50.0, size.y - 32.0, 46.0, 16.0)


## Knopf für das Notsignal (nur ohne Treibstoff sichtbar).
func distress_rect() -> Rect2:
	return Rect2(size.x - 112.0, size.y - 32.0, 58.0, 16.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if back_rect().grow(3.0).has_point(event.position):
			closed.emit()
			return
		if run.can_send_distress() and distress_rect().grow(3.0).has_point(event.position):
			distress_pressed.emit()
			return
		var id := node_at(event.position)
		if id >= 0:
			node_tapped.emit(id)
		else:
			background_tapped.emit()


func _draw() -> void:
	if not run:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	for s in _stars:
		draw_rect(Rect2((s * size).floor(), Vector2.ONE), Color("#5A6370"))
	_draw_nebula()
	_draw_front()
	_draw_links()
	for n in run.map.nodes:
		_draw_node(n)
	_draw_ship()
	_draw_labels()
	if selected >= 0:
		_draw_info_box(selected)
	_draw_top_bar()
	_draw_version()
	_draw_hint()
	_draw_button(back_rect(), Loc.t("ZURÜCK"), COLOR_TEXT, false)
	if run.can_send_distress():
		_draw_button(distress_rect(), Loc.t("NOTSIGNAL"), Color("#F7C1C1"), true)


## Weiche Nebel aus mehreren übereinanderliegenden Ellipsen.
func _draw_nebula() -> void:
	var area := Vector2(size.x, MAP_BOTTOM - MAP_TOP + 40.0)
	for blob in _nebula:
		var center := Vector2(blob.pos.x * size.x, MAP_TOP - 20.0 + blob.pos.y * area.y)
		var radius := Vector2(blob.radius.x * size.x, blob.radius.y * area.y)
		for step in 4:
			var k := 1.0 - step * 0.22
			draw_set_transform(center, 0.0, radius * k / 10.0)
			draw_circle(Vector2.ZERO, 10.0, Color(blob.color, 0.08))
	draw_set_transform(Vector2.ZERO)


## Jägerfront: rote Fläche von links bis zur gewellten Frontlinie, dahinter die Vorschau
## des nächsten Vorrückens als dünne Linie.
func _draw_front() -> void:
	if not run.is_hunt():
		return
	var top := TOP_BAR + 1.0
	var bottom := size.y - 14.0
	var poly := PackedVector2Array([Vector2(0, top)])
	var line := PackedVector2Array()
	var next := PackedVector2Array()
	for i in 41:
		var y := lerpf(top, bottom, i / 40.0)
		var my := clampf((y - MAP_TOP - 6.0) / (MAP_BOTTOM - MAP_TOP - 12.0), -0.2, 1.2)
		var x := _map_x(run.front_at(my))
		poly.append(Vector2(maxf(x, 0.0), y))
		line.append(Vector2(x, y))
		next.append(Vector2(_map_x(run.front_at(my, run.front + RunState.FRONT_STEP)), y))
	poly.append(Vector2(0, bottom))
	if _map_x(run.front + RunState.FRONT_WAVE) > 0.0:
		draw_colored_polygon(poly, Color(COLOR_FRONT, 0.85))
		draw_polyline(line, COLOR_FRONT_EDGE, 1.0)
	for i in range(0, next.size() - 1, 2):
		draw_line(next[i], next[i + 1], Color(COLOR_FRONT_EDGE, 0.35 + 0.15 * sin(_time * 3.0)), 1.0)
	var label_x := clampf(_map_x(run.front) - 60.0, 4.0, size.x - 70.0)
	_draw_tag(Vector2(label_x, bottom - 14.0), Loc.t("JÄGERFRONT"), COLOR_FRONT_EDGE, false)


func _draw_links() -> void:
	for n in run.map.nodes:
		var from := node_screen_pos(n.id)
		for to_id: int in n.links:
			if to_id < n.id and not (n.id == run.current or to_id == run.current):
				continue  # jede Verbindung nur einmal
			var to := node_screen_pos(to_id)
			if n.id == run.current and reachable(to_id):
				draw_dashed_line(from, to, COLOR_REACH, 1.0, 3.0)
			elif to_id == run.current and reachable(n.id):
				continue
			elif run.visited.has(n.id) and run.visited.has(to_id):
				draw_line(from, to, Color(COLOR_VISITED, 0.6), 1.0)
			else:
				draw_dashed_line(from, to, COLOR_LINK, 1.0, 2.0)


func _draw_node(n: Dictionary) -> void:
	var p := node_screen_pos(n.id)
	var can := reachable(n.id)
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	var overrun := run.is_overrun(n.id)
	if can:
		draw_arc(p, 5.0 + pulse, 0.0, TAU, 16, Color(COLOR_BOSS if overrun else COLOR_REACH, 0.4 + 0.4 * pulse), 1.0)
	if n.type == "boss" or n.type == "ausgang":
		var ring := 8.0 + pulse
		draw_arc(p, ring, 0.0, TAU, 24, Color(COLOR_EXIT, 0.7), 2.0)
		draw_arc(p, ring - 3.0, 0.0, TAU, 20, Color(COLOR_EXIT, 0.3), 1.0)
	if n.type == "boss" and not run.cleared.has(n.id):
		var r := 4.0
		var pts := PackedVector2Array([p + Vector2(0, -r - 1), p + Vector2(r + 1, 0), p + Vector2(0, r + 1), p + Vector2(-r - 1, 0)])
		draw_colored_polygon(pts, COLOR_OUTLINE)
		pts = PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		draw_colored_polygon(pts, COLOR_BOSS)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color("#F7C1C1"))
		return
	if (n.type == "haendler" or n.type == "reparatur") and not overrun:
		var c := COLOR_SHOP if n.type == "haendler" else COLOR_REPAIR
		draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), COLOR_OUTLINE)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), c if not run.visited.has(n.id) else c.darkened(0.3))
		return
	if run.is_quest_target(n.id) and not overrun:
		_draw_quest_marker(p, pulse)
	elif _beacon_visible(n.id):
		draw_arc(p, 4.5, 0.0, TAU, 14, COLOR_BOSS, 1.0)
	var color := COLOR_UNKNOWN
	var radius := 2.0
	if overrun:
		color = COLOR_BOSS
	elif run.visited.has(n.id):
		color = COLOR_VISITED
		radius = 2.5
	if can and not overrun:
		color = COLOR_REACH
		radius = 3.0
	draw_circle(p, radius + 1.0, COLOR_OUTLINE)
	draw_circle(p, radius, color)


## Auftragsziel: pulsierender Ring und ein Fähnchen mit „!“ über dem System.
func _draw_quest_marker(p: Vector2, pulse: float) -> void:
	draw_arc(p, 5.5 + pulse, 0.0, TAU, 18, Color(COLOR_QUEST, 0.5 + 0.4 * pulse), 1.0)
	var top := p + Vector2(0, -13)
	var pts := PackedVector2Array([top + Vector2(0, -5), top + Vector2(5, 0), top + Vector2(0, 5), top + Vector2(-5, 0)])
	draw_colored_polygon(pts, COLOR_OUTLINE)
	pts = PackedVector2Array([top + Vector2(0, -4), top + Vector2(4, 0), top + Vector2(0, 4), top + Vector2(-4, 0)])
	draw_colored_polygon(pts, COLOR_QUEST)
	draw_rect(Rect2(top + Vector2(-0.5, -2.5), Vector2(1, 3)), COLOR_OUTLINE)
	draw_rect(Rect2(top + Vector2(-0.5, 1.5), Vector2(1, 1)), COLOR_OUTLINE)
	draw_line(top + Vector2(0, 5), p + Vector2(0, -4), COLOR_QUEST, 1.0)


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
		pts.append(p + v.rotated(dir.angle()) + Vector2(0, -8))
	var outline := PackedVector2Array()
	for v: Vector2 in [Vector2(8, 0), Vector2(-4, -6), Vector2(-2, 0), Vector2(-4, 6)]:
		outline.append(p + v.rotated(dir.angle()) + Vector2(0, -8))
	draw_colored_polygon(outline, COLOR_OUTLINE)
	draw_colored_polygon(pts, COLOR_SHIP)


func _draw_labels() -> void:
	var exit_id := run.map.exit_id()
	var exit_pos := node_screen_pos(exit_id)
	if run.map.node(exit_id).type == "boss" and not run.cleared.has(exit_id):
		_draw_tag(exit_pos + Vector2(0, -22), Loc.t("BOSS"), COLOR_BOSS, true)
	_draw_tag(exit_pos + Vector2(0, 12), Loc.t("AUSGANG"), COLOR_EXIT, true)
	if run.jumps_done() == 0 and run.current == run.map.start_id():
		_draw_tag(node_screen_pos(run.current) + Vector2(0, 8), Loc.t("START"), COLOR_VISITED, true)
	for n in run.map.nodes:
		if run.is_overrun(n.id):
			continue
		var below := node_screen_pos(n.id) + Vector2(0, 6)
		if run.is_quest_target(n.id):
			var left := run.quest_jumps_left(n.id)
			var tag := Loc.t("AUFTRAG") if left < 0 else Loc.t("AUFTRAG · %d") % left
			_draw_tag(below, tag, COLOR_BOSS if left == 1 else COLOR_QUEST, true)
		elif n.type == "haendler" and not run.visited.has(n.id):
			_draw_tag(below, Loc.t("HÄNDLER"), COLOR_SHOP, true)
		elif n.type == "reparatur" and not run.visited.has(n.id):
			_draw_tag(below, Loc.t("REPARATUR"), COLOR_REPAIR, true)
		elif _beacon_visible(n.id):
			_draw_tag(below, Loc.t("NOTRUF"), COLOR_BOSS, true)


func _beacon_visible(id: int) -> bool:
	if not run.is_beacon(id) or run.visited.has(id) or run.is_overrun(id):
		return false
	var d := run.map.distance(run.current, id)
	return d >= 0 and d <= SENSOR_RANGE


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


func _draw_button(rect: Rect2, text: String, color: Color, pulse: bool) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(rect, COLOR_BOX)
	if pulse:
		draw_rect(rect, Color(COLOR_BOSS, 0.15 + 0.2 * (0.5 + 0.5 * sin(_time * 5.0))))
	draw_rect(rect.grow(-0.5), COLOR_BOSS if pulse else COLOR_BAR_LINE, false, 1.0)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, rect.position + Vector2(roundf((rect.size.x - w) / 2.0), 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## Infofeld neben dem ausgewählten Ziel (GDD: Antippen zeigt Infos, zweites Antippen springt).
func _draw_info_box(id: int) -> void:
	var n := run.map.node(id)
	var title := Loc.t("Unerforschtes System") if not run.visited.has(id) else Loc.t("Besuchtes System")
	match n.type:
		"boss":
			title = Loc.t("Flaggschiff der Piraten · Ausgang") if not run.cleared.has(id) else Loc.t("Ausgang")
		"ausgang":
			title = Loc.t("Ausgang: nächster Sektor")
		"haendler":
			title = Loc.t("Händler: Treibstoff, Reparatur")
		"reparatur":
			title = Loc.t("Reparaturstation")
	if _beacon_visible(id):
		title = Loc.t("Notruf empfangen")
	if run.is_quest_target(id):
		title = Loc.t("Auftrag: %s") % Loc.t(run.quests[id].title)
		var left := run.quest_jumps_left(id)
		if left == 1:
			title += Loc.t(" · letzter Sprung!")
		elif left > 1:
			title += Loc.t(" · noch %d Sprünge") % left
	var line := Loc.t("%d Treibstoff · nochmal antippen") % run.jump_cost()
	var line_color := COLOR_REACH
	var soon := run.jumps_until_overrun(id)
	if run.is_overrun(id):
		title = Loc.t("Von Jägern besetzt")
		line = Loc.t("Kampf gegen die Jäger! · nochmal antippen")
		line_color = COLOR_BOSS
	elif not can_jump:
		line = Loc.t("Antrieb lädt noch · erst SPRUNG")
		line_color = COLOR_DIM
	elif run.fuel < run.jump_cost():
		line = Loc.t("Kein Treibstoff: Notsignal senden")
		line_color = COLOR_BOSS
	elif soon > 0 and soon <= 2:
		line = (Loc.t("Jäger in 1 Sprung hier · %d Treibstoff") % run.jump_cost()) if soon == 1 else (Loc.t("Jäger in %d Sprüngen hier · %d Treibstoff") % [soon, run.jump_cost()])
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
	draw_rect(rect.grow(-0.5), line_color if line_color != COLOR_DIM else COLOR_REACH, false, 1.0)
	draw_string(font, rect.position + Vector2(4, 9), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_SHIP)
	draw_string(font, rect.position + Vector2(4, 19), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, line_color)


func _draw_top_bar() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, size.x, TOP_BAR), COLOR_BAR)
	draw_rect(Rect2(0, TOP_BAR, size.x, 1), COLOR_BAR_LINE)
	var ship := run.ship
	var ratio := float(ship.hull) / maxf(ship.max_hull, 1)
	var hull_color := COLOR_VISITED if ratio > 0.5 else (COLOR_WARN if ratio > 0.25 else COLOR_BOSS)
	var fuel_color := COLOR_BOSS if run.fuel < run.jump_cost() else (COLOR_WARN if run.fuel <= 2 else COLOR_FUEL)
	# Text, Farbe, Symbol (Treibstoff, Rohstoffe und Hülle als Symbol statt Wort)
	var items := [
		["%d" % run.fuel, fuel_color, "fuel"],
		["%d" % run.scrap, COLOR_SCRAP, "scrap"],
		["%d/%d" % [ship.hull, ship.max_hull], hull_color, "hull"],
		[Loc.t("SEKTOR %d") % run.sector if run.is_hunt() else Loc.t("SEKTOR %d · ENDLOS") % run.sector, COLOR_REPAIR, ""],
	]
	var widths: Array[float] = []
	var total := 0.0
	for item: Array in items:
		widths.append(font.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + (9.0 if item[2] != "" else 0.0))
		total += widths.back()
	var gap := clampf((size.x - 12.0 - total) / (items.size() - 1), 6.0, 24.0)
	var x := 6.0
	for i in items.size():
		var tx := x
		if items[i][2] != "":
			HudStyle.icon(self, Vector2(x, 3), items[i][2], items[i][1])
			tx += 9.0
		draw_string(font, Vector2(tx, 10), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, items[i][1])
		x += widths[i] + gap


## Installierte Version oben rechts unter der Leiste, damit man nach einem Update sieht, welcher Build läuft.
func _draw_version() -> void:
	var font := ThemeDB.fallback_font
	var text := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(size.x - w - 4.0, TOP_BAR + 9.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_DIM)


func _draw_hint() -> void:
	if hint == "":
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, size.y - 14.0, size.x, 14.0), COLOR_BAR)
	draw_string(font, Vector2(6, size.y - 4.0), Loc.t(hint), HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, FONT_SIZE, COLOR_DIM.lightened(0.3))
