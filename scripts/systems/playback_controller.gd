class_name SoundPlaybackController
extends Node
## The only timeline owner. Video, subtitles, waveform and sound follow its signals.

signal frame_changed(elapsed: float, stage: int, progress: float)
signal cue_changed(slot: int)
signal completed(success: bool)

var level: SoundLevelData
var audio: SoundAudioDirector
var elapsed: float = 0.0
var playing: bool = false
var paused: bool = false
var route_success: bool = false
var _order: Array[String] = []
var _active_slot: int = -2

func configure(data: SoundLevelData, director: SoundAudioDirector) -> void:
	level = data
	audio = director

func start(order: Array[String]) -> void:
	stop()
	_order.assign(order)
	route_success = OrderRules.is_success(level, _order)
	elapsed = 0.0
	playing = true
	_active_slot = -2
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
	audio.set_paused(value)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not playing or paused:
		return
	var ending := level.duration if route_success else level.failure_time
	elapsed = minf(elapsed + maxf(delta, 0.0), ending)
	_publish_frame()
	if elapsed >= ending:
		stop()
		cue_changed.emit(-1)
		completed.emit(route_success)

func _publish_frame() -> void:
	var slot := int(elapsed / level.slot_duration)
	if slot >= _order.size():
		slot = -1
	if slot != _active_slot:
		_active_slot = slot
		if slot >= 0:
			audio.play_cue(level.find_clip(_order[slot]))
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
