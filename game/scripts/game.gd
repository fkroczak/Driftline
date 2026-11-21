extends Node
## Autoload „Game“: hält den laufenden Run über Szenenwechsel hinweg, wechselt
## zwischen Sternenkarte und Kampf und speichert den Run (siehe SaveGame).

const MAP_SCENE := "res://scenes/map.tscn"
const BATTLE_SCENE := "res://scenes/battle.tscn"

var run: RunState
## Der Run kam beim Start aus dem Spielstand (die Karte setzt dann einen offenen Kampf fort).
var resumed := false


## Startet einen Run, falls keiner läuft: erst aus dem Spielstand, sonst neu.
func ensure_run() -> RunState:
	if run == null:
		run = SaveGame.load_run()
		resumed = run != null
		if run == null:
			new_run()
	return run


func new_run(seed_value := 0) -> RunState:
	run = RunState.new(seed_value)
	resumed = false
	save()
	return run


## Speichert den Run; ein beendeter Run wird gelöscht, damit der nächste Start neu beginnt.
func save() -> void:
	if run == null:
		return
	if run.result != "":
		SaveGame.clear()
	else:
		SaveGame.save(run)


func to_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


func to_battle() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Beim Verlassen der App auf der Sternenkarte sichern (im Kampf gilt der Stand davor).
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		var scene := get_tree().current_scene
		if scene and scene.scene_file_path == MAP_SCENE:
			save()
