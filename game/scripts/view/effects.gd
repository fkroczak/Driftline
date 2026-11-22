class_name Effects
extends Node2D
## Kampfeffekte in Weltkoordinaten: Geschosse, Mündungsfeuer, Explosionen, Schildwellen,
## schwebende Texte. Reine Darstellung; was passiert, entscheidet Battle.
##
## Geschosse aus Battle.projectiles fliegen in ihrer Flugzeit bis an die Schildblase des
## Ziels. Dort zeigt der Einschlag, wie es ausging: Welle (Schild), Explosion (Treffer)
## oder Weiterflug (verfehlt).

const SPARK_COLORS := [Color("#FDE6BF"), Color("#FAC775"), Color("#EF9F27"), Color("#D85A30")]
const SMOKE_COLOR := Color("#424A56")
const FONT_SIZE := 8

var battle: Battle

var _bolts := {}  # Geschoss-ID -> {from, edge, to, color, width}
var _strays: Array[Dictionary] = []  # frei fliegende Geschosse (verfehlt)
var _particles: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _bubbles: Array[Dictionary] = []  # Warpblasen: {node, center, radius, life, max, expand}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func add_bolt(id: int, from: Vector2, edge: Vector2, to: Vector2, color: Color, width: float) -> void:
	_bolts[id] = {"from": from, "edge": edge, "to": to, "color": color, "width": width}


func take_bolt(id: int) -> Dictionary:
	var b: Dictionary = _bolts.get(id, {})
	_bolts.erase(id)
	return b


## Fehlschuss: Geschoss fliegt weiter durch das Bild und verblasst.
func stray(from: Vector2, dir: Vector2, color: Color, width: float) -> void:
	_strays.append({"from": from, "dir": dir, "t": 0.0, "dur": 0.35, "color": color, "width": width})


func muzzle(pos: Vector2, dir: Vector2, color: Color) -> void:
	_flashes.append({"pos": pos, "r": 3.0, "life": 0.09, "max": 0.09, "color": color})
	for i in 4:
		var v := dir.rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(30, 70)
		_spark(pos, v, color, 0.18)


func explosion(pos: Vector2, strength: float) -> void:
	_flashes.append({"pos": pos, "r": 4.0 + strength * 3.0, "life": 0.16, "max": 0.16, "color": Color("#FDE6BF")})
	_flashes.append({"pos": pos, "r": 2.0 + strength * 2.0, "life": 0.3, "max": 0.3, "color": Color("#EF9F27")})
	for i in int(8 + strength * 6):
		var v := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(25, 70 + strength * 15)
		_spark(pos, v, SPARK_COLORS[_rng.randi() % SPARK_COLORS.size()], _rng.randf_range(0.25, 0.6))
	for i in int(2 + strength * 2):
		var offset := Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
		_particles.append({
			"pos": pos + offset, "vel": Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-10, -2)),
			"life": 0.9, "max": 0.9, "color": SMOKE_COLOR, "size": 2.0, "grow": 4.0, "drag": 0.5,
		})


func shield_ripple(pos: Vector2, color: Color) -> void:
	_rings.append({"pos": pos, "life": 0.35, "max": 0.35, "r0": 2.0, "r1": 12.0, "color": color})
	for i in 6:
		_spark(pos, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(20, 45), color, 0.3)


func sparkle(pos: Vector2, color: Color) -> void:
	for i in 6:
		_spark(pos, Vector2(_rng.randf_range(-15, 15), _rng.randf_range(-35, -10)), color, 0.5)


## Einzelnes Teilchen, z. B. Rauch über Feuer oder entweichende Luft.
func puff(pos: Vector2, vel: Vector2, color: Color, life: float, grow := 0.0) -> void:
	_particles.append({"pos": pos, "vel": vel, "life": life, "max": life, "color": color,
		"size": 1.0, "grow": grow, "drag": 0.8})


## Warpblase um ein Schiff: `expand` = Abflug (Blase baut sich auf und blitzt),
## sonst Ankunft (Blase fällt in sich zusammen). Folgt dem Node, solange er sich bewegt.
func warp_bubble(node: Node2D, center: Vector2, radius: Vector2, duration: float, expand: bool) -> void:
	_bubbles.append({"node": node, "center": center, "radius": radius, "life": duration, "max": duration, "expand": expand})


## Lichtstreifen entlang eines Schiffs beim Sprung.
func warp_streaks(rect: Rect2, dir: Vector2, color: Color) -> void:
	for i in 18:
		var p := Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))
		_particles.append({"pos": p, "vel": dir * _rng.randf_range(160, 320), "life": 0.35, "max": 0.35,
			"color": color, "size": 1.0, "grow": 0.0, "drag": 0.0, "streak": true})


func float_text(pos: Vector2, text: String, color: Color) -> void:
	_texts.append({"pos": pos, "text": text, "color": color, "life": 0.9, "max": 0.9})


func _spark(pos: Vector2, vel: Vector2, color: Color, life: float) -> void:
	_particles.append({"pos": pos, "vel": vel, "life": life, "max": life, "color": color, "size": 1.0, "grow": 0.0, "drag": 3.0})


func _process(delta: float) -> void:
	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= maxf(1.0 - p.drag * delta, 0.0)
		p.size += p.grow * delta
		p.life -= delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for list: Array in [_flashes, _rings, _texts]:
		for f in list:
			f.life -= delta
	_flashes = _flashes.filter(func(f): return f.life > 0.0)
	_rings = _rings.filter(func(f): return f.life > 0.0)
	_texts = _texts.filter(func(f): return f.life > 0.0)
	for b in _bubbles:
		b.life -= delta
	_bubbles = _bubbles.filter(func(b): return b.life > 0.0 and is_instance_valid(b.node))
	for s in _strays:
		s.t += delta
	_strays = _strays.filter(func(s): return s.t < s.dur)
	queue_redraw()


func _draw() -> void:
	if battle and battle.outcome == "":
		for p in battle.projectiles:
			if p.fired and _bolts.has(p.id):
				var b: Dictionary = _bolts[p.id]
				var head: Vector2 = b.from.lerp(b.edge, clampf(p.time / p.duration, 0.0, 1.0))
				_draw_bolt(head, (b.edge - b.from).normalized(), b.color, b.width, 1.0)
	for s in _strays:
		var head: Vector2 = s.from + s.dir * 220.0 * s.t
		_draw_bolt(head, s.dir, s.color, s.width, 1.0 - s.t / s.dur)
	for b in _bubbles:
		_draw_bubble(b)
	for r in _rings:
		var t: float = 1.0 - r.life / r.max
		draw_arc(r.pos, lerpf(r.r0, r.r1, t), 0, TAU, 16, Color(r.color, 1.0 - t), 1.0)
	for f in _flashes:
		var t: float = f.life / f.max
		draw_circle(f.pos, maxf(f.r * (0.6 + 0.4 * t), 1.0), Color(f.color, t))
	for p in _particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		if p.get("streak", false):
			var v: Vector2 = p.vel * 0.06
			draw_line(p.pos - v, p.pos, Color(p.color, a), 1.0)
			continue
		var s := maxf(roundf(p.size), 1.0)
		draw_rect(Rect2(p.pos.round() - Vector2(s, s) / 2.0, Vector2(s, s)), Color(p.color, a * (0.6 if p.grow > 0.0 else 1.0)))
	var font := ThemeDB.fallback_font
	for t in _texts:
		var age: float = 1.0 - t.life / t.max
		var pos: Vector2 = (t.pos + Vector2(0, -12.0 * age)).round()
		var alpha := clampf(t.life / 0.3, 0.0, 1.0)
		var w := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var p := pos - Vector2(w / 2.0, 0).round()
		draw_string(font, p + Vector2(1, 1), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0, 0, 0, alpha))
		draw_string(font, p, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(t.color, alpha))


func _draw_bubble(b: Dictionary) -> void:
	var t: float = 1.0 - b.life / b.max  # 0 → 1
	var node: Node2D = b.node
	var center: Vector2 = node.position + b.center
	var scale := lerpf(0.55, 1.15, ease(t, 0.6)) if b.expand else lerpf(1.35, 0.85, ease(t, 2.0))
	var alpha := (sin(t * PI) * 0.9 + 0.1) if b.expand else (1.0 - t)
	var radius: Vector2 = b.radius * scale
	var points := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	# Füllung in Bändern, außen heller
	for k in 3:
		var f := 1.0 - k * 0.12
		var band := PackedVector2Array()
		for p in points:
			band.append(center + (p - center) * f)
		draw_colored_polygon(band, Color("#85B7EB", 0.06 * alpha))
	draw_polyline(points, Color("#D3E6F8", 0.9 * alpha), 1.0)
	var inner := PackedVector2Array()
	for p in points:
		inner.append(center + (p - center) * 0.93)
	draw_polyline(inner, Color("#378ADD", 0.6 * alpha), 1.0)
	# Glitzern auf der Blase
	for i in 6:
		var a := TAU * (i / 6.0 + t * 0.7)
		var p := center + Vector2(cos(a) * radius.x, sin(a) * radius.y)
		draw_rect(Rect2(p.round() - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 1, alpha))


## Geschoss als kurzer Strahl mit hellem Kern und leichtem Schein.
func _draw_bolt(head: Vector2, dir: Vector2, color: Color, width: float, alpha: float) -> void:
	var tail := head - dir * (8.0 + width * 3.0)
	draw_line(tail, head, Color(color, 0.35 * alpha), width + 2.0)
	draw_line(tail, head, Color(color, alpha), width)
	draw_line(head - dir * 3.0, head, Color(1, 1, 1, alpha), 1.0)
