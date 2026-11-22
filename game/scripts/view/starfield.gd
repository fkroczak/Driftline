class_name Starfield
extends Node2D
## Hintergrund: Sterne in drei Ebenen, die langsam nach links ziehen (Flug Richtung Bug).
## Füllt immer die ganze sichtbare Fläche, auch bei breiten Handys.
## `warp` (0..1) beschleunigt die Sterne beim Sprung zu Lichtstreifen; `reseed` zeigt nach
## der Ankunft einen anderen Himmel.

const LAYERS := [
	# Geschwindigkeit (px/s), Dichte (Sterne pro 1000 px²), Farben aus der Palette
	{"speed": 1.5, "density": 1.2, "colors": [Color("#2a2f3a"), Color("#363e58"), Color("#424a56")]},
	{"speed": 4.0, "density": 0.6, "colors": [Color("#5a6370"), Color("#747d8a"), Color("#185fa5")]},
	{"speed": 9.0, "density": 0.15, "colors": [Color("#c4cad3"), Color("#85b7eb"), Color("#fde6bf")]},
]
const BRIGHT_STARS := 6

@export var seed_value := 7
## Sprungeffekt: 0 = normal, 1 = volle Lichtgeschwindigkeit (Streifen).
var warp := 0.0

var _stars: Array[Dictionary] = []  # {pos, layer, color, big}
var _size := Vector2.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_generate)
	_generate()


func _generate() -> void:
	_size = get_viewport_rect().size
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for layer in LAYERS.size():
		var count := int(_size.x * _size.y / 1000.0 * LAYERS[layer].density)
		for i in count:
			_stars.append({
				"pos": Vector2(rng.randf() * _size.x, rng.randf() * _size.y),
				"layer": layer,
				"color": LAYERS[layer].colors[rng.randi() % LAYERS[layer].colors.size()],
				"big": false,
			})
	for i in BRIGHT_STARS:
		_stars.append({
			"pos": Vector2(rng.randf() * _size.x, rng.randf() * _size.y),
			"layer": LAYERS.size() - 1,
			"color": Color("#e6eaf0"),
			"big": true,
		})
	queue_redraw()


func reseed(value: int) -> void:
	seed_value = value
	_generate()


func _process(delta: float) -> void:
	var boost := 1.0 + warp * warp * 120.0
	for star in _stars:
		star.pos.x -= LAYERS[star.layer].speed * delta * boost
		if star.pos.x < -2.0:
			star.pos.x += _size.x + 4.0
	queue_redraw()


func _draw() -> void:
	for star in _stars:
		var p: Vector2 = star.pos.floor()
		if warp > 0.05:
			var length := roundf(warp * warp * LAYERS[star.layer].speed * 6.0)
			draw_rect(Rect2(p, Vector2(length + 1, 1)), Color(star.color, 0.8))
			continue
		if star.big:
			# Kleines Kreuz: heller Kern, gedimmte Strahlen
			var dim := Color(star.color, 0.45)
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), dim)
			draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), dim)
		draw_rect(Rect2(p, Vector2.ONE), star.color)
