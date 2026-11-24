class_name DoorPanel
extends Control
## Türen unten rechts (wie im Mockup): „ALLE AUF“/„ALLE ZU“ schaltet alle Türen,
## „SCHLEUSEN ZU“ (rot, nur wenn eine offen ist) schließt alle Luftschleusen.
## Einzelne Türen und Schleusen schaltet man weiter direkt im Schiff.

signal changed(text: String)

var state: ShipState


func setup(p_state: ShipState) -> void:
	state = p_state
	custom_minimum_size = Vector2(50, 34)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _doors_rect() -> Rect2:
	return Rect2(3, 7, size.x - 6, 12)


func _locks_rect() -> Rect2:
	return Rect2(3, 20, size.x - 6, 11)


func _draw() -> void:
	if not state:
		return
	HudStyle.box(self, Rect2(0, 3, size.x, size.y - 3))
	draw_rect(Rect2(5, 0, HudStyle.text_width("TÜREN") + 4, 7), HudStyle.COLOR_BG)
	HudStyle.text(self, Vector2(7, 7), "TÜREN", HudStyle.COLOR_TEXT)
	var r := _doors_rect()
	var label := "ALLE ZU" if state.any_door_open() else "ALLE AUF"
	HudStyle.box(self, r, HudStyle.COLOR_EDGE_HI, Color("#161B2B"))
	HudStyle.text(self, r.position + Vector2(roundf((r.size.x - HudStyle.text_width(label)) / 2.0), 9), label, HudStyle.COLOR_SHIELD)
	var l := _locks_rect()
	var open := state.any_airlock_open()
	var lock_label := "SCHLEUSE"
	HudStyle.text(self, l.position + Vector2(roundf((l.size.x - HudStyle.text_width(lock_label)) / 2.0), 9), lock_label,
		HudStyle.COLOR_BAD if open else HudStyle.COLOR_DIM)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or not state:
		return
	accept_event()
	if _doors_rect().grow(1).has_point(event.position):
		var open := not state.any_door_open()
		state.set_all_doors(open)
		Sfx.play("door_open" if open else "door_close")
		changed.emit("Alle Türen " + ("offen: Luft gleicht sich aus, Feuer kann wandern" if open else "zu"))
	elif _locks_rect().grow(1).has_point(event.position):
		if state.any_airlock_open():
			state.close_airlocks()
			Sfx.play("airlock_close")
			changed.emit("Alle Schleusen zu")
		else:
			Sfx.play("ui_deny")
			changed.emit("Schleusen öffnet man einzeln: gelbe Luke am Schiff antippen")
