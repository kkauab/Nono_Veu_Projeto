"""Original, short bronze-like menu tick; Python standard library only."""
from pathlib import Path
import math
import struct
import wave


def build():
    rate, duration = 44100, 0.085
    samples = []
    for i in range(round(rate * duration)):
        t = i / rate
        attack = min(1.0, t / 0.0025)
        tail = max(0.0, 1.0 - t / duration) ** 2
        tone = (math.sin(math.tau * 1046.5 * t) * math.exp(-t * 55)
                + 0.32 * math.sin(math.tau * 2098 * t) * math.exp(-t * 85)
                + 0.12 * math.sin(math.tau * 3172 * t) * math.exp(-t * 120))
        samples.append(round(tone * attack * tail * 0.34 * 32767))
    target = Path(__file__).resolve().parents[2] / "assets/audio/ui/menu_select.wav"
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as out:
        out.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        out.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    print(f"{target}: {duration:.3f}s, peak={max(abs(s) for s in samples)/32767:.3f}")


if __name__ == "__main__":
    build()
