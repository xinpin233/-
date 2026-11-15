class_name BushMedia
extends RefCounted
## Presentation mapping kept outside the pure gameplay rules.
static func shot(event: String) -> PackedScene:
	return load("res://scenes/reel3/%s.tscn" % event) as PackedScene

static func sound(variant: String) -> AudioStream:
	return load("res://assets/reel3/audio/%s.wav" % variant) as AudioStream
