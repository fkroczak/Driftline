class_name ResourceBar
extends Control
## Oben Mitte: Treibstoff (Kanister) und Rohstoffe (Zahnrad). Der Sektor steht auf der Sternenkarte.

var run: RunState


func setup(p_run: RunState) -> void:
	run = p_run
	custom_minimum_size = Vector2(92, 24)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not run:
		return
	HudStyle.box(self, Rect2(Vector2.ZERO, size))
	var fuel_color := HudStyle.COLOR_BAD if run.fuel < run.jump_cost() else (HudStyle.COLOR_WARN if run.fuel <= 2 else HudStyle.COLOR_FUEL)
	HudStyle.icon(self, Vector2(5, 8), "fuel", fuel_color)
	HudStyle.text(self, Vector2(14, 15), "%d" % run.fuel, fuel_color)
	var x := 14.0 + HudStyle.text_width("%d" % run.fuel) + 10.0
	HudStyle.icon(self, Vector2(x, 8), "scrap", HudStyle.COLOR_SCRAP)
	HudStyle.text(self, Vector2(x + 9, 15), "%d" % run.scrap, HudStyle.COLOR_SCRAP)
