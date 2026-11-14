class_name AudioClipData
extends Resource
## A reusable, auditionable piece of sound. Peaks are sampled from its WAV file.

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var stream: AudioStream
@export var tint: Color = Color("8bd0bf")
@export var waveform: PackedFloat32Array = PackedFloat32Array()

@export var calm_scene: PackedScene
@export var alarmed_scene: PackedScene
