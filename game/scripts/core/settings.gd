class_name Settings
extends RefCounted
## Einstellungen des Spielers (user://settings.json), gelten für alle Spielstände.
##
## - crisp_text: Schrift in voller Bildschirmauflösung (HD) statt im 384×216-Raster (Retro).
##   Die Pixel-Art bleibt in beiden Fällen ganzzahlig skaliert.
## - speed: Spieltempo an Bord und im Kampf (0,75 / 1 / 1,25).
## - auto_pause: Kampf hält an, solange Crew oder Waffe zum Befehlen ausgewählt ist.
## - shake: Bildschirm wackelt bei Treffern.
## - fullscreen: nur am Computer.
## - muted: Ton aus (Sfx liest und schreibt ihn hier mit).

const PATH := "user://settings.json"
const DEFAULTS := {
	"crisp_text": true,
	"speed": 1.0,
	"auto_pause": true,
	"shake": true,
	"fullscreen": false,
	"muted": false,
}

static var _data: Dictionary = {}


static func _load() -> void:
	if not _data.is_empty():
		return
	_data = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for key: String in DEFAULTS:
				if (parsed as Dictionary).has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
					_data[key] = parsed[key]


static func get_value(key: String) -> Variant:
	_load()
	return _data.get(key, DEFAULTS.get(key))


static func set_value(key: String, value: Variant) -> void:
	_load()
	_data[key] = value
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data))
	apply()


static func speed() -> float:
	return float(get_value("speed"))


static func has_fullscreen() -> bool:
	return OS.has_feature("pc")


## Wendet Darstellung und Fenstermodus an (beim Start und nach jeder Änderung).
static func apply() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var sfx := tree.root.get_node_or_null("Sfx")
	if sfx and bool(sfx.get("muted")) != bool(get_value("muted")):
		sfx.set("muted", get_value("muted"))
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if get_value("crisp_text") else Window.CONTENT_SCALE_MODE_VIEWPORT
	if has_fullscreen() and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if get_value("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (want == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)
