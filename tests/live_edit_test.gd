extends SceneTree

var game: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	create_timer(45).timeout.connect(func() -> void: push_error("Live edit test timed out"); quit(2))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.playback.set_process(false)
	game.audio.set_muted(true)
	check(not game.playback.playing and game.state.can_edit(), "Real opening waits for Play")
	check(game.film.get_parent() is AspectRatioContainer, "Opening stays in the film container")
	check(game.timeline.visible and game.play_button.is_visible_in_tree(), "Editing UI is immediately available")
	check(not game.film._frames[0].custom_scene.player.is_playing(), "Opening video does not autoplay or idle-loop")
	check(absf(game.film.size.x / game.film.size.y - 16.0 / 9.0) < 0.01, "Film is 16:9")
	await _capture("live_edit_start")
	# Check the actual video texture sizes, including the original 4:3 sources.
	for name in ["wide", "dial", "coin", "call", "scratch"]:
		var shot = load("res://scenes/story_%s.tscn" % name).instantiate()
		root.add_child(shot)
		shot.set_media_active(true)
		await create_timer(0.08).timeout
		shot._fit_player()
		var native: Vector2 = shot.player.get_video_texture().get_size()
		check(absf(shot.player.size.x / shot.player.size.y - native.x / native.y) < 0.001, "%s preserves decoded video aspect" % name)
		check(Rect2(Vector2.ZERO, shot.get_meta("canvas_size")).grow(1).encloses(shot.player.get_rect()), "%s video stays inside canvas" % name)
		shot.queue_free()
	# Test branch results without waiting for the ending movie for every permutation.
	var production: SoundLevelData = game.level
	game.level = production.duplicate()
	game.level.ending_shot = null
	game.level.next_reel_number = 0
	game.level.next_level_path = ""
	game.playback.configure(game.level, game.audio)
	game._reset()
	game._play_or_pause()
	game.playback.advance(0.5)
	var at: float = game.playback.elapsed
	var current = game.film._frames[0].custom_scene
	check(game.timeline.strips[0].locked and not game.timeline.strips[3].locked, "Only started/pinned clips lock")
	await _drag(3, 1)
	check(game.state.order == game.level.correct_order, "Mouse drag fixes remaining order during playback")
	check(game.playback.elapsed == at and game.playback.playing, "Live drag does not restart or stop playback")
	check(game.film._frames[0].custom_scene == current, "Live drag preserves current video instance")
	check(game.film._frames[3].custom_scene.scene_file_path.ends_with("story_call.tscn"), "Future video follows the corrected route")
	await _capture("live_edit_playing")
	game.playback.advance(60)
	check(game.state.phase == SoundRunState.Phase.SUCCEEDED, "Correcting future clips converts initial wrong arrangement to success")
	game._reset()
	game._play_or_pause()
	game.playback.advance(0.5)
	game._play_or_pause()
	await _drag(3, 1)
	check(game.playback.paused and is_equal_approx(game.playback.elapsed, 0.5 * game.level.shot_speed), "Paused future editing preserves pause and time")
	game._play_or_pause()
	game.playback.advance(60)
	check(game.state.phase == SoundRunState.Phase.SUCCEEDED, "Paused correction affects resumed result")
	# Current cue and previous slots remain immutable, even via direct calls.
	game._reset()
	game._move_clip(3, 1)
	game._play_or_pause()
	game.playback.advance(game.level.slot_duration / game.level.shot_speed + game.level.shot_hold + game.level.transition_duration + 0.1)
	check(game.playback.committed_count == 2, "Second cue has started after hold and transition")
	var order: Array[String] = game.state.order.duplicate()
	game._move_clip(1, 3)
	game._move_clip(3, 1)
	check(game.state.order == order, "Cannot move current cue or insert ahead of it")
	await _drag(3, 2)
	check(game.playback.playing and game.state.order != order, "Later clips still draggable while second cue plays")
	game.playback.advance(60)
	check(game.state.phase == SoundRunState.Phase.FAILED, "Breaking a future correct order leads to failure")
	# Crossing a cue boundary cancels an in-flight drag before locking its source.
	game._reset()
	game._play_or_pause()
	var strip: Control = game.timeline.strips[1]
	game.timeline._begin_drag(strip, strip.get_global_rect().get_center())
	game.playback.advance(game.level.slot_duration / game.level.shot_speed + game.level.shot_hold + game.level.transition_duration + 0.1)
	check(game.timeline._drag_ghost == null and game.timeline.strips[1].locked, "Cue boundary safely cancels an active drag")
	check(not game.playback.update_pending_order(game.level.correct_order), "Started wrong prefix cannot be rewritten")
	game.playback.advance(game.level.slot_duration / game.level.shot_speed + game.level.shot_hold + game.level.transition_duration)
	check(game.film._frames[2].custom_scene.scene_file_path.ends_with("story_scratch.tscn"), "Wrong phone feedback uses failure footage")
	check(game.audio.cue.stream == game.level.find_clip("phone_feedback").failure_stream, "Wrong phone feedback uses failure sound")
	game.playback.advance(60)
	for tail in [["coin", "dial", "phone_feedback"], ["coin", "phone_feedback", "dial"], ["dial", "coin", "phone_feedback"], ["dial", "phone_feedback", "coin"], ["phone_feedback", "coin", "dial"], ["phone_feedback", "dial", "coin"]]:
		game._reset()
		game.state.order.assign(["silence"] + tail)
		game.timeline.rebuild(game.level, game.state.order)
		game._play_or_pause()
		game.playback.advance(60)
		var expected: bool = tail == ["coin", "dial", "phone_feedback"]
		check((game.state.phase == SoundRunState.Phase.SUCCEEDED) == expected, "Permutation resolves correctly: %s" % str(tail))
	# Zero-duration transitions must still consume every cue on a large clock step.
	game.level.shot_hold = 0.0
	game.level.transition_duration = 0.0
	game._reset()
	game._play_or_pause()
	game.playback.advance(60)
	check(game.state.phase == SoundRunState.Phase.FAILED and game.playback.committed_count == 4, "Instant transitions do not skip wrong cues")
	# Verify the real ending movie and the unbuilt Reel 2 placeholder.
	game.level = production
	game.playback.configure(production, game.audio)
	game._reset()
	game._move_clip(3, 1)
	game._play_or_pause()
	game.playback.advance(60)
	check(game._ending, "Success starts ending inside the film")
	await create_timer(1.2).timeout
	check(game.film.get_parent() is AspectRatioContainer and game.film._frames.size() == 5, "Ending uses the same framed rail")
	await _capture("live_edit_ending")
	while game._ending:
		await process_frame
	check(not game._chapter_pending and game.level.reel_number == 2 and not game.playback.playing, "Real ending loads playable Reel 2 in editing mode")
	check(game.get_node("Margin/Content/Header/Reel").text == "REEL 02", "Chapter header advances")
	await _capture("live_edit_reel2")
	game._reset()
	check(not game._chapter_pending and game.state.order == game.level.initial_order and not game.playback.playing, "Reset keeps Reel 2 idle")
	print("LIVE EDIT: %d checks, %d failures: %s" % [checks, failures.size(), str(failures)])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _drag(source: int, target: int) -> void:
	var strip: Control = game.timeline.strips[source]
	var grip := strip.size * 0.5
	var start := strip.global_position + grip
	var finish: Vector2 = game.timeline._track.global_position + game.timeline._slot_position(target) + grip
	_mouse(start, false, true)
	await process_frame
	_mouse(start + Vector2(0, -20), true, true)
	await process_frame
	_mouse(finish, true, true)
	await create_timer(0.06).timeout
	_mouse(finish, false, false)
	check(game.timeline._settling and game.timeline._drag_ghost != null, "Live drop retains landing animation")
	await create_timer(0.25).timeout

func _mouse(at: Vector2, motion: bool, pressed: bool) -> void:
	var event: InputEventMouse
	if motion:
		event = InputEventMouseMotion.new()
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	root.get_texture().get_image().save_png("res://artifacts/" + label + ".png")
