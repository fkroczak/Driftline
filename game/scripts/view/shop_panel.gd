class_name ShopPanel
extends Control
## Händler als eigener Bildschirm mit Seiten (statt Textoptionen). Das Spiel steht, solange er offen ist.
##
## - **VORRÄTE:** Treibstoff und Hülle, dazu (bei manchen Händlern) eine Batterie für einen freien
##   Erweiterungsraum.
## - **WAFFEN:** links das Angebot als Karten mit Symbol, Werten und kurzer Erklärung, rechts die
##   eigenen Waffen zum Verkauf (halber Preis, die letzte bleibt an Bord).
## - **PERKS:** zufällige Auswahl je Händler, als Karten mit Symbol und Wirkung.
## - **CREW:** Leute zum Anheuern mit Porträt, Spezies, Geschlecht und Stärken.
##
## Logik und Preise in RunState (Abschnitt Händler als eigener Bildschirm), Waren je Händler fest.

signal closed
## Nach jedem Kauf, damit der Bildschirm Waffen, Crew und Spielstand auffrischt.
signal changed

const PAGES := [["vorraete", "VORRÄTE"], ["waffen", "WAFFEN"], ["perks", "PERKS"], ["crew", "CREW"]]  # i18n
const COLOR_DIM_BG := Color("#07080F", 0.85)
const COLOR_TITLE := Color("#FDE6BF")
const COLOR_CARD := Color("#10142A")
const BTN_W := 52.0

var run: RunState
var page := "vorraete"
var _note := ""
var _note_color := HudStyle.COLOR_DIM
var _hits: Array[Dictionary] = []  # {rect, action, arg}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(p_run: RunState) -> void:
	run = p_run
	page = "vorraete"
	_say(Loc.t("Ein Handelsposten der Gilde. Bezahlt wird in Rohstoffen oder Treibstoff."))
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	run.close_shop()
	closed.emit()


func _box() -> Rect2:
	var w := minf(size.x - 8.0, 420.0)
	var h := minf(size.y - 6.0, 208.0)
	return Rect2(((size - Vector2(w, h)) / 2.0).floor(), Vector2(w, h))


func _draw() -> void:
	_hits.clear()
	if not run:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DIM_BG)
	var box := _box()
	HudStyle.box(self, box, HudStyle.COLOR_EDGE_HI)
	HudStyle.text(self, box.position + Vector2(6, 15), Loc.t("HÄNDLER"), COLOR_TITLE, -1, 11)
	var x := box.position.x + 8.0 + HudStyle.text_width(Loc.t("HÄNDLER"), 11) + 6.0
	for tab: Array in PAGES:
		var label := Loc.t(tab[1])
		var r := Rect2(x, box.position.y + 5, HudStyle.text_width(label) + 10.0, 14)
		var active: bool = page == tab[0]
		HudStyle.button(self, r, label, HudStyle.COLOR_SHIELD if active else HudStyle.COLOR_DIM, active)
		_hits.append({"rect": r, "action": "tab", "arg": tab[0]})
		x = r.end.x + 2.0
	# Treibstoff und Rohstoffe oben rechts
	var scrap_text := "%d" % run.scrap
	var fuel_text := "%d" % run.fuel
	var sx := box.end.x - 6.0 - HudStyle.text_width(scrap_text)
	HudStyle.icon(self, Vector2(sx - 9, box.position.y + 8), "scrap", HudStyle.COLOR_SCRAP)
	HudStyle.text(self, Vector2(sx, box.position.y + 15), scrap_text, HudStyle.COLOR_SCRAP)
	var fx := sx - 14.0 - HudStyle.text_width(fuel_text)
	HudStyle.icon(self, Vector2(fx - 9, box.position.y + 8), "fuel", HudStyle.COLOR_FUEL)
	HudStyle.text(self, Vector2(fx, box.position.y + 15), fuel_text, HudStyle.COLOR_FUEL)
	var content := Rect2(box.position.x + 6, box.position.y + 23, box.size.x - 12, box.size.y - 47)
	match page:
		"waffen":
			_draw_weapons(content)
		"perks":
			_draw_perks(content)
		"crew":
			_draw_crew(content)
		_:
			_draw_supplies(content)
	var back := Rect2(box.end.x - 6 - 60, box.end.y - 21, 60, 16)
	HudStyle.paragraph(self, Vector2(box.position.x + 6, box.end.y - 16), _note, back.position.x - box.position.x - 12, _note_color, 9.0)
	HudStyle.button(self, back, Loc.t("ABLEGEN"), HudStyle.COLOR_TEXT)
	_hits.append({"rect": back, "action": "close", "arg": ""})


# --- Seiten ---


func _draw_supplies(area: Rect2) -> void:
	var y := area.position.y
	var ship := run.ship
	HudStyle.text(self, Vector2(area.position.x, y + 8), Loc.t("Hülle %d/%d · Treibstoff %d") % [ship.hull, ship.max_hull, run.fuel], HudStyle.COLOR_SHIELD)
	y += 12.0
	var supplies := run.shop_supplies()
	for i in supplies.size():
		var o: Dictionary = supplies[i]
		var card := Rect2(area.position.x, y, area.size.x, 22)
		_card(card)
		HudStyle.icon(self, card.position + Vector2(6, 8), "fuel" if o.has("fuel") else "hull", HudStyle.COLOR_FUEL if o.has("fuel") else HudStyle.COLOR_OK)
		HudStyle.text(self, card.position + Vector2(18, 14), o.text, HudStyle.COLOR_TEXT, card.size.x - BTN_W - 24)
		_cost_button(Rect2(card.end.x - BTN_W - 3, y + 3, BTN_W, 16), o.cost, o.enabled, "supply", i)
		y += 25.0
	if run.shop_goods().get("battery", false) and ship.get_system("batterie") == null:
		var card := Rect2(area.position.x, y, area.size.x, 34)
		_card(card)
		ItemIcons.draw(self, Rect2(card.position + Vector2(3, 4), Vector2(26, 26)), "batterie")
		HudStyle.text(self, card.position + Vector2(34, 12), Loc.t("Batterie (selten im Angebot)"), COLOR_TITLE, card.size.x - BTN_W - 40)
		HudStyle.paragraph(self, card.position + Vector2(34, 23), Loc.t("+%d Energie, kommt in einen freien Erweiterungsraum. Im Schiffsausbau erweiterbar.") % int(Upgrades.defs().get("battery_bars", 2)),
			card.size.x - BTN_W - 40, HudStyle.COLOR_DIM, 9.0)
		_cost_button(Rect2(card.end.x - BTN_W - 3, y + 9, BTN_W, 16), {"scrap": run.battery_price()}, run.shop_can_buy_battery(), "battery", 0)


func _draw_weapons(area: Rect2) -> void:
	var goods := run.shop_goods()
	var left := Rect2(area.position, Vector2(floorf(area.size.x * 0.62), area.size.y))
	var right := Rect2(left.end.x + 6, area.position.y, area.end.x - left.end.x - 6, area.size.y)
	HudStyle.text(self, Vector2(left.position.x, left.position.y + 8), Loc.t("ANGEBOT"), HudStyle.COLOR_SHIELD)
	var y := left.position.y + 11.0
	if goods.weapons.is_empty():
		HudStyle.text(self, Vector2(left.position.x, y + 10), Loc.t("Ausverkauft."), HudStyle.COLOR_DIM)
	var card_h := minf(44.0, floorf((left.size.y - 12.0) / maxf(goods.weapons.size(), 1)) - 3.0)
	for i in goods.weapons.size():
		var id: String = goods.weapons[i]
		var card := Rect2(left.position.x, y, left.size.x, card_h)
		_card(card)
		ItemIcons.draw(self, Rect2(card.position + Vector2(3, 3), Vector2(26, 26)), id)
		HudStyle.text(self, card.position + Vector2(32, 10), Weapon.name_of(id), COLOR_TITLE, card.size.x - BTN_W - 38)
		HudStyle.text(self, card.position + Vector2(32, 20), Weapon.summary(id), HudStyle.COLOR_SHIELD, card.size.x - BTN_W - 38)
		HudStyle.paragraph(self, card.position + Vector2(32, 30), Weapon.text_of(id), card.size.x - 36, HudStyle.COLOR_DIM, 9.0)
		_cost_button(Rect2(card.end.x - BTN_W - 3, y + 3, BTN_W, 16), {"scrap": run.shop_price(Weapon.price_of(id))}, run.shop_can_buy_weapon(i), "weapon", i)
		y += card_h + 3.0
	# Eigene Waffen zum Verkauf
	HudStyle.text(self, Vector2(right.position.x, right.position.y + 8), Loc.t("AN BORD · VERKAUF"), HudStyle.COLOR_SHIELD)
	y = right.position.y + 11.0
	var owned := run.ship.all_weapon_ids()
	for i in owned.size():
		var card := Rect2(right.position.x, y, right.size.x, 25)
		_card(card)
		ItemIcons.draw(self, Rect2(card.position + Vector2(2, 6), Vector2(13, 13)), owned[i])
		var stored := i >= run.ship.weapons.size()
		HudStyle.text(self, card.position + Vector2(17, 10), Weapon.name_of(owned[i]) + (" · " + Loc.t("Lager") if stored else ""), HudStyle.COLOR_TEXT, card.size.x - 19)
		var btn := Rect2(card.position.x + 17, y + 12, card.size.x - 20, 11)
		var can := owned.size() > 1
		var label := "+%d" % run.sell_price(owned[i])
		HudStyle.button(self, btn, Loc.t("VERKAUFEN %s") % label, HudStyle.COLOR_WARN if can else HudStyle.COLOR_DIM)
		_hits.append({"rect": btn, "action": "sell", "arg": i})
		y += 28.0
	if not run.weapon_room():
		HudStyle.paragraph(self, Vector2(right.position.x, y + 8), Loc.t("Waffenplätze und Lager voll: erst etwas verkaufen."), right.size.x, HudStyle.COLOR_BAD, 9.0)


func _draw_perks(area: Rect2) -> void:
	var goods := run.shop_goods()
	HudStyle.text(self, Vector2(area.position.x, area.position.y + 8), Loc.t("PERKS IM ANGEBOT (jeder Händler hat andere)"), HudStyle.COLOR_SHIELD)
	var y := area.position.y + 12.0
	if goods.perks.is_empty():
		HudStyle.text(self, Vector2(area.position.x, y + 10), Loc.t("Ausverkauft."), HudStyle.COLOR_DIM)
	for i in goods.perks.size():
		var id: String = goods.perks[i]
		var card := Rect2(area.position.x, y, area.size.x, 38)
		_card(card)
		ItemIcons.draw(self, Rect2(card.position + Vector2(4, 5), Vector2(28, 28)), id)
		HudStyle.text(self, card.position + Vector2(38, 13), Upgrades.perk_name(id), COLOR_TITLE, card.size.x - BTN_W - 44)
		HudStyle.paragraph(self, card.position + Vector2(38, 25), Upgrades.perk_text(id), card.size.x - BTN_W - 44, HudStyle.COLOR_TEXT, 9.0)
		_cost_button(Rect2(card.end.x - BTN_W - 3, y + 11, BTN_W, 16), {"scrap": run.shop_price(run.perk_price(id))}, run.shop_can_buy_perk(i), "perk", i)
		y += 41.0
	# Perks an Bord als kleine Symbole
	if not run.ship.perks.is_empty():
		HudStyle.text(self, Vector2(area.position.x, y + 9), Loc.t("AN BORD:"), HudStyle.COLOR_DIM)
		var x := area.position.x + HudStyle.text_width(Loc.t("AN BORD:")) + 4.0
		for id in run.ship.perks:
			ItemIcons.draw(self, Rect2(Vector2(x, y + 1), Vector2(13, 13)), id)
			_hits.append({"rect": Rect2(Vector2(x, y + 1), Vector2(13, 13)), "action": "info_perk", "arg": id})
			x += 15.0


func _draw_crew(area: Rect2) -> void:
	var goods := run.shop_goods()
	HudStyle.text(self, Vector2(area.position.x, area.position.y + 8), Loc.t("Platz an Bord: %d/%d") % [run.ship.crew.size(), RunState.MAX_CREW], HudStyle.COLOR_SHIELD)
	var y := area.position.y + 12.0
	if goods.crew.is_empty():
		HudStyle.text(self, Vector2(area.position.x, y + 10), Loc.t("Niemand mehr da."), HudStyle.COLOR_DIM)
	var count := maxi(goods.crew.size(), 1)
	var card_w := floorf((area.size.x - (count - 1) * 4.0) / count)
	for i in goods.crew.size():
		var c: Dictionary = goods.crew[i]
		var gender := Species.gender_of(c.species, c.name)
		var look := Species.look_of(c.name)
		var card := Rect2(area.position.x + i * (card_w + 4.0), y, card_w, area.end.y - y)
		_card(card)
		var pic := Rect2(card.position + Vector2(4, 4), Vector2(40, 40))
		draw_rect(pic, Color("#20263A"))
		var crop := CrewArt.square_crop(c.species)
		draw_texture_rect_region(CrewArt.portrait_of(c.species, gender, look), pic, crop)
		var tx := pic.end.x + 5.0
		var tw := card.end.x - tx - 4.0
		HudStyle.text(self, Vector2(tx, card.position.y + 12), c.name, COLOR_TITLE, tw)
		HudStyle.text(self, Vector2(tx, card.position.y + 22), "%s · %s" % [Species.display_name(c.species), Species.gender_label(gender)],
			Species.tint(c.species).lerp(HudStyle.COLOR_TEXT, 0.3), tw)
		HudStyle.text(self, Vector2(tx, card.position.y + 32), Loc.t("%d LP") % int(Species.value(c.species, "hp", 100)), HudStyle.COLOR_DIM, tw)
		var ty := pic.end.y + 9.0
		for t: String in Species.traits(c.species):
			ty += HudStyle.paragraph(self, Vector2(card.position.x + 5, ty), "· " + t, card.size.x - 10, HudStyle.COLOR_TEXT, 9.0)
		_cost_button(Rect2(card.end.x - BTN_W - 4, card.end.y - 19, BTN_W, 16), {"scrap": run.shop_price(Upgrades.crew_price(c.species))}, run.shop_can_hire(i), "hire", i)


# --- Bausteine ---


func _card(rect: Rect2) -> void:
	HudStyle.box(self, rect, HudStyle.COLOR_EDGE, COLOR_CARD)


## Knopf mit Preis (Rohstoffe oder Treibstoff); grün, wenn bezahlbar, sonst grau.
func _cost_button(rect: Rect2, cost: Dictionary, enabled: bool, action: String, arg: int) -> void:
	var color := HudStyle.COLOR_OK if enabled else HudStyle.COLOR_DIM
	HudStyle.box(self, rect, color, Color("#161B2B"))
	var fuel := int(cost.get("fuel", 0))
	var value := "%d" % (fuel if fuel > 0 else int(cost.get("scrap", 0)))
	var w := 9.0 + HudStyle.text_width(value)
	var x := rect.position.x + roundf((rect.size.x - w) / 2.0)
	var base := rect.position.y + roundf(rect.size.y / 2.0 + 3.0)
	HudStyle.icon(self, Vector2(x, base - 7.0), "fuel" if fuel > 0 else "scrap", color)
	HudStyle.text(self, Vector2(x + 9.0, base), value, color)
	_hits.append({"rect": rect, "action": action, "arg": arg})


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
	var result := ""
	match action:
		"close":
			Sfx.play("ui_click")
			close()
			return
		"tab":
			Sfx.play("ui_click")
			page = arg
			_say("")
			return
		"info_perk":
			Sfx.play("ui_click")
			_say("%s: %s" % [Upgrades.perk_name(arg), Upgrades.perk_text(arg)])
			return
		"supply":
			result = run.shop_buy_supply(arg)
		"battery":
			result = run.shop_buy_battery()
		"weapon":
			result = run.shop_buy_weapon(arg)
			if result == "" and not run.weapon_room():
				_deny(Loc.t("Kein Platz: erst eine Waffe verkaufen"))
				return
		"sell":
			result = run.shop_sell_weapon(arg)
			if result == "":
				_deny(Loc.t("Die letzte Waffe bleibt an Bord"))
				return
		"perk":
			result = run.shop_buy_perk(arg)
		"hire":
			result = run.shop_hire(arg)
			if result == "" and run.ship.crew.size() >= RunState.MAX_CREW:
				_deny(Loc.t("Kein Platz an Bord"))
				return
	if result == "":
		_deny(Loc.t("Nicht genug Rohstoffe"))
		return
	Sfx.play("reward" if action != "sell" else "ui_click")
	_say(result, HudStyle.COLOR_OK)
	changed.emit()


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
