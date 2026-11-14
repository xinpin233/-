class_name SoundGameTheme
extends RefCounted

const INK := Color("101820")
const PAPER := Color("f4e9d6")
const MUTED := Color("a6b4bd")
const GOLD := Color("efbd7b")
const TEAL := Color("8bd0bf")
const RED := Color("ef9988")

static func create() -> Theme:
	var skin := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC"])
	skin.default_font = font
	skin.default_font_size = 18
	skin.set_color("font_color", "Label", PAPER)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("e3dcc3") if state in ["hover", "focus"] else Color("c6bea2")
		if state == "disabled":
			box.bg_color = Color("7f7b69")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.border_color = GOLD if state == "focus" else Color("a39c83")
		box.set_corner_radius_all(6)
		box.shadow_size = 3
		box.shadow_offset = Vector2(0, 3)
		box.shadow_color = Color(0, 0, 0, 0.5)
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		skin.set_stylebox(state, "Button", box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		skin.set_color(state, "Button", Color("292d27"))
	skin.set_color("font_disabled_color", "Button", Color("637684"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("1c211e")
	panel.set_border_width_all(1)
	panel.border_color = Color("53564a")
	panel.set_corner_radius_all(5)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	skin.set_stylebox("panel", "PanelContainer", panel)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("171c18")
	track.set_corner_radius_all(3)
	skin.set_stylebox("background", "ProgressBar", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(3)
	skin.set_stylebox("fill", "ProgressBar", fill)
	return skin
