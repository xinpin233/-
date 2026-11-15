class_name SoundLevelData
extends Resource
## Story, timings and routes live here, outside the UI and transport.

@export var title: String = "门后"
@export var subtitle: String = "维修走廊 / 第一幕"
@export_multiline var introduction: String = "隔着磨砂门，她只能听见门外的声音。"
@export var clips: Array[AudioClipData] = []
@export var initial_order: Array[String] = []
@export var correct_order: Array[String] = []
@export var slot_duration: float = 2.5
@export_range(0.0, 3.0) var transition_duration: float = 0.9
@export var duration: float = 9.0
@export var failure_time: float = 8.2
@export var stage_starts: PackedFloat32Array = PackedFloat32Array([0.0, 2.5, 5.0, 7.0])
@export var ambience: AudioStream
@export var opening_scene: PackedScene
@export var follow_clip_shots := false
@export var lock_first_clip := false
@export var success_shots: Array[PackedScene] = []
@export var failure_shots: Array[PackedScene] = []
@export var ending_scene: PackedScene
@export var autoplay := false
@export_file("*.ogv") var success_video: String = ""
@export_file("*.ogv") var failure_video: String = ""
@export var success_title: String = "平安离开"
@export_multiline var success_caption: String = "她在卷闸落下前回到值班室，找到了帮助。"
@export var failure_title: String = "出口封闭"
@export_multiline var failure_caption: String = "卷闸挡住了出口。试着改变声音的顺序，再放映一次。"

func find_clip(clip_id: String) -> AudioClipData:
	for clip in clips:
		if clip.id == clip_id:
			return clip
	return null

func validation_error() -> String:
	if clips.is_empty() or initial_order.size() != clips.size():
		return "音频素材和初始顺序的数量不一致。"
	if duration <= 0.0 or slot_duration <= 0.0:
		return "关卡时长必须大于零。"
	if failure_time <= 0.0 or failure_time > duration:
		return "失败时间必须位于关卡时长内。"
	if slot_duration * clips.size() > duration:
		return "音频时隙超出了关卡时长。"
	if stage_starts.size() != clips.size() or stage_starts[0] != 0.0:
		return "每段音频需要一个分镜时间节点，第一格从零开始。"
	for index in range(1, stage_starts.size()):
		if stage_starts[index] <= stage_starts[index - 1] or stage_starts[index] >= duration:
			return "分镜时间必须递增并位于关卡时长内。"
	var ids: Array[String] = []
	for clip in clips:
		if clip == null or clip.id.is_empty() or clip.id in ids:
			return "每段音频必须有唯一标识。"
		ids.append(clip.id)
	var initial := initial_order.duplicate()
	var expected := correct_order.duplicate()
	ids.sort()
	initial.sort()
	expected.sort()
	if initial != ids or expected != ids:
		return "初始顺序和正确顺序必须各包含所有音频一次。"
	return ""
