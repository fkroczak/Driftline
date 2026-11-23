class_name CrewPanel
extends Control
## Crew-Liste links (wie im Mockup): je Person ein Kasten mit Porträt, Name und Lebensbalken.
## Der Captain trägt einen goldenen Stern, die Farbe des Porträts zeigt die Spezies.
## Oben rechts im Kasten das Symbol der Tätigkeit (löschen, flicken, reparieren, geheilt werden).
## Antippen wählt die Person aus. Ist `expanded` gesetzt, erscheint direkt unter ihrem Eintrag
## ein Infokasten (Spezies, LP, Erfahrung je System); die Einträge darunter rücken nach unten.
## Reicht der Platz bis `max_height` nicht, liegt der Kasten über den folgenden Einträgen,
## aber nie über dem Schiff.
## Auf schmalen Bildschirmen (`compact`) nur Porträts ohne Namen und ohne Infokasten.

signal crew_selected(member: CrewMember)

const PORTRAITS := {
	"mensch": preload("res://assets/crew/mensch_gross_unten.png"),
}
const CROP := Rect2(10, 10, 20, 20)
const WIDE := Vector2(54, 18)
const NARROW := Vector2(24, 26)
const GAP := 2.0
const COLOR_SELECTED := Color("#5DCAA5")
const INFO_LINE := 8.0
## Kurze Namen, damit Name und Erfahrungspunkte in die schmale Spalte passen.
const SKILLS := [
	["cockpit", "Cockpit"], ["waffen", "Waffen"], ["schilde", "Schilde"],
	["antrieb", "Antrieb"], ["sensoren", "Sens."], [CrewMember.REPAIR_SKILL, "Repar."],
]

var state: ShipState
var selected: CrewMember
var compact := false
## Person, deren Infokasten unter dem Eintrag steht (null = keiner).
var expanded: CrewMember
## Platz nach unten (lokal), den die Liste samt Infokasten höchstens nutzen darf.
var max_height := 1000.0


func setup(p_state: ShipState) -> void:
	state = p_state
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resize()


func slot() -> Vector2:
	var s := NARROW if compact else WIDE
	if state and state.crew.size() > 6:
		s.y = 16.0 if not compact else 17.0  # volle Crew (8) passt noch neben das Schiff
	return s


func info_height() -> float:
	return 4.0 + INFO_LINE * (1 + SKILLS.size()) + 2.0


func _expanded_index() -> int:
	return -1 if compact or expanded == null else state.crew.find(expanded)


## Schiebt der Infokasten die folgenden Einträge nach unten? (Sonst liegt er darüber.)
func _pushes() -> bool:
	return maxi(state.crew.size(), 1) * (slot().y + GAP) + info_height() + GAP <= max_height


func entry_y(i: int) -> float:
	var y := i * (slot().y + GAP)
	var e := _expanded_index()
	if e >= 0 and i > e and _pushes():
		y += info_height() + GAP
	return y


func info_rect() -> Rect2:
	var e := _expanded_index()
	if e < 0:
		return Rect2()
	var y := entry_y(e) + slot().y + GAP
	if y + info_height() > max_height:
		y = entry_y(e) - GAP - info_height()  # ganz unten: über den Eintrag
	return Rect2(0, maxf(y, 0.0), slot().x, info_height())


func _wanted_size() -> Vector2:
	var h := maxi(state.crew.size(), 1) * (slot().y + GAP)
	if _expanded_index() >= 0:
		h = maxf(h if not _pushes() else h + info_height() + GAP, info_rect().end.y)
	return Vector2(slot().x, h)


func _resize() -> void:
	custom_minimum_size = _wanted_size()
	size = custom_minimum_size


func _process(_delta: float) -> void:
	if state and size != _wanted_size():
		_resize()
	queue_redraw()


func _draw() -> void:
	if not state:
		return
	var s := slot()
	for i in state.crew.size():
		var member := state.crew[i]
		var rect := Rect2(Vector2(0, entry_y(i)), s)
		HudStyle.box(self, rect, COLOR_SELECTED if member == selected else HudStyle.COLOR_EDGE)
		var portrait: Texture2D = PORTRAITS.get(member.species, PORTRAITS["mensch"])
		var tint := Species.tint(member.species)
		var ratio := member.hp / member.max_hp
		var hp_color := HudStyle.COLOR_OK if ratio > 0.6 else (HudStyle.COLOR_WARN if ratio > 0.3 else HudStyle.COLOR_BAD)
		if compact:
			draw_texture_rect_region(portrait, Rect2(rect.position + Vector2(2, 1), CROP.size), CROP, tint)
			var hp_bar := Rect2(rect.position + Vector2(2, s.y - 4), Vector2(s.x - 4, 2))
			draw_rect(hp_bar, HudStyle.COLOR_OFF)
			draw_rect(Rect2(hp_bar.position, Vector2(roundf(hp_bar.size.x * ratio), 2)), hp_color)
		else:
			var head := Rect2(10, 8, 20, 14)
			draw_texture_rect_region(portrait, Rect2(rect.position + Vector2(1, 2), Vector2(14, 10)), head, tint)
			var first := member.display_name.split(" ")[0]
			HudStyle.text(self, rect.position + Vector2(17, 9), first, HudStyle.COLOR_TEXT, s.x - 19)
			var hp_bar := Rect2(rect.position + Vector2(17, 12), Vector2(s.x - 20, 3))
			draw_rect(hp_bar, HudStyle.COLOR_OFF)
			draw_rect(Rect2(hp_bar.position, Vector2(roundf(hp_bar.size.x * ratio), 3)), hp_color)
		if member.is_captain():
			HudStyle.star(self, rect.position + Vector2(1, s.y - 7) if not compact else rect.position + Vector2(s.x - 7, s.y - 10))
		ActivityIcons.draw(self, rect.position + Vector2(s.x - 8, 1), member.activity)
	if _expanded_index() >= 0:
		_draw_info(info_rect())


## Infokasten: Spezies und LP, darunter die Erfahrung je System (5 Punkte = Meister).
func _draw_info(rect: Rect2) -> void:
	var m := expanded
	HudStyle.box(self, rect, COLOR_SELECTED)
	# Steg zum Eintrag (meist darüber, ganz unten in der Liste darunter)
	var below := rect.position.y >= entry_y(_expanded_index())
	var stem_y := rect.position.y - GAP if below else rect.end.y
	draw_rect(Rect2(rect.size.x / 2.0 - 3.0, stem_y, 6, GAP), COLOR_SELECTED)
	var y := rect.position.y + 2.0 + INFO_LINE
	var ratio := m.hp / m.max_hp
	var hp_color := HudStyle.COLOR_OK if ratio > 0.6 else (HudStyle.COLOR_WARN if ratio > 0.3 else HudStyle.COLOR_BAD)
	var hp := str(roundi(m.hp))
	var hp_w := HudStyle.text_width(hp)
	HudStyle.text(self, Vector2(3, y), Species.display_name(m.species), Species.tint(m.species).lerp(HudStyle.COLOR_TEXT, 0.3), rect.size.x - hp_w - 8)
	HudStyle.text(self, Vector2(rect.size.x - hp_w - 3, y), hp, hp_color)
	y += 2.0
	draw_line(Vector2(3, y), Vector2(rect.size.x - 3, y), Color(HudStyle.COLOR_EDGE, 0.6))
	var dots_x := rect.size.x - 3.0 - (CrewMember.MAX_EXPERIENCE * 3.0 - 1.0)
	for skill: Array in SKILLS:
		y += INFO_LINE
		var lvl := m.level(skill[0])
		HudStyle.text(self, Vector2(3, y), skill[1], HudStyle.COLOR_TEXT if lvl > 0 else HudStyle.COLOR_DIM, dots_x - 4)
		for dot in int(CrewMember.MAX_EXPERIENCE):
			draw_rect(Rect2(Vector2(dots_x + dot * 3, y - 4), Vector2(2, 2)), HudStyle.COLOR_GOLD if dot < lvl else HudStyle.COLOR_OFF)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if info_rect().has_point(event.position):
			crew_selected.emit(expanded)  # Kasten antippen = wie Eintrag antippen
			accept_event()
			return
		for i in state.crew.size():
			if event.position.y >= entry_y(i) and event.position.y < entry_y(i) + slot().y + GAP:
				crew_selected.emit(state.crew[i])
				accept_event()
				return
