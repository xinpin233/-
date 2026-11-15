class_name SoundAudioStrip
extends PanelContainer

signal preview_requested(slot: int)
signal move_requested(source: int, target: int)
signal drag_started(strip: SoundAudioStrip, global_position: Vector2)
signal drag_released(strip: SoundAudioStrip, global_position: Vector2)

var slot: int = 0
var clip: AudioClipData
var locked: bool = false
var waveform: SoundWaveformView
var preview_button: Button
var up_button: Button
var down_button: Button
var _slot_label: Label
var _time_label: Label
var _title_label: Label
var _sub_label: Label
var _owner_id: int = 0
var _count: int = 0
var _selected: bool = false
var _lifted: bool = false
var _press_position := Vector2.ZERO
var _drag_armed := false
var _drag_started := false

func setup(data: AudioClipData, index: int, count: int, owner_id: int = 0) -> void:
	clip = data
	slot = index
	_count = count
	_owner_id = owner_id
	custom_minimum_size = Vector2(292, 84)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	focus_mode = Control.FOCUS_ALL
	var panel := StyleBoxFlat.new()
	panel.bg_color = clip.tint
	panel.border_color = clip.tint.lightened(0.08)
	panel.border_width_top = 2
	panel.border_width_bottom = 3
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	add_theme_stylebox_override("panel", panel)

	var surface := Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(surface)

	var top_bar := ColorRect.new()
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(0, 23)
	top_bar.color = Color("19365b", 0.94)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(top_bar)

	waveform = SoundWaveformView.new()
	waveform.position = Vector2(4, 25)
	waveform.size = Vector2(0, 32)
	waveform.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waveform.peaks = clip.waveform
	waveform.tint = Color("61586a")
	waveform.accent = clip.tint
	surface.add_child(waveform)

	_slot_label = _label("%02d" % (slot + 1), 12, SoundGameTheme.PAPER)
	_slot_label.position = Vector2(7, 4)
	_slot_label.size = Vector2(28, 18)
	surface.add_child(_slot_label)
	_title_label = _label(clip.title, 13, SoundGameTheme.PAPER)
	_title_label.position = Vector2(32, 3)
	_title_label.size = Vector2(170, 19)
	surface.add_child(_title_label)
	_time_label = _label("00:00:00:00", 11, SoundGameTheme.MUTED)
	_time_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_time_label.position = Vector2(-84, 4)
	_time_label.size = Vector2(77, 18)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	surface.add_child(_time_label)
	_sub_label = _label("音频 · " + clip.description, 11, Color("deebff", 0.9))
	_sub_label.position = Vector2(8, 60)
	_sub_label.size = Vector2(0, 18)
	surface.add_child(_sub_label)
	surface.resized.connect(func() -> void: _layout_surface(surface, top_bar, waveform, _sub_label))
	call_deferred("_layout_surface", surface, top_bar, waveform, _sub_label)

	# Keep the audition control in the scene tree for keyboard/accessibility code,
	# but let the block itself be the visible interaction surface.
	preview_button = _button("试听", "点击音频素材试听")
	preview_button.visible = false
	preview_button.pressed.connect(func() -> void: preview_requested.emit(slot))
	surface.add_child(preview_button)
	up_button = _button("←", "向前移动一个位置")
	up_button.visible = false
	up_button.pressed.connect(func() -> void: move_requested.emit(slot, slot - 1))
	surface.add_child(up_button)
	down_button = _button("→", "向后移动一个位置")
	down_button.visible = false
	down_button.pressed.connect(func() -> void: move_requested.emit(slot, slot + 1))
	surface.add_child(down_button)
	for item in [top_bar, _slot_label, _title_label, _time_label, _sub_label]:
		item.hide()
	set_slot_duration(2.5)
	set_locked(false)

func _layout_surface(surface: Control, top_bar: ColorRect, wave: SoundWaveformView, sub_label: Label) -> void:
	top_bar.size = Vector2(surface.size.x, 23)
	wave.position = Vector2(8, 10)
	wave.size = Vector2(maxf(1.0, surface.size.x - 16.0), maxf(1.0, surface.size.y - 20.0))
	sub_label.position = Vector2(8, maxf(25.0, surface.size.y - 22.0))
	sub_label.size = Vector2(maxf(1.0, surface.size.x - 16.0), 18)

func _panel_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = clip.tint.lightened(0.08) if selected else clip.tint
	box.border_color = Color("c8323a") if selected else clip.tint
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(0)
	box.shadow_color = Color(0, 0, 0, 0.42) if selected else Color(0, 0, 0, 0.20)
	box.shadow_size = 0
	if _lifted:
		box.shadow_color = Color("3b3540")
		box.shadow_size = 0
		box.shadow_offset = Vector2(0, 8)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

func set_selected(value: bool) -> void:
	_selected = value
	add_theme_stylebox_override("panel", _panel_style(value))

func set_slot_duration(duration: float) -> void:
	if _time_label:
		_time_label.text = "%04.1f s" % duration

func set_lifted(value: bool) -> void:
	_lifted = value
	set_selected(value)

func set_slot_index(index: int, count: int) -> void:
	slot = index
	_count = count
	if _slot_label:
		_slot_label.text = "%02d" % (slot + 1)
	set_locked(locked)

func drag_grab_position(fallback_global_position: Vector2) -> Vector2:
	if _drag_started:
		return _press_position
	return get_global_transform().affine_inverse() * fallback_global_position

func end_pointer_gesture() -> void:
	_drag_armed = false
	_drag_started = false

func set_locked(value: bool) -> void:
	locked = value
	if value:
		end_pointer_gesture()
	if preview_button:
		preview_button.disabled = value
		up_button.disabled = value or slot == 0
		down_button.disabled = value or slot == _count - 1
	mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_DRAG

func set_progress(value: float, active: bool) -> void:
	if waveform:
		waveform.playhead = value if active else -1.0
		waveform.queue_redraw()
	if _slot_label:
		_slot_label.add_theme_color_override("font_color", clip.tint if active else SoundGameTheme.PAPER)

func set_previewing(value: bool) -> void:
	if _title_label:
		_title_label.text = ("▶ " if value else "") + clip.title

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
			_drag_armed = true
			_drag_started = false
			accept_event()
		elif _drag_armed:
			_drag_armed = false
			if _drag_started:
				drag_released.emit(self, event.global_position)
			else:
				preview_requested.emit(slot)
			accept_event()
	elif event is InputEventMouseMotion and _drag_armed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if event.position.distance_to(_press_position) >= 8.0:
			_drag_armed = false
			_drag_started = true
			drag_started.emit(self, event.global_position)
			accept_event()

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
	button.focus_mode = Control.FOCUS_ALL
	return button
