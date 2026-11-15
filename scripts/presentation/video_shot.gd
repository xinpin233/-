extends Node2D

@export var black_on_finished := false
@export var stream: VideoStream
@export var poster: Texture2D
@onready var player: VideoStreamPlayer = $Player
@onready var still: TextureRect = $Still
var started := false
var _fitted := false

func _ready() -> void:
	player.finished.connect(_finished)
	still.texture = poster
	player.stream = stream
	# Keep the gate at the authored 16:9 canvas until the first real frame
	# arrives, otherwise the player fills a stale rect and stretches the image.
	_fit_player()
	if stream != null:
		player.volume_db = -80.0
		player.hide()

func set_media_active(active: bool) -> void:
	if stream == null:
		return
	if active and not started:
		started = true
		player.play()
		player.show()
	player.paused = not active
	_fit_player()

func set_idle_loop() -> void:
	player.loop = true

func _fit_player() -> void:
	var canvas: Vector2 = get_meta("canvas_size", Vector2(1100, 618.75))
	var texture := player.get_video_texture()
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		var native := texture.get_size()
		var factor := minf(canvas.x / native.x, canvas.y / native.y)
		player.size = native * factor
		player.position = (canvas - player.size) * 0.5
		_fitted = true
		return
	# No frame decoded yet: pin the control to the canvas so nothing stretches.
	if not _fitted:
		player.size = canvas
		player.position = Vector2.ZERO

func _finished() -> void:
	if black_on_finished:
		player.hide()
		still.hide()
		$Matte.color = Color.BLACK
