class_name SoundAudioStrip
extends PanelContainer

signal preview_requested(slot: int)
signal move_requested(source: int, target: int)

var slot: int = 0
var clip: AudioClipData
var locked: bool = false
var _click_pending := false

func setup(data: AudioClipData, index: int, _count: int) -> void:
	clip = data
	slot = index

	custom_minimum_size.y = 90
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "点击试听，拖动调整顺序。"
	focus_mode = Control.FOCUS_ALL
	var panel := StyleBoxFlat.new()
	panel.bg_color = clip.tint
	panel.border_color = clip.tint.lightened(0.08)
	panel.border_width_top = 2
	panel.border_width_bottom = 3
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	add_theme_stylebox_override("panel", panel)
	set_locked(false)

func set_slot_duration(_duration: float) -> void:
	pass

func set_locked(value: bool) -> void:
	locked = value
	mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_DRAG

func set_progress(value: float, active: bool) -> void:
	if active:
		get_parent().set_preview_progress(slot, value)
func set_previewing(value: bool) -> void:
	modulate = Color(1.16, 1.16, 1.08) if value else Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_pending = true
			grab_focus()
		else:
			var audition := _click_pending and Rect2(Vector2.ZERO, size).has_point(event.position)
			_click_pending = false
			if audition:
				preview_requested.emit(slot)

func _get_drag_data(_position: Vector2) -> Variant:
	if locked:
		return null
	_click_pending = false
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

