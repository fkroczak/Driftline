extends Control
## Hauptmenü: zwei Spielmodi nebeneinander, je mit „Weiter“ (falls ein Run gespeichert ist)
## und „Neuer Run“. Ein neuer Run überschreibt einen gespeicherten erst nach einem zweiten Antippen.

const CARD := Vector2(172, 118)
const LOGO := preload("res://assets/ui/logo.png")
const LOGO_Y := 12.0
const HOLE := Vector2(64, 15)  # Mitte des Einschusslochs im Logo (tools/app_icon.py gibt sie aus)
const SPARK_COLORS := [Color("#FDE6BF"), Color("#FAC775"), Color("#EF9F27"), Color("#D85A30")]
const GLOW_COLORS := [Color("#FAC775"), Color("#EF9F27"), Color("#D85A30")]
const GLOW_PIXELS := [Vector2(-1, -4), Vector2(3, -3), Vector2(-3, 1), Vector2(2, 3), Vector2(-4, -2), Vector2(4, 0)]
const MODES := [
	{"id": RunState.MODE_HUNT, "name": "DIE JAGD", "color": Color("#E24B4A"),
		"text": ["4 Sektoren, je ein Boss am Ausgang.", "Die Jägerfront rückt mit jedem", "Sprung vor: nach 10 Sprüngen", "holt sie dich ein."]},
	{"id": RunState.MODE_ENDLESS, "name": "ENDLOSES UNIVERSUM", "color": Color("#85B7EB"),
		"text": ["Sektor um Sektor, ohne Verfolger.", "Die Gegner werden immer stärker.", "Wie weit kommst du?", ""]},
]

var _buttons: Array[Dictionary] = []  # {rect, mode, action}
var _confirm := ""  # Modus, für den „Neuer Run“ einmal angetippt wurde
var _time := 0.0
var _sparks: Array[Dictionary] = []  # {pos, vel, age, life}
var _smoke: Array[Dictionary] = []
var _spark_timer := 0.0
var _smoke_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_time += delta
	_update_effects(delta)
	queue_redraw()


func _hole() -> Vector2:
	return Vector2(roundf((size.x - LOGO.get_width()) / 2.0), LOGO_Y) + HOLE


## Funken sprühen stoßweise aus dem Einschussloch, Rauch steigt langsam auf.
func _update_effects(delta: float) -> void:
	var intensity := 0.5 + 0.5 * sin(_time * 2.3) * sin(_time * 0.9 + 1.0)
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = lerpf(0.25, 0.03, intensity)
		var burst := 1 if _rng.randf() > 0.12 else _rng.randi_range(4, 8)
		for i in burst:
			var a := _rng.randf_range(-2.7, -0.4)
			_sparks.append({"pos": _hole() + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)),
				"vel": Vector2(cos(a), sin(a)) * _rng.randf_range(14, 46), "age": 0.0, "life": _rng.randf_range(0.3, 0.9)})
	_smoke_timer -= delta
	if _smoke_timer <= 0.0:
		_smoke_timer = _rng.randf_range(0.12, 0.3)
		_smoke.append({"pos": _hole() + Vector2(_rng.randf_range(-2, 2), -3), "vel": Vector2(_rng.randf_range(1, 5), -_rng.randf_range(5, 9)),
			"age": 0.0, "life": _rng.randf_range(1.4, 2.4)})
	for list: Array[Dictionary] in [_sparks, _smoke]:
		for p in list:
			p.age += delta
			p.pos += p.vel * delta
		list.assign(list.filter(func(p: Dictionary) -> bool: return p.age < p.life))
	for p in _sparks:
		p.vel.y += 50.0 * delta


func _draw_effects() -> void:
	for p in _smoke:
		var t: float = p.age / p.life
		var c := Color("#424A56") if t < 0.5 else Color("#2A2F3A")
		c.a = 1.0 - t * 0.6
		draw_rect(Rect2(p.pos.floor(), Vector2.ONE), c)
	for p in _sparks:
		var t: float = p.age / p.life
		draw_rect(Rect2(p.pos.floor(), Vector2.ONE), SPARK_COLORS[mini(int(t * SPARK_COLORS.size()), SPARK_COLORS.size() - 1)])
	# glühender Rand flackert
	var h := _hole()
	for i in GLOW_PIXELS.size():
		var k := int(_time * 12.0 + i * 7) % 5
		if k < GLOW_COLORS.size():
			draw_rect(Rect2(h + GLOW_PIXELS[i], Vector2.ONE), GLOW_COLORS[k])


func _draw() -> void:
	draw_texture(LOGO, Vector2(roundf((size.x - LOGO.get_width()) / 2.0), LOGO_Y))
	_draw_effects()
	var sub := "Raumschiff-Roguelike"
	HudStyle.text(self, Vector2(roundf((size.x - HudStyle.text_width(sub)) / 2.0), 46), sub, HudStyle.COLOR_DIM)
	_buttons.clear()
	var gap := 12.0
	var total := CARD.x * 2 + gap
	var x0 := roundf((size.x - total) / 2.0)
	for i in MODES.size():
		_draw_card(Rect2(Vector2(x0 + i * (CARD.x + gap), 58), CARD), MODES[i])
	var sound := "TON AUS" if Sfx.muted else "TON AN"
	_button(Rect2(4, size.y - 21, 52, 17), sound, HudStyle.COLOR_DIM if Sfx.muted else HudStyle.COLOR_TEXT, "", "sound")
	var version := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	HudStyle.text(self, Vector2(size.x - HudStyle.text_width(version) - 4, size.y - 4), version, HudStyle.COLOR_DIM)


func _draw_card(rect: Rect2, m: Dictionary) -> void:
	var color: Color = m.color
	HudStyle.box(self, rect, color)
	HudStyle.text(self, rect.position + Vector2(6, 12), m.name, color)
	var y := rect.position.y + 24
	for line: String in m.text:
		HudStyle.text(self, Vector2(rect.position.x + 6, y), line, HudStyle.COLOR_TEXT, rect.size.x - 10)
		y += 10
	var best := Game.best_score(m.id)
	if best > 0:
		var record := ("Rekord: Sektor %d" % best) if not (m.id == RunState.MODE_HUNT and best > RunState.HUNT_SECTORS) else "Rekord: alle Sektoren geschafft"
		HudStyle.text(self, Vector2(rect.position.x + 6, y), record, HudStyle.COLOR_GOLD)
	var saved := SaveGame.summary(m.id)
	var bw := rect.size.x - 12
	var by := rect.end.y - 22
	if not saved.is_empty():
		var cont := Rect2(rect.position.x + 6, by - 20, bw, 17)
		var label := "WEITER · Sektor %d, Sprung %d" % [saved.sector, saved.jumps]
		_button(cont, label, HudStyle.COLOR_OK, m.id, "continue")
	var fresh := Rect2(rect.position.x + 6, by, bw, 17)
	var new_label := "NEUER RUN"
	if _confirm == m.id:
		new_label = "Nochmal: alter Run geht verloren"
	_button(fresh, new_label, HudStyle.COLOR_WARN if _confirm == m.id else HudStyle.COLOR_TEXT, m.id, "new")


func _button(rect: Rect2, label: String, color: Color, mode: String, action: String) -> void:
	HudStyle.box(self, rect, color, Color("#161B2B"))
	HudStyle.text(self, rect.position + Vector2(roundf((rect.size.x - HudStyle.text_width(label)) / 2.0), 12), label, color, rect.size.x - 4)
	_buttons.append({"rect": rect, "mode": mode, "action": action})


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	for b in _buttons:
		if not (b.rect as Rect2).grow(2).has_point(event.position):
			continue
		Sfx.play("ui_click")
		if b.action == "sound":
			Sfx.muted = not Sfx.muted
			return
		if b.action == "continue":
			Game.continue_run(b.mode)
			Game.to_ship()
		elif SaveGame.exists(b.mode) and _confirm != b.mode:
			_confirm = b.mode
		else:
			Game.new_run(b.mode)
			Game.to_ship()
		return
	_confirm = ""
