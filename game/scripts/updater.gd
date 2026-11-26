extends Node
## Autoload „Updater“: fragt beim Start die GitHub-Releases ab (öffentlich, ohne Anmeldung,
## kein eigener Server) und meldet eine neuere Version als Banner im Hauptmenü.
##
## Android: LADEN lädt die APK nach user://updates/ und öffnet sie mit OS.shell_open (Godots
## FileProvider). Android zeigt dann seinen Installationsdialog; das Update installiert sich über
## die alte Version (gleicher Schlüssel, höhere Build-Nummer), der Spielstand bleibt. Beim ersten
## Mal fragt Android, ob Hullbound Apps installieren darf. Nötig sind die Berechtigungen INTERNET
## und REQUEST_INSTALL_PACKAGES (export_presets.cfg).
## iOS: Eine App darf sich dort nicht selbst installieren; ANSEHEN öffnet die Release-Seite.
## Am Computer und in Builds ohne Build-Nummer (Editor) wird nicht geprüft.

const DIR := "user://updates/"
const USER_AGENT := "User-Agent: Hullbound"  # ohne User-Agent lehnt die GitHub-API ab
const API_HEADERS := [USER_AGENT, "Accept: application/vnd.github+json"]
const CHECK_TIMEOUT := 15.0
## 256 KiB statt der vorgegebenen 64 KiB: weniger Durchläufe bei einer APK von rund 60 MB.
const CHUNK_SIZE := 262144

var state := UpdateCheck.State.NONE
## Gefundenes Update; null, solange keins da ist.
var offer: UpdateCheck.Offer
## Banner in dieser Sitzung weggeklickt.
var dismissed := false
## Text für das Banner (deutscher Schlüssel für Loc.t), leer = kein Fehler.
var error := ""

var _download: HTTPRequest


func _ready() -> void:
	if UpdateCheck.platform() != "" and UpdateCheck.can_check(UpdateCheck.current_version()):
		_check()


## Knopf im Banner: laden, installieren oder (iOS) die Release-Seite öffnen.
func start() -> void:
	match state:
		UpdateCheck.State.AVAILABLE, UpdateCheck.State.FAILED:
			if UpdateCheck.platform() == "android":
				_fetch()
			elif OS.shell_open(offer.page) != OK:
				push_warning("Release-Seite ließ sich nicht öffnen: %s" % offer.page)
		UpdateCheck.State.READY:
			_install()


## Anteil des Downloads (0–1).
func progress() -> float:
	if _download == null or offer == null or offer.size <= 0:
		return 0.0
	return float(_download.get_downloaded_bytes()) / offer.size


func _check() -> void:
	var http := HTTPRequest.new()
	http.timeout = CHECK_TIMEOUT
	add_child(http)
	if http.request(UpdateCheck.API_URL % UpdateCheck.REPOSITORY, API_HEADERS) != OK:
		http.queue_free()
		return
	var res: Array = await http.request_completed  # [result, code, headers, body]
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return  # kein Netz oder GitHub nicht erreichbar: dann eben kein Banner
	var body: PackedByteArray = res[3]
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Array):
		return
	var releases: Array = data
	offer = UpdateCheck.find_update(releases, UpdateCheck.platform(), UpdateCheck.current_version())
	_clean_up()
	if offer == null:
		return
	var loaded := _file_size(_path()) == offer.size  # schon in einer früheren Sitzung geladen
	state = UpdateCheck.State.READY if loaded else UpdateCheck.State.AVAILABLE


func _fetch() -> void:
	if DirAccess.make_dir_recursive_absolute(DIR) != OK:
		_fail("Download fehlgeschlagen")  # i18n
		return
	var part := _path() + ".part"
	_download = HTTPRequest.new()
	_download.download_file = part
	_download.use_threads = true
	_download.download_chunk_size = CHUNK_SIZE
	add_child(_download)
	state = UpdateCheck.State.DOWNLOADING
	error = ""
	if _download.request(offer.url, [USER_AGENT]) != OK:
		_fail("Download fehlgeschlagen")  # i18n
		return
	var res: Array = await _download.request_completed
	var complete: bool = res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200 \
		and _download.get_downloaded_bytes() == offer.size
	if not complete or DirAccess.rename_absolute(part, _path()) != OK:
		_remove(part)
		_fail("Download fehlgeschlagen")  # i18n
		return
	_download.queue_free()
	_download = null
	state = UpdateCheck.State.READY
	# Installationsdialog gleich öffnen, aber nicht mitten in einem Run (dann über das Banner)
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == Game.TITLE_SCENE:
		_install()


func _install() -> void:
	error = ""
	if OS.shell_open(ProjectSettings.globalize_path(_path())) != OK:
		error = "Installation ließ sich nicht starten"  # i18n


func _fail(message: String) -> void:
	if _download:
		_download.queue_free()
		_download = null
	state = UpdateCheck.State.FAILED
	error = message


func _path() -> String:
	return DIR + (offer.file if offer else "")


## Löscht alte Downloads; nur die Datei des aktuellen Angebots bleibt.
func _clean_up() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f: String in DirAccess.get_files_at(DIR):
		if offer == null or f != offer.file:
			_remove(DIR + f)


## Ein Fehlschlag kostet nur Speicherplatz, darum Warnung statt Abbruch.
func _remove(path: String) -> void:
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
		push_warning("Konnte %s nicht löschen" % path)


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else -1
