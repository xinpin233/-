extends SceneTree
var game: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	game = load("res://scenes/reel2.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.audio.set_muted(true)
	game.playback.set_process(false)
	check(not game.playback.playing, "Opens without autoplay")
	check(game.timeline.strips[0].locked, "Phone pinned")
	for i in [1,2,3]:
		check(not game.timeline.strips[i].locked, "All three sound cues editable")
	var production: SoundLevelData = game.level
	game.level = production.duplicate()
	game.level.next_reel_number = 0
	game.level.next_level_path = ""
	game.playback.configure(game.level,game.audio)
	var rows := [
		[["engine","brake","drive"],["drive_fast","approach","impact"],ChaseRules.Vehicle.CRASHED],
		[["engine","drive","brake"],["drive_fast","drive_fast","crash"],ChaseRules.Vehicle.CRASHED],
		[["brake","engine","drive"],["brake","accelerate","depart"],ChaseRules.Vehicle.DEPARTED],
		[["brake","drive","engine"],["brake","parked","accelerate"],ChaseRules.Vehicle.RESTARTED],
		[["drive","engine","brake"],["drive","drive_fast","crash"],ChaseRules.Vehicle.CRASHED],
		[["drive","brake","engine"],["drive","approach","impact"],ChaseRules.Vehicle.CRASHED]]
	for row_index in rows.size():
		var row: Array = rows[row_index]
		game._reset()
		game.state.order.assign(["reel2_ring"])
		for sound: String in row[0]: game.state.order.append("reel2_"+sound)
		game.timeline.rebuild(game.level,game.state.order)
		game._play_or_pause()
		for i in 3:
			game.playback.advance(5.23)
			check(game.playback.current_event == row[1][i], "Permutation %d slot %d event %s" % [row_index+1,i+2,row[1][i]])
			check(game.film._frames[i+1].custom_scene.scene_file_path == ChaseRules.shot(row[1][i]).resource_path, "Actual shot matches state event")
			check(game.timeline.strips[i+1].locked, "Consumed cue locks")
		check(game.playback.chase.vehicle == row[2], "Permutation %d final vehicle state" % (row_index+1))
		game.playback.advance(6)
		check((game.state.phase == SoundRunState.Phase.SUCCEEDED) == (row_index == 2), "Permutation %d completion" % (row_index+1))
		if row_index == 3:
			check(game.status.text.contains("尚未驶离"), "Restarted but still on bridge is retryable, not a collision")
		var machine: ChaseRules = game.playback.chase
		if row[2] == ChaseRules.Vehicle.CRASHED:
			check(machine.consume("reel2_drive") == "black" and machine.vehicle == ChaseRules.Vehicle.CRASHED, "Crash is absorbing; later sounds stay black")
	# Actual mouse reorder of the previously locked last sound.
	game._reset()
	game._play_or_pause()
	game.playback.advance(0.4)
	await drag(3,1)
	check(game.state.order == ["reel2_ring","reel2_drive","reel2_engine","reel2_brake"], "Last cue moves during playback")
	check(game.playback.committed_count == 1 and game.playback.elapsed == 0.4, "Future edits preserve committed history/time")
	await drag(3,1)
	await drag(3,2)
	check(game.state.order == ["reel2_ring","reel2_brake","reel2_engine","reel2_drive"], "Live rearrangement can reach sole successful route")
	game.playback.advance(5.23)
	var actual: Node = game.film._frames[1].custom_scene
	await drag(3,2)
	check(game.film._frames[1].custom_scene == actual, "Reorder keeps the current stopped shot")
	game.playback.advance(5.23)
	check(game.playback.current_event == "parked" and game.playback.chase.vehicle == ChaseRules.Vehicle.STOPPED, "Live edit derives parked state from actual past")
	game.playback.advance(20)
	check(game.state.phase == SoundRunState.Phase.FAILED, "Live parked route does not pass")
	# A deliberately wrong correct_order table cannot override state-machine success.
	game.level.correct_order.assign(game.level.initial_order)
	game._reset()
	game._move_clip(2,1)
	game._play_or_pause()
	game.playback.advance(30)
	check(game.state.phase == SoundRunState.Phase.SUCCEEDED, "State machine, not correct_order lookup, decides success")
	game.level = production
	game.playback.configure(production,game.audio)
	game._reset()
	game._move_clip(2,1)
	game._play_or_pause()
	game.playback.advance(30)
	check(game.level.reel_number == 3 and not game.playback.playing and not game.play_button.disabled, "Departed route advances to playable Reel 3")
	# Verify actual decoded collision video finishes black, not an opening poster.
	for name in ["crash","impact"]:
		var shot = load("res://scenes/reel2/%s.tscn" % name).instantiate()
		root.add_child(shot)
		shot.set_media_active(true)
		await shot.player.finished
		check(not shot.player.visible and not shot.still.visible and shot.get_node("Matte").color == Color.BLACK, "Collision ends on persistent black: " + name)
		shot.set_media_active(false)
		shot.set_media_active(true)
		check(not shot.player.visible, "Finished collision does not restart")
		shot.queue_free()
	print("REEL2 STATE MACHINE: %d checks, %d failures: %s" % [checks,failures.size(),str(failures)])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func drag(source: int,target: int) -> void:
	var strip: Control = game.timeline.strips[source]
	var grip := strip.size*0.5
	var start := strip.global_position+grip
	var finish: Vector2 = game.timeline._track.global_position+game.timeline._slot_position(target)+grip
	mouse(start,false,true)
	await process_frame
	mouse(start+Vector2(0,-20),true,true)
	await process_frame
	mouse(finish,true,true)
	await create_timer(0.05).timeout
	check(game.timeline._drag_ghost != null,"Mouse drag lifts cue")
	mouse(finish,false,false)
	await create_timer(0.25).timeout
func mouse(at: Vector2,motion: bool,pressed: bool) -> void:
	var event: InputEventMouse
	if motion: event = InputEventMouseMotion.new()
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event,true)
