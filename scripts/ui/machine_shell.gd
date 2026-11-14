extends Control

var drawer: PanelContainer
var slide := 0.0
var desk: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk = get_parent()
	drawer = PanelContainer.new()
	drawer.size = Vector2(266, 320)
	drawer.z_index = 10
	add_child(drawer)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	drawer.add_child(box)
	var title := Label.new()
	title.text = "声音素材"
	box.add_child(title)
	for clip in desk.level.clips:
		var button := Button.new()
		button.text = "▷   " + clip.title
		button.tooltip_text = "试听素材"
		button.pressed.connect(func() -> void:
			var slot: int = desk.state.order.find(clip.id)
			if slot >= 0:
				desk._preview(slot)
		)
		box.add_child(button)
	var tab := Label.new()
	tab.text = "素\n材\n库\n\n›"
	tab.position = Vector2(273, 78)
	tab.size = Vector2(30, 170)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.add_child(tab)

func _process(delta: float) -> void:
	var mouse := get_local_mouse_position()
	var target := 1.0 if Rect2(-238 + slide * 250, 110, 310, 340).has_point(mouse) else 0.0
	slide = move_toward(slide, target, delta * 4.0)
	drawer.position = Vector2(-238 + smoothstep(0.0, 1.0, slide) * 250, 120)
	queue_redraw()

func plate(rect: Rect2, fill: Color, edge: Color, radius: int, shadow := 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_size = shadow
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_offset = Vector2(0, 5)
	draw_style_box(style, rect)

func _draw() -> void:
	var extent: Vector2 = desk.size
	plate(Rect2(Vector2(9, 9), extent - Vector2(18, 18)), Color("#282925"), Color("#42443d"), 20, 8)
	plate(Rect2(Vector2(17, 17), extent - Vector2(34, 34)), Color("#30312c"), Color("#1c1e1b"), 15)
	for y in range(22, int(extent.y) - 22, 4):
		draw_line(Vector2(23, y), Vector2(extent.x - 23, y), Color(0.8, 0.79, 0.68, 0.018))
	var film: Control = desk.get_node("%Film")
	var rect := film.get_global_rect()
	plate(rect.grow(18), Color("#c9c1a4"), Color("#e2dcc4"), 24, 8)
	plate(rect.grow(10), Color("#191d19"), Color("#8e8975"), 17)
	for point in [Vector2(30, 30), Vector2(extent.x - 30, 30), Vector2(30, extent.y - 30), extent - Vector2(30, 30)]:
		draw_circle(point + Vector2(0, 1), 8, Color("#171915"))
		draw_circle(point, 6, Color("#45473e"))
		draw_line(point - Vector2(3, 3), point + Vector2(3, 3), Color("#171915"), 2, true)
	var lamp := Vector2(extent.x - 65, 38)
	draw_circle(lamp, 10, Color("#435848"))
	draw_circle(lamp, 5, Color("#9cd3a2"))
