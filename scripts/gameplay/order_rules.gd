class_name OrderRules
extends RefCounted
## Pure rules: no scene tree, drawing, audio, or timing side effects.

static func is_success(level: SoundLevelData, order: Array[String]) -> bool:
	return order == level.correct_order

static func moved(order: Array[String], source: int, target: int) -> Array[String]:
	var result: Array[String] = order.duplicate()
	if source < 0 or target < 0 or source >= result.size() or target >= result.size():
		return result
	var item: String = result[source]
	result.remove_at(source)
	result.insert(target, item)
	return result
