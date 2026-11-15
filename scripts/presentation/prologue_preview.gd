extends Control
@export var interactive := false
@export var title_only := false
@export var skip_title_intro := false
@export var title_ring: AudioStream
@export var menu_music: AudioStream

var canvas := Control.new()
var wide := Node2D.new()
var receiver := Node2D.new()
var titles := Control.new()
var elapsed := 0.0
const SOUND_SEGMENTS = [
	preload("res://assets/prologue/audio/01_coin_receiver.wav"),
	preload("res://assets/prologue/audio/02_dial_ringback.wav"),
	preload("res://assets/prologue/audio/03_title_ring.wav"),
]
var sound := AudioStreamPlayer.new()
var bgm := AudioStreamPlayer.new()
var sound_segment := -1
var controls := HBoxContainer.new()
var coin_slot: Button
var coin_source: Button
var play_button: Button
var film: Control
var dial := Sprite2D.new()
var coin_inserted := false
var playing := false
const BUSY = preload("res://assets/prologue/audio/alt_busy.wav")

func _ready() -> void:
	theme = SoundGameTheme.create()
	add_child(sound)
	bgm.stream = menu_music if title_only else preload("res://assets/prologue/audio/title_bgm.wav")
	bgm.volume_db = -15.0
	bgm.finished.connect(func() -> void: bgm.play())
	add_child(bgm)
	if interactive:
		_build_controls()
		film.add_child(canvas)
	else:
		add_child(canvas)
	canvas.size = Vector2(1600, 1200)
	canvas.clip_contents = true
	canvas.add_child(wide)
	canvas.add_child(receiver)
	_load_layers(wide, "wide")
	_load_layers(receiver, "receiver")
	if title_only:
		wide.hide()
		receiver.hide()
		var title_wide := Sprite2D.new()
		title_wide.name = "TitleWide"
		title_wide.texture = preload("res://assets/prologue/shot_wide.png")
		title_wide.centered = false
		canvas.add_child(title_wide)
	dial.texture = preload("res://assets/prologue/dial.png")
	dial.centered = false
	var dial_size := dial.texture.get_size()
	var dial_scale := minf(1600.0 / dial_size.x, 1200.0 / dial_size.y)
	dial.scale = Vector2.ONE * dial_scale
	dial.position = (Vector2(1600, 1200) - dial_size * dial_scale) * 0.5
	canvas.add_child(dial)
	canvas.add_child(titles)
	titles.size = Vector2(1600, 1200)
	var veil := ColorRect.new()
	veil.color = Color(0.96, 0.93, 0.96, 0.87)
	veil.size = titles.size
	titles.add_child(veil)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	font.font_weight = 900
	for offset in [Vector2(6, 7), Vector2.ZERO]:
		var title := Label.new()
		title.text = "声之行"
		title.position = Vector2(380, 240) + offset
		title.size = Vector2(840, 230)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", font)
		title.add_theme_font_size_override("font_size", 170)
		title.add_theme_color_override("font_color", Color("#3b3540") if offset != Vector2.ZERO else Color("#c8323a"))
		titles.add_child(title)
	var rule := ColorRect.new()
	rule.position = Vector2(630, 510)
	rule.size = Vector2(340, 5)
	rule.color = Color("#c8323a")
	titles.add_child(rule)
	var logo := Sprite2D.new()
	logo.texture = preload("res://assets/prologue/studio_logo.jpg")
	logo.centered = false
	logo.position = Vector2(670, 590)
	logo.scale = Vector2.ONE * (260.0 / logo.texture.get_width())
	titles.add_child(logo)
	var replay := Button.new()
	replay.text = "重玩序章" if title_only else ("开始游戏" if interactive else "重播")
	replay.position = Vector2(700, 1020)
	replay.size = Vector2(200, 60)
	if interactive or title_only:
		replay.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	else:
		replay.pressed.connect(_replay)
	titles.add_child(replay)
	if title_only:
		var exit_button := Button.new()
		exit_button.text = "退出"
		exit_button.position = Vector2(700, 1090)
		exit_button.size = Vector2(200, 60)
		exit_button.pressed.connect(func() -> void: get_tree().quit())
		titles.add_child(exit_button)
	resized.connect(_fit)
	_fit()
	if title_only:
		sound.stream = title_ring
		sound.finished.connect(_repeat_title_ring)
		_repeat_title_ring()
		if skip_title_intro:
			_advance_title(4.0)
	_update_picture()
	if interactive:
		_start_show.call_deferred()

func _build_controls() -> void:
	var shell := Control.new()
	shell.set_script(preload("res://scripts/ui/machine_shell.gd"))
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 76)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 42)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	margin.add_child(content)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.3333334
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(aspect)
	film = Control.new()
	film.name = "Film"
	film.clip_contents = true
	aspect.add_child(film)
	film.owner = self
	film.unique_name_in_owner = true
	film.resized.connect(_fit)
	content.add_child(controls)
	controls.custom_minimum_size.y = 84
	controls.add_theme_constant_override("separation", 7)
	coin_slot = Button.new()
	coin_slot.text = "+"
	coin_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(coin_slot)
	coin_slot.set_drag_forwarding(Callable(), _can_drop_coin, _drop_coin)
	_add_audio_block("拨号", preload("res://assets/prologue/audio/dial_keys.wav"))
	_add_audio_block("电话反馈", BUSY)
	play_button = Button.new()
	play_button.name = "PlayButton"
	play_button.text = "放映"
	play_button.custom_minimum_size = Vector2(220, 48)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	content.add_child(play_button)
	play_button.owner = self
	play_button.unique_name_in_owner = true
	play_button.pressed.connect(_start_show)
	add_child(shell)
	move_child(shell, 0)

func _add_audio_block(label: String, stream: AudioStream) -> void:
	var block := Button.new()
	block.text = label
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.pressed.connect(_audition.bind(stream))
	controls.add_child(block)

func _populate_drawer(box: VBoxContainer) -> void:
	coin_source = Button.new()
	coin_source.text = "投币声"
	box.add_child(coin_source)
	coin_source.pressed.connect(_audition.bind(SOUND_SEGMENTS[0]))
	coin_source.set_drag_forwarding(_drag_coin, Callable(), Callable())

func _audition(stream: AudioStream) -> void:
	if not playing:
		sound.stream = stream
		sound.play()

func _drag_coin(_position: Vector2) -> Variant:
	if playing or coin_inserted:
		return null
	var ghost := Label.new()
	ghost.text = "投币声"
	coin_source.set_drag_preview(ghost)
	return "coin"

func _can_drop_coin(_position: Vector2, data: Variant) -> bool:
	return not playing and not coin_inserted and data == "coin"

func _drop_coin(position: Vector2, data: Variant) -> void:
	if _can_drop_coin(position, data):
		_insert_coin()

func _insert_coin() -> void:
	coin_inserted = true
	coin_slot.text = "已放入投币声"
	coin_slot.disabled = true


func _start_show() -> void:
	if playing:
		return
	_replay()
	playing = true
	play_button.disabled = true
	for block in controls.get_children():
		block.disabled = true


func _load_layers(target: Node2D, folder: String) -> void:
	var path := "res://assets/prologue/" + folder + "/"
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(path + "scene_layers.json"))
	for record in records:
		var sprite := Sprite2D.new()
		sprite.name = record["name"]
		sprite.texture = load(path + record["file"])
		sprite.centered = false
		sprite.position = Vector2(record["x"], record["y"])
		sprite.visible = record["visible"]
		target.add_child(sprite)

func _fit() -> void:
	var area := film.size if interactive and is_instance_valid(film) else size
	var factor := minf(size.x / 1600.0, area.y / 1200.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (area - canvas.size * factor) * 0.5
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#d8cdd9"))

func _process(delta: float) -> void:
	if title_only:
		_advance_title(delta)
		return
	if interactive and not playing:
		return
	var previous := elapsed
	elapsed = minf(elapsed + delta, 12.0)
	if previous < 9.5 and elapsed >= 9.5:
		bgm.play()
	var success := not interactive or coin_inserted
	var segment := mini(int(elapsed / 3.0), 2)
	if interactive and success and elapsed >= 6.0:
		segment = 4 if elapsed < 7.5 else 2
	if not success and elapsed >= 6.0:
		segment = 3
	if segment != sound_segment:
		sound_segment = segment
		sound.stream = BUSY if segment == 3 else (preload("res://assets/prologue/audio/ringback.wav") if segment == 4 else SOUND_SEGMENTS[segment])
		var offset := 0.0 if segment >= 3 else elapsed - segment * 3.0
		if not success and segment == 0:
			sound.stop()
		elif interactive and segment == 1:
			sound.stream = preload("res://assets/prologue/audio/dial_keys.wav")
			sound.play(offset)
		else:
			sound.play(0.0 if interactive and segment == 2 else offset)
	if not success and elapsed >= 8.8:
		playing = false
		_replay()

		play_button.disabled = false
		for block in controls.get_children():
			block.disabled = false

	_update_picture()

func _repeat_title_ring() -> void:
	if elapsed < 4.0 and sound.stream != null:
		sound.play()

func _advance_title(delta: float) -> void:
	var was_open := elapsed >= 4.0
	elapsed = minf(elapsed + delta, 4.0)
	var pan := smoothstep(0.0, 2.7, elapsed)
	var art := canvas.get_node("TitleWide") as Sprite2D
	art.scale = Vector2.ONE * (1600.0 / art.texture.get_width()) * lerpf(1.0, 0.96, pan)
	art.position = Vector2(32.0 * pan, 265.0 - 190.0 * pan)
	titles.visible = true
	titles.modulate.a = smoothstep(1.5, 3.1, elapsed)
	for child in titles.get_children():
		if child is Button:
			child.visible = elapsed >= 4.0
	sound.volume_db = lerpf(-4.0, -24.0, pan)
	if not was_open and elapsed >= 4.0 and bgm.stream != null:
		bgm.play()

func _update_picture() -> void:
	var answer := smoothstep(1.85, 2.55, elapsed)
	dial.visible = interactive and elapsed >= 3.0 and elapsed < 6.0
	wide.modulate.a = 1.0 - answer
	receiver.modulate.a = answer
	var pan := smoothstep(6.0, 9.0, elapsed)
	# Pull back slightly so the upward movement keeps the full artwork visible.
	for scene in [wide, receiver]:
		scene.scale = Vector2.ONE * (1.0 - 0.06 * pan)
		scene.position = Vector2(48, 0) * pan
	titles.modulate.a = smoothstep(7.5, 9.5, elapsed)
	titles.visible = elapsed >= 7.5

func _unhandled_key_input(event: InputEvent) -> void:
	if title_only:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if interactive:
			_start_show()
		else:
			_replay()

func _replay() -> void:
	sound.stop()
	bgm.stop()
	sound_segment = -1
	elapsed = 0.0
	_update_picture()
