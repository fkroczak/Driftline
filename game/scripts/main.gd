extends Node2D
## Prototyp Phase 1: eigenes Schiff mit Crew, Bewegung per Antippen.

const LAYOUT_PATH := "res://data/ships/mensch_frachter.json"
const MARGIN := 6.0

var state: ShipState

@onready var ship_view: ShipView = $ShipView
@onready var crew_panel: CrewPanel = $HUD/CrewPanel
@onready var info: Label = $HUD/Info


func _ready() -> void:
	var layout := ShipLayout.load_json(LAYOUT_PATH)
	for error in layout.validate():
		push_error("%s: %s" % [LAYOUT_PATH, error])
	state = ShipState.new(layout)
	state.add_crew("Mara Voss", "mensch", Vector2i(9, 3), {"cockpit": 3.0, "waffen": 1.0})
	state.add_crew("Jonas Reil", "mensch", Vector2i(6, 6), {"waffen": 3.0, "schilde": 1.0})
	state.add_crew("Ilka Brandt", "mensch", Vector2i(6, 2), {"schilde": 2.0, "antrieb": 2.0})
	ship_view.setup(state)
	crew_panel.setup(state)
	ship_view.selection_changed.connect(_on_selection_changed)
	crew_panel.crew_selected.connect(_on_crew_selected)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_on_selection_changed(null, -1)


## Crew-Leiste links, Schiff mittig im restlichen Platz. Die sichtbare Fläche ist
## je nach Handy unterschiedlich breit. Mit Gegnerschiff ändert sich das später.
func _layout() -> void:
	var view_size := get_viewport_rect().size
	var left := crew_panel.position.x + crew_panel.size.x
	var ship_size := ship_view.get_size()
	ship_view.position = Vector2(
		left + (view_size.x - left - ship_size.x) / 2.0,
		MARGIN + (view_size.y - ship_size.y) / 2.0,
	).floor()


func _process(delta: float) -> void:
	state.update(delta)
	_update_info()


func _on_crew_selected(member: CrewMember) -> void:
	ship_view.select(null if member == ship_view.selected else member)


func _on_selection_changed(member: CrewMember, _room_idx: int) -> void:
	crew_panel.selected = member
	_update_info()


func _update_info() -> void:
	var member := ship_view.selected
	if not member:
		var ordered := ship_view.last_order
		var room := ship_view.focused_room
		if ordered and ordered.is_moving():
			info.text = "%s → %s" % [ordered.display_name, state.layout.rooms[state.layout.room_index_at(ordered.destination())].name]
		else:
			info.text = state.layout.rooms[room].name if room >= 0 else "Crew antippen, dann Ziel antippen"
		return
	var target_room := state.layout.room_index_at(member.destination())
	var room_data: Dictionary = state.layout.rooms[target_room]
	var text := "%s → %s" % [member.display_name, room_data.name] if member.is_moving() else "%s · %s" % [member.display_name, room_data.name]
	if room_data.system != "" and room_data.console != null:
		text += " · Erfahrung %d" % member.level(room_data.system)
		if not member.is_moving() and member.tile == room_data.console:
			text += " · an der Konsole"
	info.text = text
