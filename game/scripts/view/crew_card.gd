class_name CrewCard
extends Control
## Crew-Karte für schmale Bildschirme (Crew-Liste nur mit Porträts): erscheint bei Auswahl über die Liste
## rechts neben dem Eintrag (ein kleiner Pfeil zeigt darauf). Breite Liste: Infokasten in CrewPanel. Zeigt Name, Captain-Stern,
## Spezies mit ihren Stärken und Schwächen, Lebenspunkte und die Erfahrung je System
## (Punkte wie unter dem Porträt, 5 = Meister). Nimmt keine Eingaben an, damit man weiter ins
## Schiff tippen kann.

const W := 140.0
const LINE := 9.0
## Systeme mit Konsole, an denen Crew Erfahrung sammelt, und die Reparatur (lernt man bei der Arbeit).
const SKILLS := ["cockpit", "waffen", "schilde", "antrieb", "sensoren", CrewMember.REPAIR_SKILL]

var member: CrewMember
## Höhe des Pfeils am linken Rand (lokal), zeigt auf den Eintrag in der Crew-Liste.
var pointer_y := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_member(p_member: CrewMember) -> void:
	member = p_member
	visible = member != null
	if member:
		size = Vector2(W, _height())
	queue_redraw()


func _height() -> float:
	return 4.0 + LINE * 2 + 4.0 + Species.traits(member.species).size() * LINE + 4.0 + ceili(SKILLS.size() / 2.0) * LINE + 6.0


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not member:
		return
	HudStyle.box(self, Rect2(Vector2.ZERO, size), HudStyle.COLOR_OK)
	if pointer_y >= 0.0:
		var py := roundf(clampf(pointer_y, 4.0, size.y - 4.0))
		draw_colored_polygon(PackedVector2Array([Vector2(1, py - 3), Vector2(-3, py), Vector2(1, py + 3)]), HudStyle.COLOR_OK)
	var y := 4.0 + 7.0
	var x := 5.0
	if member.is_captain():
		HudStyle.star(self, Vector2(x, y - 6))
		x += 8.0
	HudStyle.text(self, Vector2(x, y), member.display_name, Color("#E6EAF0"), W - x - 4)
	if member.is_captain():
		var cw := HudStyle.text_width("Captain")
		HudStyle.text(self, Vector2(W - cw - 5, y), "Captain", HudStyle.COLOR_GOLD)
	y += LINE
	var hp := "%d/%d LP" % [roundi(member.hp), roundi(member.max_hp)]
	HudStyle.text(self, Vector2(5, y), Species.display_name(member.species), Species.tint(member.species).lerp(HudStyle.COLOR_TEXT, 0.3))
	var ratio := member.hp / member.max_hp
	var hp_color := HudStyle.COLOR_OK if ratio > 0.6 else (HudStyle.COLOR_WARN if ratio > 0.3 else HudStyle.COLOR_BAD)
	HudStyle.text(self, Vector2(W - HudStyle.text_width(hp) - 5, y), hp, hp_color)
	y += 4.0
	draw_line(Vector2(4, y), Vector2(W - 4, y), Color(HudStyle.COLOR_EDGE, 0.6))
	for t: String in Species.traits(member.species):
		y += LINE
		HudStyle.text(self, Vector2(5, y), "· " + t, HudStyle.COLOR_TEXT, W - 8)
	y += 4.0
	draw_line(Vector2(4, y), Vector2(W - 4, y), Color(HudStyle.COLOR_EDGE, 0.6))
	for i in SKILLS.size():
		var system: String = SKILLS[i]
		var col := i % 2
		var row := i / 2
		var p := Vector2(5 + col * 68, y + LINE * (row + 1))
		var lvl := member.level(system)
		HudStyle.text(self, p, "Reparatur" if system == CrewMember.REPAIR_SKILL else SystemInfo.display_name(system), HudStyle.COLOR_TEXT if lvl > 0 else HudStyle.COLOR_DIM, 44)
		for dot in int(CrewMember.MAX_EXPERIENCE):
			draw_rect(Rect2(p + Vector2(45 + dot * 4, -5), Vector2(3, 3)), HudStyle.COLOR_GOLD if dot < lvl else HudStyle.COLOR_OFF)
