extends Node2D
## Prototyp Phase 1: eigenes Schiff gegen einen Piratenkutter.
## Crew bewegen, Energie verteilen, je Waffe ein Ziel wählen, Türen und Schleusen schalten.
## Waffen feuern selbst; Feuer, Hüllenbrüche und Sauerstoff laufen in ShipState.

const LAYOUT_PATH := "res://data/ships/mensch_frachter.json"
const ENEMY_PATH := "res://data/ships/piraten_kutter.json"
const MARGIN := 6.0
const TOP := 30.0
const BOTTOM_PANEL_Y := 184.0
const COLOR_PLAYER_BOLT := Color("#FAC775")
const COLOR_ENEMY_BOLT := Color("#E24B4A")
const COLOR_SHIELD := Color("#85B7EB")
## Sichtbarer Rumpf im Sprite (ohne transparenten Rand): links/rechts.
const PLAYER_HULL_X := Vector2(35, 257)
const ENEMY_HULL_X := Vector2(2, 116)

var state: ShipState
var enemy: ShipState
var battle: Battle

var _shake := 0.0
var _red_flash := 0.0
var _enemy_base := Vector2.ZERO
var _time := 0.0
var _explosion_queue: Array[Dictionary] = []  # {delay, pos, strength}
var _can_restart_at := -1.0
var _hint := ""
var _hint_until := 0.0

@onready var world: Node2D = $World
@onready var ship_view: ShipView = $World/ShipView
@onready var enemy_view: ShipView = $World/EnemyView
@onready var effects: Effects = $World/Effects
@onready var crew_panel: CrewPanel = $HUD/CrewPanel
@onready var power_panel: PowerPanel = $HUD/PowerPanel
@onready var weapon_panel: WeaponPanel = $HUD/WeaponPanel
@onready var status_bar: StatusBar = $HUD/StatusBar
@onready var info: Label = $HUD/Info
@onready var damage_flash: ColorRect = $HUD/DamageFlash
@onready var banner: Label = $HUD/Banner


func _ready() -> void:
	var layout := ShipLayout.load_json(LAYOUT_PATH)
	for error in layout.validate():
		push_error("%s: %s" % [LAYOUT_PATH, error])
	state = ShipState.new(layout)
	state.add_crew("Mara Voss", "mensch", Vector2i(9, 3), {"cockpit": 3.0, "waffen": 1.0})
	state.add_crew("Jonas Reil", "mensch", Vector2i(6, 6), {"waffen": 3.0, "schilde": 1.0})
	state.add_crew("Ilka Brandt", "mensch", Vector2i(6, 0), {"schilde": 2.0, "antrieb": 2.0})

	var enemy_layout := ShipLayout.load_json(ENEMY_PATH)
	for error in enemy_layout.validate():
		push_error("%s: %s" % [ENEMY_PATH, error])
	enemy = ShipState.new(enemy_layout)
	for spec in [["Kapitänin", "cockpit"], ["Schütze", "waffen"], ["Mechaniker", "schilde"]]:
		var console: Vector2i = enemy_layout.console_of(enemy_layout.room_index_by_id(spec[1]))
		enemy.add_crew(spec[0], "mensch", console, {spec[1]: 1.0})

	battle = Battle.new(state, enemy)
	ship_view.setup(state)
	enemy_view.setup(enemy)
	effects.battle = battle
	crew_panel.setup(state)
	power_panel.setup(state, load(state.layout.sprite_path))
	weapon_panel.setup(state, enemy)
	enemy_view.aim_weapons = state.weapons
	status_bar.setup(state)
	ship_view.selection_changed.connect(_on_selection_changed)
	enemy_view.room_tapped.connect(_on_enemy_room)
	weapon_panel.selection_changed.connect(func(idx: int) -> void: enemy_view.aim_selected = idx)
	ship_view.hatch_toggled.connect(_on_hatch_toggled)
	crew_panel.crew_selected.connect(_on_crew_selected)
	banner.gui_input.connect(_on_banner_input)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_on_selection_changed(null, -1)


## Crew-Leiste links, eigenes Schiff direkt daneben, Gegner mittig im restlichen Platz.
## Unten Energie- und Waffenleiste. Die sichtbare Fläche ist je nach Handy 384–480 px breit.
func _layout() -> void:
	var view_size := get_viewport_rect().size
	var left := crew_panel.position.x + crew_panel.size.x + 2.0
	var ship_size := ship_view.get_size()
	var play_h := BOTTOM_PANEL_Y - TOP
	ship_view.position = Vector2(left - PLAYER_HULL_X.x, TOP + (play_h - ship_size.y) / 2.0).floor()
	var player_right := ship_view.position.x + PLAYER_HULL_X.y
	var enemy_w := ENEMY_HULL_X.y - ENEMY_HULL_X.x
	var free := view_size.x - player_right
	var enemy_x := player_right + (free - enemy_w) / 2.0 - ENEMY_HULL_X.x
	enemy_x = minf(enemy_x, view_size.x - ENEMY_HULL_X.y - 2.0)
	var enemy_size := enemy_view.get_size()
	_enemy_base = Vector2(enemy_x, ship_view.position.y + (ship_size.y - enemy_size.y) / 2.0).floor()
	enemy_view.position = _enemy_base
	power_panel.position = Vector2(left + 4.0, BOTTOM_PANEL_Y)
	weapon_panel.position = Vector2(power_panel.position.x + power_panel.size.x + 6.0, BOTTOM_PANEL_Y)
	status_bar.position = Vector2(view_size.x - status_bar.size.x - MARGIN, 4.0).floor()
	damage_flash.size = view_size
	banner.size = view_size


func _process(delta: float) -> void:
	_time += delta
	battle.update(delta)
	for e in battle.take_events():
		_on_battle_event(e)
	_update_explosions(delta)
	_ambient_effects(ship_view, delta)
	_ambient_effects(enemy_view, delta)
	# Gegner schwebt leicht, solange er intakt ist
	if not enemy.is_destroyed():
		enemy_view.position = _enemy_base + Vector2(0, roundf(sin(_time * 1.3)))
	_shake = move_toward(_shake, 0.0, delta * 14.0)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _shake if _shake > 0.3 else Vector2.ZERO
	_red_flash = move_toward(_red_flash, 0.0, delta * 1.5)
	damage_flash.color = Color(0.89, 0.29, 0.29, _red_flash)
	_update_info()


func _on_battle_event(e: Dictionary) -> void:
	match e.type:
		"target":
			enemy_view.on_target_changed(e.weapon)
		"fire_started":
			var pos := _tile_pos(e)
			effects.explosion(pos, 0.3)
			if e.own_ship:
				effects.float_text(pos + Vector2(0, -6), "FEUER", Color("#EF9F27"))
		"breach":
			var pos := _tile_pos(e)
			if e.own_ship:
				effects.float_text(pos + Vector2(0, -10), "HÜLLENBRUCH", Color("#85B7EB"))
		"extinguished":
			var pos := _tile_pos(e)
			for i in 5:
				effects.puff(pos + Vector2(randf_range(-4, 4), randf_range(-3, 3)), Vector2(randf_range(-4, 4), randf_range(-14, -6)), Color("#A9B0BB"), 0.8, 3.0)
		"breach_fixed":
			effects.sparkle(_tile_pos(e), Color("#85B7EB"))
		"crew_died":
			var pos := _tile_pos(e)
			effects.sparkle(pos, Color("#E24B4A"))
			effects.float_text(pos + Vector2(0, -8), "%s gefallen" % e.name, Color("#F7C1C1"))
			if e.own_ship:
				_red_flash = 0.15
		"fire":
			_on_fire(e)
		"shield":
			var b := effects.take_bolt(e.projectile)
			var view := _defender(e)
			view.flash_shield()
			if not b.is_empty():
				effects.shield_ripple(b.edge, COLOR_SHIELD)
				effects.float_text(b.edge + Vector2(0, -6), "SCHILD", COLOR_SHIELD)
			if not e.from_player:
				_shake = maxf(_shake, 1.5)
		"hit":
			var b := effects.take_bolt(e.projectile)
			var view := _defender(e)
			var pos: Vector2 = b.get("to", view.position + view.room_center(e.room))
			effects.explosion(pos, e.damage)
			effects.float_text(pos + Vector2(0, -8), "-%d" % e.damage, Color("#F7C1C1"))
			view.flash_room(e.room)
			if not e.from_player:
				_shake = maxf(_shake, 2.5 + e.damage * 1.5)
				_red_flash = 0.12 + 0.05 * e.damage
		"miss":
			var b := effects.take_bolt(e.projectile)
			if not b.is_empty():
				var dir: Vector2 = (b.edge - b.from).normalized()
				effects.stray(b.edge, dir, b.color, b.width)
				effects.float_text(b.edge + Vector2(0, -6), "AUSGEWICHEN", Color("#C4CAD3"))
		"repaired":
			var view := ship_view if e.own_ship else enemy_view
			if e.room >= 0:
				var pos := view.position + view.room_center(e.room)
				effects.sparkle(pos, Color("#5DCAA5"))
				if e.own_ship:
					effects.float_text(pos, "REPARIERT", Color("#5DCAA5"))
		"destroyed":
			_on_destroyed(e.own_ship, e.reason)


## Weltposition einer Kachel aus einem Schiffs-Ereignis (tile, own_ship).
func _tile_pos(e: Dictionary) -> Vector2:
	var view := ship_view if e.own_ship else enemy_view
	return view.position + view.state.layout.tile_center(Vector2(e.tile))


## Laufende Kleinsteffekte: Rauch über Feuer, Luft aus Lecks und offenen Schleusen.
func _ambient_effects(view: ShipView, delta: float) -> void:
	var ship := view.state
	if ship.is_destroyed():
		return
	for t: Vector2i in ship.fires:
		if randf() < delta * 4.0:
			var p := view.position + ship.layout.tile_center(Vector2(t)) + Vector2(randf_range(-4, 4), -4)
			effects.puff(p, Vector2(randf_range(-3, 3), randf_range(-12, -6)), Color("#424A56"), 1.0, 3.0)
	for t: Vector2i in ship.breaches:
		var o: float = ship.oxygen[ship.layout.room_index_at(t)]
		if randf() < delta * 10.0 * o:
			var p := view.position + ship.layout.tile_center(Vector2(t))
			effects.puff(p, Vector2.from_angle(randf() * TAU) * randf_range(8, 20), Color("#D3E6F8", 0.8), 0.5)
	for i in ship.airlock_open.size():
		if not ship.airlock_open[i]:
			continue
		var o: float = ship.oxygen[ship.layout.room_index_at(ship.layout.airlocks[i].tile)]
		if randf() < delta * 40.0 * maxf(o, 0.05):
			var dir := Vector2(ship.layout.airlocks[i].dir)
			var p := view.position + view.airlock_point(i)
			var v := (dir.rotated(randf_range(-0.5, 0.5))) * randf_range(20, 45) * (0.4 + o)
			effects.puff(p, v, Color("#D3E6F8", 0.9), 0.7)


func _on_enemy_room(room: int) -> void:
	var idx := weapon_panel.selected
	if idx >= 0:
		battle.set_weapon_target(idx, -1 if state.weapons[idx].target == room else room)
		weapon_panel.select(-1)
	else:
		battle.set_all_targets(room)


func _on_hatch_toggled(kind: String, open: bool) -> void:
	if kind == "airlock":
		_show_hint("Luftschleuse " + ("offen – Raum verliert Luft" if open else "geschlossen"))
	else:
		_show_hint("Tür " + ("offen" if open else "geschlossen"))


func _show_hint(text: String) -> void:
	_hint = text
	_hint_until = _time + 2.0


func _defender(e: Dictionary) -> ShipView:
	return enemy_view if e.from_player else ship_view


func _on_fire(e: Dictionary) -> void:
	var attacker := ship_view if e.from_player else enemy_view
	var defender := enemy_view if e.from_player else ship_view
	var ship := state if e.from_player else enemy
	var weapon := ship.weapons[e.weapon]
	var from := attacker.position + attacker.mount_point()
	var jitter := Vector2(randf_range(-5, 5), randf_range(-5, 5))
	var to := defender.position + defender.room_center(e.room) + jitter
	var ellipse := defender.shield_ellipse()
	var edge := _ellipse_entry(from, to, defender.position + ellipse[0], ellipse[1])
	var color := COLOR_PLAYER_BOLT if e.from_player else COLOR_ENEMY_BOLT
	var width := 1.0 + float(weapon.damage - 1)
	effects.add_bolt(e.projectile, from, edge, to, color, width)
	effects.muzzle(from, (edge - from).normalized(), color)
	if e.from_player:
		weapon_panel.flash_fired(e.weapon)


## Punkt, an dem die Strecke from→to in die Ellipse eintritt (Schildblase).
func _ellipse_entry(from: Vector2, to: Vector2, center: Vector2, radius: Vector2) -> Vector2:
	var a := (from - center) / radius
	var d := (to - from) / radius
	var qa := d.dot(d)
	var qb := 2.0 * a.dot(d)
	var qc := a.dot(a) - 1.0
	var disc := qb * qb - 4.0 * qa * qc
	if qc <= 0.0 or disc < 0.0 or qa == 0.0:
		return from.lerp(to, 0.7)  # Start liegt schon in der Blase
	var t := (-qb - sqrt(disc)) / (2.0 * qa)
	return from.lerp(to, clampf(t, 0.0, 1.0))


## Schiff zerstört: Explosionskette über alle Räume, danach ausblenden und Ergebnis zeigen.
func _on_destroyed(own_ship: bool, reason: String) -> void:
	ship_view.selected = null
	weapon_panel.select(-1)
	if reason == "crew":
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_callback(_show_banner.bind(own_ship, reason))
		return
	var view := ship_view if own_ship else enemy_view
	var rooms := view.state.layout.rooms.size()
	for i in 10:
		var pos := view.position + view.room_center(randi() % rooms) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		_explosion_queue.append({"delay": i * 0.14 + randf() * 0.05, "pos": pos, "strength": 1.5 + randf() * 1.5})
	_shake = 5.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(view, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(_show_banner.bind(own_ship, reason))


func _update_explosions(delta: float) -> void:
	for x in _explosion_queue:
		x.delay -= delta
		if x.delay <= 0.0:
			effects.explosion(x.pos, x.strength)
			_shake = maxf(_shake, 2.0)
	_explosion_queue = _explosion_queue.filter(func(x): return x.delay > 0.0)


func _show_banner(own_ship: bool, reason: String) -> void:
	var text := ""
	if own_ship:
		text = "Schiff verloren" if reason == "hull" else "Die ganze Crew ist tot"
	else:
		text = "Sieg – Piratenkutter zerstört" if reason == "hull" else "Sieg – Piratencrew ausgeschaltet"
	banner.text = text + "\nTippen für neuen Kampf"
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(banner, "modulate", Color.WHITE, 0.4)
	_can_restart_at = _time + 0.6


func _on_banner_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _can_restart_at >= 0.0 and _time >= _can_restart_at:
		get_tree().reload_current_scene()


func _on_crew_selected(member: CrewMember) -> void:
	ship_view.select(null if member == ship_view.selected else member)


func _on_selection_changed(member: CrewMember, _room_idx: int) -> void:
	crew_panel.selected = member
	_update_info()


func _update_info() -> void:
	if _time < _hint_until:
		info.text = _hint
		return
	if weapon_panel.selected >= 0:
		info.text = "Waffe %d: Gegnerraum antippen (gleicher Raum = Ziel aufheben)" % (weapon_panel.selected + 1)
		return
	var member := ship_view.selected
	if not member:
		var ordered := ship_view.last_order
		var room := ship_view.focused_room
		if ordered and ordered.is_moving():
			info.text = "%s → %s" % [ordered.display_name, state.layout.rooms[state.layout.room_index_at(ordered.destination())].name]
		elif room >= 0:
			info.text = state.layout.rooms[room].name
		elif not battle.player_has_target():
			info.text = "Gegnerraum antippen = alle Waffen zielen · Waffe antippen = einzeln"
		else:
			info.text = "Tür/Schleuse antippen: auf/zu · Energie: antippen +1, halten −1"
		return
	var target_room := state.layout.room_index_at(member.destination())
	var room_data: Dictionary = state.layout.rooms[target_room]
	var text := "%s → %s" % [member.display_name, room_data.name] if member.is_moving() else "%s · %s" % [member.display_name, room_data.name]
	if room_data.system != "" and room_data.console != null:
		text += " · Erfahrung %d" % member.level(room_data.system)
		if not member.is_moving() and member.tile == room_data.console:
			text += " · an der Konsole"
	info.text = text
