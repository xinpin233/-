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
	if desk.has_method("_populate_drawer"):
		desk._populate_drawer(box)
	else:
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
	var handle := Node2D.new()
	drawer.add_child(handle)
	handle.add_child(tab)

func _process(delta: float) -> void:
	var mouse := get_local_mouse_position()
	var target := 1.0 if Rect2(-238 + slide * 250, 110, 310, 340).has_point(mouse) else 0.0
	slide = move_toward(slide, target, delta * 4.0)
	drawer.position = Vector2(-238 + smoothstep(0.0, 1.0, slide) * 250, 120)
	queue_redraw()

func _draw() -> void:
	var extent: Vector2 = desk.size
	draw_rect(Rect2(Vector2.ZERO, extent), Color("#d8cdd9"))
	var film: Control = desk.get_node("%Film")
	var rect := film.get_global_rect().grow(12)
	draw_rect(Rect2(rect.position + Vector2(10, 10), rect.size), Color("#a49aa6"))
	draw_rect(rect, Color("#3b3540"))
	var play: Control = desk.get_node("%PlayButton")
	var button_rect := play.get_global_rect()
	draw_rect(Rect2(button_rect.position + Vector2(5, 5), button_rect.size), Color("#3b3540"))
