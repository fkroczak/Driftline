extends Node
## Autoload „Sfx“: spielt die Soundeffekte aus res://assets/sfx/ (erzeugt mit tools/sfxgen).
##
## - play(name): kurzer Effekt. Mehrere Stimmen gleichzeitig; derselbe Effekt kurz hintereinander
##   wird ausgedünnt, damit Salven und Explosionsketten nicht übersteuern.
## - loop(name, level): Dauerklang (Brummen, Feuer) mit Pegel 0..1, weich ein- und ausgeblendet.
## - muted: Ton aus/an, gespeichert über Settings (user://settings.json, Schlüssel "muted").

const DIR := "res://assets/sfx/"
const VOICES := 16
## Derselbe Effekt frühestens nach so vielen Millisekunden erneut.
const MIN_GAP_MS := 45
## Pegel von Schleifen bei level = 1.
const LOOP_DB := -8.0
const LOOP_FADE := 2.5  # Pegeländerung je Sekunde (linear, 0..1)

var muted := false:
	set(value):
		muted = value
		AudioServer.set_bus_mute(0, muted)
		_save_settings()

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}  # Name -> Zeit in ms
var _loops := {}  # Name -> {player, level, target}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_load_settings()


## Spielt einen Effekt. vary: zufällige Tonhöhenabweichung (±), damit Wiederholungen lebendig klingen.
func play(sound: String, volume_db := 0.0, pitch := 1.0, vary := 0.04) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sound, -100000)) < MIN_GAP_MS:
		return
	_last[sound] = now
	var p := _free_player()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch * (1.0 + randf_range(-vary, vary)), 0.05)
	p.play()


## Dauerklang auf Pegel 0..1 bringen (0 blendet aus und hält an).
func loop(sound: String, level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	if not _loops.has(sound):
		if level <= 0.0:
			return
		var stream := _stream(sound)
		if stream == null:
			return
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(wav.get_length() * wav.mix_rate)
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = -80.0
		add_child(p)
		p.play()
		_loops[sound] = {"player": p, "level": 0.0, "target": level}
		return
	_loops[sound].target = level


## Alle Dauerklänge ausblenden (z. B. beim Wechsel ins Hauptmenü).
func stop_loops() -> void:
	for sound: String in _loops:
		_loops[sound].target = 0.0


## Beim Beenden alles anhalten, sonst hält der Audioserver laufende Schleifen fest.
func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null
	for sound: String in _loops:
		var p: AudioStreamPlayer = _loops[sound].player
		p.stop()
		p.stream = null
	_loops.clear()
	_streams.clear()


func _process(delta: float) -> void:
	for sound: String in _loops.keys():
		var l: Dictionary = _loops[sound]
		l.level = move_toward(l.level, l.target, LOOP_FADE * delta)
		var p: AudioStreamPlayer = l.player
		if l.level <= 0.0 and l.target <= 0.0:
			p.queue_free()
			_loops.erase(sound)
			continue
		p.volume_db = LOOP_DB + linear_to_db(l.level)


func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := DIR + sound + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
		if _streams[sound] == null:
			push_warning("Sfx: %s fehlt" % path)
	return _streams[sound]


## Freie Stimme, sonst die älteste (reihum).
func _free_player() -> AudioStreamPlayer:
	for i in VOICES:
		var p := _players[(_next + i) % VOICES]
		if not p.playing:
			_next = (_next + i + 1) % VOICES
			return p
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	return p


func _load_settings() -> void:
	muted = bool(Settings.get_value("muted"))


func _save_settings() -> void:
	if bool(Settings.get_value("muted")) != muted:
		Settings.set_value("muted", muted)
