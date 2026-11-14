"""Sample real PCM WAV peaks into the editable Godot clip resources."""
from array import array
from pathlib import Path
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
CLIPS = [
    ("drips", "滴答", "门外 · 液体滴落", "Color(0.55, 0.82, 0.75, 1)"),
    ("gasp", "惊叫", "门外 · 一声惊呼", "Color(0.94, 0.74, 0.48, 1)"),
]

for clip_id, title, description, color in CLIPS:
    with wave.open(str(ROOT / "assets" / "audio" / f"{clip_id}.wav")) as audio:
        assert audio.getsampwidth() == 2, "Expected 16-bit PCM"
        samples = array("h", audio.readframes(audio.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
    count = 144
    peaks = [max(abs(value) for value in samples[i * len(samples) // count:(i + 1) * len(samples) // count]) / 32768 for i in range(count)]
    maximum = max(peaks) or 1
    values = ", ".join(f"{value / maximum:.4f}" for value in peaks)
    text = f'''[gd_resource type="Resource" script_class="AudioClipData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/audio_clip_data.gd" id="1"]
[ext_resource type="AudioStream" path="res://assets/audio/{clip_id}.wav" id="2"]

[resource]
script = ExtResource("1")
id = "{clip_id}"
title = "{title}"
description = "{description}"
stream = ExtResource("2")
tint = {color}
waveform = PackedFloat32Array({values})
'''
    target = ROOT / "resources" / "clips" / f"{clip_id}.tres"
    target.write_text(text, encoding="utf-8")
    print(f"Wrote {target.name}: {count} peaks")
