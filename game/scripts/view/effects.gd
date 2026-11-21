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
	for r in _rings:
		var t: float = 1.0 - r.life / r.max
		draw_arc(r.pos, lerpf(r.r0, r.r1, t), 0, TAU, 16, Color(r.color, 1.0 - t), 1.0)
	for f in _flashes:
		var t: float = f.life / f.max
		draw_circle(f.pos, maxf(f.r * (0.6 + 0.4 * t), 1.0), Color(f.color, t))
	for p in _particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
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


## Geschoss als kurzer Strahl mit hellem Kern und leichtem Schein.
func _draw_bolt(head: Vector2, dir: Vector2, color: Color, width: float, alpha: float) -> void:
	var tail := head - dir * (8.0 + width * 3.0)
	draw_line(tail, head, Color(color, 0.35 * alpha), width + 2.0)
	draw_line(tail, head, Color(color, alpha), width)
	draw_line(head - dir * 3.0, head, Color(1, 1, 1, alpha), 1.0)
