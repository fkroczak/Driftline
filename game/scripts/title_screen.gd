extends Control
## Hauptmenü. Startseite mit SPIELEN, TUTORIAL, LEXIKON und EINSTELLUNGEN.
## SPIELEN zeigt die zwei Spielmodi nebeneinander, je mit „Weiter“ (falls ein Run gespeichert ist)
## und „Neuer Run“. Ein neuer Run überschreibt einen gespeicherten erst nach einem zweiten Antippen.
## Lexikon und Einstellungen liegen als Überlagerung darüber.

const CARD := Vector2(172, 118)
const MENU_W := 132.0
const MENU_H := 20.0
const COLOR_TITLE := Color("#FDE6BF")
const MODES := [
	{"id": RunState.MODE_HUNT, "name": "DIE JAGD", "color": Color("#E24B4A"),
		"text": "4 Sektoren, je ein Boss am Ausgang. Die Jägerfront rückt mit jedem Sprung vor: nach 10 Sprüngen holt sie dich ein."},
	{"id": RunState.MODE_ENDLESS, "name": "ENDLOSES UNIVERSUM", "color": Color("#85B7EB"),
		"text": "Sektor um Sektor, ohne Verfolger. Die Gegner werden immer stärker. Wie weit kommst du?"},
]
const SHIP_TEXTURE := preload("res://assets/ships/mensch_frachter.png")

## "start" (Hauptmenü) oder "modes" (Spielmodus wählen)
var _page := "start"
var _buttons: Array[Dictionary] = []  # {rect, action, mode}
var _confirm := ""  # Modus, für den „Neuer Run“ einmal angetippt wurde
var _time := 0.0
var _settings: SettingsPanel
var _codex: CodexView


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_settings = SettingsPanel.new()
	_codex = CodexView.new()
	for overlay: Control in [_codex, _settings]:
		add_child(overlay)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	for overlay: Control in [_codex, _settings]:
		overlay.position = Vector2.ZERO
		overlay.size = size


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	_buttons.clear()
	if _page == "start":
		_draw_start()
	else:
		_draw_modes()
	var version := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	HudStyle.text(self, Vector2(size.x - HudStyle.text_width(version) - 4, size.y - 4), version, HudStyle.COLOR_DIM)


func _draw_title(y: float) -> void:
	var title := "HULLBOUND"
	var tw := HudStyle.text_width(title, 26)
	HudStyle.text(self, Vector2(roundf((size.x - tw) / 2.0), y), title, COLOR_TITLE, -1, 26)
	var sub := "Raumschiff-Roguelike"
	HudStyle.text(self, Vector2(roundf((size.x - HudStyle.text_width(sub)) / 2.0), y + 12), sub, HudStyle.COLOR_DIM)


func _draw_start() -> void:
	# Der eigene Frachter zieht langsam hinter dem Menü vorbei
	var ship_w := SHIP_TEXTURE.get_width() * 0.5
	var travel := size.x + ship_w + 40.0
	var sx := fmod(_time * 9.0, travel) - ship_w - 20.0
	var sy := size.y - 46.0 + roundf(sin(_time * 0.8) * 1.5)
	draw_texture_rect(SHIP_TEXTURE, Rect2(Vector2(sx, sy).round(), SHIP_TEXTURE.get_size() * 0.5), false, Color(1, 1, 1, 0.55))
	_draw_title(44)
	var entries := [
		["play", "SPIELEN", HudStyle.COLOR_OK],
		["tutorial", "TUTORIAL", HudStyle.COLOR_WARN],
		["codex", "LEXIKON", HudStyle.COLOR_SHIELD],
		["settings", "EINSTELLUNGEN", HudStyle.COLOR_TEXT],
	]
	var x := roundf((size.x - MENU_W) / 2.0)
	var y := 72.0
	for e: Array in entries:
		_button(Rect2(x, y, MENU_W, MENU_H), e[1], e[2], e[0])
		y += MENU_H + 5
	var count := Codex.count_known()
	var note := "Lexikon: %d / %d entdeckt" % [count.x, count.y]
	HudStyle.text(self, Vector2(roundf((size.x - HudStyle.text_width(note)) / 2.0), y + 8), note, HudStyle.COLOR_DIM)


func _draw_modes() -> void:
	_draw_title(30)
	var gap := 12.0
	var total := CARD.x * 2 + gap
	var x0 := roundf((size.x - total) / 2.0)
	for i in MODES.size():
		_draw_card(Rect2(Vector2(x0 + i * (CARD.x + gap), 52), CARD), MODES[i])
	_button(Rect2(x0, 52 + CARD.y + 8, 70, 17), "ZURÜCK", HudStyle.COLOR_TEXT, "back")


func _draw_card(rect: Rect2, m: Dictionary) -> void:
	var color: Color = m.color
	HudStyle.box(self, rect, color)
	HudStyle.text(self, rect.position + Vector2(6, 12), m.name, color)
	var y := rect.position.y + 24
	y += HudStyle.paragraph(self, Vector2(rect.position.x + 6, y), m.text, rect.size.x - 12, HudStyle.COLOR_TEXT)
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
		_button(cont, label, HudStyle.COLOR_OK, "continue", m.id)
	var fresh := Rect2(rect.position.x + 6, by, bw, 17)
	var new_label := "NEUER RUN"
	if _confirm == m.id:
		new_label = "Nochmal: alter Run geht verloren"
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
					Game.new_run(b.mode)
					Game.to_ship()
		return
	_confirm = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if _page == "modes" and event.is_action_pressed("ui_cancel"):
		_page = "start"
		get_viewport().set_input_as_handled()
