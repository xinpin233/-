class_name SoundGameTheme
extends RefCounted

const INK := Color("151513")
const PAPER := Color("e9e5d9")
const MUTED := Color("64635d")
const GOLD := Color("dc1c22")
const TEAL := Color("476653")
const RED := Color("dc1c22")

static func button_style(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = INK
	box.set_border_width_all(1)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	box.shadow_color = INK
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 4)
	return box

static func create() -> Theme:
	var skin := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	skin.default_font = font
	skin.default_font_size = 14
	skin.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := PAPER
		if state == "hover": fill = Color.WHITE
		if state == "pressed": fill = Color("c9c4b8")
		var box := button_style(fill)
		if state == "disabled": box.border_color = Color("b4b0a6")
		skin.set_stylebox(state, "Button", box)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = RED
	focus.set_border_width_all(2)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	skin.set_stylebox("focus", "Button", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		skin.set_color(state, "Button", INK)
	skin.set_color("font_disabled_color", "Button", Color("aaa69c"))
	return skin
