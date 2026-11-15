"""Import supplied Reel 2 movies without altering originals; build local runtime media."""
from pathlib import Path
import subprocess, shutil, wave, array, json
ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"C:\Users\xiiipin\Desktop\视频素材\REEL2")
OUT = ROOT / "assets/reel2"
for folder in ["source", "video", "audio"]: (OUT / folder).mkdir(parents=True, exist_ok=True)
movies = {"phone": "大哥大.mp4", "drive": "车平稳行驶过.mp4", "accelerate": "车辆启动.mp4", "brake": "停下车.mp4", "crash": "撞车.mp4"}
def ff(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *map(str,args)], check=True)
for key, name in movies.items():
    src = SOURCE / name
    shutil.copy2(src, OUT / "source" / name)
    ff("-i",src,"-an","-vf","tpad=stop_mode=clone:stop_duration=5","-t",5,"-c:v","libtheora","-q:v",8,OUT / "video" / (key+".ogv"))
    ff("-i",src,"-frames:v",1,OUT / "video" / (key+".png"))
    ff("-i",src,"-vn","-af","apad","-t",5,"-ac",1,"-ar",44100,"-c:a","pcm_s16le",OUT / "audio" / (key+".wav"))
# Approach is the pre-impact section; collision starts from the matching cut.
for key,start,duration in [("approach",0,2.5),("impact",2.5,2.5)]:
    src=SOURCE/movies["crash"]
    ff("-ss",start,"-i",src,"-an","-vf",f"trim=duration={duration},setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=5","-t",5,"-c:v","libtheora","-q:v",8,OUT/"video"/(key+".ogv"))
    ff("-ss",start,"-i",src,"-frames:v",1,OUT/"video"/(key+".png"))
ff("-ss",2.5,"-i",SOURCE/movies["crash"],"-vn","-af","apad","-t",5,"-ac",1,"-ar",44100,"-c:a","pcm_s16le",OUT/"audio/impact.wav")
# Source archives are retained without asking Godot to import duplicate MP4s.
(OUT/"source/.gdignore").touch()
scene_dir=ROOT/"scenes/reel2";scene_dir.mkdir(exist_ok=True)
def scene(key,subtitle=""):
    text=f'''[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://scripts/presentation/video_shot.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/reel2/video/{key}.png" id="2"]
[ext_resource type="VideoStream" path="res://assets/reel2/video/{key}.ogv" id="3"]
[node name="VideoShot" type="Node2D"]
metadata/canvas_size = Vector2(1100, 618.75)
script = ExtResource("1")
poster = ExtResource("2")
stream = ExtResource("3")
[node name="Matte" type="ColorRect" parent="."]
offset_right = 1100.0
offset_bottom = 618.75
mouse_filter = 2
color = Color(0.145, 0.137, 0.149, 1)
[node name="Still" type="TextureRect" parent="."]
offset_right = 1100.0
offset_bottom = 618.75
mouse_filter = 2
expand_mode = 1
stretch_mode = 5
[node name="Player" type="VideoStreamPlayer" parent="."]
offset_right = 1100.0
offset_bottom = 618.75
mouse_filter = 2
expand = true
'''
    if key in ["impact", "crash"]:
        text = text.replace('stream = ExtResource("3")', 'stream = ExtResource("3")\nblack_on_finished = true')
    if subtitle:
        text+=f'''[node name="Dialogue" type="Label" parent="."]
offset_top = 540.0
offset_right = 1100.0
offset_bottom = 590.0
mouse_filter = 2
horizontal_alignment = 1
theme_override_font_sizes/font_size = 30
theme_override_colors/font_color = Color(1, 0.98, 0.94, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 2
text = "{subtitle}"
'''
    return text
for key in [*movies,"approach","impact"]: (scene_dir/(key+".tscn")).write_text(scene(key),encoding="utf-8")
(scene_dir/"answer.tscn").write_text(scene("drive","接通电话：喂？"),encoding="utf-8")
clips=[("ring","大哥大来电","开场 · 车载电话","phone","6545cc"),("engine","发动机声","逐渐加速","accelerate","2463eb"),("brake","卡车警示声","前方卡车","brake","f3c52b"),("drive","行驶声","车辆持续行驶","drive","00836f")]
for key,title,desc,audio,color in clips:
    with wave.open(str(OUT/"audio"/(audio+".wav"))) as wav: samples=array.array("h",wav.readframes(wav.getnframes()))
    peaks=[max(map(abs,samples[i*len(samples)//144:(i+1)*len(samples)//144]),default=0)/32768 for i in range(144)]
    rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    failure='[ext_resource type="AudioStream" path="res://assets/reel2/audio/impact.wav" id="3"]' if key=="outcome" else ''
    text=f'''[gd_resource type="Resource" script_class="AudioClipData" load_steps={4 if failure else 3} format=3]
[ext_resource type="Script" path="res://scripts/data/audio_clip_data.gd" id="1"]
[ext_resource type="AudioStream" path="res://assets/reel2/audio/{audio}.wav" id="2"]
{failure}
[resource]
script = ExtResource("1")
id = "reel2_{key}"
title = "{title}"
description = "{desc}"
stream = ExtResource("2")
'''
    if failure: text+='failure_stream = ExtResource("3")\n'
    text+='tint = Color('+', '.join(map(str,rgb))+', 1)\nwaveform = PackedFloat32Array('+', '.join(f'{v:.4f}' for v in peaks)+')\n'
    (ROOT/"resources/clips"/("reel2_"+key+".tres")).write_text(text,encoding="utf-8")
print("Imported five source videos and created Reel 2 runtime assets.")

ff("-i",SOURCE/movies["drive"],"-an","-vf","setpts=0.7*PTS,tpad=stop_mode=clone:stop_duration=5","-t",5,"-c:v","libtheora","-q:v",8,OUT/"video/drive_fast.ogv")
(scene_dir/"drive_fast.tscn").write_text(scene("drive").replace("video/drive.ogv", "video/drive_fast.ogv"),encoding="utf-8")
ff("-ss",3.8,"-i",SOURCE/movies["brake"],"-frames:v",1,OUT/"video/parked.png")
