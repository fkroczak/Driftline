class_name TutorialCoach
extends Control
## Tutorial-Hinweise über dem Schiff: ein Kasten mit dem aktuellen Schritt und ein blinkender Rahmen
## um das Bedienelement, um das es geht. Schritte mit Aufgabe gehen von selbst weiter, sobald
## ship_screen.gd sie als erledigt meldet (`check`); Info-Schritte mit WEITER. Jeder Schritt lässt
## sich überspringen, BEENDEN führt zurück ins Hauptmenü.
##
## Der Kasten nimmt nur Eingaben auf seinen Knöpfen an; alles andere geht ans Spiel durch.

signal finished

const W := 168.0
const LINE := 10.0
const COLOR_EDGE := Color("#FAC775")
const COLOR_TITLE := Color("#FDE6BF")

## id, Überschrift, Text, info (nur WEITER), at ("right" oder "left": wo der Kasten steht)
const STEPS := [
	["intro", "Willkommen an Bord", "Das ist dein Frachter. Oben links Hülle und Schilde, daneben Treibstoff und Rohstoffe. Links deine Crew.", true, "right"],  # i18n
	["select", "Crew auswählen", "Tippe eine Figur im Schiff an (oder links in der Crew-Liste).", false, "right"],  # i18n
	["move", "Crew bewegen", "Tippe jetzt einen Raum an: Die Figur läuft dorthin. An einer Konsole bedient sie das System und macht es stärker.", false, "right"],  # i18n
	["power", "Energie verteilen", "Unten links: Spalte antippen gibt +1 Energie, gedrückt halten nimmt 1 weg. Der Reaktor reicht nie für alles.", false, "right"],  # i18n
	["doors", "Türen und Schleusen", "Türen unten rechts oder direkt im Schiff antippen. Offene Schleusen saugen die Luft ab und ersticken so Feuer.", true, "right"],  # i18n
	["pause", "Pause", "Tippe den Pause-Knopf oben rechts (oder Leertaste). In der Pause gibst du in Ruhe Befehle.", false, "right"],  # i18n
	["unpause", "Weiter geht's", "Nochmal antippen, dann läuft die Zeit weiter. Gedrückt halten schaltet die Auto-Pause um.", false, "right"],  # i18n
	["jump", "Springen", "Der Sprungantrieb lädt (Balken bei SPRUNG). Ist er voll, tippe SPRUNG an. Im Cockpit muss jemand sitzen.", false, "right"],  # i18n
	["map", "Sternenkarte", "Tippe ein gelbes Ziel an, nochmal antippen springt. Jeder Sprung kostet 1 Treibstoff.", false, "right"],  # i18n
	["battle", "Feindkontakt!", "Ein Piratenkutter. Solange dieser Kasten offen ist, steht der Kampf. Deine Waffen laden unten, sobald sie Energie haben.", true, "left"],  # i18n
	["target", "Ziel wählen", "Tippe einen Raum des Gegners an: Alle Waffen zielen dorthin und feuern, sobald sie geladen sind. Tipp: erst die Schilde!", false, "left"],  # i18n
	["win", "Durchhalten", "Schilde fangen Schüsse ab, deine Crew repariert beschädigte Räume. Zerstöre den Kutter!", false, "left"],  # i18n
	["done", "Geschafft!", "Du kennst jetzt die Grundlagen. Im Lexikon findest du alle Schiffe und Spezies, die du entdeckt hast. Viel Glück, Captain!", true, "right"],  # i18n
]

## Liefert true, wenn die Aufgabe des Schritts erledigt ist: func(step_id: String) -> bool
var check: Callable
## Rahmen um das Bedienelement des Schritts (leer = keiner): func(step_id: String) -> Rect2
var focus: Callable
## Linke Kante für Kästen mit at = "left" (rechts neben der Crew-Liste).
var left_x := 40.0
var top_y := 30.0

var step := 0
var _time := 0.0
var _box := Rect2()
var _next_rect := Rect2()
var _quit_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func current_id() -> String:
	return STEPS[step][0] if step < STEPS.size() else ""


## Info-Schritt offen: Das Spiel steht so lange.
func wants_pause() -> bool:
	return visible and step < STEPS.size() and STEPS[step][3]


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if step < STEPS.size() and not STEPS[step][3] and check.is_valid() and check.call(current_id()):
		_advance()
	queue_redraw()


func _advance() -> void:
	step += 1
	_time = 0.0
	if step >= STEPS.size():
		finished.emit()


func _draw() -> void:
	if step >= STEPS.size():
		return
	var s: Array = STEPS[step]
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	if focus.is_valid():
		var r: Rect2 = focus.call(s[0])
		if r.has_area():
			draw_rect(r.grow(2), Color(COLOR_EDGE, 0.35 + 0.65 * pulse), false, 1.0)
	var lines := HudStyle.wrap_text(Loc.t(s[2]), W - 12)
	var h := 16.0 + lines.size() * LINE + 24.0
	var x := left_x if s[4] == "left" else size.x - W - 4.0
	_box = Rect2(Vector2(x, top_y).floor(), Vector2(W, h))
	HudStyle.box(self, _box, COLOR_EDGE, Color("#0A0B16", 0.94))
	HudStyle.text(self, _box.position + Vector2(6, 11), Loc.t(s[1]), COLOR_TITLE)
	var count := "%d/%d" % [step + 1, STEPS.size()]
	HudStyle.text(self, Vector2(_box.end.x - 6 - HudStyle.text_width(count), _box.position.y + 11), count, HudStyle.COLOR_DIM)
	var y := _box.position.y + 23.0
	for line in lines:
		HudStyle.text(self, Vector2(_box.position.x + 6, y), line, HudStyle.COLOR_TEXT)
		y += LINE
	var by := _box.end.y - 17.0
	var last := step == STEPS.size() - 1
	_quit_rect = Rect2(_box.position.x + 6, by, 56, 13) if not last else Rect2()
	if not last:
		HudStyle.button(self, _quit_rect, Loc.t("BEENDEN"), HudStyle.COLOR_DIM)
	var label := Loc.t("ZUM MENÜ") if last else (Loc.t("WEITER") if s[3] else Loc.t("ÜBERSPRINGEN"))
	var color := HudStyle.COLOR_OK if s[3] else HudStyle.COLOR_DIM
	_next_rect = Rect2(_box.end.x - 6 - 72, by, 72, 13)
	if s[3] and fmod(_time, 1.2) < 0.6:
		draw_rect(_next_rect.grow(1), Color(color, 0.25))
	HudStyle.button(self, _next_rect, label, color)


func _input(event: InputEvent) -> void:
	if not visible or step >= STEPS.size():
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos := (make_input_local(event) as InputEventMouseButton).position
	var on_next := _next_rect.grow(2).has_point(pos)
	var on_quit := _quit_rect.has_area() and _quit_rect.grow(2).has_point(pos)
	if not (on_next or on_quit or _box.has_point(pos)):
		return
	get_viewport().set_input_as_handled()  # Kasten schluckt Taps (auch das Loslassen)
	if not event.pressed:
		return
	if on_quit or on_next:
		Sfx.play("ui_click")
	if on_quit:
		Game.end_tutorial()
	elif on_next:
		if step == STEPS.size() - 1:
			Game.end_tutorial()
		else:
			_advance()
