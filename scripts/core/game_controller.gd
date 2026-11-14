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
@onready var heading: Label = %StoryHeading
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
	playback.cue_changed.connect(func(slot: int) -> void: _active_slot = slot)
	playback.completed.connect(_on_completed)
	audio.preview_finished.connect(_clear_preview)
	timeline.preview_requested.connect(_preview)
	timeline.move_requested.connect(_move_clip)
	play_button.pressed.connect(_play_or_pause)
	stop_button.pressed.connect(_stop)
	reset_button.pressed.connect(_reset)
	mute_button.pressed.connect(_toggle_mute)
	film.media_warning.connect(func(message: String) -> void: caption.text = message)
	%Chapter.text = "01 / " + level.title + "\n" + level.subtitle
	progress.max_value = level.duration
	_reset()

func _show_error(message: String) -> void:
	status.text = "关卡未就绪"
	caption.text = message
	for button in [play_button, stop_button, reset_button, mute_button]:
		button.disabled = true
	push_error(message)

func _reset() -> void:
	playback.stop()
	_clear_preview()
	state.reset(level)
	timeline.rebuild(level, state.order)
	_reset_presentation("等待放映")

func _reset_presentation(message: String) -> void:
	film.reset()
	_active_slot = -1
	progress.value = 0
	time_label.text = "00.0 / %04.1f s" % level.duration
	heading.text = "隔着磨砂门"
	caption.text = level.introduction
	status.text = message
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
	_reset_presentation("顺序已调整 · 等待放映")
	# Keep keyboard focus on the moved clip after rebuilding its row.
	timeline.strips[target].preview_button.grab_focus()

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
		status.text = "已暂停"
	elif state.phase == SoundRunState.Phase.PAUSED:
		state.phase = SoundRunState.Phase.PLAYING
		playback.set_paused(false)
		film.set_paused(false)
		status.text = "放映中 · 第 %02d 次" % state.attempts
	else:
		_clear_preview()
		state.phase = SoundRunState.Phase.PLAYING
		state.attempts += 1
		status.text = "放映中 · 第 %02d 次" % state.attempts
		status.add_theme_color_override("font_color", SoundGameTheme.GOLD)
		film.start_route(level, OrderRules.is_success(level, state.order), state.order[0])
		playback.start(state.order)
	_refresh_controls()

func _stop() -> void:
	playback.stop()
	_clear_preview()
	state.phase = SoundRunState.Phase.EDITING
	_reset_presentation("已停止 · 可以重新剪辑")

func _toggle_mute() -> void:
	audio.set_muted(not audio.muted)
	mute_button.text = "取消静音 [M]" if audio.muted else "声音：开 [M]"
	mute_button.button_pressed = audio.muted

func _on_frame(elapsed: float, stage: int, fraction: float) -> void:
	film.update_frame(elapsed, stage, fraction, level)
	var story := SoundStoryPresenter.text_for(stage, fraction, playback.route_success)
	heading.text = story[0]
	caption.text = story[1]
	progress.value = elapsed
	time_label.text = "%04.1f / %04.1f s" % [elapsed, level.duration]
	timeline.update_playhead(elapsed, _active_slot)

func _on_completed(success: bool) -> void:
	state.phase = SoundRunState.Phase.SUCCEEDED if success else SoundRunState.Phase.FAILED
	film.freeze()
	status.text = "结局 · " + (level.success_title if success else level.failure_title)
	status.add_theme_color_override("font_color", SoundGameTheme.TEAL if success else SoundGameTheme.RED)
	heading.text = level.success_title if success else level.failure_title
	caption.text = level.success_caption if success else level.failure_caption
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
			play_button.text = "暂停放映 [空格]"
		SoundRunState.Phase.PAUSED:
			play_button.text = "继续放映 [空格]"
		_:
			play_button.text = "按此顺序放映 [空格]"

func _input(event: InputEvent) -> void:
	if playback == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
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
