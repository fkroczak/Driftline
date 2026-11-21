extends Node2D
## Sternenkarte zwischen den Kämpfen. Ein gelbes Ziel antippen zeigt das Infofeld,
## ein zweites Antippen springt. Kampfknoten führen in die Kampfszene, leere Systeme sind sicher.
## Wer vor dem Boss geflohen ist, steht weiter vor ihm und greift per Antippen erneut an.

const JUMP_TIME := 0.7

var run: RunState
var _busy := false

@onready var view: MapView = $MapView


func _ready() -> void:
	run = Game.ensure_run()
	view.setup(run)
	view.node_tapped.connect(_on_node_tapped)
	view.background_tapped.connect(_on_background_tapped)
	get_viewport().size_changed.connect(_layout)
	_layout()
	view.hint = _default_hint()


func _layout() -> void:
	view.position = Vector2.ZERO
	view.size = get_viewport_rect().size


func _default_hint() -> String:
	if run.needs_battle():
		return "Das Flaggschiff wartet: Schiff antippen, um erneut anzugreifen"
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
	if run.needs_battle():
		view.hint = "Feindkontakt!" if run.node().type != "boss" else "Das Flaggschiff der Piraten!"
		var tween := create_tween()
		tween.tween_interval(0.8)
		tween.tween_callback(Game.to_battle)
		return
	_busy = false
	view.hint = "Leeres System, keine Gegner."
	if run.last_repair > 0:
		view.hint += " Zeit zum Flicken: Hülle +%d" % run.last_repair
	else:
		view.hint += " Die Crew verschnauft."
