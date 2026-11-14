class_name SoundRunState
extends RefCounted

enum Phase { EDITING, PLAYING, PAUSED, SUCCEEDED, FAILED }

var phase: Phase = Phase.EDITING
var order: Array[String] = []
var attempts: int = 0

func reset(level: SoundLevelData) -> void:
	phase = Phase.EDITING
	order.assign(level.initial_order)
	attempts = 0

func can_edit() -> bool:
	return phase not in [Phase.PLAYING, Phase.PAUSED]
