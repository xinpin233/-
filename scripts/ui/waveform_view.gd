class_name SoundWaveformView
extends Control

var peaks := PackedFloat32Array()
var tint := SoundGameTheme.TEAL
var accent := Color(0, 0, 0, 0)
var playhead: float = -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var mid := size.y * 0.5
	draw_line(Vector2(0, mid), Vector2(size.x, mid), Color(tint, 0.15))
	if peaks.is_empty():
		return
	var step := size.x / peaks.size()
	var silhouette := PackedVector2Array()
	for index in peaks.size():
		var height := maxf(2.0, peaks[index] * (size.y - 8.0))
		silhouette.append(Vector2((index + 0.5) * step, mid - height * 0.5))
	for index in range(peaks.size() - 1, -1, -1):
		var height := maxf(2.0, peaks[index] * (size.y - 8.0))
		silhouette.append(Vector2((index + 0.5) * step, mid + height * 0.5))
	draw_colored_polygon(silhouette, Color(tint, 0.34))
	for index in peaks.size():
		var height := maxf(2.0, peaks[index] * (size.y - 8.0))
		var x := (index + 0.5) * step
		var color := tint if playhead < 0 or float(index) / peaks.size() <= playhead else Color(tint, 0.3)
		if accent.a > 0.0 and peaks[index] > 0.58:
			color = accent if playhead < 0 or float(index) / peaks.size() <= playhead else Color(accent, 0.3)
		draw_line(Vector2(x, mid - height * 0.5), Vector2(x, mid + height * 0.5), color, maxf(1.0, step * 0.48), true)
	if playhead >= 0.0:
		var x := clampf(playhead, 0, 1) * size.x
		draw_line(Vector2(x, 0), Vector2(x, size.y), SoundGameTheme.PAPER, 2.0)
