"""Synthesize the speech-like babble banks used by the portrait dialogue.

Each speaker gets one bank per portrait expression. A bank holds short nonsense
syllables in four categories, as in Celeste: passage, emphasis and the two
sentence endings. Glottal pulse + four formant resonators; no recorded voice,
no network service and no third-party package, so the sounds carry no license.

The output is deterministic: running it again rewrites identical files.

Usage: python tools/audio/build_dialogue_babble.py
"""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/dialogue_babble'
BANKS_SCRIPT = ROOT / 'scripts/audio/dialogue_babble_banks.gd'
RES_OUT = 'res://assets/audio/dialogue_babble'
SR = 22050

# F1-F4 of an average adult voice; the speaker profile scales the vocal tract.
VOWELS = {
    'a': (730, 1250, 2500, 3400),
    'e': (480, 1850, 2550, 3400),
    'i': (300, 2200, 2900, 3400),
    'o': (500, 900, 2450, 3400),
    'u': (330, 780, 2350, 3400),
}
BANDWIDTHS = (60, 90, 120, 200)
VOWEL_PITCH = {'a': .97, 'e': 1.0, 'i': 1.04, 'o': .99, 'u': 1.035}  # closed vowels sit higher
NASAL = (260, 1100, 2300, 3300)
PLOSIVES = set('pbtdkg')
VOICELESS = set('ptk')
FRICATIVES = set('sfvzxj')
NASALS = set('mn')
LIQUIDS = set('lr')
SYLLABLES = [('b', 'a'), ('d', 'e'), ('k', 'i'), ('n', 'o'), ('p', 'u'), ('s', 'a'), ('t', 'e'), ('m', 'i'),
             ('l', 'o'), ('r', 'u'), ('g', 'a'), ('v', 'ei')]

# Speaker names match the dialogue resources. f0 in Hz; formants: vocal tract scale;
# syllable: mean length in s; melody: random pitch spread in semitones.
SPEAKERS = {
    'SENU': dict(file='senu', f0=138, formants=1.04, syllable=.082, melody=1.6, rasp=.010, breath=.04, bright=.55),
    'PESCADOR': dict(file='fisherman', f0=94, formants=.93, syllable=.100, melody=1.0, rasp=.045, breath=.10,
                     bright=.38),
}
# Multipliers per portrait expression (VeilPortraitDialogue.EXPRESSIONS).
EXPRESSIONS = {
    'neutral': dict(pitch=1.00, melody=1.00, pace=1.00, rasp=1.0, breath=1.00, volume=1.00, tremor=0.0),
    'concerned': dict(pitch=1.05, melody=1.25, pace=.94, rasp=1.2, breath=1.35, volume=.90, tremor=.4),
    'sad': dict(pitch=.91, melody=.55, pace=1.20, rasp=1.0, breath=1.80, volume=.72, tremor=0.0),
    'resolute': dict(pitch=.97, melody=.75, pace=.92, rasp=1.5, breath=.75, volume=1.05, tremor=0.0),
}
# count, length factor, pitch fall across the syllable, pitch factor, consonant force, peak
CATEGORIES = {
    'passage': (10, .90, .04, 1.00, 1.00, .60),
    'emphasis': (4, 1.25, .08, 1.12, 1.25, .75),
    'end_statement': (3, 1.60, .18, .97, 1.00, .60),
    'end_question': (3, 1.50, -.30, 1.05, 1.00, .60),
}


class Resonator:
    """Two-pole formant filter (Klatt)."""

    def __init__(self):
        self.y1 = self.y2 = self.a = self.b = self.c = 0.0

    def tune(self, freq: float, width: float) -> None:
        r = math.exp(-math.pi * width / SR)
        self.c = -r * r
        self.b = 2 * r * math.cos(2 * math.pi * min(freq, SR * .45) / SR)
        self.a = 1 - self.b - self.c

    def __call__(self, x: float) -> float:
        y = self.a * x + self.b * self.y1 + self.c * self.y2
        self.y2, self.y1 = self.y1, y
        return y


def glottal_pulse(phase: float, closing: float, opening: float = .42) -> float:
    """Rosenberg pulse: opens slowly, closes fast."""
    if phase < opening:
        return .5 * (1 - math.cos(math.pi * phase / opening))
    if phase < opening + closing:
        return math.cos(math.pi * (phase - opening) / (2 * closing))
    return 0.0


class Voice:
    def __init__(self, speaker: dict, expression: str, seed: int):
        e = EXPRESSIONS[expression]
        self.p = dict(speaker, f0=speaker['f0'] * e['pitch'], melody=speaker['melody'] * e['melody'],
                      syllable=speaker['syllable'] * e['pace'], rasp=speaker['rasp'] * e['rasp'],
                      breath=speaker['breath'] * e['breath'])
        self.volume, self.tremor = e['volume'], e['tremor']
        self.closing = .08 + (.6 - speaker['bright']) * .3
        self.rng = random.Random(seed)
        self.tract = [Resonator() for _ in range(4)]
        self.phase = self.previous = self.clock = 0.0
        self.jitter = self.shimmer = 1.0
        self.out: list[float] = []

    def silence(self, seconds: float) -> None:
        self.out.extend([0.0] * int(seconds * SR))

    def noise(self, seconds: float, amp: float, hiss: bool = True) -> None:
        n, before = max(1, int(seconds * SR)), 0.0
        for i in range(n):
            w = self.rng.uniform(-1, 1)
            self.out.append(((w - before) if hiss else (w + before) * .5) * amp * math.sin(math.pi * i / n))
            before = w

    def voiced(self, seconds, f0_start, f0_end, shape_start, shape_end, amp, attack=.010, release=.030) -> None:
        p, n, raw = self.p, max(1, int(seconds * SR)), []
        for i in range(n):
            t = i / n
            if i % 32 == 0:
                for j, res in enumerate(self.tract):
                    res.tune((shape_start[j] + (shape_end[j] - shape_start[j]) * t) * p['formants'], BANDWIDTHS[j])
            self.clock += 1 / SR
            vibrato = 1 + .006 * math.sin(2 * math.pi * 5.3 * self.clock) \
                + self.tremor * .025 * math.sin(2 * math.pi * 8.5 * self.clock)
            self.phase += (f0_start + (f0_end - f0_start) * t) * vibrato * self.jitter / SR
            if self.phase >= 1.0:
                self.phase -= 1.0
                self.jitter = 1 + self.rng.gauss(0, p['rasp'])
                self.shimmer = 1 + self.rng.gauss(0, p['rasp'] * 3)
            g = glottal_pulse(self.phase, self.closing)
            # The derivative of the pulse adds lip radiation; breath noise follows the opening.
            y = (g - self.previous) * self.shimmer + self.rng.uniform(-1, 1) * p['breath'] * (.3 + g) * .15
            self.previous = g
            for res in self.tract:
                y = res(y)
            raw.append(y)
        peak = max(1e-9, max(abs(v) for v in raw))
        a, s = attack * SR, release * SR
        for i, v in enumerate(raw):
            tremolo = 1 - self.tremor * .25 * (.5 + .5 * math.sin(2 * math.pi * 8.5 * i / SR))
            self.out.append(v / peak * amp * self.volume * tremolo * min(1.0, i / a, (n - i) / s))

    def syllable(self, onset: str, nucleus: str, f0: float, seconds: float, fall: float, force: float) -> None:
        start, end = VOWELS[nucleus[0]], VOWELS[nucleus[-1]]
        f0 *= VOWEL_PITCH[nucleus[0]]
        if onset in PLOSIVES:
            self.silence(.012)
            self.noise(.010 if onset in VOICELESS else .006, (.30 if onset in VOICELESS else .13) * force)
        elif onset in FRICATIVES:
            self.noise(.045, .14 if onset in 'sxf' else .08, hiss=onset in 'sxz')
        elif onset in NASALS:
            self.voiced(.035, f0, f0, NASAL, NASAL, .4, release=.004)
        elif onset in LIQUIDS:
            start = tuple((a + b) / 2 for a, b in zip(start, (380, 1250, 2500, 3400)))
        self.voiced(seconds, f0 * (1 + fall / 2), f0 * (1 - fall / 2), start, end, .9 * min(force, 1.1))

    def pitch(self) -> float:
        return self.p['f0'] * 2 ** (self.rng.uniform(-1, 1) * self.p['melody'] / 12)


def finish(samples: list[float], peak: float) -> list[float]:
    """Remove DC, add a short room so syllables blend, normalize and soft-limit."""
    out, x_before, y_before = [], 0.0, 0.0
    for x in samples + [0.0] * int(.05 * SR):
        y_before = .995 * (y_before + x - x_before)
        x_before = x
        out.append(y_before)
    dry = out[:]
    for delay, gain in ((int(.023 * SR), .12), (int(.041 * SR), .07)):
        for i in range(delay, len(out)):
            out[i] += dry[i - delay] * gain
    top = max(1e-9, max(abs(v) for v in out))
    out = [math.tanh(v / top * peak * 1.1) / math.tanh(1.1) for v in out]
    for k in range(min(len(out), int(.005 * SR))):  # no click at the end
        out[-1 - k] *= k / (.005 * SR)
    return out


def write_wav(samples: list[float], path: Path) -> None:
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b''.join(struct.pack('<h', round(max(-1.0, min(1.0, v)) * 32767)) for v in samples))


def build() -> dict:
    OUT.mkdir(parents=True, exist_ok=True)
    banks: dict = {}
    for speaker, profile in SPEAKERS.items():
        for expression, mood in EXPRESSIONS.items():
            for category, (count, length, fall, lift, force, peak) in CATEGORIES.items():
                files = []
                for k in range(count):
                    seed = k * 31 + sum(map(ord, speaker + expression + category))
                    voice = Voice(profile, expression, seed)
                    onset, nucleus = SYLLABLES[(k + sum(map(ord, category))) % len(SYLLABLES)]
                    voice.syllable(onset, nucleus, voice.pitch() * lift, voice.p['syllable'] * length, fall, force)
                    name = f"{profile['file']}_{expression}_{category}_{k + 1:02d}.wav"
                    write_wav(finish(voice.out, peak * mood['volume']), OUT / name)
                    files.append(name)
                banks.setdefault(speaker, {}).setdefault(expression, {})[category] = files
    return banks


def write_banks_script(banks: dict) -> None:
    lines = ['extends RefCounted',
             '## Generated by tools/audio/build_dialogue_babble.py. Do not edit by hand.',
             '## Speaker -> portrait expression -> category -> syllables.', '', 'const BANKS := {']
    for s, speaker in enumerate(banks):
        lines.append(f'\t"{speaker}": {{')
        for e, expression in enumerate(banks[speaker]):
            lines.append(f'\t\t"{expression}": {{')
            categories = banks[speaker][expression]
            for c, category in enumerate(categories):
                streams = ', '.join(f'preload("{RES_OUT}/{name}")' for name in categories[category])
                lines.append(f'\t\t\t"{category}": [{streams}]' + (',' if c < len(categories) - 1 else ''))
            lines.append('\t\t}' + (',' if e < len(banks[speaker]) - 1 else ''))
        lines.append('\t}' + (',' if s < len(banks) - 1 else ''))
    lines.append('}')
    BANKS_SCRIPT.parent.mkdir(parents=True, exist_ok=True)
    BANKS_SCRIPT.write_text('\n'.join(lines) + '\n', encoding='utf8', newline='\n')


if __name__ == '__main__':
    result = build()
    write_banks_script(result)
    total = sum(len(f) for s in result.values() for e in s.values() for f in e.values())
    print(f'{total} syllables in {OUT.relative_to(ROOT)}; banks in {BANKS_SCRIPT.relative_to(ROOT)}')
