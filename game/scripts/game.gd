extends Node
## Autoload „Game“: hält den laufenden Run über Szenenwechsel hinweg und wechselt
## zwischen Sternenkarte und Kampf.

const MAP_SCENE := "res://scenes/map.tscn"
const BATTLE_SCENE := "res://scenes/battle.tscn"

var run: RunState


## Startet einen Run, falls keiner läuft (z. B. wenn eine Szene direkt im Editor gestartet wird).
func ensure_run() -> RunState:
	if run == null:
		new_run()
	return run


func new_run(seed_value := 0) -> RunState:
	run = RunState.new(seed_value)
	return run


func to_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


func to_battle() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)
