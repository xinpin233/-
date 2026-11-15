class_name ChaseRules
extends RefCounted
## One reducer shared by playback and future-shot previews. No permutation lookup.
enum Vehicle { DRIVING, STOPPED, RESTARTED, IMMINENT_CRASH, CRASHED, DEPARTED }
var vehicle: Vehicle = Vehicle.DRIVING
var actions := 0
var accelerated := false
var events: Array[String] = []

func consume(sound: String, last_slot: bool = false) -> String:
	var event := "black"
	if vehicle == Vehicle.CRASHED:
		event = "black"
	elif sound == "reel2_ring":
		event = "phone"
	elif vehicle == Vehicle.IMMINENT_CRASH:
		vehicle = Vehicle.CRASHED
		event = "impact"
	elif sound == "reel2_brake":
		if actions == 0:
			vehicle = Vehicle.STOPPED
			event = "brake"
		elif last_slot:
			vehicle = Vehicle.CRASHED
			event = "crash"
		else:
			vehicle = Vehicle.IMMINENT_CRASH
			event = "approach"
	elif sound == "reel2_engine":
		if vehicle == Vehicle.STOPPED:
			vehicle = Vehicle.RESTARTED
			event = "accelerate"
		else:
			accelerated = true
			event = "drive_fast"
	elif sound == "reel2_drive":
		if vehicle == Vehicle.RESTARTED:
			vehicle = Vehicle.DEPARTED
			event = "depart"
		elif vehicle == Vehicle.STOPPED:
			event = "parked"
		else:
			event = "drive_fast" if accelerated else "drive"
	if sound != "reel2_ring":
		actions += 1
	events.append(event)
	return event

func succeeded() -> bool:
	return vehicle == Vehicle.DEPARTED

static func shot(event: String) -> PackedScene:
	var file := event
	if event == "depart":
		file = "drive"
	return load("res://scenes/reel2/%s.tscn" % file) as PackedScene
