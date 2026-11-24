class_name JumpButton
extends Control
## Sprungknopf oben rechts (wie im Mockup): „SPRUNG“ mit Ladebalken des Sprungantriebs.
## Nach jedem Sprung lädt der Antrieb neu: außerhalb des Kampfs schnell, im Kampf langsam.
## Laden und Springen gehen nur mit Energie im Antrieb und besetztem Cockpit. Ist er voll, blinkt der Knopf; Antippen öffnet
## die Sternenkarte zur Zielwahl. Lädt er nicht, steht der Grund in der zweiten Zeile.

signal jump_requested

var state: ShipState
var run: RunState
var _time := 0.0
var _deny := 0.0


func setup(p_state: ShipState, p_run: RunState = null) -> void:
	state = p_state
	run = p_run
	mouse_filter = Control.MOUSE_FILTER_STOP


func deny() -> void:
	_deny = 0.25


## Warum der Sprung (noch) nicht geht, "" = bereit. Deutsch als Code; angezeigt wird Loc.t(reason()).
func reason() -> String:
	if state.operator_of_system("cockpit") == null or state.level("cockpit") <= 0:
		return "Pilot?"  # i18n
	if state.level("antrieb") <= 0:
		return "Antrieb?"  # i18n
	if not state.jump_ready():
		return "%d %%" % floori(state.jump_charge * 100.0)
	if run and run.fuel < run.jump_cost() and not run.sector_cleared:  # der Sprung in den nächsten Sektor ist frei
		return "kein Treibstoff"  # i18n
	return ""


func _process(delta: float) -> void:
	_time += delta
	_deny = maxf(_deny - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	var x := roundf(sin(_deny * 60.0) * 1.5) if _deny > 0.0 else 0.0
	var rect := Rect2(Vector2(x, 0), size)
	var why := reason()
	var ready := why == ""
	var blink := ready and fmod(_time, 0.8) < 0.4
	HudStyle.box(self, rect, HudStyle.COLOR_WARN if ready else HudStyle.COLOR_EDGE)
	if blink:
		draw_rect(rect.grow(-1), Color(HudStyle.COLOR_WARN, 0.2))
	var title := Loc.t("SPRUNG")
	var tw := HudStyle.text_width(title)
	HudStyle.text(self, rect.position + Vector2(roundf((size.x - tw) / 2.0), 9), title,
		HudStyle.COLOR_WARN if ready else HudStyle.COLOR_TEXT)
	var bar := Rect2(rect.position + Vector2(4, 12), Vector2(size.x - 8, 4))
	draw_rect(bar, HudStyle.COLOR_OFF)
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * state.jump_charge), bar.size.y)),
		HudStyle.COLOR_WARN if state.jump_charge >= 1.0 else HudStyle.COLOR_FUEL.darkened(0.2))
	draw_rect(bar.grow(0.5), Color(HudStyle.COLOR_WARN, 0.5), false, 1.0)
	var line := (Loc.t("Neuer Sektor") if run and run.sector_cleared else Loc.t("Ziel wählen")) if ready else Loc.t(why)
	var lw := HudStyle.text_width(line)
	HudStyle.text(self, rect.position + Vector2(roundf((size.x - lw) / 2.0), 23), line,
		HudStyle.COLOR_WARN if ready else HudStyle.COLOR_DIM, size.x - 2)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		jump_requested.emit()
		accept_event()
