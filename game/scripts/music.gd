extends Node
## Autoload „Music“: ruhige Hintergrundmusik aus res://assets/music/ (erzeugt mit
## tools/musicgen, Satz AMBIENT).
##
## - situation(name): "titel", "ruhe", "ereignis", "station", "piraten", "jaeger" oder "ende".
##   Im Modus „Auto“ (Einstellung music_track) gehört zu jeder Situation ein Stück. Eine neue
##   Situation gilt erst, wenn sie HOLD Sekunden anhält (kein Hin und Her bei kurzen Dialogen),
##   dann wird weich überblendet.
## - Ist in den Einstellungen ein festes Stück gewählt, läuft überall dieses.
## - Eigener Bus „Music“; Ton aus (Sfx.muted) schaltet den Master und damit auch die Musik stumm.

const DIR := "res://assets/music/"
const BUS := "Music"
const BUS_DB := -6.0
const FADE := 2.0  # Sekunden für Ein-/Ausblenden
const HOLD := 0.8  # so lange muss eine neue Situation anhalten
## Reihenfolge = Nummer in den Einstellungen (1–5).
const TRACKS := ["stille_drift", "signal_im_nebel", "enterhaken", "schatten_der_jaeger", "andockhafen"]
const TITLES := {"stille_drift": "Stille Drift", "signal_im_nebel": "Signal im Nebel",
	"enterhaken": "Enterhaken", "schatten_der_jaeger": "Schatten der Jäger", "andockhafen": "Andockhafen"}
const AUTO := {"titel": "stille_drift", "ruhe": "stille_drift", "ereignis": "signal_im_nebel",
	"station": "andockhafen", "piraten": "enterhaken", "jaeger": "schatten_der_jaeger", "ende": ""}

var _players: Array[AudioStreamPlayer] = []
var _active := 0  # Index des Spielers, der gerade einblendet bzw. spielt
var _current := ""  # laufendes Stück ("" = Stille)
var _situation := ""
var _pending := ""
var _pending_time := 0.0
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, BUS_DB)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	refresh.call_deferred()


## Spielsituation melden (darf jedes Bild aufgerufen werden). Wirkt nach HOLD Sekunden,
## die erste Meldung sofort.
func situation(name: String, immediate := false) -> void:
	if name == _situation:
		_pending = ""
		return
	if immediate or _situation == "":
		_situation = name
		_pending = ""
		refresh()
		return
	if name != _pending:
		_pending = name
		_pending_time = 0.0


## Stück passend zu Einstellung und Situation wählen (auch nach Änderung der Einstellungen).
func refresh() -> void:
	_switch_to(wanted())


## Welches Stück jetzt laufen soll ("" = keins).
func wanted() -> String:
	var fixed := str(Settings.get_value("music_track"))
	if fixed == "off":
		return ""
	if fixed in TRACKS:
		return fixed
	return str(AUTO.get(_situation, ""))


func current() -> String:
	return _current


static func title_of(track: String) -> String:
	return str(TITLES.get(track, track))


func _switch_to(track: String) -> void:
	if track == _current:
		return
	_current = track
	if track == "":
		return  # _process blendet alles aus
	var stream := _stream(track)
	if stream == null:
		return
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = -80.0
	p.play()


func _process(delta: float) -> void:
	if _pending != "":
		_pending_time += delta
		if _pending_time >= HOLD:
			_situation = _pending
			_pending = ""
			refresh()
	for i in _players.size():
		var p := _players[i]
		if not p.playing:
			continue
		var target := 1.0 if i == _active and _current != "" else 0.0
		var level := move_toward(db_to_linear(p.volume_db), target, delta / FADE)
		if level <= 0.001 and target == 0.0:
			p.stop()
			p.volume_db = -80.0
			continue
		p.volume_db = linear_to_db(maxf(level, 0.0001))


func _stream(track: String) -> AudioStream:
	if not _streams.has(track):
		var path := DIR + track + ".ogg"
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		if s == null:
			push_warning("Music: %s fehlt" % path)
		_streams[track] = s
	return _streams[track]


## Beim Beenden alles anhalten und freigeben, sonst hält der Audioserver den Ogg-Stream fest.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE]:
		_release()


func _exit_tree() -> void:
	_release()


func _release() -> void:
	for p in _players:
		p.stop()
		p.stream = null
	_streams.clear()
	_current = ""
