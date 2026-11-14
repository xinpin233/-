class_name SoundAudioTimeline
extends Control
## Owns drag presentation; the controller still owns the committed sound order.

signal preview_requested(slot: int)
signal move_requested(source: int, target: int)

const TRACK_INSET := Vector2(0, 2)
const CLIP_HEIGHT := 120.0
const CLIP_GAP := 9.0
const REFLOW_TIME := 0.16
const LAND_TIME := 0.19
const LIFT_HEIGHT := 10.0

var strips: Array[SoundAudioStrip] = []
var _slot_duration := 2.5
var _track_duration := 5.0
var _clip_width := 292.0
var _track: Control
var _track_host: Control
var _drop_slot: Panel
var _drop_marker: ColorRect
var _playhead: ColorRect
var _playhead_elapsed := 0.0
var _ruler: Control
var _drag_layer: CanvasLayer
var _drag_overlay: Control
var _drag_source := -1
var _drag_target := -1
var _drag_strip: SoundAudioStrip
var _drag_ghost: SoundAudioStrip
var _drag_target_position := Vector2.ZERO
var _drag_pointer_offset := Vector2.ZERO
var _drop_valid := false
var _settling := false
var _committing_drop := false
var _lift_amount := 0.0
var _lift_tween: Tween
var _landing_tween: Tween
var _reflow_tweens: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 152)
	add_theme_constant_override("separation", 7)
	_ruler = Control.new()
	_ruler.custom_minimum_size.y = 18
	_ruler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ruler)
	_track_host = Control.new()
	_track_host.custom_minimum_size.y = 124
	_track_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_host.clip_contents = false
	_track_host.position = Vector2(0, 25)
	_track_host.size = Vector2(size.x, 124)
	add_child(_track_host)
	var rail := Panel.new()
	rail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail_style := StyleBoxFlat.new()
	rail_style.bg_color = Color.TRANSPARENT
	rail_style.border_color = Color("2c4651")
	rail_style.set_border_width_all(0)
	rail_style.set_corner_radius_all(4)
	rail.add_theme_stylebox_override("panel", rail_style)
	_track_host.add_child(rail)
	_drop_slot = Panel.new()
	_drop_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color("dc1c22", 0.08)
	slot_style.border_color = SoundGameTheme.RED
	slot_style.set_border_width_all(1)
	slot_style.set_corner_radius_all(0)
	_drop_slot.add_theme_stylebox_override("panel", slot_style)
	_drop_slot.hide()
	_track_host.add_child(_drop_slot)
	# A plain Control lets neighbouring clips slide without a Container snapping them back.
	_track = Control.new()
	_track.position = TRACK_INSET
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_host.add_child(_track)
	_drop_marker = ColorRect.new()
	_drop_marker.color = SoundGameTheme.GOLD
	_drop_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_marker.hide()
	_track_host.add_child(_drop_marker)
	_playhead = ColorRect.new()
	_playhead.color = SoundGameTheme.GOLD
	_playhead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playhead.z_index = 4
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([Vector2(-7, -6), Vector2(9, -6), Vector2(1, 3)])
	cap.color = SoundGameTheme.RED
	_playhead.add_child(cap)
	_track_host.add_child(_playhead)
	# The lifted clip is outside the clipped rail, so its edges and shadow stay visible.
	_drag_layer = CanvasLayer.new()
	_drag_layer.layer = 20
	add_child(_drag_layer)
	_drag_overlay = Control.new()
	_drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.add_child(_drag_overlay)
	resized.connect(_position_overlays)

func rebuild(level: SoundLevelData, order: Array[String]) -> void:
	if not _committing_drop:
		_clear_drag()
	_slot_duration = level.slot_duration
	_track_duration = level.slot_duration * maxf(1, order.size())
	var existing: Dictionary = {}
	for strip in strips:
		existing[strip.clip.id] = strip
	var updated: Array[SoundAudioStrip] = []
	for index in order.size():
		var data := level.find_clip(order[index])
		var strip: SoundAudioStrip = existing.get(order[index])
		if strip != null and strip.clip != data:
			_stop_reflow(strip)
			strip.queue_free()
			strip = null
		if strip == null:
			strip = SoundAudioStrip.new()
			strip.setup(data, index, order.size(), get_instance_id())
			strip.preview_requested.connect(func(slot: int) -> void: preview_requested.emit(slot))
			strip.move_requested.connect(func(source: int, target: int) -> void: move_requested.emit(source, target))
			strip.drag_started.connect(_begin_drag)
			strip.drag_released.connect(_release_drag)
			_track.add_child(strip)
		strip.set_slot_index(index, order.size())
		strip.set_slot_duration(_slot_duration)
		updated.append(strip)
		existing.erase(order[index])
	for old_strip: SoundAudioStrip in existing.values():
		_stop_reflow(old_strip)
		old_strip.queue_free()
	strips = updated
	_build_ruler(order.size())
	_playhead.hide()
	_position_overlays()

func _build_ruler(_count: int) -> void:
	for child in _ruler.get_children():
		_ruler.remove_child(child)
		child.queue_free()
	var seconds := ceili(_track_duration)
	for index in seconds + 1:
		var tick := Label.new()
		tick.text = "│00:%02d" % index
		tick.add_theme_font_size_override("font_size", 10)
		tick.add_theme_color_override("font_color", SoundGameTheme.MUTED)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ruler.add_child(tick)

func set_locked(value: bool) -> void:
	if value:
		_clear_drag()
	for strip in strips:
		strip.set_locked(value)

func update_playhead(elapsed: float, active_slot: int) -> void:
	_playhead_elapsed = elapsed
	for strip in strips:
		strip.set_progress(clampf((elapsed - strip.slot * _slot_duration) / _slot_duration, 0.0, 1.0), strip.slot == active_slot)
	_layout_playhead()

func _layout_playhead() -> void:
	_playhead.visible = true
	var usable_width := maxf(0.0, _track_host.size.x - TRACK_INSET.x * 2)
	_playhead.position = Vector2(TRACK_INSET.x + usable_width * clampf(_playhead_elapsed / _track_duration, 0.0, 1.0), TRACK_INSET.y)
	_playhead.size = Vector2(2, CLIP_HEIGHT + 18)
	_playhead.position.y = -14

func set_preview(slot: int) -> void:
	for strip in strips:
		strip.set_previewing(strip.slot == slot)

func _begin_drag(strip: SoundAudioStrip, global_position: Vector2) -> void:
	if strip.locked or _drag_source >= 0:
		return
	# Finish a previous landing before accepting a rapid second grab.
	var grip := strip.drag_grab_position(global_position)
	_clear_drag()
	_drag_source = strip.slot
	_drag_target = strip.slot
	_drag_strip = strip
	_drag_pointer_offset = grip
	strip.end_pointer_gesture()
	_drag_ghost = SoundAudioStrip.new()
	_drag_ghost.setup(strip.clip, strip.slot, strips.size(), get_instance_id())
	_drag_ghost.set_slot_duration(_slot_duration)
	_drag_ghost.set_locked(true)
	_drag_ghost.set_lifted(true)
	_drag_ghost.custom_minimum_size = strip.size
	_drag_ghost.size = strip.size
	_drag_ghost.pivot_offset = _drag_pointer_offset
	_disable_pointer_input(_drag_ghost)
	_drag_overlay.add_child(_drag_ghost)
	strip.modulate.a = 0.0
	_drop_slot.show()
	_lift_amount = 0.0
	_lift_tween = create_tween()
	_lift_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lift_tween.tween_property(self, "_lift_amount", 1.0, 0.11)
	_update_drag(global_position)
	_layout_strips(false)

func _process(_delta: float) -> void:
	if _drag_source >= 0:
		_render_drag()

func _input(event: InputEvent) -> void:
	if _drag_source < 0:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_drag(event.global_position)
		else:
			cancel_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(event.global_position)
		get_viewport().set_input_as_handled()

func _release_drag(strip: SoundAudioStrip, global_position: Vector2) -> void:
	if _drag_source >= 0 and strip == _drag_strip:
		_finish_drag(global_position)

func _update_drag(global_position: Vector2) -> void:
	if _drag_source < 0 or not is_instance_valid(_drag_ghost):
		return
	var local_pointer: Vector2 = _track_host.get_global_transform().affine_inverse() * global_position
	var overlay_pointer := _overlay_point(global_position)
	_drag_target_position = overlay_pointer - _drag_pointer_offset
	_drop_valid = Rect2(Vector2(-48, -90), _track_host.size + Vector2(96, 180)).has_point(local_pointer)
	var next_target := _drag_source
	if _drop_valid:
		var center_x := local_pointer.x - _drag_pointer_offset.x + _clip_width * 0.5
		next_target = _target_slot(center_x)
	if next_target != _drag_target:
		_drag_target = next_target
		_layout_strips(true)
	_position_drop_marker(_drag_target)
	_drop_marker.visible = _drop_valid
	_drop_slot.modulate.a = 1.0 if _drop_valid else 0.35
	_drag_ghost.modulate.a = 1.0 if _drop_valid else 0.72
	_render_drag()

func _render_drag() -> void:
	if not is_instance_valid(_drag_ghost):
		return
	# Keep the original grip point under the pointer; only the lift eases in.
	_drag_ghost.position = _drag_target_position + Vector2(0, -LIFT_HEIGHT * _lift_amount)
	_drag_ghost.scale = Vector2.ONE * lerpf(1.0, 1.025, _lift_amount)
	_drag_ghost.rotation = deg_to_rad(-1.5) * _lift_amount

func _target_slot(center_x: float) -> int:
	var stride := _clip_width + CLIP_GAP
	var relative_center := center_x - TRACK_INSET.x - _clip_width * 0.5
	var candidate := clampi(roundi(relative_center / stride), 0, strips.size() - 1)
	# A small dead band keeps a clip from shuffling back and forth on a boundary.
	if candidate != _drag_target and absi(candidate - _drag_target) == 1:
		var boundary := (float(candidate + _drag_target) * 0.5) * stride
		if absf(relative_center - boundary) < minf(12.0, _clip_width * 0.04):
			return _drag_target
	return candidate

func _finish_drag(global_position: Vector2) -> void:
	if _drag_source < 0:
		return
	_update_drag(global_position)
	_land_drag(_drag_target if _drop_valid else _drag_source)

func cancel_drag(animated: bool = true) -> void:
	if _drag_source < 0:
		return
	if animated:
		_land_drag(_drag_source)
	else:
		_clear_drag()

func is_dragging() -> bool:
	return _drag_source >= 0

func _land_drag(target: int) -> void:
	var source := _drag_source
	_drag_source = -1
	_settling = true
	if _lift_tween != null:
		_lift_tween.kill()
	if target != source:
		_committing_drop = true
		# These are final array indices, including a move to the very last slot.
		move_requested.emit(source, target)
		_committing_drop = false
	if not is_instance_valid(_drag_strip) or not is_instance_valid(_drag_ghost):
		_clear_drag()
		return
	# If a controller declined the move, land at the actual unchanged slot.
	_drag_target = _drag_strip.slot
	_drag_ghost.set_slot_index(_drag_target, strips.size())
	_layout_strips(true)
	_position_drop_marker(_drag_target)
	_drop_marker.hide()
	_drag_ghost.modulate.a = 1.0
	var destination := _overlay_point(_track.get_global_transform() * _slot_position(_drag_target))
	_landing_tween = create_tween().set_parallel(true)
	_landing_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_landing_tween.tween_property(_drag_ghost, "position", destination, LAND_TIME)
	_landing_tween.tween_property(_drag_ghost, "scale", Vector2.ONE, LAND_TIME)
	_landing_tween.tween_property(_drag_ghost, "rotation", 0.0, LAND_TIME)
	_landing_tween.chain().tween_callback(_complete_landing)

func _complete_landing() -> void:
	_landing_tween = null
	_clear_drag()

func _clear_drag() -> void:
	if _lift_tween != null:
		_lift_tween.kill()
		_lift_tween = null
	if _landing_tween != null:
		_landing_tween.kill()
		_landing_tween = null
	if is_instance_valid(_drag_ghost):
		_drag_ghost.hide()
		_drag_ghost.queue_free()
	_drag_ghost = null
	_drag_strip = null
	_drag_source = -1
	_drag_target = -1
	_settling = false
	for strip in strips:
		strip.modulate = Color.WHITE
		strip.end_pointer_gesture()
	if is_instance_valid(_drop_slot):
		_drop_slot.hide()
		_drop_marker.hide()
	if is_instance_valid(_track):
		_layout_strips(false)

func _layout_strips(animated: bool) -> void:
	var visual_order: Array[SoundAudioStrip] = strips.duplicate()
	if _drag_source >= 0:
		visual_order.erase(_drag_strip)
		visual_order.insert(_drag_target, _drag_strip)
	for index in visual_order.size():
		var strip := visual_order[index]
		var destination := _slot_position(index)
		_stop_reflow(strip)
		if animated and strip != _drag_strip and strip.position.distance_to(destination) > 0.5:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(strip, "position", destination, REFLOW_TIME)
			_reflow_tweens[strip.get_instance_id()] = tween
		else:
			strip.position = destination
	if _drag_target >= 0:
		_position_drop_marker(_drag_target)

func _stop_reflow(strip: SoundAudioStrip) -> void:
	var key := strip.get_instance_id()
	var tween: Tween = _reflow_tweens.get(key)
	if tween != null:
		tween.kill()
	_reflow_tweens.erase(key)

func _slot_position(index: int) -> Vector2:
	return Vector2(index * (_clip_width + CLIP_GAP), 0)

func _position_drop_marker(target: int) -> void:
	var slot_position := TRACK_INSET + _slot_position(target)
	_drop_slot.position = slot_position
	_drop_slot.size = Vector2(_clip_width, CLIP_HEIGHT)
	_drop_marker.position = slot_position + Vector2(-3, -3)
	_drop_marker.size = Vector2(2, CLIP_HEIGHT + 6)

func _position_overlays() -> void:
	_ruler.position = Vector2.ZERO
	_ruler.size = Vector2(size.x, 18)
	for index in _ruler.get_child_count():
		var tick: Control = _ruler.get_child(index)
		tick.position = Vector2((size.x - 2) * index / maxf(1, _ruler.get_child_count() - 1), 0)
		if index == _ruler.get_child_count() - 1: tick.position.x -= 36
	_track_host.position = Vector2(0, 25)
	_track_host.size = Vector2(size.x, CLIP_HEIGHT + 4)
	if _drag_source >= 0:
		cancel_drag(false)
	var available := maxf(140.0, _track_host.size.x - TRACK_INSET.x * 2)
	_clip_width = maxf(140.0, (available - maxf(0, strips.size() - 1) * CLIP_GAP) / maxf(1, strips.size()))
	_track.size = Vector2(available, CLIP_HEIGHT)
	_layout_playhead()
	for strip in strips:
		strip.custom_minimum_size = Vector2(_clip_width, CLIP_HEIGHT)
		strip.size = strip.custom_minimum_size
	_layout_strips(_committing_drop)
	if _settling and not _committing_drop:
		_clear_drag()

func _overlay_point(global_position: Vector2) -> Vector2:
	return _drag_overlay.get_global_transform().affine_inverse() * global_position

func _disable_pointer_input(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.tooltip_text = ""
	for child in control.get_children():
		if child is Control:
			_disable_pointer_input(child)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		cancel_drag(false)
