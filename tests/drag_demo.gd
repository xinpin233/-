extends SceneTree
## Record the real mouse interaction at fixed 60 fps; save every other rendered frame.

class DemoPointer extends Control:
	func _draw() -> void:
		var outline := PackedVector2Array([Vector2(0, 0), Vector2(0, 22), Vector2(6, 17), Vector2(11, 27), Vector2(16, 24), Vector2(11, 15), Vector2(20, 15)])
		draw_colored_polygon(outline, Color("f7f3e9"))
		outline.append(outline[0])
		draw_polyline(outline, Color("101820"), 2.0, true)

var game: Control
var pointer: DemoPointer
var frame_index := 0
var captured := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/drag_motion/frames")
	game = load("res://scenes/main.tscn").instantiate()
	game.level = game.level.duplicate()
	game.level.autoplay = false
	root.add_child(game)
	await process_frame
	await process_frame
	game.audio.set_muted(true)
	var layer := CanvasLayer.new()
	layer.layer = 30
	game.add_child(layer)
	pointer = DemoPointer.new()
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.position = Vector2(500, 710)
	layer.add_child(pointer)
	await _hold(24)
	await _gesture(1, 0, 0.25)
	await _hold(32)
	await _gesture(0, 1, 0.78)
	await _hold(35)
	print("DEMO: %d frames captured at 30 fps." % captured)
	game.queue_free()
	await process_frame
	quit()

func _gesture(source: int, target: int, grip_fraction: float) -> void:
	var timeline: SoundAudioTimeline = game.timeline
	var strip := timeline.strips[source]
	var grip := Vector2(strip.size.x * grip_fraction, 40)
	var start: Vector2 = strip.get_global_transform() * grip
	var destination: Vector2 = timeline._track.get_global_transform() * (timeline._slot_position(target) + grip)
	await _move(pointer.position, start, 16, 0)
	_button(start, true)
	await _hold(5)
	await _move(start, start + Vector2(0, -30), 12, MOUSE_BUTTON_MASK_LEFT)
	await _move(start + Vector2(0, -30), destination + Vector2(0, -30), 42, MOUSE_BUTTON_MASK_LEFT)
	await _hold(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/06_drag_reflow.png")
	await _move(destination + Vector2(0, -30), destination + Vector2(0, -6), 8, MOUSE_BUTTON_MASK_LEFT)
	_button(destination + Vector2(0, -6), false)
	await _hold(20)

func _move(from: Vector2, to: Vector2, frames: int, mask: int) -> void:
	var previous := from
	for index in frames:
		var t := float(index + 1) / frames
		t = t * t * (3.0 - 2.0 * t)
		var at := from.lerp(to, t)
		var event := InputEventMouseMotion.new()
		event.position = at
		event.global_position = at
		event.relative = at - previous
		event.button_mask = mask
		root.push_input(event, true)
		pointer.position = at
		previous = at
		await _frame()

func _button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)

func _hold(frames: int) -> void:
	for index in frames:
		await _frame()

func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if frame_index % 2 == 0:
		var screenshot := root.get_texture().get_image()
		var ratio := Vector2(screenshot.get_size()) / root.get_visible_rect().size
		var top: float = game.timeline.global_position.y - 36
		var bottom: float = game.timeline._track_host.get_global_rect().end.y + 16
		var crop := Rect2i(Vector2(24, top) * ratio, Vector2(root.get_visible_rect().size.x - 48, bottom - top) * ratio)
		screenshot.get_region(crop).save_png("res://artifacts/drag_motion/frames/frame_%04d.png" % captured)
		captured += 1
	frame_index += 1
