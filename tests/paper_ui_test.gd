extends SceneTree

var game: Control
var failures: Array[String] = []
var checks := 0
var capture := false

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _run() -> void:
	create_timer(25).timeout.connect(func() -> void: push_error("UI test timed out"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	game = load("res://scenes/main.tscn").instantiate()
	game.level = game.level.duplicate()
	game.level.autoplay = false
	game.level.ending_scene = null
	root.add_child(game)
	await process_frame
	await process_frame
	game.playback.set_process(false)
	game.audio.set_muted(true)
	check(game.level.clips.size() == 4, "Phone chapter keeps four clips")
	check(game.timeline._ruler.visible, "Ruler is visible")
	check(game.timeline.strips[0]._title_label.is_visible_in_tree(), "Clip names are visible")
	check(game.film._frames[0].custom_scene != null, "Phone artwork is preserved")
	_check_aspect()
	await _snapshot("paper_ui")
	var original: Array[String] = game.state.order.duplicate()
	# Slot 0 is pinned by lock_first_clip, so the movable solve starts at the coin slot.
	var source: Control = game.timeline.strips[3]
	var grip := Vector2(source.size.x * 0.22, 44)
	var start := source.global_position + grip
	var dial_x_before: float = game.timeline.strips[1].position.x
	await _mouse(start, false, true)
	await _mouse(start + Vector2(0, -30), true, true)
	await create_timer(0.14).timeout
	check(game.timeline._drag_ghost != null, "Real mouse input lifts the card")
	if game.timeline._drag_ghost == null:
		_finish()
		return
	check(game.timeline._drag_ghost._lifted, "Dragged card gets lifted treatment")
	check(game.timeline._drag_ghost.rotation < 0, "Dragged card tilts")
	var target: Vector2 = game.timeline._track.global_position + game.timeline._slot_position(1) + grip + Vector2(0, -30)
	await _mouse(target, true, true)
	check(game.state.order == original, "Dragging is a preview until release")
	await create_timer(0.06).timeout
	check(source != game.timeline.strips[1] and game.timeline.strips[1].position.x > dial_x_before + 0.5, "Neighbour moves aside during drag")
	await _snapshot("paper_drag")
	await _mouse(target, false, false)
	await create_timer(0.25).timeout
	check(game.state.order == game.level.correct_order, "Mouse release commits the insertion")
	check(game.timeline._drag_ghost == null, "Landing clears drag overlay")
	game._play_or_pause()
	check(not game.timeline.strips[2].locked, "Pending clips stay editable during playback")
	game.playback.advance(game.level.slot_duration * 2.0 + 0.1)
	check(game.timeline.strips[1].locked, "Committed clip locks once it has played")
	check(not game.timeline.strips[3].locked, "Unplayed clips remain movable mid-playback")
	var before_swap: Array[String] = game.state.order.duplicate()
	game._move_clip(3, 2)
	check(game.state.order[2] == before_swap[3] and game.state.order[3] == before_swap[2], "Reordering unplayed clips works during playback")
	game._move_clip(2, 3)
	game._play_or_pause()
	var paused_at: float = game.playback.elapsed
	game.playback.advance(1.0)
	check(is_equal_approx(paused_at, game.playback.elapsed), "Pause freezes playback")
	game._stop()
	check(not game.timeline.strips[1].locked, "Stopping unlocks editing")
	game._reset()
	start = game.timeline.strips[3].global_position + grip
	await _mouse(start, false, true)
	await _mouse(start + Vector2(0, -30), true, true)
	await _mouse(start + Vector2(0, -350), true, true)
	await _mouse(start + Vector2(0, -350), false, false)
	await create_timer(0.25).timeout
	check(game.state.order == original, "Dropping outside the track cancels")
	await _mouse(start, false, true)
	await _mouse(start + Vector2(0, -30), true, true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await create_timer(0.25).timeout
	check(game.timeline._drag_ghost == null and game.state.order == original, "Escape cancels without committing")
	await _mouse(start, false, false)
	await _mouse(start, false, true)
	await _mouse(start + Vector2(0, -30), true, true)
	game._play_or_pause()
	check(game.timeline._drag_ghost == null, "Starting playback clears an active drag")
	game._stop()
	await _mouse(start, false, false)
	# A fast horizontal grab may cross a slot in the very first motion event.
	game._reset()
	await process_frame
	start = game.timeline.strips[3].global_position + grip
	target = game.timeline._track.global_position + game.timeline._slot_position(1) + grip
	await _mouse(start, false, true)
	await _mouse(target, true, true)
	var neighbour: Control = game.timeline.strips[1]
	check(game.timeline._drag_ghost != null, "Fast horizontal grab creates drag overlay")
	check(neighbour.position.x < game.timeline._slot_position(2).x - 1.0, "First motion crossing a slot animates instead of snapping")
	await create_timer(0.28).timeout
	check(neighbour.position.x > game.timeline._slot_position(2).x - 6.0, "Neighbour slides into the vacated slot")
	await _mouse(target, false, false)
	check(game.timeline._drag_ghost != null and game.timeline._settling, "Release retains the overlay for landing animation")
	await create_timer(0.25).timeout
	check(game.state.order == game.level.correct_order, "Fast horizontal drag commits the correct order")
	for resolution in [Vector2i(1000, 700), Vector2i(1920, 1080), Vector2i(1424, 900)]:
		root.size = resolution
		await process_frame
		await process_frame
		_check_aspect()
		var last: Control = game.timeline.strips.back()
		check(last.get_global_rect().end.x <= game.timeline.get_global_rect().end.x + 1, "All clips fit at %s" % resolution)
		check(game.play_button.get_global_rect().end.y <= root.get_visible_rect().end.y, "Transport fits at %s" % resolution)
		await _snapshot("paper_%dx%d" % [resolution.x, resolution.y])
	_finish()

func _check_aspect() -> void:
	var frame: Control = game.film._frames[0]
	var artwork: Node2D = frame.custom_scene
	var basis := artwork.get_global_transform()
	check(is_equal_approx(basis.x.length(), basis.y.length()), "Artwork uses uniform scale")
	var gate: Vector2 = frame.content_size()
	check(is_equal_approx(gate.x / gate.y, 16.0 / 9.0), "Shot gate stays 16:9")
	var bounds := Rect2(artwork.global_position, gate * basis.get_scale())
	check(game.film.get_global_rect().grow(1).encloses(bounds), "Composition fits inside film")

func _mouse(at: Vector2, motion: bool, pressed: bool) -> void:
	if motion:
		var event := InputEventMouseMotion.new()
		event.position = at
		event.global_position = at
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
	else:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
	await process_frame

func _snapshot(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	root.get_texture().get_image().save_png("res://artifacts/" + label + ".png")

func _finish() -> void:
	print("PAPER UI: %d checks, %d failures: %s" % [checks, failures.size(), str(failures)])
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
