class_name CrewPanel
extends Control
## Crew-Liste links (wie im Mockup): je Person ein Kasten mit Porträt, Name und Lebensbalken.
## Der Captain trägt einen goldenen Stern, die Farbe des Porträts zeigt die Spezies.
## Oben rechts im Kasten das Symbol der Tätigkeit (löschen, flicken, reparieren, geheilt werden).
## Antippen wählt die Person aus (die Crew-Karte zeigt dann, was sie kann).
## Auf schmalen Bildschirmen (`compact`) nur Porträts ohne Namen.

signal crew_selected(member: CrewMember)

const PORTRAITS := {
	"mensch": preload("res://assets/crew/mensch_gross_unten.png"),
}
const CROP := Rect2(10, 10, 20, 20)
const WIDE := Vector2(54, 18)
const NARROW := Vector2(24, 26)
const GAP := 2.0
const COLOR_SELECTED := Color("#5DCAA5")

var state: ShipState
var selected: CrewMember
var compact := false


func setup(p_state: ShipState) -> void:
	state = p_state
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resize()


func slot() -> Vector2:
	var s := NARROW if compact else WIDE
	if state and state.crew.size() > 6:
		s.y = 16.0 if not compact else 17.0  # volle Crew (8) passt noch neben das Schiff
	return s


func _resize() -> void:
	custom_minimum_size = Vector2(slot().x, maxi(state.crew.size(), 1) * (slot().y + GAP))
	size = custom_minimum_size


func _process(_delta: float) -> void:
	if state and size != Vector2(slot().x, maxi(state.crew.size(), 1) * (slot().y + GAP)):
		_resize()
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	var s := slot()
	for i in state.crew.size():
		var member := state.crew[i]
		var rect := Rect2(Vector2(0, i * (s.y + GAP)), s)
		HudStyle.box(self, rect, COLOR_SELECTED if member == selected else HudStyle.COLOR_EDGE)
		var portrait: Texture2D = PORTRAITS.get(member.species, PORTRAITS["mensch"])
		var tint := Species.tint(member.species)
		var ratio := member.hp / member.max_hp
		var hp_color := HudStyle.COLOR_OK if ratio > 0.6 else (HudStyle.COLOR_WARN if ratio > 0.3 else HudStyle.COLOR_BAD)
		if compact:
			draw_texture_rect_region(portrait, Rect2(rect.position + Vector2(2, 1), CROP.size), CROP, tint)
			var hp_bar := Rect2(rect.position + Vector2(2, s.y - 4), Vector2(s.x - 4, 2))
			draw_rect(hp_bar, HudStyle.COLOR_OFF)
			draw_rect(Rect2(hp_bar.position, Vector2(roundf(hp_bar.size.x * ratio), 2)), hp_color)
		else:
			var head := Rect2(10, 8, 20, 14)
			draw_texture_rect_region(portrait, Rect2(rect.position + Vector2(1, 2), Vector2(14, 10)), head, tint)
			var first := member.display_name.split(" ")[0]
			HudStyle.text(self, rect.position + Vector2(17, 9), first, HudStyle.COLOR_TEXT, s.x - 19)
			var hp_bar := Rect2(rect.position + Vector2(17, 12), Vector2(s.x - 20, 3))
			draw_rect(hp_bar, HudStyle.COLOR_OFF)
			draw_rect(Rect2(hp_bar.position, Vector2(roundf(hp_bar.size.x * ratio), 3)), hp_color)
		if member.is_captain():
			HudStyle.star(self, rect.position + Vector2(1, s.y - 7) if not compact else rect.position + Vector2(s.x - 7, s.y - 10))
		ActivityIcons.draw(self, rect.position + Vector2(s.x - 8, 1), member.activity)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := int(event.position.y / (slot().y + GAP))
		if idx >= 0 and idx < state.crew.size():
			crew_selected.emit(state.crew[idx])
			accept_event()
