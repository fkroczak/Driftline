class_name CrewPanel
extends Control
## Crew-Leiste: Porträt je Crewmitglied, Antippen wählt es aus.
## Darunter Punkte für die Erfahrung im System des Raums, in dem die Figur gerade ist.

signal crew_selected(member: CrewMember)

const PORTRAITS := {
	"mensch": preload("res://assets/crew/mensch_gross_unten.png"),
}
const SLOT := Vector2(44, 54)
const GAP := 3.0
const COLOR_BG := Color("#161B2B")
const COLOR_EDGE := Color("#363E58")
const COLOR_SELECTED := Color("#5DCAA5")
const COLOR_XP := Color("#FAC775")
const COLOR_XP_EMPTY := Color("#2A2F3A")

var state: ShipState
var selected: CrewMember


func setup(p_state: ShipState) -> void:
	state = p_state
	custom_minimum_size = Vector2(SLOT.x, state.crew.size() * (SLOT.y + GAP))
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	for i in state.crew.size():
		var member := state.crew[i]
		var rect := Rect2(Vector2(0, i * (SLOT.y + GAP)), SLOT)
		draw_rect(rect, COLOR_BG)
		draw_rect(rect.grow(-0.5), COLOR_SELECTED if member == selected else COLOR_EDGE, false, 1.0)
		var portrait: Texture2D = PORTRAITS.get(member.species, PORTRAITS["mensch"])
		draw_texture(portrait, rect.position + Vector2(2, 1))
		# Erfahrung im aktuellen Raum: bis zu 5 Punkte
		var room := state.layout.room_index_at(member.tile)
		var system: String = state.layout.rooms[room].system if room >= 0 else ""
		if system != "":
			var level := member.level(system)
			for dot in int(CrewMember.MAX_EXPERIENCE):
				var p := rect.position + Vector2(8 + dot * 6, SLOT.y - 6)
				draw_rect(Rect2(p, Vector2(4, 3)), COLOR_XP if dot < level else COLOR_XP_EMPTY)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := int(event.position.y / (SLOT.y + GAP))
		if idx >= 0 and idx < state.crew.size():
			crew_selected.emit(state.crew[idx])
			accept_event()
