extends Control
## Hauptmenü. Startseite mit SPIELEN, TUTORIAL, LEXIKON und EINSTELLUNGEN.
## SPIELEN zeigt die zwei Spielmodi nebeneinander, je mit „Weiter“ (falls ein Run gespeichert ist)
## und „Neuer Run“. Ein neuer Run überschreibt einen gespeicherten erst nach einem zweiten Antippen.
## NEUER RUN öffnet die Startauswahl (Schiff, Crew, Waffen, Perks, Schwierigkeit; LoadoutView).
## Lexikon, Startauswahl und Einstellungen liegen als Überlagerung darüber.

const CARD := Vector2(172, 118)
const MENU_W := 132.0
const MENU_H := 20.0
const COLOR_TITLE := Color("#FDE6BF")
const MODES := [
	{"id": RunState.MODE_HUNT, "name": "DIE JAGD", "color": Color("#E24B4A"),  # i18n
		"text": "4 Sektoren, je ein Boss am Ausgang. Die Jägerfront rückt mit jedem Sprung vor: nach 10 Sprüngen holt sie dich ein."},  # i18n
	{"id": RunState.MODE_ENDLESS, "name": "ENDLOSES UNIVERSUM", "color": Color("#85B7EB"),  # i18n
		"text": "Sektor um Sektor, ohne Verfolger. Die Gegner werden immer stärker. Wie weit kommst du?"},  # i18n
]
const SHIP_TEXTURE := preload("res://assets/ships/mensch_frachter.png")
const LOGO := preload("res://assets/ui/logo.png")
const HOLE := Vector2(64, 15)  # Mitte des Einschusslochs im Logo (tools/app_icon.py gibt sie aus)
const SPARK_COLORS := [Color("#FDE6BF"), Color("#FAC775"), Color("#EF9F27"), Color("#D85A30")]
const GLOW_COLORS := [Color("#FAC775"), Color("#EF9F27"), Color("#D85A30")]
const GLOW_PIXELS := [Vector2(-1, -4), Vector2(3, -3), Vector2(-3, 1), Vector2(2, 3), Vector2(-4, -2), Vector2(4, 0)]

## "start" (Hauptmenü) oder "modes" (Spielmodus wählen)
var _page := "start"
var _buttons: Array[Dictionary] = []  # {rect, action, mode}
var _confirm := ""  # Modus, für den „Neuer Run“ einmal angetippt wurde
var _time := 0.0
var _settings: SettingsPanel
var _codex: CodexView
var _loadout: LoadoutView
var _logo_y := 12.0
var _sparks: Array[Dictionary] = []  # {pos, vel, age, life}
var _smoke: Array[Dictionary] = []
var _spark_timer := 0.0
var _smoke_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_settings = SettingsPanel.new()
	_codex = CodexView.new()
	_loadout = LoadoutView.new()
	_loadout.started.connect(_on_loadout_started)
	for overlay: Control in [_codex, _loadout, _settings]:
		add_child(overlay)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	for overlay: Control in [_codex, _loadout, _settings]:
		overlay.position = Vector2.ZERO
		overlay.size = size


func _process(delta: float) -> void:
	_time += delta
	_update_effects(delta)
	queue_redraw()


func _hole() -> Vector2:
	return Vector2(roundf((size.x - LOGO.get_width()) / 2.0), _logo_y) + HOLE


## Funken sprühen stoßweise aus dem Einschussloch des Logos, Rauch steigt langsam auf.
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
	_buttons.clear()
	if _page == "start":
		_draw_start()
	else:
		_draw_modes()
	var version := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	HudStyle.text(self, Vector2(size.x - HudStyle.text_width(version) - 4, size.y - 4), version, HudStyle.COLOR_DIM)


## Logo mit Funken am Einschussloch; `y` ist die Grundlinie des Untertitels.
func _draw_title(y: float) -> void:
	_logo_y = y - 34.0
	draw_texture(LOGO, Vector2(roundf((size.x - LOGO.get_width()) / 2.0), _logo_y))
	_draw_effects()
	var sub := Loc.t("Raumschiff-Roguelike")
	HudStyle.text(self, Vector2(roundf((size.x - HudStyle.text_width(sub)) / 2.0), y), sub, HudStyle.COLOR_DIM)


func _draw_start() -> void:
	# Der eigene Frachter zieht langsam hinter dem Menü vorbei
	var ship_w := SHIP_TEXTURE.get_width() * 0.5
	var travel := size.x + ship_w + 40.0
	var sx := fmod(_time * 9.0, travel) - ship_w - 20.0
	var sy := size.y - 46.0 + roundf(sin(_time * 0.8) * 1.5)
	draw_texture_rect(SHIP_TEXTURE, Rect2(Vector2(sx, sy).round(), SHIP_TEXTURE.get_size() * 0.5), false, Color(1, 1, 1, 0.55))
	_draw_title(60)
	var entries := [
		["play", "SPIELEN", HudStyle.COLOR_OK],  # i18n
		["tutorial", "TUTORIAL", HudStyle.COLOR_WARN],  # i18n
		["codex", "LEXIKON", HudStyle.COLOR_SHIELD],  # i18n
		["settings", "EINSTELLUNGEN", HudStyle.COLOR_TEXT],  # i18n
	]
	var x := roundf((size.x - MENU_W) / 2.0)
	var y := 70.0
	for e: Array in entries:
		_button(Rect2(x, y, MENU_W, MENU_H), Loc.t(e[1]), e[2], e[0])
		y += MENU_H + 5
	var count := Codex.count_known()
	var note := Loc.t("Lexikon: %d / %d entdeckt") % [count.x, count.y]
	HudStyle.text(self, Vector2(roundf((size.x - HudStyle.text_width(note)) / 2.0), y + 8), note, HudStyle.COLOR_DIM)


func _draw_modes() -> void:
	_draw_title(46)
	var gap := 12.0
	var total := CARD.x * 2 + gap
	var x0 := roundf((size.x - total) / 2.0)
	for i in MODES.size():
		_draw_card(Rect2(Vector2(x0 + i * (CARD.x + gap), 58), CARD), MODES[i])
	_button(Rect2(x0, 58 + CARD.y + 6, 70, 17), Loc.t("ZURÜCK"), HudStyle.COLOR_TEXT, "back")


func _draw_card(rect: Rect2, m: Dictionary) -> void:
	var color: Color = m.color
	HudStyle.box(self, rect, color)
	HudStyle.text(self, rect.position + Vector2(6, 12), Loc.t(m.name), color)
	var y := rect.position.y + 24
	y += HudStyle.paragraph(self, Vector2(rect.position.x + 6, y), Loc.t(m.text), rect.size.x - 12, HudStyle.COLOR_TEXT)
	var best := Game.best_score(m.id)
	if best > 0:
		var record := (Loc.t("Rekord: Sektor %d") % best) if not (m.id == RunState.MODE_HUNT and best > RunState.HUNT_SECTORS) else Loc.t("Rekord: alle Sektoren geschafft")
		HudStyle.text(self, Vector2(rect.position.x + 6, y), record, HudStyle.COLOR_GOLD)
	var saved := SaveGame.summary(m.id)
	var bw := rect.size.x - 12
	var by := rect.end.y - 22
	if not saved.is_empty():
		var cont := Rect2(rect.position.x + 6, by - 20, bw, 17)
		var label := Loc.t("WEITER · Sektor %d, Sprung %d") % [saved.sector, saved.jumps]
		_button(cont, label, HudStyle.COLOR_OK, "continue", m.id)
	var fresh := Rect2(rect.position.x + 6, by, bw, 17)
	var new_label := Loc.t("NEUER RUN")
	if _confirm == m.id:
		new_label = Loc.t("Nochmal: alter Run geht verloren")
	_button(fresh, new_label, HudStyle.COLOR_WARN if _confirm == m.id else HudStyle.COLOR_TEXT, "new", m.id)


func _button(rect: Rect2, label: String, color: Color, action: String, mode := "") -> void:
	HudStyle.button(self, rect, label, color)
	_buttons.append({"rect": rect, "mode": mode, "action": action})


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	for b in _buttons:
		if not (b.rect as Rect2).grow(2).has_point(event.position):
			continue
		_confirm = "" if b.action != "new" else _confirm
		Sfx.play("ui_click")
		match b.action:
			"play":
				_page = "modes"
			"back":
				_page = "start"
			"tutorial":
				Game.start_tutorial()
				Game.to_ship()
			"codex":
				_codex.open()
			"settings":
				_settings.open()
			"continue":
				Game.continue_run(b.mode)
				Game.to_ship()
			"new":
				if SaveGame.exists(b.mode) and _confirm != b.mode:
					_confirm = b.mode
				else:
					_confirm = ""
					_loadout.open(b.mode, Loc.t(_mode_def(b.mode).name))
		return
	_confirm = ""


func _mode_def(id: String) -> Dictionary:
	for m: Dictionary in MODES:
		if m.id == id:
			return m
	return MODES[0]


func _on_loadout_started(mode: String, cfg: Dictionary) -> void:
	Game.new_run(mode, 0, cfg)
	Game.to_ship()


func _unhandled_key_input(event: InputEvent) -> void:
	if _page == "modes" and event.is_action_pressed("ui_cancel"):
		_page = "start"
		get_viewport().set_input_as_handled()
