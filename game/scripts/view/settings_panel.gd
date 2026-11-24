class_name SettingsPanel
extends Control
## Einstellungen als Überlagerung, im Hauptmenü und im Spiel (Knopf oben rechts).
## Jede Zeile hat Optionen zum Antippen; die Änderung gilt sofort und wird gespeichert.
## Im Spiel kommen „Weiterspielen“ und „Hauptmenü“ dazu, im Tutorial „Tutorial beenden“.

signal closed
signal quit_requested

const BOX := Vector2(260, 172)
const ROW_H := 20.0
const COLOR_DIM_BG := Color("#07080F", 0.85)
const COLOR_TITLE := Color("#FDE6BF")

## Im Spiel: zusätzliche Knöpfe für Weiterspielen und Hauptmenü.
var in_game := false
var tutorial := false

var _hits: Array[Dictionary] = []  # {rect, key, value} oder {rect, action}
var _note := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open() -> void:
	_note = ""
	visible = true
	queue_redraw()


func _rows() -> Array:
	var rows := [
		{"key": "crisp_text", "label": "Schrift", "options": [[true, "HD"], [false, "Retro"]],
			"note": "HD: Schrift in voller Auflösung · Retro: alles im groben Pixelraster"},
		{"key": "speed", "label": "Spieltempo", "options": [[0.75, "Langsam"], [1.0, "Normal"], [1.25, "Schnell"]],
			"note": "Wie schnell Zeit an Bord und im Kampf vergeht"},
		{"key": "auto_pause", "label": "Auto-Pause", "options": [[true, "An"], [false, "Aus"]],
			"note": "Kampf hält an, solange Crew oder Waffe ausgewählt ist"},
		{"key": "shake", "label": "Wackeln", "options": [[true, "An"], [false, "Aus"]],
			"note": "Bildschirm wackelt bei Treffern und Explosionen"},
	]
	if Settings.has_fullscreen():
		rows.append({"key": "fullscreen", "label": "Vollbild", "options": [[true, "An"], [false, "Aus"]], "note": "Nur am Computer"})
	return rows


func _draw() -> void:
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DIM_BG)
	var rows := _rows()
	var h := 30.0 + rows.size() * ROW_H + 22.0 + 26.0
	var box := Rect2(((size - Vector2(BOX.x, h)) / 2.0).floor(), Vector2(BOX.x, h))
	HudStyle.box(self, box, HudStyle.COLOR_EDGE_HI)
	HudStyle.text(self, box.position + Vector2(8, 15), "EINSTELLUNGEN", COLOR_TITLE, -1, 11)
	var y := box.position.y + 26.0
	for row: Dictionary in rows:
		HudStyle.text(self, Vector2(box.position.x + 8, y + 12), row.label, HudStyle.COLOR_TEXT)
		var opts: Array = row.options
		var ow := 52.0 if opts.size() == 3 else 60.0
		var x := box.end.x - 8 - opts.size() * (ow + 3) + 3
		var current: Variant = Settings.get_value(row.key)
		for opt: Array in opts:
			var r := Rect2(x, y + 1, ow, ROW_H - 4)
			var active := _same(current, opt[0])
			HudStyle.button(self, r, opt[1], HudStyle.COLOR_OK if active else HudStyle.COLOR_DIM, active)
			_hits.append({"rect": r, "key": row.key, "value": opt[0], "note": row.note})
			x += ow + 3
		y += ROW_H
	if _note != "":
		HudStyle.text(self, Vector2(box.position.x + 8, y + 10), _note, HudStyle.COLOR_DIM, box.size.x - 16)
	y += 22.0
	var bw := (box.size.x - 16 - 6) / 2.0
	if in_game:
		_action(Rect2(box.position.x + 8, y, bw, 18), "WEITERSPIELEN", HudStyle.COLOR_OK, "close")
		_action(Rect2(box.position.x + 8 + bw + 6, y, bw, 18), "TUTORIAL BEENDEN" if tutorial else "HAUPTMENÜ", HudStyle.COLOR_WARN, "quit")
	else:
		_action(Rect2(box.position.x + (box.size.x - bw) / 2.0, y, bw, 18), "ZURÜCK", HudStyle.COLOR_TEXT, "close")


func _action(rect: Rect2, label: String, color: Color, action: String) -> void:
	HudStyle.button(self, rect, label, color)
	_hits.append({"rect": rect, "action": action})


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
		return is_equal_approx(float(a), float(b))
	return a == b


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	for hit in _hits:
		if not (hit.rect as Rect2).grow(1).has_point(event.position):
			continue
		if hit.has("action"):
			if hit.action == "quit":
				quit_requested.emit()
			else:
				visible = false
				closed.emit()
		else:
			Settings.set_value(hit.key, hit.value)
			_note = hit.note
		queue_redraw()
		return


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()
