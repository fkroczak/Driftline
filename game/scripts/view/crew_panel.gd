class_name CrewPanel
extends Control
## Crew-Leiste: kompaktes Porträt (Kopf und Schultern) je Crewmitglied, Antippen wählt es aus.
## Darunter Lebensbalken und Punkte für die Erfahrung im System des aktuellen Raums,
## oben rechts das Symbol der Tätigkeit (löschen, flicken, reparieren, geheilt werden).

signal crew_selected(member: CrewMember)

const PORTRAITS := {
	"mensch": preload("res://assets/crew/mensch_gross_unten.png"),
}
## Ausschnitt aus dem 40×44-Porträt.
const CROP := Rect2(6, 8, 28, 28)
const SLOT := Vector2(32, 39)
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
		draw_texture_rect_region(portrait, Rect2(rect.position + Vector2(2, 1), CROP.size), CROP)
		ActivityIcons.draw(self, rect.position + Vector2(SLOT.x - 8, 1), member.activity)
		# Lebenspunkte
		var ratio := member.hp / CrewMember.MAX_HP
		var hp_color := Color("#5DCAA5") if ratio > 0.6 else (Color("#FAC775") if ratio > 0.3 else Color("#E24B4A"))
		var hp_bar := Rect2(rect.position + Vector2(3, SLOT.y - 8), Vector2(SLOT.x - 6, 2))
		draw_rect(hp_bar, COLOR_XP_EMPTY)
		draw_rect(Rect2(hp_bar.position, Vector2(roundf(hp_bar.size.x * ratio), 2)), hp_color)
		# Erfahrung im aktuellen Raum: bis zu 5 Punkte
		var room := state.layout.room_index_at(member.tile)
		var system: String = state.layout.rooms[room].system if room >= 0 else ""
		if system != "":
			var level := member.level(system)
			for dot in int(CrewMember.MAX_EXPERIENCE):
				var p := rect.position + Vector2(4 + dot * 5, SLOT.y - 4)
				draw_rect(Rect2(p, Vector2(4, 2)), COLOR_XP if dot < level else COLOR_XP_EMPTY)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := int(event.position.y / (SLOT.y + GAP))
		if idx >= 0 and idx < state.crew.size():
			crew_selected.emit(state.crew[idx])
			accept_event()
