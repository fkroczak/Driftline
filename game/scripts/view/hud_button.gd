class_name HudButton
extends Control
## Einfacher Knopf im HUD-Stil: Kasten mit Text, Antippen meldet `pressed`.
## `accent` färbt Rahmen und Text, `blink` lässt ihn pulsieren, `sub` ist eine zweite Zeile.

signal pressed

@export var label := ""
var sub := ""
var accent := HudStyle.COLOR_TEXT
var edge := HudStyle.COLOR_EDGE
var blink := false
## Statt Text drei Striche (Menü).
var bars := false
var enabled := true
var _time := 0.0
var _deny := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func deny() -> void:
	_deny = 0.25


func _process(delta: float) -> void:
	_time += delta
	_deny = maxf(_deny - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var x := roundf(sin(_deny * 60.0) * 1.5) if _deny > 0.0 else 0.0
	var rect := Rect2(Vector2(x, 0), size)
	var color := accent if enabled else HudStyle.COLOR_DIM
	HudStyle.box(self, rect, color if blink and fmod(_time, 0.8) < 0.4 else edge)
	if blink and fmod(_time, 0.8) < 0.4:
		draw_rect(rect.grow(-1), Color(color, 0.18))
	if bars:
		var c := (size / 2.0).floor() + Vector2(x, 0)
		for k in 3:
			draw_rect(Rect2(c + Vector2(-5, -5 + k * 4), Vector2(10, 2)), Color("#FDE6BF"))
		return
	var shown := Loc.t(label)
	var w := HudStyle.text_width(shown)
	var y := 10.0 if sub != "" else roundf(size.y / 2.0 + 3.0)
	HudStyle.text(self, Vector2(x + roundf((size.x - w) / 2.0), y), shown, color)
	if sub != "":
		var sub_text := Loc.t(sub)
		var sw := HudStyle.text_width(sub_text)
		HudStyle.text(self, Vector2(x + roundf((size.x - sw) / 2.0), 20), sub_text, HudStyle.COLOR_DIM)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()
