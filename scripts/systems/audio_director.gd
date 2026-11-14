class_name SoundAudioDirector
extends Node
## Owns all sound players; the transport only requests cues.

signal preview_finished

var ambience := AudioStreamPlayer.new()
var cue := AudioStreamPlayer.new()
var preview := AudioStreamPlayer.new()
var muted: bool = false

func _ready() -> void:
	for player in [ambience, cue, preview]:
		add_child(player)
	preview.finished.connect(func() -> void: preview_finished.emit())
	ambience.volume_db = -5.0

func start_bed(stream: AudioStream) -> void:
	stop_all()
	ambience.stream = stream
	if stream != null:
		ambience.play()

func play_cue(clip: AudioClipData) -> void:
	cue.stop()
	if clip != null:
		cue.stream = clip.stream
		cue.play()

func audition(clip: AudioClipData) -> void:
	preview.stop()
	if clip != null:
		preview.stream = clip.stream
		preview.play()

func set_paused(value: bool) -> void:
	ambience.stream_paused = value
	cue.stream_paused = value

func stop_all() -> void:
	for player in [ambience, cue, preview]:
		player.stop()
		player.stream_paused = false

func set_muted(value: bool) -> void:
	muted = value
	# Keep this game's mute local; do not change the project's Master bus.
	for player in [ambience, cue, preview]:
		player.volume_linear = 0.0 if muted else (0.56 if player == ambience else 1.0)
