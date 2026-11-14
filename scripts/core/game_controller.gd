extends Control
## Composition root: connects views, state and systems through signals.

@export var level: SoundLevelData

var state := SoundRunState.new()
var audio: SoundAudioDirector
var playback: SoundPlaybackController
var _active_slot: int = -1
var _preview_slot: int = -1

@onready var film: SoundFilmViewport = %Film
@onready var timeline: SoundAudioTimeline = %AudioTimeline
@onready var caption: Label = %Caption
@onready var status: Label = %Status
@onready var play_button: Button = %PlayButton
@onready var stop_button: Button = %StopButton
@onready var reset_button: Button = %ResetButton
@onready var mute_button: Button = %MuteButton
@onready var progress: ProgressBar = %Progress
@onready var time_label: Label = %TimeLabel

func _ready() -> void:
	theme = SoundGameTheme.create()
	if level == null:
		_show_error("没有配置关卡资源。")
		return
	var error := level.validation_error()
	if not error.is_empty():
		_show_error(error)
		return
	audio = SoundAudioDirector.new()
	add_child(audio)
	playback = SoundPlaybackController.new()
	add_child(playback)
	playback.configure(level, audio)
	playback.frame_changed.connect(_on_frame)
	playback.transition_changed.connect(_on_transition)
	playback.cue_changed.connect(func(slot: int) -> void: _active_slot = slot)
	playback.completed.connect(_on_completed)
	audio.preview_finished.connect(_clear_preview)
	timeline.preview_requested.connect(_preview)
	timeline.move_requested.connect(_move_clip)
	play_button.pressed.connect(_play_or_pause)
	stop_button.pressed.connect(_stop)
	reset_button.pressed.connect(_reset)
	mute_button.pressed.connect(_toggle_mute)
	film.media_warning.connect(func(message: String) -> void: push_warning(message))

	progress.max_value = level.duration
	_reset()
	if level.autoplay:
		_play_or_pause.call_deferred()

func _show_error(message: String) -> void:
	status.show()
	status.text = "关卡未就绪"
	caption.text = message
	caption.get_parent().show()
	for button in [play_button, stop_button, reset_button, mute_button]:
		button.disabled = true
	push_error(message)

func _reset() -> void:
	playback.stop()
	_clear_preview()
	state.reset(level)
	timeline.rebuild(level, state.order)
	_reset_presentation()

func _reset_presentation() -> void:
	film.reset(level.opening_scene)
	_active_slot = -1
	progress.value = 0
	time_label.text = "00.0 / %04.1f s" % level.duration
	caption.text = ""
	status.hide()
	status.add_theme_color_override("font_color", SoundGameTheme.GOLD)
	timeline.update_playhead(0, -1)
	_refresh_controls()

func _move_clip(source: int, target: int) -> void:
	if not state.can_edit() or source == target or source < 0 or target < 0 or source >= state.order.size() or target >= state.order.size():
		return
	audio.stop_all()
	_clear_preview()
	state.order = OrderRules.moved(state.order, source, target)
	state.phase = SoundRunState.Phase.EDITING
	timeline.rebuild(level, state.order)
	_reset_presentation()
	# Keep keyboard focus on the moved clip after rebuilding its row.
	timeline.strips[target].grab_focus()

func _preview(slot: int) -> void:
	if not state.can_edit() or slot < 0 or slot >= state.order.size():
		return
	_clear_preview()
	_preview_slot = slot
	timeline.set_preview(slot)
	audio.audition(level.find_clip(state.order[slot]))

func _clear_preview() -> void:
	_preview_slot = -1
	if is_instance_valid(timeline):
		timeline.set_preview(-1)
		timeline.update_playhead(0, -1)

func _process(_delta: float) -> void:
	if _preview_slot < 0 or audio == null:
		return
	# Audio position follows the actual sound, independent from the story timeline.
	var position := audio.preview.get_playback_position()
	var clip := level.find_clip(state.order[_preview_slot])
	var duration := clip.stream.get_length()
	if duration > 0.0:
		timeline.strips[_preview_slot].set_progress(clampf(position / duration, 0.0, 1.0), true)

func _play_or_pause() -> void:
	if state.phase == SoundRunState.Phase.PLAYING:
		state.phase = SoundRunState.Phase.PAUSED
		playback.set_paused(true)
		film.set_paused(true)
	elif state.phase == SoundRunState.Phase.PAUSED:
		state.phase = SoundRunState.Phase.PLAYING
		playback.set_paused(false)
		film.set_paused(false)
	else:
		_clear_preview()
		state.phase = SoundRunState.Phase.PLAYING
		state.attempts += 1
		status.hide()
		status.add_theme_color_override("font_color", SoundGameTheme.GOLD)
		film.start_route(level, OrderRules.is_success(level, state.order), state.order)
		playback.start(state.order)
	_refresh_controls()

func _stop() -> void:
	playback.stop()
	_clear_preview()
	state.phase = SoundRunState.Phase.EDITING
	_reset_presentation()

func _toggle_mute() -> void:
	audio.set_muted(not audio.muted)
	mute_button.text = "取消静音 [M]" if audio.muted else "声音：开 [M]"
	mute_button.button_pressed = audio.muted

func _on_transition(stage: int, fraction: float) -> void:
	film.update_transition(stage, fraction)
	timeline.update_playhead(playback.elapsed, -1)

func _on_frame(elapsed: float, stage: int, fraction: float) -> void:
	film.update_frame(elapsed, stage, fraction, level)
	caption.text = ""
	progress.value = elapsed
	time_label.text = "%04.1f / %04.1f s" % [elapsed, level.duration]
	timeline.update_playhead(elapsed, _active_slot)

func _on_completed(success: bool) -> void:
	if success and level.ending_scene != null:
		get_tree().change_scene_to_packed.call_deferred(level.ending_scene)
		return
	if not success and level.autoplay:
		state.phase = SoundRunState.Phase.FAILED
		_reset_presentation()
		return
	state.phase = SoundRunState.Phase.SUCCEEDED if success else SoundRunState.Phase.FAILED
	film.freeze()
	status.hide()
	status.add_theme_color_override("font_color", SoundGameTheme.TEAL if success else SoundGameTheme.RED)
	caption.text = ""
	_active_slot = -1
	timeline.update_playhead(playback.elapsed, -1)
	_refresh_controls()

func _refresh_controls() -> void:
	var locked := not state.can_edit()
	timeline.set_locked(locked)
	stop_button.disabled = not locked
	reset_button.disabled = locked
	match state.phase:
		SoundRunState.Phase.PLAYING:
			play_button.text = "暂停"
		SoundRunState.Phase.PAUSED:
			play_button.text = "继续放映"
		_:
			play_button.text = "放映"

func _input(event: InputEvent) -> void:
	if playback == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F11:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		KEY_SPACE:
			_play_or_pause()
		KEY_ESCAPE:
			_stop()
		KEY_R:
			if state.can_edit():
				_reset()
		KEY_M:
			_toggle_mute()
		_:
			return
	get_viewport().set_input_as_handled()
