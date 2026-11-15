extends Control
## Composition root: connects views, state and systems through signals.

@export var level: SoundLevelData

var state := SoundRunState.new()
var audio: SoundAudioDirector
var playback: SoundPlaybackController
var _active_slot: int = -1
var _preview_slot: int = -1
var _ending := false
var _chapter_pending := false

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
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Arial", "Microsoft YaHei UI"])
	title_font.font_weight = 800
	$Margin/Content/Header/Reel.add_theme_font_override("font", title_font)
	for style in ["normal", "hover", "pressed"]:
		var fill := SoundGameTheme.RED if style == "normal" else Color("b9161c")
		play_button.add_theme_stylebox_override(style, SoundGameTheme.button_style(fill))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		play_button.add_theme_color_override(color_name, Color.WHITE)
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
	playback.shot_held.connect(_on_shot_held)
	playback.cue_changed.connect(func(slot: int) -> void: _active_slot = slot)
	playback.completed.connect(_on_completed)
	playback.order_committed.connect(func(_slot: int) -> void: timeline.set_editable_from(playback.committed_count))
	audio.preview_finished.connect(_clear_preview)
	timeline.preview_requested.connect(_preview)
	timeline.move_requested.connect(_move_clip)
	play_button.pressed.connect(_play_or_pause)
	stop_button.pressed.connect(_stop)
	reset_button.pressed.connect(_reset)
	mute_button.pressed.connect(_toggle_mute)
	film.media_warning.connect(func(message: String) -> void: push_warning(message))

	progress.max_value = level.duration
	%Chapter.text = "序 幕  ·  " + level.title
	%Location.text = "场景 / " + level.title
	_reset()

func _show_error(message: String) -> void:
	status.show()
	status.text = "关卡未就绪"
	caption.text = message
	caption.get_parent().show()
	for button in [play_button, stop_button, reset_button, mute_button]:
		button.disabled = true
	push_error(message)

func _reset() -> void:
	_ending = false
	playback.configure(level, audio)
	playback.stop()
	_clear_preview()
	state.reset(level)
	progress.max_value = level.duration
	$Margin/Content/Header/Reel.text = "REEL %02d" % level.reel_number
	%Chapter.text = "第 %d 卷  ·  %s" % [level.reel_number, level.title]
	%Location.text = "场景 / " + level.title
	timeline.rebuild(level, state.order)
	_reset_presentation()

func _reset_presentation(keep_opening := false) -> void:
	if not keep_opening:
		film.reset(level.opening_scene, level.loop_opening_while_editing)
	_active_slot = -1
	progress.value = 0
	time_label.text = "● REEL %02d  /  00:00" % level.reel_number
	$MachineShell.set_stage(0)
	caption.text = ""
	status.hide()
	status.add_theme_color_override("font_color", SoundGameTheme.GOLD)
	timeline.update_playhead(0, -1)
	_refresh_controls()

func _move_clip(source: int, target: int) -> void:
	if level.lock_first_clip and (source == 0 or target == 0):
		return
	if _ending or source == target or source < 0 or target < 0 or source >= state.order.size() or target >= state.order.size():
		return
	if playback.playing:
		if source < playback.committed_count or target < playback.committed_count:
			return
		var updated := OrderRules.moved(state.order, source, target)
		if playback.update_pending_order(updated):
			state.order = updated
			film.refresh_pending(level, state.order, playback.committed_count)
			timeline.rebuild(level, state.order)
			_refresh_controls()
		return
	audio.stop_all()
	_clear_preview()
	state.order = OrderRules.moved(state.order, source, target)
	state.phase = SoundRunState.Phase.EDITING
	timeline.rebuild(level, state.order)
	_reset_presentation(level.loop_opening_while_editing)
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
		timeline.cancel_drag(false)
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
	mute_button.text = "静音" if audio.muted else "声音"
	mute_button.button_pressed = audio.muted

func _on_shot_held(elapsed: float) -> void:
	film.freeze()
	timeline.update_playhead(elapsed, -1)

func _on_transition(stage: int, fraction: float) -> void:
	film.update_transition(stage, fraction)
	timeline.update_playhead(playback.elapsed, -1)

func _on_frame(elapsed: float, stage: int, fraction: float) -> void:
	film.update_frame(elapsed, stage, fraction, level)
	caption.text = ""
	progress.value = elapsed
	time_label.text = "● REEL %02d  /  00:%02d" % [level.reel_number, int(elapsed)]
	$MachineShell.set_stage(stage)
	timeline.update_playhead(elapsed, _active_slot)

func _on_completed(success: bool) -> void:
	if success and (level.ending_shot != null or not level.next_level_path.is_empty()):
		_play_ending()
		return
	if not success and level.autoplay:
		state.phase = SoundRunState.Phase.FAILED
		_reset_presentation()
		return
	state.phase = SoundRunState.Phase.SUCCEEDED if success else SoundRunState.Phase.FAILED
	film.freeze()
	status.visible = level.use_bush_rules or level.use_chase_rules
	status.text = level.success_title if success else level.failure_title
	if not success and playback.chase != null and playback.chase.vehicle != ChaseRules.Vehicle.CRASHED:
		status.text = "尚未驶离"
	status.add_theme_color_override("font_color", SoundGameTheme.TEAL if success else SoundGameTheme.RED)
	caption.text = level.success_caption if success else level.failure_caption
	caption.get_parent().visible = level.use_bush_rules or level.use_chase_rules
	_active_slot = -1
	timeline.update_playhead(playback.elapsed, -1)
	_refresh_controls()

func _play_ending() -> void:
	_ending = true
	play_button.disabled = true
	timeline.set_locked(true)
	if level.ending_shot != null:
		var player := await film.roll_to_ending(level.ending_shot, level.transition_duration)
		var ring := audio.ambience
		if level.ending_sound != null:
			ring.stream = level.ending_sound
			ring.play()
			if not audio.muted:
				create_tween().tween_property(ring, "volume_db", -26.0, 4.2)
		await player.finished
		_advance_chapter()
		return
	_advance_chapter()

func _advance_chapter() -> void:
	_ending = false
	if not level.next_level_path.is_empty():
		level = load(level.next_level_path) as SoundLevelData
		_reset()
	else:
		state.phase = SoundRunState.Phase.SUCCEEDED
		_refresh_controls()

func _refresh_controls() -> void:
	timeline.visible = true
	play_button.get_parent().visible = true
	var locked := _ending
	play_button.disabled = locked
	timeline.set_editable_from(playback.committed_count if playback.playing else 0)
	timeline.set_locked(locked)
	stop_button.disabled = not playback.playing or _ending
	reset_button.disabled = playback.playing or locked
	match state.phase:
		SoundRunState.Phase.PLAYING:
			play_button.text = "暂 停  Ⅱ"
		SoundRunState.Phase.PAUSED:
			play_button.text = "继 续  ▶"
		_:
			play_button.text = "放 映  ▶"

func _input(event: InputEvent) -> void:
	if playback == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if _ending and event.keycode != KEY_F11:
		return
	match event.keycode:
		KEY_F11:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		KEY_SPACE:
			_play_or_pause()
		KEY_ESCAPE:
			if timeline.is_dragging():
				timeline.cancel_drag()
			else:
				_stop()
		KEY_R:
			if state.can_edit():
				_reset()
		KEY_M:
			_toggle_mute()
		_:
			return
	get_viewport().set_input_as_handled()
