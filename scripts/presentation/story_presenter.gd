class_name SoundStoryPresenter
extends RefCounted

static func text_for(stage: int, progress: float, safe: bool) -> String:
	match stage:
		0:
			if progress > 0.26:
				return "门外怎么了？" if safe else "又积水了？"
		1:
			if progress > 0.3:
				return "有人受伤了？" if safe else "原来是滑倒了。"
	return ""
