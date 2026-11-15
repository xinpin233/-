extends SceneTree
var failures: Array[String] = []
var count := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	for path in ["res://resources/levels/phone_prologue.tres", "res://resources/levels/reel2_chase.tres"]:
		var game = load("res://scenes/main.tscn").instantiate()
		game.level = load(path)
		root.add_child(game)
		await process_frame
		game.playback.set_process(false)
		game.audio.set_muted(true)
		game._play_or_pause()
		game.playback.advance(game.level.slot_duration)
		check(game.playback._hold_left == 0, "No extra freeze before transition")
		var duration: float = game.level.transition_duration
		check(is_equal_approx(game.playback._transition_left, duration), "Transition starts immediately at boundary")
		game.playback.advance(duration * 0.5)
		check(absf(game.film._rail_offset + 560) < 1, "Halfway transition slides halfway without snapping")
		var offset: float = game.film._rail_offset
		game._play_or_pause()
		game.playback.advance(1)
		check(game.film._rail_offset == offset, "Pause preserves intermediate transition position")
		game._play_or_pause()
		game.playback.advance(0.12)
		check(game.playback.committed_count == 2, "Next cue starts after the short transition")
		check(is_equal_approx(game.film._rail_offset, -1120), "Transition settles on next shot")
		var shot = game.film._frames[1].custom_scene
		check(shot.started and shot.player.is_playing() and not shot.player.paused, "Incoming video starts on same playback update")
		game.queue_free()
		await process_frame
	print("TRANSITIONS: %d checks, %d failures: %s" % [count,failures.size(),str(failures)])
	quit(0 if failures.is_empty() else 1)
