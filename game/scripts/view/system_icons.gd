class_name SystemIcons
extends RefCounted
## Raumsymbole (12 × 12) aus assets/ui/system_icons.png, erzeugt von tools/artgen/icons.py (ATLAS).

const ATLAS := preload("res://assets/ui/system_icons.png")
const CELL := 14
const ORDER := ["reaktor", "schilde", "waffen", "antrieb", "cockpit", "medbay", "sensoren", "lebenserhaltung", "batterie"]


static func has(system: String) -> bool:
	return ORDER.has(system)


## Symbol mittig auf `center` zeichnen (mit Schattenkante, 13 × 13).
static func draw(canvas: CanvasItem, center: Vector2, system: String, tint := Color.WHITE) -> void:
	var i := ORDER.find(system)
	if i < 0:
		return
	canvas.draw_texture_rect_region(ATLAS, Rect2((center - Vector2(6, 6)).round(), Vector2(13, 13)), Rect2(i * CELL, 0, 13, 13), tint)


static func texture(system: String) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = ATLAS
	t.region = Rect2(maxi(ORDER.find(system), 0) * CELL, 0, 13, 13)
	return t
