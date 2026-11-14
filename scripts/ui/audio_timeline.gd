class_name SoundAudioTimeline
extends HBoxContainer
## Displays ordered sound data; emits intent and never mutates game state itself.

signal preview_requested(slot: int)
signal move_requested(source: int, target: int)

var strips: Array[SoundAudioStrip] = []
var _slot_duration: float = 2.5
var _cursor: Control

func _ready() -> void:
	var overlay := Node2D.new()
	add_child(overlay)
	_cursor = preload("res://scripts/ui/timeline_cursor.gd").new()
	overlay.add_child(_cursor)
	resized.connect(_resize_cursor)
	_resize_cursor()

func _resize_cursor() -> void:
	_cursor.size = size
	_cursor.queue_redraw()

func rebuild(level: SoundLevelData, order: Array[String]) -> void:
	_slot_duration = level.slot_duration
	for strip in strips:
		remove_child(strip)
		strip.queue_free()
	strips.clear()
	for index in order.size():
		var strip := SoundAudioStrip.new()
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.setup(level.find_clip(order[index]), index, order.size())
		strip.set_slot_duration(level.slot_duration)
		strip.preview_requested.connect(func(slot: int) -> void: preview_requested.emit(slot))
		strip.move_requested.connect(func(source: int, target: int) -> void: move_requested.emit(source, target))
		add_child(strip)
		strips.append(strip)

func set_locked(value: bool) -> void:
	for strip in strips:
		strip.set_locked(value)


func update_playhead(elapsed: float, active_slot: int) -> void:
	if is_instance_valid(_cursor):
		_cursor.fraction = clampf(elapsed / maxf(_slot_duration * strips.size(), 0.001), 0.0, 1.0)
		_cursor.queue_redraw()

func set_preview_progress(slot: int, fraction: float) -> void:
	if is_instance_valid(_cursor) and not strips.is_empty():
		_cursor.fraction = (slot + fraction) / strips.size()
		_cursor.queue_redraw()

func set_preview(slot: int) -> void:
	for strip in strips:
		strip.set_previewing(strip.slot == slot)
