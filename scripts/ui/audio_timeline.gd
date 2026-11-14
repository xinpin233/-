class_name SoundAudioTimeline
extends VBoxContainer
## Displays ordered sound data; emits intent and never mutates game state itself.

signal preview_requested(slot: int)
signal move_requested(source: int, target: int)

var strips: Array[SoundAudioStrip] = []
var _slot_duration: float = 2.5

func rebuild(level: SoundLevelData, order: Array[String]) -> void:
	_slot_duration = level.slot_duration
	for strip in strips:
		remove_child(strip)
		strip.queue_free()
	strips.clear()
	for index in order.size():
		var strip := SoundAudioStrip.new()
		strip.setup(level.find_clip(order[index]), index, order.size())
		strip.set_slot_duration(level.slot_duration)
		strip.preview_requested.connect(func(slot: int) -> void: preview_requested.emit(slot))
		strip.move_requested.connect(func(source: int, target: int) -> void: move_requested.emit(source, target))
		add_child(strip)
		strips.append(strip)

func set_locked(value: bool) -> void:
	for strip in strips:
		strip.set_locked(value)
		if not value:
			strip.preview_button.text = "试听"

func update_playhead(elapsed: float, active_slot: int) -> void:
	for strip in strips:
		strip.set_progress(clampf((elapsed - strip.slot * _slot_duration) / _slot_duration, 0.0, 1.0), strip.slot == active_slot)

func set_preview(slot: int) -> void:
	for strip in strips:
		strip.set_previewing(strip.slot == slot)
