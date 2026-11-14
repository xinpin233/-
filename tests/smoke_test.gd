extends SceneTree
## Run with: godot --headless --path . --script res://tests/smoke_test.gd
## Omit --headless and append -- --capture to also render review screenshots.

var failures: Array[String] = []
var checks: int = 0
var game: Control
var capture: bool = false

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
	_check(game.level.validation_error().is_empty(), "Valid level data")
	_check(game.timeline.strips.size() == 2, "Two audio strips exist")
	_check(game.state.order == game.level.initial_order, "Initial order loaded")
	_check(game.timeline.strips[0].waveform.peaks.size() == 144, "Real waveform loaded")
	_check(game.get_node("Margin/Content/Footer").get_global_rect().end.y <= root.get_visible_rect().size.y, "Footer fits viewport")
	_check(game.film.size.y >= 285, "Film has usable space")
	await _snapshot("01_editing")
	game.timeline.strips[0].preview_requested.emit(0)
	_check(game.audio.preview.playing, "Audition button starts sound")
	_check(game.audio.preview.stream == game.level.find_clip("drips").stream, "Audition matches clip")
	game.get_node("%PlayButton").pressed.emit()
	_check(not game.audio.preview.playing, "Playback stops audition")
	_check(game.state.phase == SoundRunState.Phase.PLAYING, "Play button starts run")
	_check(game.timeline.strips[0].locked, "Playback locks editing")
	game._move_clip(0, 1)
	_check(game.state.order == game.level.initial_order, "Reordering blocked while playing")
	game.playback.advance(1.0)
	game._play_or_pause()
	var paused_time: float = game.playback.elapsed
	game.playback.advance(3.0)
	_check(game.playback.elapsed == paused_time, "Paused clock stays still")
	_check(game.audio.cue.stream_paused, "Pause reaches audio")
	game._play_or_pause()
	game.playback.advance(1.6)
	_check(game._active_slot == 1, "Second sound starts at its slot")
	_check(game.audio.cue.stream == game.level.find_clip("gasp").stream, "Correct second sound")
	game.playback.advance(5.0)
	_check(game.state.phase == SoundRunState.Phase.PLAYING, "Failure is not reported before its time")
	game.playback.advance(0.61)
	_check(game.state.phase == SoundRunState.Phase.FAILED, "Wrong order fails in the middle")
	_check(is_equal_approx(game.playback.elapsed, game.level.failure_time), "Failure freezes at configured timestamp")
	_check(not game.audio.ambience.playing and not game.audio.cue.playing, "Failure cleans sound")
	_check(not game.timeline.strips[0].locked, "Failure unlocks editing")
	await _snapshot("02_failed")
	game.timeline.strips[1].move_requested.emit(1, 0)
	_check(game.state.order == game.level.correct_order, "Arrow moves clip into correct order")
	_check(game.state.phase == SoundRunState.Phase.EDITING, "Edit clears ending")
	game._move_clip(-1, 1)
	_check(game.state.order == game.level.correct_order, "Invalid move is ignored")
	var target: SoundAudioStrip = game.timeline.strips[1]
	var payload := {"kind": "sound_clip", "source": 0, "owner": game.timeline.get_instance_id()}
	_check(target._can_drop_data(Vector2.ZERO, payload), "Timeline accepts own drag")
	_check(not target._can_drop_data(Vector2.ZERO, {"kind": "unrelated"}), "Unrelated drag rejected")
	target._drop_data(Vector2.ZERO, payload)
	_check(game.state.order == game.level.initial_order, "Dropping changes order")
	await process_frame
	await process_frame
	# Exercise real GUI drag routing through nested waveform/labels, not just the data callback.
	var source_point: Vector2 = game.timeline.strips[1].global_position + Vector2(430, 40)
	var target_point: Vector2 = game.timeline.strips[0].global_position + Vector2(430, 40)
	await _mouse_move(source_point)
	await _mouse_button(source_point, true)
	await _mouse_move(source_point + Vector2(0, -24), Vector2(0, -24), MOUSE_BUTTON_MASK_LEFT)
	await _mouse_move(target_point, target_point - source_point, MOUSE_BUTTON_MASK_LEFT)
	await _mouse_button(target_point, false)
	_check(game.state.order == game.level.correct_order, "Mouse drag through waveform reorders strips")
	# Continue independently so a failed drag assertion does not hide playback regressions.
	if game.state.order != game.level.correct_order:
		game._move_clip(1, 0)
	for iteration in 3:
		game._play_or_pause()
		game.playback.advance(2.6)
		game.playback.advance(2.5)
		game.playback.advance(2.1)
		if iteration == 0:
			await _snapshot("03_safe_route")
		game.playback.advance(2.0)
		_check(game.state.phase == SoundRunState.Phase.SUCCEEDED, "Success replay %d" % (iteration + 1))
		_check(is_equal_approx(game.playback.elapsed, game.level.duration), "Successful run reaches full duration")
		_check(not game.playback.playing and not game.audio.cue.playing, "Replay cleans transport and cue")
	await _snapshot("04_succeeded")
	game._play_or_pause()
	game.playback.advance(1.0)
	game._stop()
	_check(game.state.phase == SoundRunState.Phase.EDITING, "Stop returns to editing")
	_check(game.state.order == game.level.correct_order, "Stop preserves edited order")
	_check(not game.audio.ambience.playing, "Stop clears ambience")
	game._reset()
	_check(game.state.order == game.level.initial_order and game.state.attempts == 0, "Reset restores initial state")
	var rail: Control = game.film.get_child(0)
	_check(is_equal_approx(rail.scale.x, rail.scale.y), "Film preserves character proportions")
	game.film.set_paused(true)
	game.film.reset()
	var video: VideoStreamPlayer = game.film.get_child(1)
	_check(not video.paused, "Video pause flag resets before replay")
	game._toggle_mute()
	_check(not game.audio.muted, "Mute can be toggled off")
	game._toggle_mute()
	_check(game.audio.muted and is_zero_approx(game.audio.cue.volume_linear), "Mute applies to players")
	# Global Space remains a playback shortcut even when the audition button has focus.
	game.timeline.strips[0].grab_focus()
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	await process_frame
	_check(game.state.phase == SoundRunState.Phase.PLAYING, "Space plays with audition button focused")
	game._stop()
	game._reset()
	if failures.is_empty():
		print("PASS: %d checks, failure route, three success replays, pause, stop, reset, audition, drag, keyboard, layout." % checks)
	else:
		print("FAIL: %d/%d checks failed: %s" % [failures.size(), checks, str(failures)])
	game.queue_free()
	await process_frame
	# Let the audio mixer release stopped voices before process shutdown.
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)

func _mouse_move(at: Vector2, relative := Vector2.ZERO, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = mask
	root.push_input(event, true)
	await process_frame

func _mouse_button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event, true)
	await process_frame

func _snapshot(label: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var image := root.get_texture().get_image()
	image.save_png("res://artifacts/" + label + ".png")
