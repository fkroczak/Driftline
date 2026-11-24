class_name LoadoutView
extends Control
## Startauswahl vor einem neuen Run (Hauptmenü → NEUER RUN): Schiff, Crew, Waffen, Perks und
## Schwierigkeit auf eigenen Reitern. Alles kostet Startpunkte (siehe Loadout und
## data/loadout.json); oben rechts steht, wie viele noch frei sind. START beginnt den Run.
## Die letzte Auswahl bleibt in user://loadout.json für das nächste Mal.

signal started(mode: String, cfg: Dictionary)
signal closed

const SAVE_PATH := "user://loadout.json"
const COLOR_BG := Color("#07080F", 0.96)
const COLOR_TITLE := Color("#FDE6BF")
const COLOR_NAME := Color("#E6EAF0")
const TABS := [
	["ship", "SCHIFF"],  # i18n
	["crew", "CREW"],  # i18n
	["weapons", "WAFFEN"],  # i18n
	["perks", "PERKS"],  # i18n
	["difficulty", "SCHWIERIGKEIT"],  # i18n
]
const LIST_W := 112.0
const ROW_H := 17.0
const NOTE_TIME := 2.5

var cfg: Dictionary = {}
var _mode := RunState.MODE_HUNT
var _mode_name := ""
var _tab := "ship"
var _view_ship := Loadout.DEFAULT_SHIP
var _hits: Array[Dictionary] = []
var _note := ""
var _note_time := 0.0
var _textures := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Öffnet die Auswahl für einen Modus, vorbelegt mit der letzten gültigen Auswahl.
func open(mode: String, mode_name: String) -> void:
	_mode = mode
	_mode_name = mode_name
	cfg = _load_last()
	_view_ship = cfg.ship
	_tab = "ship"
	_note = ""
	visible = true
	queue_redraw()


## Letzte Auswahl laden; was inzwischen nicht mehr passt (gesperrt, unbekannt), fällt auf den Standard.
func _load_last() -> Dictionary:
	var saved: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary:
			saved = parsed
	var c := Loadout.normalized(saved)
	if not Loadout.is_unlocked(c.ship):
		c = Loadout.default_config(Loadout.DEFAULT_SHIP, c.difficulty)
	var known := Loadout.known_species()
	c.crew = (c.crew as Array).map(func(s: String) -> String: return s if known.has(s) else Species.DEFAULT)
	return c if Loadout.is_valid(c) else Loadout.default_config(Loadout.DEFAULT_SHIP, c.difficulty)


func _save_last() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cfg))


func _process(delta: float) -> void:
	if visible and _note_time > 0.0:
		_note_time -= delta
		if _note_time <= 0.0:
			_note = ""
		queue_redraw()


func _say(text: String, deny := true) -> void:
	_note = text
	_note_time = NOTE_TIME
	if deny:
		Sfx.play("ui_deny")


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _textures[path]


func _hit(rect: Rect2, action: String, arg: Variant = null) -> void:
	_hits.append({"rect": rect, "action": action, "arg": arg})


func _points(n: int) -> String:
	return Loc.t("%d P") % n


# --- Zeichnen ---


func _draw() -> void:
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	HudStyle.text(self, Vector2(8, 15), Loc.t("NEUER RUN") + " · " + _mode_name, COLOR_TITLE, -1, 11)
	var valid := Loadout.is_valid(cfg)
	var start := Rect2(size.x - 8 - 58, 4, 58, 16)
	HudStyle.button(self, start, Loc.t("START"), HudStyle.COLOR_OK if valid else HudStyle.COLOR_DIM, valid)
	_hit(start, "start")
	var back := Rect2(start.position.x - 4 - 54, 4, 54, 16)
	HudStyle.button(self, back, Loc.t("ZURÜCK"), HudStyle.COLOR_TEXT)
	_hit(back, "back")
	# Reiter
	var x := 8.0
	for t: Array in TABS:
		var label := Loc.t(t[1])
		var r := Rect2(x, 24, HudStyle.text_width(label) + 12, 15)
		var active: bool = _tab == t[0]
		HudStyle.button(self, r, label, HudStyle.COLOR_SHIELD if active else HudStyle.COLOR_DIM, active)
		_hit(r, "tab", t[0])
		x += r.size.x + 3
	# Punkte
	var left := Loadout.remaining(cfg)
	var pts := Loc.t("Punkte frei: %d / %d") % [left, Loadout.budget(cfg)]
	HudStyle.text(self, Vector2(size.x - 8 - HudStyle.text_width(pts), 35), pts, HudStyle.COLOR_GOLD if left >= 0 else HudStyle.COLOR_BAD)
	var content := Rect2(8, 44, size.x - 16, size.y - 44 - 18)
	match _tab:
		"ship":
			_draw_ships(content)
		"crew":
			_draw_crew(content)
		"weapons":
			_draw_weapons(content)
		"perks":
			_draw_perks(content)
		"difficulty":
			_draw_difficulty(content)
	_draw_footer()


func _draw_footer() -> void:
	var y := size.y - 6
	var text := _note
	var color := HudStyle.COLOR_BAD
	if text == "":
		var problems := Loadout.problems(cfg)
		if not problems.is_empty():
			text = problems[0]
		elif Loadout.remaining(cfg) > 0:
			text = Loc.t("Übrige Punkte werden zu %d Rohstoffen") % Loadout.leftover_scrap(cfg)
			color = HudStyle.COLOR_SCRAP
		else:
			text = Loc.t("Alle Punkte verteilt")
			color = HudStyle.COLOR_DIM
	HudStyle.text(self, Vector2(8, y), text, color, size.x - 16)


## Bild ganzzahlig verkleinert (1/2, 1/3 …) oder vergrößert, damit die Pixel sauber bleiben.
func _draw_picture(tex: Texture2D, area: Rect2, tint: Color) -> void:
	if tex == null:
		return
	var fit := minf(area.size.x / tex.get_width(), area.size.y / tex.get_height())
	var s := floorf(fit) if fit >= 1.0 else 1.0 / ceilf(1.0 / fit)
	var draw_size := tex.get_size() * s
	draw_texture_rect(tex, Rect2((area.position + (area.size - draw_size) / 2.0).floor(), draw_size), false, tint)


func _draw_ships(c: Rect2) -> void:
	var y := c.position.y
	for id in Loadout.ship_ids():
		var unlocked := Loadout.is_unlocked(id)
		var chosen: bool = cfg.ship == id
		var r := Rect2(c.position.x, y, LIST_W, ROW_H - 2)
		var edge := HudStyle.COLOR_OK if chosen else (HudStyle.COLOR_SHIELD if id == _view_ship else (HudStyle.COLOR_EDGE if unlocked else HudStyle.COLOR_OFF))
		HudStyle.box(self, r, edge, Color(edge, 0.18) if chosen else HudStyle.COLOR_BG)
		var label := Loc.t(str(Loadout.ship(id).get("name", id)))
		HudStyle.text(self, r.position + Vector2(5, 10), label if unlocked else "? " + label, COLOR_NAME if unlocked else HudStyle.COLOR_DIM, r.size.x - 30)
		var cost := _points(Loadout.ship_cost(id))
		HudStyle.text(self, Vector2(r.end.x - 4 - HudStyle.text_width(cost), r.position.y + 10), cost, HudStyle.COLOR_GOLD if unlocked else HudStyle.COLOR_DIM)
		_hit(r, "ship", id)
		y += ROW_H
	y += 6
	HudStyle.paragraph(self, Vector2(c.position.x, y + 4), Loc.t("Stärkere Schiffe kosten Punkte, die dann für Crew, Waffen und Perks fehlen."), LIST_W, HudStyle.COLOR_DIM)
	# Detail
	var panel := Rect2(c.position.x + LIST_W + 6, c.position.y, c.size.x - LIST_W - 6, c.size.y)
	HudStyle.box(self, panel, HudStyle.COLOR_EDGE)
	var id := _view_ship
	var d := Loadout.ship(id)
	var unlocked := Loadout.is_unlocked(id)
	var stats := Loadout.ship_stats(id)
	var tint := Color(str(stats.get("tint", "#ffffff"))) if unlocked else Color(0.05, 0.06, 0.1, 1.0)
	var pic := Rect2(panel.position + Vector2(4, 3), Vector2(panel.size.x - 8, 50))
	_draw_picture(_texture(str(stats.get("sprite", ""))), pic, tint)
	var x := panel.position.x + 7
	var w := panel.size.x - 14
	y = pic.end.y + 10
	HudStyle.text(self, Vector2(x, y), Loc.t(str(d.get("name", id))), COLOR_TITLE, -1, 11)
	var cost := Loc.t("Kosten: %d Punkte") % Loadout.ship_cost(id)
	HudStyle.text(self, Vector2(panel.end.x - 7 - HudStyle.text_width(cost), y), cost, HudStyle.COLOR_GOLD)
	y += 11
	if not unlocked:
		HudStyle.text(self, Vector2(x, y), Loc.t("Gesperrt"), HudStyle.COLOR_BAD)
		HudStyle.paragraph(self, Vector2(x, y + 11), Loadout.unlock_text(id), w, HudStyle.COLOR_GOLD)
		return
	var sys: Dictionary = stats.get("systems", {})
	var line := Loc.t("Hülle %d · Reaktor %d · Schilde %d · Waffen %d · Antrieb %d · Medbay %d") % [
		int(stats.get("hull", 0)), int(stats.get("reactor", 0)), int(sys.get("schilde", 0)),
		int(sys.get("waffen", 0)), int(sys.get("antrieb", 0)), int(sys.get("medbay", 0))]
	y += HudStyle.paragraph(self, Vector2(x, y), line, w, HudStyle.COLOR_SHIELD)
	var weapons: Array[String] = []
	for wid: String in stats.get("weapons", []):
		weapons.append(Weapon.name_of(wid))
	var extra := Loc.t("Startwaffen: ") + ", ".join(weapons)
	if int(d.get("start_scrap", 0)) > 0:
		extra += " · " + Loc.t("+%d Rohstoffe") % int(d.start_scrap)
	y += HudStyle.paragraph(self, Vector2(x, y), extra, w, HudStyle.COLOR_FUEL) + 3
	HudStyle.paragraph(self, Vector2(x, y), Loc.t(str(d.get("text", ""))), w, HudStyle.COLOR_TEXT)
	if cfg.ship != id:
		var pick := Rect2(panel.end.x - 7 - 70, panel.end.y - 20, 70, 15)
		HudStyle.button(self, pick, Loc.t("WÄHLEN"), HudStyle.COLOR_OK)
		_hit(pick, "ship_pick", id)


func _draw_crew(c: Rect2) -> void:
	var x := c.position.x
	var w := c.size.x
	var y := c.position.y
	# Captain: immer dabei, kostet nichts
	var r := Rect2(x, y, w, ROW_H - 2)
	HudStyle.box(self, r, HudStyle.COLOR_GOLD)
	HudStyle.star(self, r.position + Vector2(5, 5), HudStyle.COLOR_GOLD)
	HudStyle.text(self, r.position + Vector2(14, 10), "Mara Voss", COLOR_NAME)
	HudStyle.text(self, r.position + Vector2(84, 10), Species.display_name("mensch") + " · " + Loc.t("Captain"), HudStyle.COLOR_DIM)
	var free := Loc.t("gratis")
	HudStyle.text(self, Vector2(r.end.x - 5 - HudStyle.text_width(free), r.position.y + 10), free, HudStyle.COLOR_DIM)
	y += ROW_H
	var crew: Array = cfg.crew
	for i in crew.size():
		var sp: String = crew[i]
		r = Rect2(x, y, w, ROW_H - 2)
		HudStyle.box(self, r, HudStyle.COLOR_EDGE)
		draw_texture_rect_region(CrewArt.sheet(sp), Rect2(r.position + Vector2(2, 0), Vector2(14, 14)), Rect2(0, 0, 16, 16))
		var prev := Rect2(r.position.x + 20, r.position.y + 1, 13, 13)
		var next := Rect2(r.position.x + 92, r.position.y + 1, 13, 13)
		HudStyle.button(self, prev, "<", HudStyle.COLOR_SHIELD)
		HudStyle.button(self, next, ">", HudStyle.COLOR_SHIELD)
		_hit(prev, "species", [i, -1])
		_hit(next, "species", [i, 1])
		HudStyle.text(self, Vector2(prev.end.x + 4, r.position.y + 10), Species.display_name(sp), Species.tint(sp).lerp(HudStyle.COLOR_TEXT, 0.3), next.position.x - prev.end.x - 6)
		var traits := Species.traits(sp)
		HudStyle.text(self, Vector2(next.end.x + 6, r.position.y + 10), ", ".join(traits.slice(0, 2)), HudStyle.COLOR_DIM, r.end.x - next.end.x - 70)
		var price := _points(Loadout.crew_cost(sp) + Loadout.crew_surcharge(i))
		var del := Rect2(r.end.x - 15, r.position.y + 1, 13, 13)
		HudStyle.text(self, Vector2(del.position.x - 5 - HudStyle.text_width(price), r.position.y + 10), price, HudStyle.COLOR_GOLD)
		HudStyle.button(self, del, "x", HudStyle.COLOR_BAD)
		_hit(del, "crew_remove", i)
		y += ROW_H
	if crew.size() < Loadout.crew_max():
		var add := Rect2(x, y, 150, ROW_H - 2)
		var label := Loc.t("+ CREW (%d P)") % (Loadout.crew_cost(Species.DEFAULT) + Loadout.crew_surcharge(crew.size()))
		HudStyle.button(self, add, label, HudStyle.COLOR_OK)
		_hit(add, "crew_add")
		y += ROW_H
	y += 6
	var hint := Loc.t("Bis zu %d Personen neben dem Captain. Ab der dritten kostet jede %d Punkt mehr. Neue Spezies gibt es hier, sobald sie einmal in deiner Crew waren (Lexikon).") % [Loadout.crew_max(), int(Loadout.defs().get("crew_extra", 1))]
	HudStyle.paragraph(self, Vector2(x, y + 4), hint, w, HudStyle.COLOR_DIM)


func _draw_weapons(c: Rect2) -> void:
	var col_w := floorf((c.size.x - 6) / 2.0)
	var x := c.position.x
	var y := c.position.y
	var slots := Loadout.weapon_slots(cfg)
	var weapons: Array = cfg.weapons
	var power := Loadout.weapon_power(cfg)
	HudStyle.text(self, Vector2(x, y + 8), Loc.t("Waffenplätze %d / %d") % [weapons.size(), slots], HudStyle.COLOR_TEXT)
	var pw := Loc.t("Energie %d / %d") % [power.x, power.y]
	HudStyle.text(self, Vector2(x + col_w - HudStyle.text_width(pw), y + 8), pw, HudStyle.COLOR_WARN if power.x > power.y else HudStyle.COLOR_OK)
	y += 13
	for i in slots:
		var r := Rect2(x, y, col_w, 21)
		if i < weapons.size():
			var wid: String = weapons[i]
			HudStyle.box(self, r, HudStyle.COLOR_EDGE)
			HudStyle.text(self, r.position + Vector2(5, 9), Weapon.name_of(wid), COLOR_NAME, col_w - 50)
			HudStyle.text(self, r.position + Vector2(5, 18), Weapon.summary(wid), HudStyle.COLOR_DIM, col_w - 24)
			var price := _points(Loadout.weapon_cost(wid))
			var del := Rect2(r.end.x - 15, r.position.y + 4, 13, 13)
			HudStyle.text(self, Vector2(del.position.x - 5 - HudStyle.text_width(price), r.position.y + 9), price, HudStyle.COLOR_GOLD)
			HudStyle.button(self, del, "x", HudStyle.COLOR_BAD)
			_hit(del, "weapon_remove", i)
		else:
			HudStyle.box(self, r, HudStyle.COLOR_OFF)
			HudStyle.text(self, r.position + Vector2(5, 13), Loc.t("frei"), HudStyle.COLOR_DIM)
		y += 23
	if power.x > power.y:
		HudStyle.paragraph(self, Vector2(x, y + 8), Loc.t("Mehr Waffen als Energie im Waffensystem: nicht alle laufen gleichzeitig, bis du ausbaust."), col_w, HudStyle.COLOR_WARN)
	# Angebot
	x = c.position.x + col_w + 6
	y = c.position.y
	HudStyle.text(self, Vector2(x, y + 8), Loc.t("Antippen zum Einbauen"), HudStyle.COLOR_DIM)
	y += 13
	for wid in Loadout.weapon_ids():
		var r := Rect2(x, y, col_w, 18)
		var fits := weapons.size() < slots and Loadout.weapon_cost(wid) <= Loadout.remaining(cfg)
		HudStyle.box(self, r, HudStyle.COLOR_EDGE if fits else HudStyle.COLOR_OFF)
		HudStyle.text(self, r.position + Vector2(5, 8), Weapon.name_of(wid), COLOR_NAME if fits else HudStyle.COLOR_DIM, col_w - 30)
		HudStyle.text(self, r.position + Vector2(5, 16), Weapon.summary(wid), HudStyle.COLOR_DIM, col_w - 10)
		var price := _points(Loadout.weapon_cost(wid))
		HudStyle.text(self, Vector2(r.end.x - 5 - HudStyle.text_width(price), r.position.y + 8), price, HudStyle.COLOR_GOLD if fits else HudStyle.COLOR_DIM)
		_hit(r, "weapon_add", wid)
		y += 19


func _draw_perks(c: Rect2) -> void:
	var x := c.position.x
	var y := c.position.y
	var perks: Array = cfg.perks
	HudStyle.text(self, Vector2(x, y + 8), Loc.t("Perks zum Start: %d / %d") % [perks.size(), Loadout.perks_max()], HudStyle.COLOR_TEXT)
	var hint := Loc.t("Weitere kaufst du unterwegs mit Rohstoffen.")
	HudStyle.text(self, Vector2(c.end.x - HudStyle.text_width(hint), y + 8), hint, HudStyle.COLOR_DIM)
	y += 13
	for id in Loadout.perk_ids():
		var on := perks.has(id)
		var r := Rect2(x, y, c.size.x, 16)
		HudStyle.box(self, r, HudStyle.COLOR_OK if on else HudStyle.COLOR_EDGE, Color(HudStyle.COLOR_OK, 0.15) if on else HudStyle.COLOR_BG)
		var tick := Rect2(r.position + Vector2(4, 4), Vector2(8, 8))
		draw_rect(tick, HudStyle.COLOR_OK if on else HudStyle.COLOR_OFF, on)
		HudStyle.text(self, r.position + Vector2(17, 11), Upgrades.perk_name(id), COLOR_NAME, 102)
		var price := _points(Loadout.perk_cost(id))
		HudStyle.text(self, Vector2(r.end.x - 5 - HudStyle.text_width(price), r.position.y + 11), price, HudStyle.COLOR_GOLD)
		HudStyle.text(self, r.position + Vector2(122, 11), Upgrades.perk_text(id), HudStyle.COLOR_DIM, r.size.x - 122 - 24)
		_hit(r, "perk", id)
		y += 17


func _draw_difficulty(c: Rect2) -> void:
	var ids := Loadout.difficulty_ids()
	var gap := 6.0
	var cw := floorf((c.size.x - gap * (ids.size() - 1)) / ids.size())
	var colors := [HudStyle.COLOR_OK, HudStyle.COLOR_WARN, HudStyle.COLOR_BAD]
	for i in ids.size():
		var id := ids[i]
		var d := Loadout.difficulty(id)
		var chosen: bool = cfg.difficulty == id
		var color: Color = colors[mini(i, colors.size() - 1)]
		var r := Rect2(c.position.x + i * (cw + gap), c.position.y, cw, c.size.y - 4)
		HudStyle.box(self, r, color if chosen else HudStyle.COLOR_EDGE, Color(color, 0.12) if chosen else HudStyle.COLOR_BG)
		var x := r.position.x + 6
		var w := r.size.x - 12
		var y := r.position.y + 14
		HudStyle.text(self, Vector2(x, y), Loc.t(str(d.get("name", id))), color, -1, 11)
		y += 12
		HudStyle.text(self, Vector2(x, y), Loc.t("%d Startpunkte") % int(d.get("points", 0)), HudStyle.COLOR_GOLD)
		y += 12
		var lines: Array[String] = []
		if int(d.get("enemy_hull", 0)) != 0:
			lines.append(Loc.t("Gegnerhülle %+d") % int(d.enemy_hull))
		if int(d.get("enemy_depth", 0)) != 0:
			lines.append(Loc.t("Gegnerstufe %+d") % int(d.enemy_depth))
		if not is_equal_approx(float(d.get("scrap_gain", 1.0)), 1.0):
			lines.append(Loc.t("Rohstoffe %+d %%") % roundi((float(d.scrap_gain) - 1.0) * 100.0))
		if int(d.get("start_fuel", 0)) != 0:
			lines.append(Loc.t("Treibstoff %+d") % int(d.start_fuel))
		for l in lines:
			HudStyle.text(self, Vector2(x, y), l, HudStyle.COLOR_SHIELD, w)
			y += 10
		y += 4
		HudStyle.paragraph(self, Vector2(x, y), Loc.t(str(d.get("text", ""))), w, HudStyle.COLOR_TEXT)
		_hit(r, "difficulty", id)


# --- Eingabe ---


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	for hit in _hits:
		if not (hit.rect as Rect2).grow(1).has_point(event.position):
			continue
		_act(hit.action, hit.arg)
		queue_redraw()
		return


func _act(action: String, arg: Variant) -> void:
	match action:
		"back":
			Sfx.play("ui_click")
			_close()
		"start":
			var problems := Loadout.problems(cfg)
			if not problems.is_empty():
				_say(problems[0])
				return
			Sfx.play("ui_click")
			_save_last()
			visible = false
			started.emit(_mode, cfg.duplicate(true))
		"tab":
			Sfx.play("ui_click")
			_tab = arg
		"ship":
			_view_ship = arg
			if Loadout.is_unlocked(arg):
				_pick_ship(arg)
			else:
				_say(Loadout.unlock_text(arg))
		"ship_pick":
			_pick_ship(arg)
		"difficulty":
			Sfx.play("ui_click")
			cfg.difficulty = arg
		"species":
			var known := Loadout.known_species()
			var i: int = arg[0]
			if known.size() <= 1:
				_say(Loc.t("Noch keine andere Spezies entdeckt"))
				return
			var at := known.find(cfg.crew[i])
			cfg.crew[i] = known[posmod(at + int(arg[1]), known.size())]
			Sfx.play("ui_click")
		"crew_add":
			var price := Loadout.crew_cost(Species.DEFAULT) + Loadout.crew_surcharge(cfg.crew.size())
			if price > Loadout.remaining(cfg):
				_say(Loc.t("Nicht genug Punkte"))
				return
			cfg.crew.append(Species.DEFAULT)
			Sfx.play("ui_click")
		"crew_remove":
			cfg.crew.remove_at(arg)
			Sfx.play("ui_click")
		"weapon_add":
			if cfg.weapons.size() >= Loadout.weapon_slots(cfg):
				_say(Loc.t("Alle Waffenplätze belegt"))
			elif Loadout.weapon_cost(arg) > Loadout.remaining(cfg):
				_say(Loc.t("Nicht genug Punkte"))
			else:
				cfg.weapons.append(arg)
				Sfx.play("weapon_select")
		"weapon_remove":
			cfg.weapons.remove_at(arg)
			Sfx.play("ui_click")
		"perk":
			if cfg.perks.has(arg):
				cfg.perks.erase(arg)
				Sfx.play("ui_click")
			elif cfg.perks.size() >= Loadout.perks_max():
				_say(Loc.t("Höchstens %d Perks zum Start") % Loadout.perks_max())
			elif Loadout.perk_cost(arg) > Loadout.remaining(cfg):
				_say(Loc.t("Nicht genug Punkte"))
			else:
				cfg.perks.append(arg)
				Sfx.play("ui_click")


## Schiff wechseln: Die Waffen werden auf die Startwaffen des Schiffs gesetzt, Crew und Perks bleiben.
func _pick_ship(id: String) -> void:
	_view_ship = id
	if cfg.ship == id:
		return
	cfg.ship = id
	cfg.weapons = (Loadout.ship(id).get("weapons", []) as Array).duplicate()
	Sfx.play("ui_click")
	if Loadout.remaining(cfg) < 0:
		_say(Loc.t("Zu teuer: Nimm etwas anderes heraus oder wähle eine andere Schwierigkeit"), false)


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
