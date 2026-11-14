class_name SoundStoryPresenter
extends RefCounted
## Demo-specific story text. Replace this layer when authoring another story.

static func text_for(stage: int, progress: float, safe: bool) -> Array[String]:
	match stage:
		0:
			return ["隔着磨砂门", ("「啊！」……门外怎么了？" if safe else "滴、答。门外大概又积水了。") if progress > 0.26 else "维修走廊里，她只看得见门上的灯。"]
		1:
			return ["第二个声音", ("又有液体滴下来……是不是有人受伤了？" if safe else "原来是有人踩到水滑了一下。") if progress > 0.3 else "她停下来，侧耳听。"]
		2:
			return ["她做了决定", "她转身回去找值班员。" if safe else "她沿着走廊往前，打算从另一头出去。"]
		_:
			return ["走出走廊" if safe else "出口封闭", "她在卷闸落下前撤到了值班室。" if safe else "漏水导致线路断电，卷闸正在落下……"]
