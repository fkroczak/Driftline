class_name ItemIcons
extends RefCounted
## Symbole für Waffen, Perks und Batterie (12 × 12) aus assets/ui/item_icons.png,
## erzeugt von tools/artgen/item_icons.py (ORDER).

const ATLAS := preload("res://assets/ui/item_icons.png")
const CELL := 14
const ORDER := ["pulslaser", "schwerer_laser", "bordkanone", "salvenlaser", "brandkanone", "schwere_kanone",
	"durchschlaglaser", "torpedo", "panzerung", "zielcomputer", "ausweichduesen", "reparaturdrohne",
	"brandschutz", "bergungsgreifer", "treibstoffrecycler", "batterie"]


## Symbol in `rect` zeichnen (ganzzahlig vergrößert, mit Schattenkante).
static func draw(canvas: CanvasItem, rect: Rect2, id: String, tint := Color.WHITE) -> void:
	var i := ORDER.find(id)
	if i < 0:
		return
	var scale := maxf(floorf(minf(rect.size.x, rect.size.y) / 13.0), 1.0)
	var size := Vector2(13, 13) * scale
	canvas.draw_texture_rect_region(ATLAS, Rect2((rect.get_center() - size / 2.0).round(), size), Rect2(i * CELL, 0, 13, 13), tint)
