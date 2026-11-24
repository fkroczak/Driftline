extends Node2D
## Hauptbildschirm: das eigene Schiff, immer. Hier läuft alles ab:
##
## - **Ruhe** (kein Gegner): Die Zeit an Bord läuft weiter, die Crew löscht, flickt und repariert,
##   die Medbay heilt. Der Sprungantrieb lädt nach jedem Sprung neu (Knopf SPRUNG oben rechts).
## - **Sprung:** SPRUNG (geladen) oder KARTE öffnet die Sternenkarte über dem Schiff. Ein Ziel
##   antippen zeigt das Infofeld, nochmal antippen springt: Warpblase, das Schiff schießt nach
##   rechts davon, Lichtstreifen, im neuen System fliegt es von links herein.
## - **Am Ziel:** Ereignis, Händler oder Reparaturstation als Dialog über dem Schiff (Spiel steht),
##   oder ein Gegner springt herein und der Kampf beginnt.
## - **Kampf:** wie bisher (Energie, Waffen, Crew, Türen, Schleusen). Flucht = SPRUNG, sobald der
##   Antrieb geladen ist, dann Ziel auf der Karte wählen. Nach einem Sieg blendet das Banner von
##   selbst aus (kein Antippen nötig), das Schiff ist wieder in Ruhe.
## - **Boss besiegt** (Jagd): Banner, danach springt das Schiff von selbst in den nächsten Sektor.
## - **Run vorbei** (Niederlage oder letzter Boss): Banner, Antippen führt ins Hauptmenü.

const TOP := 28.0
const BOTTOM_PANEL_Y := 180.0
const INFO_Y := 168.0
const COLOR_PLAYER_BOLT := Color("#FAC775")
const COLOR_ENEMY_BOLT := Color("#E24B4A")
const COLOR_SHIELD := Color("#85B7EB")
## Sichtbarer Rumpf im Sprite (ohne transparenten Rand): links/rechts.
const PLAYER_HULL_X := Vector2(35, 257)
const ENEMY_HULL_X := Vector2(2, 116)
## Ab dieser Breite zeigt die Crew-Liste Namen.
const WIDE_SCREEN := 440.0
const WARP_OUT := 0.9
const WARP_IN := 1.0
const VICTORY_BANNER := 2.6
const SECTOR_DELAY := 3.0
const MAP_JUMP_TIME := 0.6

var run: RunState
var state: ShipState
var enemy: ShipState
var battle: Battle

var _shake := 0.0
var _red_flash := 0.0
var _ship_base := Vector2.ZERO
var _enemy_base := Vector2.ZERO
var _time := 0.0
var _explosion_queue: Array[Dictionary] = []  # {delay, pos, strength}
var _can_leave_at := -1.0
var _hint := ""
var _hint_until := 0.0
## "ruhe", "kampf", "warp" (Sprung läuft), "ende" (Run vorbei)
var _phase := "ruhe"
## Selbst pausiert (bleibt, bis man fortsetzt) oder automatisch pausiert (endet mit dem Befehl).
var _manual_pause := false
var _auto_paused := false
## Für Sounds: Waffen bereit, Antrieb bereit, letzte Hüllenwarnung.
var _weapons_ready: Array[bool] = []
var _jump_was_ready := false
var _hull_alarm_at := -100.0
## Sound je Waffe (Spieler: so wie es ist, Gegner: tiefer und leiser).
const WEAPON_SOUNDS := {"pulslaser": "laser_pulse", "schwerer_laser": "laser_heavy", "bordkanone": "cannon"}
const HULL_ALARM := 0.3

@onready var starfield: Starfield = $Starfield
@onready var world: Node2D = $World
@onready var ship_view: ShipView = $World/ShipView
@onready var enemy_view: ShipView = $World/EnemyView
@onready var effects: Effects = $World/Effects
@onready var crew_panel: CrewPanel = $HUD/CrewPanel
@onready var crew_card: CrewCard = $HUD/CrewCard
## Person, deren Karte gezeigt wird (nur bei Auswahl über die Crew-Liste).
var _card_member: CrewMember
@onready var power_panel: PowerPanel = $HUD/PowerPanel
@onready var weapon_panel: WeaponPanel = $HUD/WeaponPanel
@onready var door_panel: DoorPanel = $HUD/DoorPanel
@onready var status_bar: StatusBar = $HUD/StatusBar
@onready var resource_bar: ResourceBar = $HUD/ResourceBar
@onready var info: Label = $HUD/Info
@onready var damage_flash: ColorRect = $HUD/DamageFlash
@onready var warp_flash: ColorRect = $HUD/WarpFlash
@onready var banner: Label = $HUD/Banner
@onready var legend: Legend = $HUD/Legend
@onready var help_button: HelpButton = $HUD/HelpButton
@onready var jump_button: JumpButton = $HUD/JumpButton
@onready var map_button: HudButton = $HUD/MapButton
@onready var pause_button: PauseButton = $HUD/PauseButton
@onready var pause_overlay: ColorRect = $HUD/PauseOverlay
@onready var pause_label: Label = $HUD/PauseLabel
@onready var dialog: EventDialog = $HUD/EventDialog
@onready var map_view: MapView = $HUD/MapView


func _ready() -> void:
	run = Game.ensure_run()
	state = run.ship
	var texture: Texture2D = load(state.layout.sprite_path)
	ship_view.setup(state)
	enemy_view.visible = false
	crew_panel.setup(state)
	power_panel.setup(state, texture)
	weapon_panel.setup(state, null)
	door_panel.setup(state)
	status_bar.setup(state)
	resource_bar.setup(run)
	legend.setup(state.layout, texture)
	jump_button.setup(state, run)
	map_view.setup(run)
	map_view.visible = false
	ship_view.selection_changed.connect(_on_selection_changed)
	enemy_view.room_tapped.connect(_on_enemy_room)
	weapon_panel.selection_changed.connect(func(idx: int) -> void: enemy_view.aim_selected = idx)
	weapon_panel.selection_changed.connect(_on_order_selection)
	ship_view.hatch_toggled.connect(_on_hatch_toggled)
	power_panel.system_tapped.connect(_on_system_tapped)
	door_panel.changed.connect(_show_hint)
	help_button.pressed.connect(func() -> void: legend.visible = true)
	Sfx.loop("ship_hum", 1.0)
	jump_button.jump_requested.connect(_on_jump_requested)
	map_button.pressed.connect(func() -> void: _open_map())
	pause_button.toggled_pause.connect(_toggle_pause)
	pause_button.toggled_auto.connect(_toggle_auto_pause)
	crew_panel.crew_selected.connect(_on_crew_selected)
	banner.gui_input.connect(_on_banner_input)
	dialog.chosen.connect(_on_choice)
	map_view.node_tapped.connect(_on_map_node)
	map_view.background_tapped.connect(func() -> void:
		map_view.selected = -1
		map_view.hint = _map_hint())
	map_view.distress_pressed.connect(_on_distress)
	map_view.closed.connect(func() -> void:
		Sfx.play("map_close")
		_close_map())
	get_viewport().size_changed.connect(_layout)
	_layout()
	_on_selection_changed(null, -1)
	starfield.reseed(hash([run.seed_value, run.sector, run.current]))
	# Ankunft: Schiff fliegt herein, dann gilt, was am Knoten wartet
	_phase = "warp"
	_warp_in(_enter_node)


# --- Ablauf ---


## Am Knoten: offener Dialog, wartender Gegner oder Ruhe. Nach dem Boss weiter in den nächsten Sektor.
func _enter_node() -> void:
	Game.can_save = true
	if run.result != "":
		_show_run_over()
		return
	if run.sector_cleared:
		_phase = "ruhe"
		var text := "Flaggschiff vernichtet – Sektor %d geschafft" % run.sector
		if run.last_reward != "":
			text += "\nBeute: " + run.last_reward
		_show_banner_text(text + "\nSprung ins nächste Universum …", SECTOR_DELAY)
		Sfx.play("sector_clear")
		get_tree().create_timer(SECTOR_DELAY).timeout.connect(_sector_jump)
		return
	if not run.dialog.is_empty():
		_phase = "ruhe"
		dialog.show_dialog(run.dialog)
		Sfx.play("dialog_open")
		return
	if run.needs_battle():
		_start_battle()
		return
	_phase = "ruhe"
	if run.jumps_done() == 0:
		_show_hint("Sektor %d · Antrieb lädt · dann SPRUNG antippen und Ziel wählen" % run.sector, 4.0)


func _start_battle() -> void:
	_phase = "kampf"
	Game.can_save = false
	enemy = run.create_enemy()
	battle = Battle.new(state, enemy)
	battle.enemy_may_flee = not run.hunter_battle and not run.is_boss_battle()
	effects.battle = battle
	enemy_view.setup(enemy)
	enemy_view.aim_weapons = state.weapons
	enemy_view.aim_selected = -1
	weapon_panel.setup(state, enemy)
	enemy_view.visible = true
	_layout()
	var who := enemy.layout.display_name
	_weapons_ready.clear()
	Sfx.play("warp_in", -3.0, 0.85)
	if run.hunter_battle:
		Sfx.play("alarm")
		_show_hint("Die Jäger haben euch eingeholt: %s!" % who, 3.0)
	else:
		_show_hint("Feindkontakt: %s" % who, 3.0)
	# Gegner springt herein: Blase fällt zusammen, Schiff gleitet von rechts an seinen Platz
	enemy_view.position = _enemy_base + Vector2(220, 0)
	effects.warp_bubble(enemy_view, enemy_view.shield_ellipse()[0], enemy_view.shield_ellipse()[1], WARP_IN, false)
	var tween := create_tween()
	tween.tween_property(enemy_view, "position", _enemy_base, WARP_IN).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Sieg, Niederlage oder Flucht: Kampf auflösen, Gegner weg.
func _end_battle() -> void:
	battle = null
	effects.battle = null
	enemy = null
	enemy_view.visible = false
	weapon_panel.setup(state, null)
	weapon_panel.select(-1)
	Game.can_save = true


# --- Sprung ---


func _on_jump_requested() -> void:
	if _phase in ["warp", "ende"]:
		return
	var why := jump_button.reason()
	if why != "" and why != "kein Treibstoff":
		jump_button.deny()
		Sfx.play("ui_deny")
		match why:
			"Pilot?":
				_show_hint("Sprung: Jemand muss ins Cockpit")
			"Antrieb?":
				_show_hint("Sprung: Der Antrieb braucht Energie")
			_:
				_show_hint("Sprungantrieb lädt noch (%s)" % why)
		return
	_open_map()


func _open_map() -> void:
	if _phase in ["warp", "ende"]:
		return
	Sfx.play("map_open")
	map_view.refresh()
	map_view.can_jump = state.jump_ready()
	map_view.hint = _map_hint()
	map_view.visible = true
	ship_view.select(null)
	weapon_panel.select(-1)


func _close_map() -> void:
	map_view.visible = false
	map_view.selected = -1


func _map_hint() -> String:
	if run.can_send_distress():
		return "Kein Treibstoff mehr: Notsignal senden und hoffen, dass Freunde antworten"
	if not state.jump_ready():
		match jump_button.reason():
			"Pilot?":
				return "Cockpit nicht besetzt: Karte nur ansehen · ZURÜCK zum Schiff"
			"Antrieb?":
				return "Antrieb ohne Energie: Karte nur ansehen · ZURÜCK zum Schiff"
		return "Antrieb lädt noch: Karte nur ansehen · ZURÜCK zum Schiff"
	if _phase == "kampf":
		return "Flucht: Ziel antippen, nochmal antippen springt"
	if run.is_hunt() and run.jumps_done() == 0:
		return "Gelbes Ziel antippen, nochmal antippen springt · Boss am Ausgang rechts · Jäger von links"
	return "Gelbes Ziel antippen, nochmal antippen springt"


func _on_map_node(id: int) -> void:
	var can := map_view.reachable(id)
	if not can:
		Sfx.play("ui_deny" if id != run.current else "ui_click")
		map_view.selected = id if run.node().links.has(id) else -1
		if id == run.current:
			map_view.hint = "Hier ist das Schiff gerade"
		elif not run.node().links.has(id):
			map_view.hint = "Zu weit weg: nur direkt verbundene Ziele"
		elif not state.jump_ready():
			match jump_button.reason():
				"Pilot?":
					map_view.hint = "Sprung: Jemand muss ins Cockpit"
				"Antrieb?":
					map_view.hint = "Sprung: Der Antrieb braucht Energie"
				_:
					map_view.hint = "Antrieb lädt noch (%d %%)" % floori(state.jump_charge * 100.0)
		elif run.fuel < run.jump_cost():
			map_view.hint = "Kein Treibstoff für den Sprung: Notsignal senden"
		return
	if map_view.selected != id:
		map_view.selected = id
		map_view.hint = "Nochmal antippen: springen" + (" · Achtung, Jäger!" if run.is_overrun(id) else "")
		Sfx.play("map_select")
		return
	_jump(id)


## Sprung zum Ziel: im Kampf zuerst die Flucht, dann Abflug mit Warpblase, Ankunft im neuen System.
func _jump(id: int) -> void:
	_phase = "warp"
	Game.can_save = false
	_manual_pause = false
	_auto_paused = false
	_apply_pause()
	var from := run.current
	if battle:
		battle.player_jump()
		battle.take_events()
		run.finish_battle("entkommen")
	var sector := run.sector
	run.jump_to(id)
	Game.save()
	if run.sector != sector:
		# Ausgang (Endlos): Die neue Karte gilt schon, direkt in den nächsten Sektor springen
		_close_map()
		_warp_out(_arrive)
		_show_hint("Ausgang erreicht · Sektor %d" % run.sector, 4.0)
		return
	map_view.ship_from = from
	map_view.ship_to = id
	map_view.hint = "Sprung …"
	Sfx.play("map_travel")
	var tween := create_tween()
	tween.tween_method(map_view.set_ship_t, 0.0, 1.0, MAP_JUMP_TIME)
	tween.tween_callback(func() -> void:
		_close_map()
		_warp_out(_arrive))


func _arrive() -> void:
	_end_battle()
	map_view.refresh()
	starfield.reseed(hash([run.seed_value, run.sector, run.current, run.total_jumps]))
	_warp_in(_enter_node)


func _sector_jump() -> void:
	if not run.sector_cleared:
		return
	_phase = "warp"
	Game.can_save = false
	_warp_out(func() -> void:
		run.next_sector()
		Game.save()
		_arrive()
		_show_hint("Sektor %d · neue Karte, die Jäger beginnen von vorn" % run.sector if run.is_hunt() else "Sektor %d" % run.sector, 4.0))


## Abflug: Blase baut sich auf, Schiff leuchtet, schießt nach rechts davon, Sterne werden zu Streifen.
func _warp_out(done: Callable) -> void:
	Sfx.play("warp_out", 0.0, 1.0, 0.0)
	ship_view.select(null)
	var e := ship_view.shield_ellipse()
	effects.warp_bubble(ship_view, e[0], e[1], WARP_OUT * 0.6, true)
	var tween := create_tween()
	tween.tween_property(ship_view, "modulate", Color(1.6, 1.7, 2.0, 1.0), WARP_OUT * 0.5)
	tween.parallel().tween_property(starfield, "warp", 1.0, WARP_OUT)
	tween.tween_callback(func() -> void:
		effects.warp_streaks(Rect2(ship_view.position + Vector2(PLAYER_HULL_X.x, 10), Vector2(PLAYER_HULL_X.y - PLAYER_HULL_X.x, ship_view.get_size().y - 20)), Vector2.RIGHT, Color("#D3E6F8")))
	tween.tween_property(ship_view, "position", _ship_base + Vector2(get_viewport_rect().size.x, 0), WARP_OUT * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(warp_flash, "color", Color(0.85, 0.9, 1.0, 0.9), 0.08)
	tween.tween_callback(done)


## Ankunft: Sterne bremsen ab, Schiff gleitet von links herein, die Blase fällt in sich zusammen.
func _warp_in(done: Callable) -> void:
	ship_view.position = _ship_base - Vector2(get_viewport_rect().size.x * 0.8, 0)
	ship_view.modulate = Color(1.6, 1.7, 2.0, 1.0)
	starfield.warp = 1.0
	Sfx.play("warp_in", 0.0, 1.0, 0.0)
	var e := ship_view.shield_ellipse()
	var tween := create_tween()
	tween.tween_property(warp_flash, "color", Color(0.85, 0.9, 1.0, 0.0), 0.3)
	tween.parallel().tween_property(starfield, "warp", 0.0, WARP_IN).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ship_view, "position", _ship_base, WARP_IN).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ship_view, "modulate", Color.WHITE, WARP_IN)
	tween.parallel().tween_callback(func() -> void: effects.warp_bubble(ship_view, e[0], e[1], WARP_IN * 0.9, false))
	tween.tween_callback(done)


# --- Dialoge ---


func _on_choice(index: int) -> void:
	Sfx.play("dialog_choice")
	run.choose(index)
	Game.save()
	if not run.dialog.is_empty():
		dialog.show_dialog(run.dialog)
		return
	dialog.show_dialog({})
	if run.result != "":
		_show_run_over()
	elif run.needs_battle():
		_start_battle()


func _on_distress() -> void:
	if run.send_distress():
		Sfx.play("distress")
		Game.save()
		_close_map()
		dialog.show_dialog(run.dialog)


# --- Pause ---


func is_paused() -> bool:
	return _manual_pause or _auto_paused


func _toggle_pause() -> void:
	if is_paused():
		_manual_pause = false
		_auto_paused = false
		Sfx.play("resume")
	else:
		_manual_pause = true
		Sfx.play("pause")
	_apply_pause()


func _toggle_auto_pause() -> void:
	pause_button.auto_pause = not pause_button.auto_pause
	Sfx.play("ui_click")
	if not pause_button.auto_pause and _auto_paused:
		_auto_paused = false
		_apply_pause()
	_show_hint("Auto-Pause " + ("an: Kampf hält beim Auswählen von Crew oder Waffe an" if pause_button.auto_pause else "aus"))


## Auto-Pause (nur im Kampf): Auswahl einer Figur oder Waffe hält an, Befehl oder Abwählen läuft weiter.
func _on_order_selection(idx: int) -> void:
	if not pause_button.auto_pause or _phase != "kampf" or battle == null or battle.outcome != "":
		if _auto_paused:
			_auto_paused = false
			_apply_pause()
		return
	var selecting := idx >= 0 or ship_view.selected != null or weapon_panel.selected >= 0
	if selecting and not _manual_pause and not _auto_paused:
		_auto_paused = true
		_apply_pause()
	elif not selecting and _auto_paused:
		_auto_paused = false
		_apply_pause()


func _apply_pause() -> void:
	var paused := is_paused()
	pause_button.paused = paused
	pause_overlay.visible = paused
	pause_label.visible = paused
	pause_label.text = "PAUSE" if _manual_pause else "AUTO-PAUSE"
	effects.set_process(not paused)
	starfield.set_process(not paused)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_pause()
		get_viewport().set_input_as_handled()


# --- Layout ---


## Oben links Hülle und Schilde, Mitte Ressourcen, rechts Sprung, Karte, Pause, Hilfe.
## Links die Crew-Liste, daneben das eigene Schiff, rechts der Gegner. Unten Energie, Waffen, Türen.
func _layout() -> void:
	var view_size := get_viewport_rect().size
	crew_panel.compact = view_size.x < WIDE_SCREEN
	_show_card()
	status_bar.position = Vector2(2, 2)
	help_button.size = Vector2(18, 24)
	pause_button.size = Vector2(20, 24)
	map_button.size = Vector2(34, 24)
	jump_button.size = Vector2(56, 24)
	help_button.position = Vector2(view_size.x - help_button.size.x - 2, 2)
	pause_button.position = help_button.position - Vector2(pause_button.size.x + 2, 0)
	map_button.position = pause_button.position - Vector2(map_button.size.x + 2, 0)
	jump_button.position = map_button.position - Vector2(jump_button.size.x + 2, 0)
	var res_left := status_bar.position.x + status_bar.size.x + 3
	resource_bar.size.x = clampf(jump_button.position.x - res_left - 3, 60.0, 130.0)
	resource_bar.position = Vector2(res_left, 2)
	crew_panel.position = Vector2(2, TOP + 2.0)
	crew_panel.max_height = BOTTOM_PANEL_Y - 3.0 - crew_panel.position.y
	var left := crew_panel.position.x + crew_panel.slot().x + 2.0
	var ship_size := ship_view.get_size()
	var play_h := BOTTOM_PANEL_Y - TOP - 12.0
	_ship_base = Vector2(left - PLAYER_HULL_X.x, TOP + (play_h - ship_size.y) / 2.0 + 2.0).floor()
	if _phase != "warp":
		ship_view.position = _ship_base
	var player_right := _ship_base.x + PLAYER_HULL_X.y
	var enemy_w := ENEMY_HULL_X.y - ENEMY_HULL_X.x
	var free := view_size.x - player_right
	var enemy_x := player_right + (free - enemy_w) / 2.0 - ENEMY_HULL_X.x
	enemy_x = minf(enemy_x, view_size.x - ENEMY_HULL_X.y - 2.0)
	var enemy_size := enemy_view.get_size()
	_enemy_base = Vector2(enemy_x, _ship_base.y + (ship_size.y - enemy_size.y) / 2.0).floor()
	enemy_view.position = _enemy_base
	power_panel.position = Vector2(2, BOTTOM_PANEL_Y)
	door_panel.position = Vector2(view_size.x - door_panel.size.x - 2, BOTTOM_PANEL_Y)
	var weapons_x := power_panel.position.x + power_panel.size.x + 3.0
	weapon_panel.position = Vector2(weapons_x, BOTTOM_PANEL_Y)
	info.position = Vector2(left, INFO_Y)
	info.size.x = view_size.x - left - 4
	_place_crew_card()
	for c: Control in [damage_flash, warp_flash, banner, legend, pause_overlay, dialog, map_view]:
		c.position = Vector2.ZERO
		c.size = view_size
	pause_label.size.x = view_size.x


# --- Laufende Zeit ---


## Crew-Karte direkt neben dem Eintrag der Person in der Crew-Liste (nicht über dem Gegner).
func _place_crew_card() -> void:
	var member := crew_card.member
	if not crew_card.visible or not member:
		return
	var idx := state.crew.find(member)
	if idx < 0:
		crew_card.show_member(null)
		return
	var slot := crew_panel.slot()
	var entry_y := crew_panel.position.y + idx * (slot.y + CrewPanel.GAP)
	var y := clampf(entry_y - 2.0, TOP + 2.0, BOTTOM_PANEL_Y - crew_card.size.y - 4.0)
	crew_card.position = Vector2(crew_panel.position.x + slot.x + 4.0, y).floor()
	crew_card.pointer_y = entry_y + slot.y / 2.0 - crew_card.position.y


func _process(delta: float) -> void:
	_time += delta
	_update_info()
	_place_crew_card()
	enemy_view.show_jump = battle != null and battle.enemy_fleeing
	_update_sound_loops()
	if legend.visible or is_paused() or dialog.visible or map_view.visible or _phase == "ende":
		return  # Spiel steht, Befehle gehen trotzdem
	if battle:
		battle.update(delta)
		for e in battle.take_events():
			_on_battle_event(e)
	elif _phase != "warp":
		_update_peace(delta)
	_update_explosions(delta)
	_ready_sounds()
	_ambient_effects(ship_view, delta)
	if enemy_view.visible:
		_ambient_effects(enemy_view, delta)
	if enemy and not enemy.is_destroyed() and _phase == "kampf":
		enemy_view.position.y = _enemy_base.y + roundf(sin(_time * 1.3))
	_shake = move_toward(_shake, 0.0, delta * 14.0)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _shake if _shake > 0.3 else Vector2.ZERO
	_red_flash = move_toward(_red_flash, 0.0, delta * 1.5)
	damage_flash.color = Color(0.89, 0.29, 0.29, _red_flash)


## Ohne Gegner läuft nur das eigene Schiff (Reparatur, Löschen, Heilen, Luft, Sprungantrieb).
func _update_peace(delta: float) -> void:
	state.update(delta)
	for e in state.events:
		e["own_ship"] = true
		_on_battle_event(e)
	state.events.clear()
	if state.is_crew_dead() and run.result == "":
		run.result = "verloren"
		Game.save()
		_show_run_over()


func _on_battle_event(e: Dictionary) -> void:
	match e.type:
		"target":
			enemy_view.on_target_changed(e.weapon)
			Sfx.play("target_lock" if e.room >= 0 else "power_down")
		"fire_started":
			var pos := _tile_pos(e)
			Sfx.play("fire_start", _side_db(e.own_ship))
			effects.explosion(pos, 0.3)
			if e.own_ship:
				effects.float_text(pos + Vector2(0, -6), "FEUER", Color("#EF9F27"))
		"breach":
			var pos := _tile_pos(e)
			Sfx.play("breach", _side_db(e.own_ship))
			if e.own_ship:
				effects.float_text(pos + Vector2(0, -10), "HÜLLENBRUCH", Color("#85B7EB"))
		"extinguished":
			var pos := _tile_pos(e)
			Sfx.play("extinguish", _side_db(e.own_ship) - 2.0)
			for i in 5:
				effects.puff(pos + Vector2(randf_range(-4, 4), randf_range(-3, 3)), Vector2(randf_range(-4, 4), randf_range(-14, -6)), Color("#A9B0BB"), 0.8, 3.0)
		"breach_fixed":
			Sfx.play("breach_fixed", _side_db(e.own_ship) - 2.0)
			effects.sparkle(_tile_pos(e), Color("#85B7EB"))
		"crew_died":
			var pos := _tile_pos(e)
			Sfx.play("crew_died", _side_db(e.own_ship))
			effects.sparkle(pos, Color("#E24B4A"))
			effects.float_text(pos + Vector2(0, -8), "%s gefallen" % e.name, Color("#F7C1C1"))
			if e.own_ship:
				_red_flash = 0.15
		"fire":
			_on_fire(e)
		"shield":
			var b := effects.take_bolt(e.projectile)
			var view := _defender(e)
			Sfx.play("shield", _side_db(not e.from_player))
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
			Sfx.play("hit_hull", _side_db(not e.from_player) + (e.damage - 2) * 1.5)
			if int(e.get("system_damage", 0)) > 0:
				Sfx.play("hit_system", _side_db(not e.from_player) - 2.0)
				view.flash_room(e.room)
				effects.float_text(pos + Vector2(0, 2), "SYSTEM", Color("#FAC775"))
			if not e.from_player:
				_shake = maxf(_shake, 2.5 + e.damage * 1.5)
				_red_flash = 0.12 + 0.05 * e.damage
				_hull_warning()
		"miss":
			var b := effects.take_bolt(e.projectile)
			if not b.is_empty():
				var dir: Vector2 = (b.edge - b.from).normalized()
				effects.stray(b.edge, dir, b.color, b.width)
				Sfx.play("miss", _side_db(not e.from_player))
				effects.float_text(b.edge + Vector2(0, -6), "AUSGEWICHEN", Color("#C4CAD3"))
		"repaired":
			var view := ship_view if e.own_ship else enemy_view
			if e.room >= 0:
				var pos := view.position + view.room_center(e.room)
				effects.sparkle(pos, Color("#5DCAA5"))
				Sfx.play("repaired", _side_db(e.own_ship) - (0.0 if e.own_ship else 4.0))
				if e.own_ship:
					effects.float_text(pos, "REPARIERT", Color("#5DCAA5"))
		"destroyed":
			_on_destroyed(e.own_ship, e.reason)
		"enemy_flee":
			Sfx.play("alarm")
			_show_hint("Gegner lädt den Sprungantrieb! Antrieb oder Cockpit treffen", 4.0)
		"enemy_jumped":
			_on_enemy_jumped()


## Ereignisse am Gegnerschiff etwas leiser als am eigenen.
func _side_db(own_ship: bool) -> float:
	return 0.0 if own_ship else -3.0


## Warnton, wenn die eigene Hülle kritisch wird (höchstens alle paar Sekunden).
func _hull_warning() -> void:
	if state.max_hull <= 0 or state.hull <= 0:
		return
	if float(state.hull) / state.max_hull <= HULL_ALARM and _time - _hull_alarm_at > 6.0:
		_hull_alarm_at = _time
		Sfx.play("hull_low", 0.0, 1.0, 0.0)


## Kurze Signale: Waffe geladen (im Kampf), Sprungantrieb bereit.
func _ready_sounds() -> void:
	if battle and battle.outcome == "":
		_weapons_ready.resize(state.weapons.size())
		for i in state.weapons.size():
			var charged := state.weapons[i].is_ready()
			if charged and not _weapons_ready[i]:
				Sfx.play("weapon_ready")
			_weapons_ready[i] = charged
	var jump := state.jump_ready()
	if jump and not _jump_was_ready and _phase in ["ruhe", "kampf"]:
		Sfx.play("jump_ready")
	_jump_was_ready = jump


## Dauerklänge: Brummen des Schiffs, Prasseln je nach Zahl der Brände (eigene lauter).
func _update_sound_loops() -> void:
	var fires := float(state.fires.size())
	if enemy and enemy_view.visible:
		fires += enemy.fires.size() * 0.4
	Sfx.loop("fire_loop", 0.0 if _phase == "ende" else minf(fires / 3.0, 1.0) * 0.9)


## Weltposition einer Kachel aus einem Schiffs-Ereignis (tile, own_ship).
func _tile_pos(e: Dictionary) -> Vector2:
	var view := ship_view if e.own_ship else enemy_view
	return view.position + view.state.layout.tile_center(Vector2(e.tile))


## Laufende Kleinsteffekte: Rauch über Feuer, Luft aus Lecks und offenen Schleusen.
func _ambient_effects(view: ShipView, delta: float) -> void:
	var ship := view.state
	if ship == null or ship.is_destroyed() or not view.visible:
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
	for member in ship.crew:
		var pos := view.position + ship.layout.tile_center(member.tile_position())
		match member.activity:
			"loeschen":
				if randf() < delta * 30.0:
					var target := view.position + ship.layout.tile_center(Vector2(member.activity_tile))
					var dir := (target - pos).normalized() if target != pos else Vector2.UP
					var v := dir.rotated(randf_range(-0.35, 0.35)) * randf_range(30, 55)
					effects.puff(pos + dir * 4.0, v, Color("#E6EAF0", 0.9), 0.35)
			"reparieren", "flicken":
				if randf() < delta * 14.0:
					var spot := pos + Vector2(member.facing) * 6.0
					var c := Color("#FDE6BF") if randf() < 0.5 else Color("#FAC775")
					effects.puff(spot, Vector2(randf_range(-25, 25), randf_range(-35, -10)), c, 0.25)
			"heilen":
				if randf() < delta * 6.0:
					effects.puff(pos + Vector2(randf_range(-5, 5), 2), Vector2(0, randf_range(-14, -8)), Color("#97C459"), 0.8)
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
	if battle == null:
		return
	var idx := weapon_panel.selected
	if idx >= 0:
		battle.set_weapon_target(idx, -1 if state.weapons[idx].target == room else room)
		weapon_panel.select(-1)
	else:
		battle.set_all_targets(room)


func _on_hatch_toggled(kind: String, open: bool) -> void:
	if kind == "airlock":
		Sfx.play("airlock_open" if open else "airlock_close")
	else:
		Sfx.play("door_open" if open else "door_close")
	if kind == "airlock":
		_show_hint("Luftschleuse " + ("offen – Raum verliert Luft" if open else "geschlossen"))
	else:
		_show_hint("Tür " + ("offen" if open else "geschlossen"))


func _on_system_tapped(system: String, changed: bool) -> void:
	var sys := state.get_system(system)
	var text := "%s: %s · Energie %d/%d" % [SystemInfo.display_name(system), SystemInfo.describe(system), sys.power, sys.usable()]
	if system == "schilde":
		var layers := state.max_shield_layers()
		text += " · %d Schicht%s" % [layers, "" if layers == 1 else "en"]
		if sys.power % 2 == 1:
			text += " (1 Balken fehlt zum Paar)"
	if not changed:
		text += " · " + ("kein Reaktor frei" if state.power_free() <= 0 and sys.power < sys.usable() else "nichts zu ändern")
	_show_hint(text)


func _show_hint(text: String, duration := 2.0) -> void:
	_hint = text
	_hint_until = _time + duration


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
	var sound: String = WEAPON_SOUNDS.get(weapon.id, "laser_pulse")
	if e.from_player:
		Sfx.play(sound)
	else:
		Sfx.play(sound, -4.0, 0.88)
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
	_manual_pause = false
	_auto_paused = false
	_apply_pause()
	ship_view.select(null)
	weapon_panel.select(-1)
	var outcome := battle.outcome
	if reason == "crew":
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_callback(_battle_over.bind(outcome, reason))
		return
	var view := ship_view if own_ship else enemy_view
	Sfx.play("ship_explode", 0.0 if own_ship else -1.0, 1.0, 0.0)
	var rooms := view.state.layout.rooms.size()
	for i in 10:
		var pos := view.position + view.room_center(randi() % rooms) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		_explosion_queue.append({"delay": i * 0.14 + randf() * 0.05, "pos": pos, "strength": 1.5 + randf() * 1.5})
	_shake = 5.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(view, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(_battle_over.bind(outcome, reason))


## Gegner springt weg: Blase, Aufleuchten, nach rechts davon. Danach Ruhe ohne Beute.
func _on_enemy_jumped() -> void:
	_manual_pause = false
	_auto_paused = false
	_apply_pause()
	ship_view.select(null)
	weapon_panel.select(-1)
	var e := enemy_view.shield_ellipse()
	Sfx.play("warp_out", -4.0, 1.12, 0.0)
	effects.warp_bubble(enemy_view, e[0], e[1], WARP_OUT * 0.6, true)
	var tween := create_tween()
	tween.tween_property(enemy_view, "modulate", Color(1.6, 1.7, 2.0, 1.0), WARP_OUT * 0.5)
	tween.tween_property(enemy_view, "position", _enemy_base + Vector2(get_viewport_rect().size.x, 0), WARP_OUT * 0.5) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		enemy_view.modulate = Color.WHITE
		_battle_over("gegner_entkommen", ""))


func _update_explosions(delta: float) -> void:
	for x in _explosion_queue:
		x.delay -= delta
		if x.delay <= 0.0:
			effects.explosion(x.pos, x.strength)
			_shake = maxf(_shake, 2.0)
	_explosion_queue = _explosion_queue.filter(func(x): return x.delay > 0.0)


## Kampf vorbei: Ergebnis in den Run, dann Ruhe (Sieg) oder Run-Ende (Niederlage).
## Nach einem Sieg muss nichts bestätigt werden: Das Banner blendet von selbst aus.
func _battle_over(outcome: String, reason: String) -> void:
	var name := enemy.layout.display_name if enemy else ""
	run.finish_battle(outcome)
	_end_battle()
	Game.save()
	if run.result == "verloren":
		_show_run_over()
		return
	var text := ("Sieg – %s zerstört" % name) if reason == "hull" else "Sieg – Besatzung ausgeschaltet"
	if outcome == "gegner_entkommen":
		text = "%s ist entkommen – keine Beute" % name
	if run.result == "geschafft":
		_show_run_over()
		return
	if run.last_reward != "":
		text += "\nBeute: " + run.last_reward
	if run.sector_cleared:
		_enter_node()  # Banner und Sprung in den nächsten Sektor
		return
	_phase = "ruhe"
	text += "\nCrew repariert · dann SPRUNG"
	_show_banner_text(text, VICTORY_BANNER)
	if outcome == "sieg":
		Sfx.play("victory", 0.0, 1.0, 0.0)
	if run.last_reward != "":
		get_tree().create_timer(0.9).timeout.connect(func() -> void: Sfx.play("reward"))


## Banner, das von selbst wieder ausblendet (Antippen schließt es früher).
func _show_banner_text(text: String, seconds: float) -> void:
	banner.text = text
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	_can_leave_at = -1.0
	var tween := create_tween()
	tween.tween_property(banner, "modulate", Color.WHITE, 0.3)
	tween.tween_interval(seconds)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func() -> void:
		if _phase != "ende":
			banner.visible = false)


## Run vorbei: Banner bleibt, Antippen führt ins Hauptmenü.
func _show_run_over() -> void:
	_phase = "ende"
	_end_battle()
	var text := ""
	Sfx.loop("fire_loop", 0.0)
	Sfx.play("run_complete" if run.result == "geschafft" else "defeat", 0.0, 1.0, 0.0)
	if run.result == "geschafft":
		text = "Alle %d Sektoren geschafft!\nDie Jäger haben das Nachsehen." % RunState.HUNT_SECTORS
	else:
		text = "Schiff verloren" if state.is_destroyed() else "Die ganze Crew ist tot"
		text += "\nSektor %d, %d Sprünge insgesamt" % [run.sector, run.total_jumps]
	banner.text = text + "\nTippen: Hauptmenü"
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(banner, "modulate", Color.WHITE, 0.4)
	_can_leave_at = _time + 0.8


func _on_banner_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if _phase == "ende":
		if _can_leave_at >= 0.0 and _time >= _can_leave_at:
			Sfx.play("ui_click")
			Game.run = null
			Game.to_title()
		return
	banner.visible = false  # Banner wegtippen


## Antippen in der Crew-Liste wählt die Person und zeigt ihre Karte. Ist sie schon (übers Schiff)
## gewählt, aber ohne Karte, kommt nur die Karte dazu; erneutes Antippen hebt die Auswahl auf.
func _on_crew_selected(member: CrewMember) -> void:
	if member == ship_view.selected and _card_member != member:
		_card_member = member
		_show_card()
		return
	_card_member = null if member == ship_view.selected else member
	ship_view.select(_card_member)


## Die Crew-Infos erscheinen nur bei Auswahl über die Crew-Liste, nicht beim Antippen im Schiff.
func _on_selection_changed(member: CrewMember, _room_idx: int) -> void:
	if member and member != crew_panel.selected:
		Sfx.play("crew_select")
	crew_panel.selected = member
	if member != _card_member:
		_card_member = null
	_show_card()
	_on_order_selection(0 if member else -1)
	_update_info()


## Breite Liste: Infokasten unter dem Eintrag. Schmale Liste (nur Porträts): Karte daneben.
func _show_card() -> void:
	crew_panel.expanded = _card_member
	crew_card.show_member(_card_member if crew_panel.compact else null)


func _update_info() -> void:
	if _time < _hint_until:
		info.text = _hint
		return
	if is_paused() and ship_view.selected == null and weapon_panel.selected < 0:
		info.text = "Pause: Befehle geben, dann ▶ oder Leertaste"
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
			var system: String = state.layout.rooms[room].system
			info.text = state.layout.rooms[room].name
			if SystemInfo.describe(system) != "" and system != "":
				info.text += ": " + SystemInfo.describe(system)
			elif system == "" and state.layout.rooms[room].size == Vector2i(2, 2):
				info.text += ": " + SystemInfo.describe("")
		elif _phase == "kampf":
			info.text = "Gegnerraum: alle Waffen zielen · Waffenkarte: einzeln" if not battle.player_has_target() else "Energie: antippen +1, halten −1 · ? = Symbole"
		elif _phase == "ruhe":
			var left := run.ship_damage_count()
			if left > 0:
				info.text = "Noch %d %s · Crew in beschädigte Räume schicken" % [left, "Schaden" if left == 1 else "Schäden"]
			elif state.jump_ready():
				info.text = "Antrieb bereit · SPRUNG antippen und Ziel wählen"
			elif state.level("antrieb") <= 0:
				info.text = "Antrieb ohne Energie · kein Sprung möglich"
			elif state.operator_of_system("cockpit") == null:
				info.text = "Cockpit leer · kein Sprung möglich"
			else:
				info.text = "Antrieb lädt · mehr Energie im Antrieb lädt schneller"
		else:
			info.text = ""
		return
	if member == _card_member and not crew_panel.compact:
		info.text = _traits_text(member)
		return
	var target_room := state.layout.room_index_at(member.destination())
	var room_data: Dictionary = state.layout.rooms[target_room]
	var text := "%s → %s" % [member.display_name, room_data.name] if member.is_moving() else "%s · %s" % [member.display_name, room_data.name]
	if member.activity != "":
		text += " · " + ActivityIcons.NAMES.get(member.activity, "")
	text += " · freie Kachel antippen = hinschicken"
	info.text = text


## Stärken und Schwächen der Spezies für die Infozeile. Passt nicht alles hinein,
## wechseln sich die Teile alle paar Sekunden ab.
func _traits_text(member: CrewMember) -> String:
	var pages: Array[String] = []
	var line := ""
	for t: String in Species.traits(member.species):
		var next := t if line == "" else line + " · " + t
		if line != "" and HudStyle.text_width(Species.display_name(member.species) + ": " + next) > info.size.x - 4:
			pages.append(line)
			line = t
		else:
			line = next
	if line != "":
		pages.append(line)
	if pages.is_empty():
		return member.display_name
	return Species.display_name(member.species) + ": " + pages[int(_time / 3.0) % pages.size()]
