class_name SoundWaveformView
extends Control

var peaks := PackedFloat32Array()
var tint := Color("#61586a")
var accent := Color(0, 0, 0, 0)
var playhead: float = -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if peaks.is_empty():
		return
	var count := mini(64, peaks.size())
	var step := size.x / count
	var mid := size.y * 0.5
	for index in count:
		var peak := 0.0
		for sample in range(index * peaks.size() / count, (index + 1) * peaks.size() / count):
			peak = maxf(peak, peaks[sample])
		var height := maxf(2.0, sqrt(peak) * size.y * 0.88)
		var opacity := 0.65 if playhead < 0.0 or float(index) / count <= playhead else 0.32
		var width := maxf(1.0, step * 0.55)
		draw_rect(Rect2((index + 0.5) * step - width * 0.5, mid - height * 0.5, width, height), Color(tint, opacity))