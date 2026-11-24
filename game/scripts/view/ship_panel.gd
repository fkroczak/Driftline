class_name ShipPanel
extends Control
## Schiffsausbau als Überlagerung (Knopf SCHIFF oben, nur außerhalb des Kampfs). Das Spiel steht,
## solange er offen ist. Zwei Seiten:
##
## - **SYSTEME:** je System die Stufe als Balken (grün = ausgebaut, dunkel = noch möglich) und ein
##   Knopf „+1“ mit dem Preis in Rohstoffen. Den Namen antippen erklärt das System.
## - **WAFFEN & PERKS:** links die Waffenplätze und das Lager (Waffe ins Lager oder wieder
##   einbauen; kaufen und verkaufen nur beim Händler), rechts die Perks an Bord (gekauft werden
##   sie beim Händler).
##
## Preise und Grenzen stehen in data/upgrades.json, die Logik in RunState (Abschnitt Schiffsausbau).

signal closed
## Nach jedem Kauf oder Umbau, damit der Bildschirm Waffenleiste und Spielstand auffrischt.
signal changed

const PAGE_SYSTEMS := "systeme"
const PAGE_WEAPONS := "waffen"
const ROW_H := 17.0
const BTN_W := 48.0
const COLOR_DIM_BG := Color("#07080F", 0.85)
const COLOR_TITLE := Color("#FDE6BF")

var run: RunState
var page := PAGE_SYSTEMS
var _note := ""
var _note_color := HudStyle.COLOR_DIM
var _hits: Array[Dictionary] = []  # {rect, action, arg}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(p_run: RunState) -> void:
	run = p_run
	_note = Loc.t("Ausbauen kostet Rohstoffe. Namen antippen erklärt, was es bringt.")
	_note_color = HudStyle.COLOR_DIM
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	closed.emit()


func _box() -> Rect2:
	var w := minf(size.x - 12.0, 400.0)
	var h := minf(size.y - 8.0, 206.0)
	return Rect2(((size - Vector2(w, h)) / 2.0).floor(), Vector2(w, h))


func _draw() -> void:
	_hits.clear()
	if not run:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DIM_BG)
	var box := _box()
	HudStyle.box(self, box, HudStyle.COLOR_EDGE_HI)
	HudStyle.text(self, box.position + Vector2(8, 15), Loc.t("SCHIFF"), COLOR_TITLE, -1, 11)
	# Reiter
	var x := box.position.x + 8.0 + HudStyle.text_width(Loc.t("SCHIFF"), 11) + 10.0
	for tab: Array in [[PAGE_SYSTEMS, Loc.t("SYSTEME")], [PAGE_WEAPONS, Loc.t("WAFFEN & PERKS")]]:
		var r := Rect2(x, box.position.y + 5, HudStyle.text_width(tab[1]) + 14.0, 14)
		var active: bool = page == tab[0]
		HudStyle.button(self, r, tab[1], HudStyle.COLOR_SHIELD if active else HudStyle.COLOR_DIM, active)
		_hits.append({"rect": r, "action": "tab", "arg": tab[0]})
		x = r.end.x + 3.0
	# Rohstoffe oben rechts
	var scrap_text := "%d" % run.scrap
	var sx := box.end.x - 8.0 - HudStyle.text_width(scrap_text)
	HudStyle.icon(self, Vector2(sx - 10, box.position.y + 8), "scrap", HudStyle.COLOR_SCRAP)
	HudStyle.text(self, Vector2(sx, box.position.y + 15), scrap_text, HudStyle.COLOR_SCRAP)
	var content := Rect2(box.position.x + 8, box.position.y + 24, box.size.x - 16, box.size.y - 50)
	if page == PAGE_SYSTEMS:
		_draw_systems(content)
	else:
		_draw_weapons(Rect2(content.position, Vector2(floorf(content.size.x * 0.48), content.size.y)))
		var right := content.position.x + floorf(content.size.x * 0.52)
		_draw_perks(Rect2(right, content.position.y, content.end.x - right, content.size.y))
	# Fußzeile: Hinweis und ZURÜCK
	var back := Rect2(box.end.x - 8 - 64, box.end.y - 22, 64, 16)
	HudStyle.paragraph(self, Vector2(box.position.x + 8, box.end.y - 17), _note, back.position.x - box.position.x - 14, _note_color, 9.0)
	HudStyle.button(self, back, Loc.t("ZURÜCK"), HudStyle.COLOR_TEXT)
	_hits.append({"rect": back, "action": "close", "arg": ""})


func _draw_systems(area: Rect2) -> void:
	var y := area.position.y
	for id: String in Upgrades.SYSTEM_ORDER:
		var sys := run.ship.get_system(id)
		if sys == null:
			continue
		var rule := Upgrades.system_rule(id)
		var top := maxi(int(rule.get("max", sys.capacity)), sys.capacity)
		var name_rect := Rect2(area.position.x, y, 90, ROW_H - 2)
		HudStyle.text(self, Vector2(area.position.x, y + 11), SystemInfo.display_name(id), HudStyle.COLOR_TEXT)
		_hits.append({"rect": name_rect, "action": "info_system", "arg": id})
		# Stufen als Balken
		var px := area.position.x + 92.0
		for b in top:
			var color := HudStyle.COLOR_OK if b < sys.capacity else HudStyle.COLOR_OFF
			if b < sys.capacity and b >= sys.capacity - sys.damage:
				color = HudStyle.COLOR_BAD
			draw_rect(Rect2(px + b * 6.0, y + 4, 4, 8), color)
		HudStyle.text(self, Vector2(px + top * 6.0 + 4.0, y + 11), "%d/%d" % [sys.capacity, top], HudStyle.COLOR_DIM)
		var btn := Rect2(area.end.x - BTN_W, y, BTN_W, ROW_H - 3)
		var price := run.system_upgrade_price(id)
		if price < 0:
			HudStyle.button(self, btn, Loc.t("MAX"), HudStyle.COLOR_DIM)
		else:
			_price_button(btn, "+1", price, run.can_upgrade_system(id))
			_hits.append({"rect": btn, "action": "upgrade", "arg": id})
		y += ROW_H


func _draw_weapons(area: Rect2) -> void:
	var ship := run.ship
	var y := area.position.y
	HudStyle.text(self, Vector2(area.position.x, y + 8), Loc.t("WAFFENPLÄTZE"), HudStyle.COLOR_SHIELD)
	y += 12.0
	for i in ship.weapon_slots():
		var label := "%d  " % (i + 1)
		if i < ship.weapons.size():
			var w := ship.weapons[i]
			HudStyle.text(self, Vector2(area.position.x, y + 11), label + Loc.t(w.display_name), HudStyle.COLOR_TEXT, area.size.x - BTN_W - 4)
			_hits.append({"rect": Rect2(area.position.x, y, area.size.x - BTN_W - 4, ROW_H - 2), "action": "info_weapon", "arg": w.id})
			var btn := Rect2(area.end.x - BTN_W, y, BTN_W, ROW_H - 3)
			var room := ship.stored_weapons.size() < Upgrades.weapon_storage()
			HudStyle.button(self, btn, Loc.t("LAGER"), HudStyle.COLOR_TEXT if room else HudStyle.COLOR_DIM)
			_hits.append({"rect": btn, "action": "store", "arg": i})
		else:
			HudStyle.text(self, Vector2(area.position.x, y + 11), label + Loc.t("frei"), HudStyle.COLOR_DIM)
		y += ROW_H
	y += 3.0
	HudStyle.text(self, Vector2(area.position.x, y + 8), Loc.t("LAGER %d/%d") % [ship.stored_weapons.size(), Upgrades.weapon_storage()], HudStyle.COLOR_SHIELD)
	y += 12.0
	for i in Upgrades.weapon_storage():
		if i < ship.stored_weapons.size():
			var id := ship.stored_weapons[i]
			HudStyle.text(self, Vector2(area.position.x, y + 11), Weapon.name_of(id), HudStyle.COLOR_TEXT, area.size.x - BTN_W - 4)
			_hits.append({"rect": Rect2(area.position.x, y, area.size.x - BTN_W - 4, ROW_H - 2), "action": "info_weapon", "arg": id})
			var btn := Rect2(area.end.x - BTN_W, y, BTN_W, ROW_H - 3)
			var free := ship.weapons.size() < ship.weapon_slots()
			HudStyle.button(self, btn, Loc.t("EINBAUEN"), HudStyle.COLOR_OK if free else HudStyle.COLOR_DIM)
			_hits.append({"rect": btn, "action": "install", "arg": i})
		else:
			HudStyle.text(self, Vector2(area.position.x, y + 11), Loc.t("leer"), HudStyle.COLOR_DIM)
		y += ROW_H


func _draw_perks(area: Rect2) -> void:
	var y := area.position.y
	HudStyle.text(self, Vector2(area.position.x, y + 8), Loc.t("PERKS"), HudStyle.COLOR_SHIELD)
	y += 12.0
	if run.ship.perks.is_empty():
		HudStyle.paragraph(self, Vector2(area.position.x, y + 9), Loc.t("Noch keine Perks an Bord. Händler bieten wechselnde Perks an."), area.size.x, HudStyle.COLOR_DIM, 9.0)
	for id in run.ship.perks:
		HudStyle.text(self, Vector2(area.position.x, y + 11), Upgrades.perk_name(id), HudStyle.COLOR_OK, area.size.x)
		_hits.append({"rect": Rect2(area.position.x, y, area.size.x, ROW_H - 2), "action": "info_perk", "arg": id})
		y += ROW_H


## Knopf mit Preis: „+1 ⚙25“; grün, wenn bezahlbar, sonst grau.
func _price_button(rect: Rect2, prefix: String, price: int, affordable: bool) -> void:
	var color := HudStyle.COLOR_OK if affordable else HudStyle.COLOR_DIM
	HudStyle.box(self, rect, color, Color("#161B2B"))
	var value := "%d" % price
	var w := 8.0 + HudStyle.text_width(value) + (HudStyle.text_width(prefix) + 4.0 if prefix != "" else 0.0)
	var x := rect.position.x + roundf((rect.size.x - w) / 2.0)
	var base := rect.position.y + roundf(rect.size.y / 2.0 + 3.0)
	if prefix != "":
		HudStyle.text(self, Vector2(x, base), prefix, color)
		x += HudStyle.text_width(prefix) + 4.0
	HudStyle.icon(self, Vector2(x, base - 7.0), "scrap", color)
	HudStyle.text(self, Vector2(x + 8.0, base), value, color)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	for i in range(_hits.size() - 1, -1, -1):
		var hit := _hits[i]
		if (hit.rect as Rect2).grow(1).has_point(event.position):
			_act(hit.action, hit.arg)
			queue_redraw()
			return


func _act(action: String, arg: Variant) -> void:
	var ship := run.ship
	match action:
		"close":
			Sfx.play("ui_click")
			close()
		"tab":
			Sfx.play("ui_click")
			page = arg
			_say("")
		"info_system":
			Sfx.play("ui_click")
			_say("%s: %s" % [SystemInfo.display_name(arg), SystemInfo.describe(arg)])
		"info_weapon":
			Sfx.play("ui_click")
			_say("%s: %s · %s" % [Weapon.name_of(arg), Weapon.summary(arg), Loc.t("kaufen und verkaufen beim Händler")])
		"info_perk":
			Sfx.play("ui_click")
			_say("%s: %s" % [Upgrades.perk_name(arg), Upgrades.perk_text(arg)])
		"upgrade":
			var price := run.system_upgrade_price(arg)
			if run.upgrade_system(arg):
				Sfx.play("power_up")
				_say(Loc.t("%s ausgebaut: Stufe %d (−%d Rohstoffe)") % [SystemInfo.display_name(arg), ship.get_system(arg).capacity, price], HudStyle.COLOR_OK)
				changed.emit()
			else:
				_deny(Loc.t("Nicht genug Rohstoffe"))
		"perk":
			if run.buy_perk(arg):
				Sfx.play("power_up")
				_say(Loc.t("%s eingebaut: %s") % [Upgrades.perk_name(arg), Upgrades.perk_text(arg)], HudStyle.COLOR_OK)
				changed.emit()
			else:
				_deny(Loc.t("Nicht genug Rohstoffe"))
		"store":
			if ship.store_weapon(arg):
				Sfx.play("power_down")
				_say(Loc.t("Waffe ins Lager gebracht"))
				changed.emit()
			else:
				_deny(Loc.t("Das Lager ist voll"))
		"install":
			if ship.install_weapon(arg):
				Sfx.play("power_up")
				_say(Loc.t("Waffe eingebaut; Energie gibt es über die Waffenkarte"), HudStyle.COLOR_OK)
				changed.emit()
			else:
				_deny(Loc.t("Kein Waffenplatz frei"))


func _say(text: String, color := HudStyle.COLOR_DIM) -> void:
	_note = text
	_note_color = color


func _deny(text: String) -> void:
	Sfx.play("ui_deny")
	_say(text, HudStyle.COLOR_BAD)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
