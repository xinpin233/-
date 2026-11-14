extends Control

var fraction := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2

func _draw() -> void:
	var x := clampf(fraction * size.x, 2.0, maxf(2.0, size.x - 2.0))
	draw_line(Vector2(x + 2, 0), Vector2(x + 2, size.y), Color(0, 0, 0, 0.3), 5.0)
	draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#fff4d6"), 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 7, -9), Vector2(x + 7, -9), Vector2(x, 1)]), Color("#fff4d6"))
