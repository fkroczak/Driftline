extends Control
## Hauptmenü: zwei Spielmodi nebeneinander, je mit „Weiter“ (falls ein Run gespeichert ist)
## und „Neuer Run“. Ein neuer Run überschreibt einen gespeicherten erst nach einem zweiten Antippen.

const CARD := Vector2(172, 118)
const COLOR_TITLE := Color("#FDE6BF")
const MODES := [
	{"id": RunState.MODE_HUNT, "name": "DIE JAGD", "color": Color("#E24B4A"),
		"text": ["4 Sektoren, je ein Boss am Ausgang.", "Die Jägerfront rückt mit jedem", "Sprung vor: nach 10 Sprüngen", "holt sie dich ein."]},
	{"id": RunState.MODE_ENDLESS, "name": "ENDLOSES UNIVERSUM", "color": Color("#85B7EB"),
		"text": ["Sektor um Sektor, ohne Verfolger.", "Die Gegner werden immer stärker.", "Wie weit kommst du?", ""]},
]

var _buttons: Array[Dictionary] = []  # {rect, mode, action}
var _confirm := ""  # Modus, für den „Neuer Run“ einmal angetippt wurde
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var title := "HULLBOUND"
	var tw := HudStyle.text_width(title, 22)
	HudStyle.text(self, Vector2(roundf((size.x - tw) / 2.0), 34), title, COLOR_TITLE, -1, 22)
	var sub := "Raumschiff-Roguelike"
	HudStyle.text(self, Vector2(roundf((size.x - HudStyle.text_width(sub)) / 2.0), 46), sub, HudStyle.COLOR_DIM)
	_buttons.clear()
	var gap := 12.0
	var total := CARD.x * 2 + gap
	var x0 := roundf((size.x - total) / 2.0)
	for i in MODES.size():
		_draw_card(Rect2(Vector2(x0 + i * (CARD.x + gap), 58), CARD), MODES[i])
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
