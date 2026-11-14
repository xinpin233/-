class_name SoundAudioStrip
extends PanelContainer

signal preview_requested(slot: int)
signal move_requested(source: int, target: int)

var slot: int = 0
var clip: AudioClipData
var locked: bool = false
var waveform: SoundWaveformView
var preview_button: Button
var up_button: Button
var down_button: Button
var _slot_label: Label
var _state_label: Label
var _count: int = 0

func setup(data: AudioClipData, index: int, count: int) -> void:
	clip = data
	slot = index
	_count = count
	custom_minimum_size.y = 98
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "拖动音频条到另一个位置，或用右侧箭头调整顺序。"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	_slot_label = _label("%02d" % (slot + 1), 26, SoundGameTheme.MUTED)
	_slot_label.custom_minimum_size.x = 40
	row.add_child(_slot_label)
	var grip := _label("⠿", 30, SoundGameTheme.MUTED)
	row.add_child(grip)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 180
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(_label(clip.title, 23, clip.tint))
	info.add_child(_label(clip.description, 14, SoundGameTheme.MUTED))
	row.add_child(info)
	waveform = SoundWaveformView.new()
	waveform.peaks = clip.waveform
	waveform.tint = clip.tint
	waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	waveform.custom_minimum_size = Vector2(150, 56)
	row.add_child(waveform)
	_state_label = _label("%04.1f — %04.1f s" % [index * 2.5, (index + 1) * 2.5], 15, SoundGameTheme.MUTED)
	_state_label.custom_minimum_size.x = 128
	row.add_child(_state_label)
	preview_button = _button("试听", "试听这段声音")
	preview_button.custom_minimum_size.x = 82
	preview_button.pressed.connect(func() -> void: preview_requested.emit(slot))
	row.add_child(preview_button)
	up_button = _button("↑", "向前移动一个位置")
	up_button.pressed.connect(func() -> void: move_requested.emit(slot, slot - 1))
	row.add_child(up_button)
	down_button = _button("↓", "向后移动一个位置")
	down_button.pressed.connect(func() -> void: move_requested.emit(slot, slot + 1))
	row.add_child(down_button)
	set_locked(false)
	# Children only receive input for actual buttons. The rest remains draggable.
	for child in [row, info]:
		child.mouse_filter = Control.MOUSE_FILTER_PASS

func set_slot_duration(duration: float) -> void:
	_state_label.text = "%04.1f — %04.1f s" % [slot * duration, (slot + 1) * duration]

func set_locked(value: bool) -> void:
	locked = value
	preview_button.disabled = value
	up_button.disabled = value or slot == 0
	down_button.disabled = value or slot == _count - 1
	mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_DRAG

func set_progress(value: float, active: bool) -> void:
	waveform.playhead = value if active else -1.0
	waveform.queue_redraw()
	_slot_label.add_theme_color_override("font_color", clip.tint if active else SoundGameTheme.MUTED)
	if locked:
		preview_button.text = "播放中" if active else "试听"

func set_previewing(value: bool) -> void:
	preview_button.text = "试听中" if value else "试听"

func _get_drag_data(_position: Vector2) -> Variant:
	if locked:
		return null
	var ghost := Label.new()
	ghost.text = "移动：" + clip.title
	ghost.add_theme_color_override("font_color", clip.tint)
	set_drag_preview(ghost)
	return {"kind": "sound_clip", "source": slot, "owner": get_parent().get_instance_id()}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return not locked and data is Dictionary and data.get("kind") == "sound_clip" and data.get("owner") == get_parent().get_instance_id() and data.get("source", -1) != slot

func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		move_requested.emit(int(data["source"]), slot)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE

func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, hint: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(46, 48)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button
