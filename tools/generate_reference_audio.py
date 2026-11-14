"""Rebuild the original reference cues using only Python's standard library."""
from array import array
from math import exp, pi, sin, tanh
from pathlib import Path
from random import Random
import wave

RATE = 24000
HERE = Path(__file__).resolve().parents[1] / "assets" / "audio"
HERE.mkdir(parents=True, exist_ok=True)
rng = Random(218)
noise = 0.0

def write(name, samples):
    pcm = array("h", (round(tanh(x) * 30000) for x in samples))
    with wave.open(str(HERE / (name + ".wav")), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(pcm.tobytes())

ambience = []
drips = []
gasp = []
for i in range(9 * RATE):
    t = i / RATE
    noise = 0.965 * noise + 0.035 * rng.uniform(-1, 1)
    bed = 0.065 * noise + 0.019 * sin(2 * pi * 59 * t)
    for start in (5.25, 5.63, 6.00, 6.38):
        d = t - start
        if 0 < d < 0.18:
            bed += (0.12 * sin(2 * pi * 84 * d) + 0.08 * noise) * exp(-25 * d)
    d = t - 7.05
    if 0 < d < 1.05:
        bed += (0.5 * noise + 0.11 * sin(2 * pi * (134 * d - 21 * d * d))) * sin(pi * d / 1.05)
    ambience.append(bed)
    if i >= int(2.5 * RATE):
        continue
    drop = 0.0
    for start, pitch in ((0.35, 880), (0.85, 1140), (1.51, 980), (2.05, 1220)):
        d = t - start
        if 0 < d < 0.31:
            drop += 0.48 * (sin(2 * pi * (pitch * d + 710 * d * d))
                            + 0.23 * sin(2 * pi * 1.67 * pitch * d)) * exp(-22 * d) * min(1, d * 750)
    drips.append(drop)
    d = t - 0.46
    if 0 < d < 0.53:
        phase = 2 * pi * (374 * d - 85 * d * d + 2.5 * d ** 3)
        formants = sum(weight * sin(harmonic * phase)
                       for harmonic, weight in ((1, .24), (2, .34), (3, .10), (4, .24), (7, .10)))
        envelope = min(1, d * 28) * max(0, 1 - d / .53) ** 0.7
        gasp.append(0.65 * envelope * (formants + 0.43 * noise))
    else:
        gasp.append(0.0)

original = ambience.copy()
for i, sample in enumerate(drips + gasp):
    original[i] += sample
write("ambience", ambience)
write("drips", drips)
write("gasp", gasp)
write("original", original)
