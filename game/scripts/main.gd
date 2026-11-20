extends Node2D
## Prototyp Phase 1: eigenes Schiff mit Crew, Bewegung per Antippen.

const LAYOUT_PATH := "res://data/ships/mensch_frachter.json"

var state: ShipState

@onready var ship_view: ShipView = $ShipView
@onready var info: Label = $HUD/Info


func _ready() -> void:
	var layout := ShipLayout.load_json(LAYOUT_PATH)
	for error in layout.validate():
		push_error("%s: %s" % [LAYOUT_PATH, error])
	state = ShipState.new(layout)
	state.add_crew("Mara Voss", "mensch", Vector2i(9, 3))
	state.add_crew("Jonas Reil", "mensch", Vector2i(6, 6))
	state.add_crew("Ilka Brandt", "mensch", Vector2i(6, 2))
	ship_view.setup(state)
	get_viewport().size_changed.connect(_layout)
	_layout()
	ship_view.selection_changed.connect(_on_selection_changed)
	_on_selection_changed(null, -1)


## Schiff mittig in der sichtbaren Fläche (sie ist je nach Handy unterschiedlich breit).
## Mit Gegnerschiff rückt es später in die linke Hälfte.
func _layout() -> void:
	var view_size := get_viewport_rect().size
	ship_view.position = ((view_size - ship_view.get_size()) / 2.0).floor()


func _process(delta: float) -> void:
	state.update(delta)


func _on_selection_changed(member: CrewMember, room_idx: int) -> void:
	var room_name: String = state.layout.rooms[room_idx].name if room_idx >= 0 else ""
	if member and room_name:
		info.text = "%s → %s" % [member.display_name, room_name]
	elif member:
		info.text = "%s ausgewählt – Zielraum antippen" % member.display_name
	elif room_name:
		info.text = room_name
	else:
		info.text = "Crewmitglied antippen, dann Zielraum antippen"
