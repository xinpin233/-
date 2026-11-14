class_name SoundComicFrame
extends Control

const EDGE = Color("#3b3540")
const DARK = Color("#202c39")
const LINE = Color("#53616b")
const GOLD = Color("#e9ae6a")
const RED = Color("#d47065")
const GREEN = Color("#8fc8af")
var stage := 0
var safe_route := false
var first_cue := 0
var progress := 0.0
var start_x := 290.0
var end_x := 364.0
var clip_id := ""
var custom_scene: Node
var clip_duration := 3.0

func configure_clip(clip: AudioClipData, duration: float) -> void:
	clip_id = clip.id
	clip_duration = duration
	show_custom_scene(clip.alarmed_scene if safe_route else clip.calm_scene)

func clear_custom_scene() -> void:
	if is_instance_valid(custom_scene):
		remove_child(custom_scene)
		custom_scene.queue_free()
	custom_scene = null

func show_custom_scene(source: PackedScene) -> void:
	clear_custom_scene()
	if source != null:
		custom_scene = source.instantiate()
		if custom_scene is Node2D:
			custom_scene.scale.y = 375.0 / 825.0
		elif custom_scene is Control:
			custom_scene.scale.y = 375.0 / 825.0
		add_child(custom_scene)

func _process(_delta: float) -> void:
	if is_instance_valid(custom_scene):
		var animation := custom_scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation != null and animation.has_animation("play"):
			animation.play("play")
			animation.seek(progress * clip_duration, true)
			animation.pause()

func shape(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw() -> void:
	if is_instance_valid(custom_scene):
		return
	draw_rect(Rect2(0, 0, 1100, 375), EDGE)
	draw_set_transform(Vector2(0, 20))
	var accent := GOLD
	if stage >= 2:
		accent = GREEN if safe_route else RED
	draw_rect(Rect2(0, 0, 1100, 335), DARK)
	shape([Vector2(0, 335), Vector2(414, 221), Vector2(675, 221), Vector2(1100, 335)], Color("#39444b"))
	shape([Vector2(0, 0), Vector2(414, 62), Vector2(414, 221), Vector2(0, 335)], Color("#293745"))
	shape([Vector2(1100, 0), Vector2(675, 62), Vector2(675, 221), Vector2(1100, 335)], Color("#263542"))
	for i in 8:
		var x := float(i * 175 - 70)
		draw_line(Vector2(x, 335), Vector2(545, 221), LINE, 1.0, true)
	for i in 4:
		var y := 230.0 + float(i * i) * 11
		draw_line(Vector2(0, y), Vector2(1100, y), Color("#3a4852"), 1.0)
	draw_rect(Rect2(414, 62, 261, 160), Color("#18252e"))
	draw_rect(Rect2(476, 80, 139, 142), Color("#131c25"))
	draw_rect(Rect2(488, 91, 115, 81), Color("#756c61").lerp(accent, 0.24))
	for i in 15:
		draw_line(Vector2(490, 93 + i * 5), Vector2(601, 93 + i * 5), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(523, 70, 48, 6), accent)
	draw_rect(Rect2(594, 183, 10, 3), GOLD)
	draw_line(Vector2(547, 81), Vector2(547, 222), LINE, 2.0)
	draw_rect(Rect2(36, 39, 138, 9), GOLD.darkened(0.32))
	draw_rect(Rect2(920, 39, 138, 9), accent.darkened(0.32))
	for i in 48:
		var px := float((i * 151 + 39) % 1080)
		var py := float((i * i * 31 + 13) % 320)
		draw_line(Vector2(px, py), Vector2(px + 8 + i % 11, py), Color(1, 1, 1, 0.045))
	if stage <= 1:
		var pulse := fposmod(progress * 3.0, 1.0)
		var is_gasp := clip_id == "gasp"
		for i in (4 if is_gasp else 2):
			draw_arc(Vector2(609, 125), 22 + i * 13 + pulse * 13, -0.9, 0.9, 22, Color(accent, 0.6 * (1.0 - pulse)), 2.0, true)
	var position_x := lerpf(start_x, end_x, smoothstep(0.1, 0.9, progress))
	var moving := absf(end_x - start_x) > 5.0
	var facing := -1.0 if end_x < start_x else 1.0
	if clip_id == "alarm":
		draw_shutter(accent)
		if safe_route:
			shape([Vector2(24, 68), Vector2(113, 87), Vector2(113, 248), Vector2(24, 297)], GREEN.darkened(0.50))
			draw_line(Vector2(116, 84), Vector2(116, 252), GREEN, 4.0)
	draw_character(Vector2(position_x, 279), facing, moving, safe_route and stage > 0)
	draw_set_transform(Vector2.ZERO)
	for i in 27:
		var x := 12.0 + i * 41
		draw_rect(Rect2(x, 6, 22, 7), Color("#d8cdd9"))
		draw_rect(Rect2(x, 362, 22, 7), Color("#d8cdd9"))
	draw_rect(Rect2(0, 0, 1100, 375), LINE, false, 2.0)

func draw_shutter(accent: Color) -> void:
	var height := 215 * smoothstep(0.0, 0.7, progress)
	draw_rect(Rect2(902, 22, 146, height), Color("#252e37"))
	for i in int(height / 12):
		draw_line(Vector2(903, 22 + i * 12), Vector2(1047, 22 + i * 12), LINE, 2.0)
	draw_rect(Rect2(902, 22 + height, 146, 6), accent)

func draw_character(at: Vector2, facing: float, moving: bool, worried: bool) -> void:
	var stride := sin(progress * TAU * 3.0) * 23 if moving else 4.0
	var bob := absf(stride) * 0.14 if moving else sin(progress * TAU) * 1.5
	draw_set_transform(at + Vector2(0, 20), 0.0, Vector2(facing, 1))
	draw_rect(Rect2(-37, 0, 76, 5), Color(0, 0, 0, 0.3))
	draw_line(Vector2(-10, -44), Vector2(-12 + stride, 0), EDGE, 15.0, true)
	draw_line(Vector2(10, -44), Vector2(14 - stride, 0), EDGE, 15.0, true)
	shape([Vector2(-22, -102 - bob), Vector2(17, -102 - bob), Vector2(27, -47), Vector2(-30, -47)], GOLD.darkened(0.14))
	draw_line(Vector2(-16, -95 - bob), Vector2(-22 - stride * 0.5, -60), GOLD.darkened(0.34), 10.0, true)
	draw_line(Vector2(-21, -89 - bob), Vector2(17, -52), Color("#29292c"), 5.0, true)
	draw_circle(Vector2(1, -123 - bob), 24, EDGE)
	draw_circle(Vector2(8, -121 - bob), 18, Color("#d5a481"))
	shape([Vector2(-23, -119 - bob), Vector2(-17, -145 - bob), Vector2(12, -148 - bob), Vector2(24, -132 - bob), Vector2(-2, -128 - bob), Vector2(-11, -111 - bob)], EDGE)
	draw_circle(Vector2(17, -124 - bob), 2.6 if worried else 1.8, EDGE)
	draw_line(Vector2(14, -130 - bob), Vector2(20, (-133 if worried else -130) - bob), EDGE, 1.6, true)
	draw_line(Vector2(18, -115 - bob), Vector2(23, -115 - bob), EDGE, 1.5, true)
	draw_set_transform(Vector2(0, 20))
