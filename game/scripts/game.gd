extends Node
## Autoload „Game“: hält den laufenden Run über Szenenwechsel hinweg, wechselt zwischen
## Hauptmenü und Schiff, speichert den Run (je Modus ein Slot, siehe SaveGame) und die Bestwerte.

const TITLE_SCENE := "res://scenes/title.tscn"
const SHIP_SCENE := "res://scenes/ship.tscn"
const HIGHSCORE_PATH := "user://highscore.json"

var run: RunState
## Modus, den das Hauptmenü zuletzt gestartet oder fortgesetzt hat.
var mode := RunState.MODE_HUNT
## Darf gerade gespeichert werden? Im Kampf und während eines Sprungs nicht (der Stand davor gilt).
var can_save := true


## Liefert den laufenden Run: erst aus dem Spielstand des Modus, sonst neu.
func ensure_run() -> RunState:
	if run == null:
		run = SaveGame.load_run(mode)
		if run == null:
			new_run(mode)
	return run


func new_run(p_mode := mode, seed_value := 0) -> RunState:
	mode = p_mode
	SaveGame.clear(mode)
	run = RunState.new(seed_value, mode)
	save()
	return run


## Setzt den gespeicherten Run eines Modus fort (oder beginnt einen neuen, falls keiner da ist).
func continue_run(p_mode: String) -> RunState:
	mode = p_mode
	run = null
	return ensure_run()


## Speichert den Run; ein beendeter Run wird gelöscht und als Bestwert vermerkt.
func save() -> void:
	if run == null:
		return
	if run.result != "":
		record_score(run)
		SaveGame.clear(run.mode)
	else:
		SaveGame.save(run)


## Bester erreichter Sektor je Modus (Endlos: Punktzahl, Jagd: wie weit man kam).
func best_score(p_mode: String) -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(HIGHSCORE_PATH)) if FileAccess.file_exists(HIGHSCORE_PATH) else null
	return int((data as Dictionary).get(p_mode, 0)) if data is Dictionary else 0


func record_score(r: RunState) -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(HIGHSCORE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HIGHSCORE_PATH))
		if parsed is Dictionary:
			data = parsed
	var score := r.score()
	if r.mode == RunState.MODE_HUNT and r.result == "geschafft":
		score = RunState.HUNT_SECTORS + 1  # alle Sektoren geschafft
	if score > int(data.get(r.mode, 0)):
		data[r.mode] = score
		var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(data))


func to_title() -> void:
	Sfx.stop_loops()
	get_tree().change_scene_to_file(TITLE_SCENE)


func to_ship() -> void:
	get_tree().change_scene_to_file(SHIP_SCENE)


## Beim Verlassen der App sichern, außer mitten im Kampf oder Sprung.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if run != null and can_save:
			save()
