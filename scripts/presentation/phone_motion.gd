extends Node2D

@export_enum("wide", "dial", "receiver") var shot := "wide"
@onready var actor: Sprite2D = $Actor
@onready var rest_position := actor.position

func set_shot_progress(progress: float, duration: float) -> void:
	var time := progress * duration
	var offset := Vector2.ZERO
	match shot:
		"wide":
			offset = Vector2(sin(progress * TAU) * 3.0, -sin(progress * PI) * 3.0)
		"dial":
			for beat in [0.12, 0.51, 0.91]:
				var press := maxf(0.0, 1.0 - absf(time - beat - 0.07) / 0.10)
				offset += Vector2(-3.0, -8.0) * press
		"receiver":
			offset = Vector2(4.0, 8.0) * (1.0 - smoothstep(0.0, 0.24, progress))
			offset.x += sin(progress * TAU) * 1.5
	actor.position = rest_position + offset
