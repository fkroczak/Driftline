class_name ResourceBar
extends Control
## Oben Mitte (wie im Mockup): Treibstoff (Kanister) und Rohstoffe (Zahnrad), darunter Sektor und Sprünge.
## Im Jagd-Modus zählt „SPRUNG n/10“ bis zur Jägerfront am Ausgang; danach wird es rot.

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
	HudStyle.icon(self, Vector2(4, 3), "fuel", fuel_color)
	HudStyle.text(self, Vector2(13, 10), "%d" % run.fuel, fuel_color)
	var x := 13.0 + HudStyle.text_width("%d" % run.fuel) + 8.0
	HudStyle.icon(self, Vector2(x, 3), "scrap", HudStyle.COLOR_SCRAP)
	HudStyle.text(self, Vector2(x + 9, 10), "%d" % run.scrap, HudStyle.COLOR_SCRAP)
	var line := "SEKTOR %d · SPRUNG %d" % [run.sector, run.jumps_done()]
	var color := HudStyle.COLOR_DIM
	if run.is_hunt():
		line += "/%d" % RunState.HUNT_JUMPS
		if run.jumps_done() >= RunState.HUNT_JUMPS:
			color = HudStyle.COLOR_BAD
	HudStyle.text(self, Vector2(4, 20), line, color, size.x - 6)
