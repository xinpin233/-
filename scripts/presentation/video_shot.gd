extends Node2D

@export var stream: VideoStream
@export var poster: Texture2D
@onready var player: VideoStreamPlayer = $Player
@onready var still: TextureRect = $Still
var started := false

func _ready() -> void:
	still.texture = poster
	player.stream = stream
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
