extends SceneTree

var failures: Array[String] = []
var checks := 0
var game: Control
var capture := false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAILED: " + message)

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.playback.set_process(false)
	game.audio.set_muted(true)
	if capture and DisplayServer.get_name().to_lower() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/merged_ui.png")

	_check(game.level != null and game.level.validation_error().is_empty(), "Cloud level data loads")
	_check(game.timeline.strips.size() == game.level.clips.size(), "All cloud audio clips render")
	_check(game.state.order == game.level.initial_order, "Initial order loads")
	_check(game.timeline.strips[0].waveform.peaks.size() > 0, "Waveforms load from audio assets")
	_check(game.get_node("%Film").size.y >= 200, "Cloud film viewport has usable space")
	_check(game.get_node("MachineShell") != null, "Cloud machine shell is present")

	game.timeline.strips[0].preview_requested.emit(0)
	_check(game.audio.preview.playing, "Clicking a clip auditions it")
	_check(game.audio.preview.stream == game.level.find_clip("drips").stream, "Audition uses the selected cloud clip")
	game._clear_preview()

	game.timeline._begin_drag(game.timeline.strips[0], game.timeline.strips[0].get_global_rect().get_center())
	_check(game.timeline._drag_ghost != null, "Dragging lifts a complete audio clip")
	_check(game.timeline._drag_ghost.get_parent() == game.timeline._drag_overlay, "Lifted clip is outside the rail")
	var target_point: Vector2 = game.timeline._track.get_global_transform() * (game.timeline._slot_position(1) + game.timeline.strips[0].size * 0.5 + Vector2(0, -20))
	game.timeline._update_drag(target_point)
	_check(game.timeline._drop_marker.visible and game.timeline._drop_slot.visible, "Drag shows landing slot and marker")
	_check(game.state.order == game.level.initial_order, "Preview drag does not commit early")
	game.timeline._finish_drag(target_point)
	await create_timer(0.32).timeout
	_check(game.state.order == game.level.correct_order, "Drag commits the cloud order")
	_check(game.timeline._drag_ghost == null, "Landing clears the floating clip")
	_check(game.timeline.strips[1].clip.id == "drips", "Dragged clip lands at the requested index")

	game._reset()
	_check(game.state.order == game.level.initial_order, "Reset returns cloud order")
	game._play_or_pause()
	_check(game.state.phase == SoundRunState.Phase.PLAYING, "Play starts the cloud route")
	_check(game.timeline.strips[0].locked, "Playback locks all clips")
	game._move_clip(0, 1)
	_check(game.state.order == game.level.initial_order, "Editing is blocked during playback")
	game.playback.advance(20.0)
	_check(game.state.phase == SoundRunState.Phase.FAILED, "Wrong cloud order reaches failure")
	game._move_clip(0, 1)
	_check(game.state.order == game.level.correct_order, "Cloud can be corrected after failure")

	game._play_or_pause()
	game.playback.advance(20.0)
	_check(game.state.phase == SoundRunState.Phase.SUCCEEDED, "Correct cloud order reaches success")
	_check(not game.playback.playing, "Completed route stops transport")
	game._stop()
	game._reset()
	_check(game.state.order == game.level.initial_order, "Stop and reset remain usable")

	if failures.is_empty():
		print("PASS: %d checks, cloud UI, local drag lift/reflow/landing, four clips, audition, lock, failure and success routes." % checks)
	else:
		print("FAIL: %d/%d checks failed: %s" % [failures.size(), checks, str(failures)])
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
