extends Node2D
## Sternenkarte zwischen den Kämpfen. Ein gelbes Ziel antippen zeigt das Infofeld,
## ein zweites Antippen springt (kostet Treibstoff). Am Ziel öffnet sich je nach System ein
## Dialog (Ereignis, Händler, Reparaturstation) oder es beginnt ein Kampf.
## Wer vor dem Boss geflohen ist, steht weiter vor ihm und greift per Antippen erneut an.
## Ohne Treibstoff bleibt das Notsignal.

const JUMP_TIME := 0.7

var run: RunState
var _busy := false

@onready var view: MapView = $MapView
@onready var dialog: EventDialog = $EventDialog


func _ready() -> void:
	run = Game.ensure_run()
	view.setup(run)
	view.node_tapped.connect(_on_node_tapped)
	view.background_tapped.connect(_on_background_tapped)
	view.distress_pressed.connect(_on_distress)
	dialog.chosen.connect(_on_choice)
	get_viewport().size_changed.connect(_layout)
	_layout()
	view.hint = _default_hint()
	_show_run_dialog()


func _layout() -> void:
	view.position = Vector2.ZERO
	view.size = get_viewport_rect().size
	dialog.position = Vector2.ZERO
	dialog.size = view.size


func _default_hint() -> String:
	if run.needs_battle():
		return "Das Flaggschiff wartet: Schiff antippen, um erneut anzugreifen"
	if run.can_send_distress():
		return "Kein Treibstoff mehr: Notsignal senden und hoffen, dass Freunde antworten"
	var damage := run.ship_damage_count()
	if damage > 0:
		return "%d %s an Bord: Crew repariert im nächsten Kampf, oder die Reparaturstation" % [damage, "Schaden" if damage == 1 else "Schäden"]
	if run.jumps_done() == 0:
		return "Gelbes Ziel antippen, nochmal antippen springt · Boss rechts ist der Ausgang"
	return "Gelbes Ziel antippen, nochmal antippen springt"


func _on_background_tapped() -> void:
	view.selected = -1
	view.hint = _default_hint()


func _on_node_tapped(id: int) -> void:
	if _busy:
		return
	if id == run.current and run.needs_battle():
		_busy = true
		Game.to_battle()
		return
	if not run.can_jump_to(id):
		view.selected = -1
		if id == run.current:
			view.hint = "Hier ist das Schiff gerade"
		elif run.visited.has(id):
			view.hint = "Schon besucht"
		elif run.node().links.has(id) and run.fuel < run.jump_cost():
			view.hint = "Kein Treibstoff für den Sprung: Notsignal senden"
		else:
			view.hint = "Zu weit weg: nur gelbe, direkt verbundene Ziele"
		return
	if view.selected != id:
		view.selected = id
		view.hint = "Nochmal antippen: springen"
		return
	_jump(id)


func _jump(id: int) -> void:
	_busy = true
	var from := run.current
	run.jump_to(id)
	view.selected = -1
	view.ship_from = from
	view.ship_to = id
	view.hint = "Sprung …"
	var tween := create_tween()
	tween.tween_method(view.set_ship_t, 0.0, 1.0, JUMP_TIME)
	tween.tween_callback(_arrived)


func _arrived() -> void:
	_busy = false
	if not run.dialog.is_empty():
		_show_run_dialog()
		return
	if _start_battle_if_needed():
		return
	view.hint = "Leeres System, keine Gegner. Die Crew verschnauft."


func _on_distress() -> void:
	if run.send_distress():
		view.hint = "Notsignal gesendet …"
		_show_run_dialog()


func _on_choice(index: int) -> void:
	if run.result != "" and run.dialog.is_empty():
		Game.new_run()
		Game.to_map()  # Ende-Dialog: neuer Run
		return
	run.choose(index)
	_show_run_dialog()
	if run.dialog.is_empty():
		_start_battle_if_needed()


## Zeigt den offenen Dialog des Runs, nach einem tödlichen Ereignis das Run-Ende.
func _show_run_dialog() -> void:
	if run.dialog.is_empty() and run.result == "verloren":
		dialog.show_dialog({
			"title": "Run vorbei", "scene": "wrack",
			"text": "Das Schiff ist verloren, nach %d von %d Sprüngen." % [run.jumps_done(), StarMap.JUMPS],
			"choices": [{"text": "Neuer Run", "enabled": true, "special": false}],
		})
		return
	dialog.show_dialog(run.dialog)
	if run.dialog.is_empty():
		view.hint = _default_hint()


func _start_battle_if_needed() -> bool:
	if not run.needs_battle():
		return false
	_busy = true
	view.hint = "Feindkontakt!" if run.node().type != "boss" else "Das Flaggschiff der Piraten!"
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(Game.to_battle)
	return true
