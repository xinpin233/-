class_name SoundFilmViewport
extends Control
## Uses the original illustrated film unless an Ogg Theora route is configured.

signal media_warning(message: String)

var _rail := Control.new()
var _aperture := Control.new()
var _video := VideoStreamPlayer.new()
var _frames: Array[SoundComicFrame] = []
var _rail_offset: float = 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ColorRect.new()
	matte.color = Color("252326")
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(matte)
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aperture.clip_contents = true
	_aperture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aperture)
	_aperture.add_child(_rail)
	for index in 4:
		var frame := SoundComicFrame.new()
		frame.stage = index
		frame.position = Vector2(index * 1120, 0)
		frame.size = Vector2(1100, 375)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rail.add_child(frame)
		_frames.append(frame)
	add_child(_video)
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.volume_db = -80.0
	_video.hide()
	resized.connect(_fit)
	_fit()

func reset(opening_scene: PackedScene = null) -> void:
	_video.stop()
	_video.paused = false
	_video.hide()
	_rail.show()
	_rail_offset = 0.0
	for frame in _frames:
		frame.media_active = false
		frame.progress = 0.0
		frame.safe_route = false
		frame.first_cue = 0
		frame.clear_custom_scene()
		frame.queue_redraw()
	if opening_scene != null:
		_frames[0].show_custom_scene(opening_scene)
	_fit()

func start_route(level: SoundLevelData, safe: bool, order: Array[String]) -> void:
	reset()
	var previous_x := 290.0
	var previous_shot := level.opening_scene
	var shots := level.success_shots if safe else level.failure_shots
	for frame in _frames.slice(0, order.size()):
		frame.safe_route = safe
		frame.first_cue = 1 if order[0] == "gasp" else 0
		frame.configure_clip(level.find_clip(order[frame.stage]), level.slot_duration)
		if level.follow_clip_shots:
			if frame.stage == 0:
				frame.show_custom_scene(level.opening_scene)
			else:
				var shot_slot := level.initial_order.find(order[frame.stage])
				if shot_slot == 0:
					frame.show_custom_scene(shots[0] if safe and shots.size() > 0 else previous_shot)
				elif shot_slot > 0 and shot_slot < shots.size():
					previous_shot = shots[shot_slot]
					frame.show_custom_scene(previous_shot)
		elif frame.stage < shots.size():
			frame.show_custom_scene(shots[frame.stage])
		frame.start_x = previous_x
		match order[frame.stage]:
			"drips": frame.end_x = 405.0
			"gasp": frame.end_x = previous_x - 45.0
			"knock": frame.end_x = 173.0 if safe else 815.0
			"alarm": frame.end_x = 194.0 if safe else 815.0
		previous_x = frame.end_x
		frame.queue_redraw()
	_fit()
	var path := level.success_video if safe else level.failure_video
	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		media_warning.emit("找不到视频素材，已使用演示分镜。")
		return
	var stream := load(path) as VideoStream
	if stream == null:
		media_warning.emit("视频格式不可播放，已使用演示分镜。")
		return
	_video.stream = stream
	_video.show()
	_rail.hide()
	_video.play()

func update_frame(elapsed: float, stage: int, progress: float, level: SoundLevelData) -> void:
	if stage < 0 or stage >= _frames.size():
		return
	_frames[stage].progress = progress
	_frames[stage].media_active = true
	_frames[stage].queue_redraw()
	_video.paused = false
	_rail_offset = -1120.0 * stage
	_fit()

func update_transition(stage: int, fraction: float) -> void:
	_video.paused = true
	_frames[stage - 1].media_active = false
	_frames[stage - 1].progress = 1.0
	_frames[stage - 1].queue_redraw()
	_frames[stage].progress = 0.0
	_frames[stage].queue_redraw()
	_rail_offset = -1120.0 * (stage - 1.0 + smoothstep(0.0, 1.0, fraction))
	_fit()

func set_paused(value: bool) -> void:
	_video.paused = value
	var stage := clampi(roundi(-_rail_offset / 1120.0), 0, _frames.size() - 1)
	if value:
		_frames[stage].media_active = false

func freeze() -> void:
	set_paused(true)

func _fit() -> void:
	var index := clampi(roundi(-_rail_offset / 1120.0), 0, maxi(0, _frames.size() - 1))
	var source_size := _frames[index].content_size() if not _frames.is_empty() else Vector2(1100, 375)
	var factor := minf(size.x / source_size.x, size.y / source_size.y)
	_aperture.size = source_size * factor
	_aperture.position = (size - _aperture.size) * 0.5
	_rail.scale = Vector2.ONE * factor
	_rail.position = Vector2(_rail_offset * factor, 0)
	# Keep neighbouring shots from appearing in the side mattes.
	for frame in _frames:
		frame.visible = absf(frame.stage + _rail_offset / 1120.0) < 1.0
	if _video.stream != null:
		var texture := _video.get_video_texture()
		if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
			var native := texture.get_size()
			var video_factor := minf(size.x / native.x, size.y / native.y)
			_video.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_video.size = native * video_factor
			_video.position = (size - _video.size) * 0.5
