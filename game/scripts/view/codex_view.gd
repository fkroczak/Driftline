class_name CodexView
extends Control
## Lexikon im Hauptmenü: Reiter SCHIFFE und SPEZIES, links die Liste, rechts der gewählte Eintrag
## mit Bild, Werten und Beschreibung. Noch nicht entdeckte Einträge zeigen nur einen Schatten
## und einen Hinweis, wie man sie findet.

signal closed

const COLOR_BG := Color("#07080F", 0.95)
const COLOR_TITLE := Color("#FDE6BF")
const COLOR_NAME := Color("#E6EAF0")
const LIST_W := 104.0
const ITEM_H := 16.0
const CREW_SHEET := preload("res://assets/crew/mensch_klein_sheet.png")

var _tab := Codex.KIND_SHIP
var _selected := {Codex.KIND_SHIP: 0, Codex.KIND_SPECIES: 0}
var _hits: Array[Dictionary] = []
var _textures := {}  # Pfad -> Texture2D
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open() -> void:
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _ids() -> Array[String]:
	return Codex.ship_ids() if _tab == Codex.KIND_SHIP else Codex.species_ids()


func _draw() -> void:
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	HudStyle.text(self, Vector2(8, 15), "LEXIKON", COLOR_TITLE, -1, 11)
	var count := Codex.count_known()
	var found := "Entdeckt: %d / %d" % [count.x, count.y]
	HudStyle.text(self, Vector2(70, 14), found, HudStyle.COLOR_DIM)
	# Reiter
	var tabs := [[Codex.KIND_SHIP, "SCHIFFE"], [Codex.KIND_SPECIES, "SPEZIES"]]
	var tx := size.x - 8 - 2 * 62 - 4 - 56
	for t: Array in tabs:
		var r := Rect2(tx, 4, 60, 16)
		var active: bool = _tab == t[0]
		HudStyle.button(self, r, t[1], HudStyle.COLOR_SHIELD if active else HudStyle.COLOR_DIM, active)
		_hits.append({"rect": r, "tab": t[0]})
		tx += 62
	var back := Rect2(size.x - 8 - 54, 4, 54, 16)
	HudStyle.button(self, back, "ZURÜCK", HudStyle.COLOR_TEXT)
	_hits.append({"rect": back, "back": true})
	# Liste
	var ids := _ids()
	var sel: int = clampi(_selected[_tab], 0, ids.size() - 1)
	var y := 26.0
	for i in ids.size():
		var id := ids[i]
		var known := Codex.is_known(_tab, id)
		var r := Rect2(8, y, LIST_W, ITEM_H - 2)
		var color := HudStyle.COLOR_OK if i == sel else (HudStyle.COLOR_EDGE if known else HudStyle.COLOR_OFF)
		HudStyle.box(self, r, color, Color(color, 0.18) if i == sel else HudStyle.COLOR_BG)
		var label := _name(id) if known else "? ? ?"
		HudStyle.text(self, r.position + Vector2(5, 10), label, COLOR_NAME if known else HudStyle.COLOR_DIM, r.size.x - 8)
		_hits.append({"rect": r, "index": i})
		y += ITEM_H
	# Eintrag
	var panel := Rect2(8 + LIST_W + 6, 26, size.x - (8 + LIST_W + 6) - 8, size.y - 26 - 8)
	HudStyle.box(self, panel, HudStyle.COLOR_EDGE)
	if ids.is_empty():
		return
	var id := ids[sel]
	if _tab == Codex.KIND_SHIP:
		_draw_ship(panel, id, Codex.is_known(_tab, id))
	else:
		_draw_species(panel, id, Codex.is_known(_tab, id))


func _name(id: String) -> String:
	return str(Codex.ship(id).get("name", id)) if _tab == Codex.KIND_SHIP else Species.display_name(id)


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _textures[path]


## Bild oben im Eintrag: ganzzahlig skaliert (Pixel bleiben scharf), höchstens `max_h` hoch.
func _draw_picture(tex: Texture2D, area: Rect2, tint: Color) -> void:
	if tex == null:
		return
	var tex_size := tex.get_size()
	var s := floorf(minf(area.size.x / tex_size.x, area.size.y / tex_size.y))
	var draw_size: Vector2
	if s >= 1.0:
		draw_size = tex_size * s
	else:
		# Größer als der Platz: halbe Größe (bleibt bei 5-facher Anzeige noch sauber)
		draw_size = tex_size * 0.5
	var pos := (area.position + (area.size - draw_size) / 2.0).floor()
	draw_texture_rect(tex, Rect2(pos, draw_size), false, tint)


func _draw_ship(panel: Rect2, id: String, known: bool) -> void:
	var d := Codex.ship(id)
	var x := panel.position.x + 8
	var w := panel.size.x - 16
	var pic := Rect2(panel.position + Vector2(4, 4), Vector2(panel.size.x - 8, 82))
	var tint := Color(str(d.get("tint", "#ffffff"))) if known else Color(0.05, 0.06, 0.1, 1.0)
	_draw_picture(_texture(str(d.get("sprite", ""))), pic, tint)
	var y := pic.end.y + 10
	if not known:
		HudStyle.text(self, Vector2(x, y), "Noch nicht entdeckt", HudStyle.COLOR_DIM)
		HudStyle.paragraph(self, Vector2(x, y + 12), "Kämpfe gegen dieses Schiff, um es ins Lexikon aufzunehmen.", w, HudStyle.COLOR_DIM)
		return
	HudStyle.text(self, Vector2(x, y), str(d.get("name", id)), COLOR_TITLE, -1, 11)
	var role := str(d.get("role", ""))
	if role != "":
		HudStyle.text(self, Vector2(panel.end.x - 8 - HudStyle.text_width(role), y), role, HudStyle.COLOR_GOLD)
	y += 11
	var weapons: Array[String] = []
	for wid: String in d.get("weapons", []):
		weapons.append(Weapon.create(wid).display_name if Weapon.known(wid) else wid)
	var stats := "Hülle %d · Reaktor %d · Räume %d" % [int(d.get("hull", 0)), int(d.get("reactor", 0)), (d.get("rooms", []) as Array).size()]
	HudStyle.text(self, Vector2(x, y), stats, HudStyle.COLOR_SHIELD, w)
	y += 10
	HudStyle.text(self, Vector2(x, y), "Waffen: " + ", ".join(weapons), HudStyle.COLOR_FUEL, w)
	y += 12
	HudStyle.paragraph(self, Vector2(x, y), str(d.get("description", "")), w, HudStyle.COLOR_TEXT)


func _draw_species(panel: Rect2, id: String, known: bool) -> void:
	var d := Species.data(id)
	var x := panel.position.x + 8
	# Figur dreifach vergrößert, langsam im Kreis drehend (unten, rechts, oben, links)
	var frame: int = [0, 3, 1, 2][int(_time * 1.5) % 4]
	var pic := Rect2(panel.position + Vector2(8, 8), Vector2(48, 48))
	draw_rect(pic, Color("#20263A"))
	var tint := Species.tint(id) if known else Color(0.05, 0.06, 0.1, 1.0)
	draw_texture_rect_region(CREW_SHEET, Rect2(pic.position, Vector2(48, 48)), Rect2(frame * 16, 0, 16, 16), tint)
	var tx := pic.end.x + 8
	var tw := panel.end.x - 8 - tx
	var y := pic.position.y + 10
	if not known:
		HudStyle.text(self, Vector2(tx, y), "Noch nicht entdeckt", HudStyle.COLOR_DIM)
		HudStyle.paragraph(self, Vector2(tx, y + 12), "Nimm jemanden dieser Spezies in deine Crew auf, zum Beispiel über Ereignisse oder Händler.", tw, HudStyle.COLOR_DIM)
		return
	HudStyle.text(self, Vector2(tx, y), Species.display_name(id), COLOR_TITLE, -1, 11)
	y += 12
	var stats := [
		["LP", str(int(d.get("hp", 100)))],
		["Tempo", "%d %%" % roundi(float(d.get("speed", 1.0)) * 100.0)],
		["Reparatur", "%d %%" % roundi(float(d.get("repair", 1.0)) * 100.0)],
	]
	var sx := tx
	for s: Array in stats:
		HudStyle.text(self, Vector2(sx, y), s[0], HudStyle.COLOR_DIM)
		HudStyle.text(self, Vector2(sx + HudStyle.text_width(s[0]) + 3, y), s[1], HudStyle.COLOR_OK)
		sx += HudStyle.text_width(s[0] + s[1]) + 14
	y += 10
	var extras: Array[String] = []
	if not d.get("breathes", true):
		extras.append("atmet nicht")
	if float(d.get("fire", 1.0)) <= 0.0:
		extras.append("feuerfest")
	for b: String in d.get("bonus", []):
		extras.append("+15 % " + SystemInfo.display_name(b))
	if not extras.is_empty():
		HudStyle.text(self, Vector2(tx, y), " · ".join(extras), HudStyle.COLOR_SHIELD, tw)
	y = pic.end.y + 12
	var w := panel.size.x - 16
	for t: String in Species.traits(id):
		HudStyle.text(self, Vector2(x, y), "· " + t, HudStyle.COLOR_GOLD, w)
		y += 10
	y += 4
	HudStyle.paragraph(self, Vector2(x, y), str(d.get("lore", "")), w, HudStyle.COLOR_TEXT)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	for hit in _hits:
		if not (hit.rect as Rect2).grow(1).has_point(event.position):
			continue
		Sfx.play("ui_click")
		if hit.has("back"):
			visible = false
			closed.emit()
		elif hit.has("tab"):
			_tab = hit.tab
		elif hit.has("index"):
			_selected[_tab] = hit.index
		queue_redraw()
		return


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()
