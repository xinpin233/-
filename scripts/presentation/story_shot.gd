extends Node2D

@export var shot := "wide"
@onready var art: Sprite2D = $Art
var moving_layer: Sprite2D
var rest_position: Vector2
var pivot_uv: Vector2

func _ready() -> void:
	var layer := ShaderMaterial.new()
	layer.shader = preload("res://scripts/presentation/story_shot.gdshader")
	var radius := Vector2(0.038, 0.085)
	pivot_uv = Vector2(0.49, 0.66)
	match shot:
		"dial":
			pivot_uv = Vector2(0.554, 0.483)
			radius = Vector2(0.044, 0.117)
		"coin":
			pivot_uv = Vector2(0.531, 0.268)
			radius = Vector2(0.039, 0.022)
		"call", "scratch":
			pivot_uv = Vector2(0.621, 0.426)
			radius = Vector2(0.018, 0.064)
	layer.set_shader_parameter("center", pivot_uv)
	layer.set_shader_parameter("radius", radius)
	moving_layer = Sprite2D.new()
	moving_layer.texture = art.texture
	moving_layer.scale = art.scale
	moving_layer.offset = -art.texture.get_size() * pivot_uv
	moving_layer.centered = false
	moving_layer.material = layer
	rest_position = art.position + art.texture.get_size() * art.scale * pivot_uv
	moving_layer.position = rest_position
	add_child(moving_layer)

func set_shot_progress(progress: float, duration: float) -> void:
	var time := progress * duration
	var envelope := sin(progress * PI)
	var offset := Vector2.ZERO
	var rotation_amount := 0.0
	match shot:
		"wide":
			offset.y = -1.6 * envelope
			rotation_amount = sin(time * 3.0) * envelope * 0.035
		"dial":
			var press := 0.0
			for beat in [0.25, 0.76, 1.27]:
				press += exp(-pow((time - beat) / 0.095, 2.0))
			offset = Vector2(-1.5, -3.0) * press
		"coin":
			offset = Vector2(-2.0, -3.0) * envelope
			rotation_amount = 0.06 * envelope
		"call":
			offset.y = -2.0 * smoothstep(0.0, 0.35, progress)
		"scratch":
			offset.y = 2.0 * sin(time * 5.0) * envelope
			rotation_amount = 0.07 * envelope
	moving_layer.position = rest_position + offset
	moving_layer.rotation = rotation_amount