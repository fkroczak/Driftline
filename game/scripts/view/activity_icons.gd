class_name ActivityIcons
extends RefCounted
## Kleine 5×5-Symbole für die Tätigkeit einer Figur (über dem Kopf und in der Crew-Leiste).

const ICONS := {
	"reparieren": {"color": Color("#FAC775"), "rows": [".X.X.", ".XXX.", "..X..", "..X..", "..X.."]},
	"flicken": {"color": Color("#C4CAD3"), "rows": ["XXXX.", "XXXX.", "..X..", "..X..", "..X.."]},
	"loeschen": {"color": Color("#85B7EB"), "rows": ["..X..", ".XXX.", "XXXXX", "XXXXX", ".XXX."]},
	"heilen": {"color": Color("#97C459"), "rows": ["..X..", "..X..", "XXXXX", "..X..", "..X.."]},
	"kaempfen": {"color": Color("#E24B4A"), "rows": ["X...X", ".X.X.", "..X..", ".X.X.", "X...X"]},
	"aufbrechen": {"color": Color("#E24B4A"), "rows": ["XX...", "XXX..", ".XXX.", "..X.X", "...XX"]},
}
const NAMES := {
	"reparieren": "repariert", "flicken": "flickt Leck", "loeschen": "löscht", "heilen": "wird geheilt", "kaempfen": "kämpft", "aufbrechen": "bricht Tür auf",  # i18n
}


## Zeichnet das Symbol mit dunklem Rahmen; `pos` ist die obere linke Ecke des Rahmens (7×7).
static func draw(canvas: CanvasItem, pos: Vector2, kind: String) -> void:
	var icon: Dictionary = ICONS.get(kind, {})
	if icon.is_empty():
		return
	canvas.draw_rect(Rect2(pos, Vector2(7, 7)), Color("#0A0B16", 0.8))
	var rows: Array = icon.rows
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "X":
				canvas.draw_rect(Rect2(pos + Vector2(1 + x, 1 + y), Vector2.ONE), icon.color)
