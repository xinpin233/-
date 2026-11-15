class_name BushRules
extends RefCounted
## Pure slot reducer. No nodes, media loading, UI or knowledge of future sounds.

const SOLUTION: Array[String] = ["reel3_A", "reel3_E", "reel3_C", "reel3_D", "reel3_B"]
enum Agent { OUTSIDE, HIDDEN, MASKED, RELAXED, PASSED, EXPOSED, DEAD, INCOMPLETE, CLEARED }
var agent: Agent = Agent.OUTSIDE
var history: Array[String] = []
var first_failure := ""
var valid_prefix := true
var outputs: Array[Dictionary] = []

func consume(sound: String) -> Dictionary:
	var slot := history.size()
	valid_prefix = valid_prefix and slot < SOLUTION.size() and sound == SOLUTION[slot]
	var entered_cover := "reel3_A" in history
	history.append(sound)
	var event := "incomplete"
	var voice := "silence"
	match sound:
		"reel3_A": voice = "grass"
		"reel3_B": voice = "branch"
		"reel3_C": voice = "alert"
		"reel3_D": voice = "shot_fall"
		"reel3_E": voice = "cat"
	if agent == Agent.DEAD:
		event = "cat_after" if sound == "reel3_E" else "aftermath"
	elif not entered_cover and sound in ["reel3_E", "reel3_B"]:
		first_failure = "cat_too_early" if sound == "reel3_E" else "branch_too_early"
		event = first_failure
		voice = "early_cat" if sound == "reel3_E" else "early_branch"
		agent = Agent.DEAD
	else:
		match sound:
			"reel3_A":
				event = "hide"
				agent = Agent.HIDDEN
			"reel3_B":
				if valid_prefix and agent == Agent.PASSED:
					event = "tail_reveal"
					agent = Agent.CLEARED
				else:
					event = "branch_exposes"
					agent = Agent.EXPOSED
			"reel3_E":
				if valid_prefix and agent == Agent.HIDDEN:
					event = "cat_masks"
					agent = Agent.MASKED
				else:
					event = "cat_after"
			"reel3_C":
				if valid_prefix and agent == Agent.MASKED:
					event = "guard_relaxes"
					voice = "boots"
					agent = Agent.RELAXED
				else:
					event = "guard_aims"
					agent = Agent.EXPOSED
			"reel3_D":
				if valid_prefix and agent == Agent.RELAXED:
					event = "slip_past"
					voice = "success"
					agent = Agent.PASSED
				elif agent == Agent.EXPOSED:
					event = "shot_down"
					voice = "shot_fall"
					first_failure = "shot_down"
					agent = Agent.DEAD
				else:
					voice = "silence"
					agent = Agent.INCOMPLETE
	var result := {"clip_id": sound, "event": event, "sound": voice, "state": agent, "failure": first_failure}
	outputs.append(result)
	return result

func succeeded() -> bool:
	return history == SOLUTION and valid_prefix and agent == Agent.CLEARED and first_failure.is_empty()
