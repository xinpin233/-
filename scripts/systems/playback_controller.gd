class_name SoundPlaybackController
extends Node
## The only timeline owner. Video, subtitles, waveform and sound follow its signals.

signal order_committed(slot: int)

signal frame_changed(elapsed: float, stage: int, progress: float)
signal cue_changed(slot: int)
signal completed(success: bool)
signal transition_changed(stage: int, fraction: float)
signal shot_held(elapsed: float)

var level: SoundLevelData
var audio: SoundAudioDirector
var elapsed: float = 0.0
var playing: bool = false
var paused: bool = false
var route_success: bool = false
var committed_count := 0
var chase: ChaseRules
var bush: BushRules
var current_event := ""
var current_sound := ""
var _order: Array[String] = []
var _active_slot: int = -2
var _transition_left := 0.0
var _next_stage := 1
var _hold_left := 0.0

func configure(data: SoundLevelData, director: SoundAudioDirector) -> void:
	level = data
	audio = director

func start(order: Array[String]) -> void:
	stop()
	_order.assign(order)
	route_success = true
	committed_count = 0
	chase = ChaseRules.new() if level.use_chase_rules else null
	bush = BushRules.new() if level.use_bush_rules else null
	current_event = ""
	current_sound = ""
	elapsed = 0.0
	playing = true
	_active_slot = -2
	_transition_left = 0.0
	_next_stage = 1
	_hold_left = 0.0
	audio.start_bed(level.ambience)
	_publish_frame()

func stop() -> void:
	playing = false
	paused = false
	if audio != null:
		audio.stop_all()

func set_paused(value: bool) -> void:
	if not playing:
		return
	paused = value
	audio.set_paused(value or _transition_left > 0.0 or _hold_left > 0.0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not playing or paused:
		return
	var ending := level.duration if level.use_chase_rules or level.use_bush_rules or route_success else level.failure_time
	var remaining := maxf(delta, 0.0)
	while remaining > 0.0:
		if _hold_left > 0.0:
			var hold_step := minf(remaining, _hold_left)
			_hold_left -= hold_step
			remaining -= hold_step
			if _hold_left > 0.0 or elapsed >= ending:
				break
			if _transition_left <= 0.0:
				audio.set_paused(false)
				_publish_frame()
		if _transition_left > 0.0:
			var step := minf(remaining, _transition_left)
			_transition_left = maxf(0.0, _transition_left - step)
			remaining -= step
			transition_changed.emit(_next_stage - 1, 1.0 - _transition_left / level.transition_duration)
			if _transition_left > 0.0:
				return
			audio.set_paused(false)
			_publish_frame()
		var boundary := ending
		if _next_stage < level.stage_starts.size():
			boundary = minf(boundary, level.stage_starts[_next_stage])
		var to_boundary := maxf(0.0, boundary - elapsed) / level.shot_speed
		var step := minf(remaining, to_boundary)
		elapsed = boundary if step >= to_boundary else elapsed + step * level.shot_speed
		remaining -= step
		if elapsed >= boundary:
			_hold_left = level.shot_hold
			if _hold_left > 0.0:
				audio.set_paused(true)
				shot_held.emit(elapsed)
			if elapsed >= ending:
				if _hold_left <= 0.0:
					break
				continue
			_next_stage += 1
			_transition_left = level.transition_duration
			if _transition_left > 0.0:
				# Let sound run through the slide; only a hold freezes it.
				audio.set_paused(false)
				if _hold_left <= 0.0:
					transition_changed.emit(_next_stage - 1, 0.0)
			elif _hold_left <= 0.0:
				_publish_frame()
		else:
			break
	if _transition_left > 0.0 or _hold_left > 0.0:
		return
	_publish_frame()
	if elapsed >= ending:
		stop()
		cue_changed.emit(-1)
		completed.emit(route_success)

func _publish_frame() -> void:
	var slot := 0
	for index in level.stage_starts.size():
		if elapsed + 0.00001 >= level.stage_starts[index]:
			slot = index
	if elapsed >= level.duration:
		slot = -1
	if slot != _active_slot:
		_active_slot = slot
		if slot >= 0:
			var clip := level.find_clip(_order[slot]).duplicate() as AudioClipData
			committed_count = slot + 1
			if bush != null:
				var outcome := bush.consume(_order[slot])
				current_event = outcome.event
				current_sound = outcome.sound
				route_success = bush.succeeded()
				clip.stream = BushMedia.sound(current_sound)
			elif chase != null:
				current_event = chase.consume(_order[slot], slot == _order.size() - 1)
				route_success = chase.succeeded()
				if current_event in ["impact", "crash"]:
					clip.stream = load("res://assets/reel2/audio/%s.wav" % current_event)
				elif current_event in ["parked", "black"]:
					clip.stream = null
			else:
				route_success = route_success and _order[slot] == level.correct_order[slot]
				if not route_success and clip.failure_stream != null:
					clip.stream = clip.failure_stream
			order_committed.emit(slot)
			audio.play_cue(clip)
		else:
			audio.cue.stop()
		cue_changed.emit(slot)
	var stage := 0
	for index in level.stage_starts.size():
		if elapsed >= level.stage_starts[index]:
			stage = index
	var start := level.stage_starts[stage]
	var end := level.stage_starts[stage + 1] if stage + 1 < level.stage_starts.size() else level.duration
	frame_changed.emit(elapsed, stage, clampf((elapsed - start) / (end - start), 0.0, 1.0))

func update_pending_order(order: Array[String]) -> bool:
	if not playing or order.size() != _order.size():
		return false
	var expected := _order.duplicate()
	var actual := order.duplicate()
	expected.sort()
	actual.sort()
	if expected != actual or order.slice(0, committed_count) != _order.slice(0, committed_count):
		return false
	_order.assign(order)
	return true
