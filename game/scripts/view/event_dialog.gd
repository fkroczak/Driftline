class_name EventDialog
extends Control
## Ereignis-Dialog (GDD, Mockup hud_ereignis_pixel.png): links eine kleine Szene, rechts Titel und
## Text, darunter die Optionen als große Touch-Flächen. Ansehens-Optionen sind blau, nicht
## bezahlbare grau. Zeigt jedes Dictionary {title, text, scene, choices: [{text, enabled, special}]}.

signal chosen(index: int)

const FONT_SIZE := 8
const LINE := 10.0
const PAD := 6.0
const ART := 52.0
const CHOICE_H := 18.0
const CHOICE_GAP := 3.0
const MIN_CHOICE_H := 13.0
## Nach einem Wechsel kurz keine Eingabe, damit ein Doppeltipp nicht gleich die nächste Option wählt.
const INPUT_LOCK := 0.3

const COLOR_SHADE := Color("#07080F", 0.62)
const COLOR_PANEL := Color("#10142A", 0.97)
const COLOR_EDGE := Color("#378ADD")
const COLOR_TITLE := Color("#FDE6BF")
const COLOR_TEXT := Color("#C4CAD3")
const COLOR_CHOICE := Color("#161B2B")
const COLOR_CHOICE_EDGE := Color("#363E58")
const COLOR_SPECIAL := Color("#85B7EB")
const COLOR_OFF := Color("#5A6370")
const COLOR_ART_BG := Color("#0A0B16")

var data: Dictionary = {}
var _lock := 0.0
var _time := 0.0
var _choice_rects: Array[Rect2] = []
## Höhe einer Option; bei vielen Optionen (Händler) kleiner, damit alles auf den Bildschirm passt.
var _choice_h := CHOICE_H


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func show_dialog(p_data: Dictionary) -> void:
	data = p_data
	visible = not data.is_empty()
	_lock = INPUT_LOCK
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_lock = maxf(_lock - delta, 0.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if _lock > 0.0:
		return
	for i in _choice_rects.size():
		if _choice_rects[i].grow(1.0).has_point(event.position) and data.choices[i].enabled:
			chosen.emit(i)
			return


func _panel_rect() -> Rect2:
	var width := minf(size.x - 24.0, 380.0)
	var font := ThemeDB.fallback_font
	var text_w := width - ART - PAD * 3.0
	var text_h := font.get_multiline_string_size(data.get("text", ""), HORIZONTAL_ALIGNMENT_LEFT, text_w, FONT_SIZE).y
	var top_h := maxf(ART, LINE + 4.0 + text_h)
	var count: int = data.get("choices", []).size()
	var room := size.y - 20.0 - (PAD + top_h + PAD + PAD) + CHOICE_GAP
	_choice_h = clampf(floorf(room / maxf(count, 1)) - CHOICE_GAP, MIN_CHOICE_H, CHOICE_H)
	var height := PAD + top_h + PAD + count * (_choice_h + CHOICE_GAP) - CHOICE_GAP + PAD
	height = minf(height, size.y - 20.0)
	var pos := Vector2((size.x - width) / 2.0, maxf(16.0, (size.y - height) / 2.0 + 4.0))
	return Rect2(pos.floor(), Vector2(width, height).floor())


func _draw() -> void:
	if data.is_empty():
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_SHADE)
	var panel := _panel_rect()
	draw_rect(panel, COLOR_PANEL)
	draw_rect(panel.grow(-0.5), COLOR_EDGE, false, 1.0)
	var art := Rect2(panel.position + Vector2(PAD, PAD), Vector2(ART, ART))
	draw_rect(art, COLOR_ART_BG)
	_draw_scene(art, data.get("scene", ""))
	var tx := art.end.x + PAD
	var text_w := panel.end.x - PAD - tx
	draw_string(font, Vector2(tx, panel.position.y + PAD + 8.0), Loc.t(data.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, text_w, FONT_SIZE + 1, COLOR_TITLE)
	draw_multiline_string(font, Vector2(tx, panel.position.y + PAD + LINE + 12.0), Loc.t(data.get("text", "")),
		HORIZONTAL_ALIGNMENT_LEFT, text_w, FONT_SIZE, -1, COLOR_TEXT)
	_choice_rects.clear()
	var choices: Array = data.get("choices", [])
	var y := panel.end.y - PAD - choices.size() * (_choice_h + CHOICE_GAP) + CHOICE_GAP
	for i in choices.size():
		var c: Dictionary = choices[i]
		var rect := Rect2(panel.position.x + PAD, y, panel.size.x - PAD * 2.0, _choice_h)
		_choice_rects.append(rect)
		var edge := COLOR_SPECIAL if c.special else COLOR_CHOICE_EDGE
		var color := COLOR_SPECIAL if c.special else COLOR_TEXT
		if not c.enabled:
			edge = COLOR_CHOICE_EDGE.darkened(0.3)
			color = COLOR_OFF
		draw_rect(rect, Color(COLOR_SPECIAL, 0.12) if c.special and c.enabled else COLOR_CHOICE)
		draw_rect(rect.grow(-0.5), edge, false, 1.0)
		draw_string(font, rect.position + Vector2(6, roundf(_choice_h / 2.0 + 3.0)), "%d. %s" % [i + 1, Loc.t(c.text)], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10.0, FONT_SIZE, color)
		y += _choice_h + CHOICE_GAP


## Kleine gezeichnete Szene je Ereignistyp, ohne Grafikdateien.
func _draw_scene(r: Rect2, scene: String) -> void:
	var c := r.get_center()
	for i in 9:  # Sterne
		var p := r.position + Vector2(fmod(i * 37.0 + 5.0, r.size.x - 2.0), fmod(i * 23.0 + 9.0, r.size.y - 2.0))
		draw_rect(Rect2(p.floor(), Vector2.ONE), Color("#747D8A"))
	match scene:
		"planet":
			draw_circle(c + Vector2(2, 4), 18.0, Color("#185FA5"))
			draw_circle(c + Vector2(-2, 1), 15.0, Color("#85B7EB"))
			draw_circle(c + Vector2(-6, -3), 7.0, Color("#D3E6F8"))
			draw_arc(c + Vector2(2, 4), 24.0, PI * 1.05, PI * 1.95, 12, Color("#FDE6BF", 0.5), 1.0)
		"wrack":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -4), c + Vector2(-4, -10), c + Vector2(2, -2), c + Vector2(-14, 8)]), Color("#5A6370"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(6, -6), c + Vector2(20, -2), c + Vector2(14, 12), c + Vector2(4, 6)]), Color("#424A56"))
			for p: Vector2 in [Vector2(-2, -1), Vector2(5, 2), Vector2(-8, 3)]:
				var glow := 0.5 + 0.5 * sin(_time * 5.0 + p.x)
				draw_rect(Rect2(c + p, Vector2(2, 2)), Color("#EF9F27", glow))
		"notruf":
			for k in 3:
				var rad := fmod(_time * 14.0 + k * 8.0, 24.0)
				draw_arc(c, rad, 0.0, TAU, 20, Color("#E24B4A", 1.0 - rad / 24.0), 1.0)
			draw_rect(Rect2(c - Vector2(4, 6), Vector2(8, 12)), Color("#C4CAD3"))
			draw_rect(Rect2(c - Vector2(2, 3), Vector2(4, 3)), Color("#85B7EB"))
		"station":
			draw_rect(Rect2(c - Vector2(18, 2), Vector2(36, 4)), Color("#5A6370"))
			draw_rect(Rect2(c - Vector2(2, 18), Vector2(4, 36)), Color("#5A6370"))
			draw_circle(c, 8.0, Color("#747D8A"))
			draw_circle(c, 4.0, Color("#363E58"))
			for p: Vector2 in [Vector2(-18, 0), Vector2(17, 0), Vector2(0, -18), Vector2(0, 17)]:
				draw_rect(Rect2(c + p - Vector2(1, 1), Vector2(2, 2)), Color("#FAC775") if fmod(_time, 1.0) < 0.5 else Color("#5DCAA5"))
		"schiff":
			draw_colored_polygon(PackedVector2Array([c + Vector2(20, 0), c + Vector2(-12, -10), c + Vector2(-6, 0), c + Vector2(-12, 10)]), Color("#A9B0BB"))
			draw_rect(Rect2(c + Vector2(-16, -2), Vector2(4, 4)), Color("#EF9F27", 0.6 + 0.4 * sin(_time * 12.0)))
		"asteroiden":
			for a: Array in [[Vector2(-12, -8), 7.0], [Vector2(8, -12), 5.0], [Vector2(10, 8), 9.0], [Vector2(-10, 12), 4.0], [Vector2(0, 0), 3.0]]:
				draw_circle(c + a[0], a[1], Color("#5F4A3A"))
				draw_circle(c + a[0] - Vector2(1, 1), a[1] * 0.6, Color("#8A6E52"))
		"nebel":
			draw_circle(c + Vector2(-6, -4), 16.0, Color("#3C3489", 0.8))
			draw_circle(c + Vector2(8, 6), 14.0, Color("#72243E", 0.7))
			if fmod(_time, 1.6) < 0.15:
				draw_polyline(PackedVector2Array([c + Vector2(-4, -16), c + Vector2(2, -4), c + Vector2(-3, 2), c + Vector2(5, 14)]), Color("#FAC775"), 1.0)
		_:
			draw_circle(c, 3.0, Color("#E6EAF0"))
