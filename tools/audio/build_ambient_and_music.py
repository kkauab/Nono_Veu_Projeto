"""Synthesize ambient soundscapes and the beggar's extended open-sea maritime suite.

Multi-movement Seafaring Composition:
  - Movement 1: Giga dos Pescadores (6/8, ~96 BPM) - Bouncy rolling wave gigue.
  - Movement 2: Reel do Marujo / Dança do Vento Bravo (4/4, ~128 BPM) - Fast syncopated
    Mediterranean sea reel with lively wooden body knocks and rapid virtuosic runs.
  - Movement 3: Valsa da Maré ao Pôr do Sol (3/4, ~84 BPM) - Poetic, soaring sea waltz
    with arpeggiated nylon strings and lyrical high melody.
  - Movement 4: Grande Final do Horizonte (6/8, ~104 BPM) - Energetic return of the sea
    wind, soaring climax on high G5, and grand resolving nautical cadence.
  Total length: ~58 seconds of varied, playful, authentic open-sea music in seamless loop!

Output:
  assets/audio/ambient/harbor_wind_loop.wav
  assets/audio/ambient/sanctuary_drone_loop.wav
  assets/audio/music/beggar_oud_melody.wav
  assets/audio/music/beggar_oud_riff.wav

Usage: python tools/audio/build_ambient_and_music.py
"""
import math
import random
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AMBIENT_OUT = ROOT / 'assets/audio/ambient'
MUSIC_OUT = ROOT / 'assets/audio/music'

SR_AMBIENT = 22050
SR_MUSIC = 44100


# --- Filters & Building Blocks -----------------------------------------------

class Biquad:
    """RBJ 2nd-order biquad filter (lp, hp, bp)."""

    def __init__(self, kind: str, freq: float, q: float = 0.707, sr: int = SR_MUSIC):
        self.kind = kind
        self.sr = sr
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self.set(freq, q)

    def set(self, freq: float, q: float = 0.707):
        freq = min(max(freq, 20.0), self.sr * 0.45)
        w = 2.0 * math.pi * freq / self.sr
        cw = math.cos(w)
        alpha = math.sin(w) / (2.0 * max(0.001, q))
        if self.kind == 'lp':
            b0, b1, b2 = (1.0 - cw) * 0.5, 1.0 - cw, (1.0 - cw) * 0.5
        elif self.kind == 'hp':
            b0, b1, b2 = (1.0 + cw) * 0.5, -(1.0 + cw), (1.0 + cw) * 0.5
        else: # bp
            b0, b1, b2 = alpha, 0.0, -alpha
        a0 = 1.0 + alpha
        self.b0, self.b1, self.b2 = b0 / a0, b1 / a0, b2 / a0
        self.a1, self.a2 = -2.0 * cw / a0, (1.0 - alpha) / a0

    def __call__(self, x: float) -> float:
        y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x2, self.x1 = self.x1, x
        self.y2, self.y1 = self.y1, y
        return y


def write_wav(path: Path, samples: list[float], sr: int, loop: bool = False):
    """Write 16-bit mono PCM WAV with optional smpl loop chunk for Godot."""
    path.parent.mkdir(parents=True, exist_ok=True)
    clamped = [max(-32767, min(32767, int(round(v * 32767.0)))) for v in samples]
    data = b''.join(struct.pack('<h', v) for v in clamped)
    chunks = struct.pack('<4sIHHIIHH', b'fmt ', 16, 1, 1, sr, sr * 2, 2, 16)
    chunks += struct.pack('<4sI', b'data', len(data)) + data
    if loop:
        smpl = struct.pack('<9I', 0, 0, round(1e9 / sr), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack('<6I', 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += struct.pack('<4sI', b'smpl', len(smpl)) + smpl
    header = struct.pack('<4sI4s', b'RIFF', 4 + len(chunks), b'WAVE')
    path.write_bytes(header + chunks)


def crossfade_loop(samples: list[float], fade_samples: int) -> list[float]:
    """Crossfade head and tail so loop point is completely clickless and seamless."""
    fade_len = min(fade_samples, len(samples) // 3)
    out = samples[:-fade_len]
    tail = samples[-fade_len:]
    for i in range(fade_len):
        weight = float(i) / float(fade_len)
        out[i] = out[i] * weight + tail[i] * (1.0 - weight)
    return out


# --- Reverb ------------------------------------------------------------------

class SchroederReverb:
    """Bright acoustic pier & colonnade reverberation."""

    def __init__(self, sr: int = SR_MUSIC):
        self.comb_delays = [int(0.0211 * sr), int(0.0283 * sr), int(0.0347 * sr), int(0.0419 * sr)]
        self.comb_bufs = [[0.0] * d for d in self.comb_delays]
        self.comb_ptrs = [0] * 4
        self.comb_feedback = [0.77, 0.75, 0.73, 0.71]
        self.comb_damps = [0.28, 0.28, 0.28, 0.28]
        self.comb_filters = [0.0] * 4

        self.ap_delays = [int(0.0043 * sr), int(0.0015 * sr)]
        self.ap_bufs = [[0.0] * d for d in self.ap_delays]
        self.ap_ptrs = [0, 0]
        self.ap_gain = 0.58

    def process_sample(self, x: float) -> float:
        comb_sum = 0.0
        for i in range(4):
            ptr = self.comb_ptrs[i]
            d = self.comb_delays[i]
            y = self.comb_bufs[i][ptr]
            self.comb_filters[i] = y * (1.0 - self.comb_damps[i]) + self.comb_filters[i] * self.comb_damps[i]
            self.comb_bufs[i][ptr] = x + self.comb_filters[i] * self.comb_feedback[i]
            self.comb_ptrs[i] = (ptr + 1) % d
            comb_sum += y

        out = comb_sum * 0.25
        for i in range(2):
            ptr = self.ap_ptrs[i]
            d = self.ap_delays[i]
            delayed = self.ap_bufs[i][ptr]
            v = out - self.ap_gain * delayed
            self.ap_bufs[i][ptr] = out
            self.ap_ptrs[i] = (ptr + 1) % d
            out = delayed + self.ap_gain * v
        return out


# --- Physical Model: Plucked Lute / Oud ---------------------------------------

class OudString:
    """Snappy Karplus-Strong string with fractional delay and brightness control."""

    def __init__(self, freq: float, sr: int = SR_MUSIC, brightness: float = 0.90):
        self.sr = sr
        self.freq = freq
        period = sr / max(20.0, freq)
        self.delay_len = max(2, int(period))
        self.frac = period - self.delay_len
        self.buf = [0.0] * (self.delay_len + 2)
        self.ptr = 0
        self.prev = 0.0
        self.decay = math.exp(-1.15 / (0.45 + 240.0 / freq))
        self.brightness = brightness

    def pluck(self, rng: random.Random, velocity: float = 0.85):
        cutoff = min(self.freq * 8.5 * (0.7 + velocity * 0.5), self.sr * 0.44)
        lp = Biquad('lp', cutoff, 0.8, self.sr)
        for i in range(self.delay_len):
            raw = rng.uniform(-1.0, 1.0) * velocity
            if i < 3:
                raw += (1.0 - i * 0.33) * 1.8 * velocity
            self.buf[i] = lp(raw)
        self.ptr = 0
        self.prev = 0.0

    def sample(self) -> float:
        p0 = self.ptr
        p1 = (self.ptr + 1) % self.delay_len
        val = self.buf[p0] * (1.0 - self.frac) + self.buf[p1] * self.frac
        filtered = (val + self.prev) * 0.5
        self.prev = val
        self.buf[self.ptr] = filtered * self.decay
        self.ptr = (self.ptr + 1) % self.delay_len
        return val


class OudBody:
    """Acoustic resonant soundboard."""

    def __init__(self, sr: int = SR_MUSIC):
        self.helmholtz = Biquad('bp', 130.0, 3.0, sr)
        self.plate = Biquad('bp', 260.0, 2.5, sr)
        self.upper = Biquad('bp', 600.0, 2.0, sr)
        self.presence = Biquad('bp', 1600.0, 1.8, sr)

    def process(self, x: float) -> float:
        body = (self.helmholtz(x) * 0.30 +
                self.plate(x) * 0.40 +
                self.upper(x) * 0.30 +
                self.presence(x) * 0.20)
        return x * 0.55 + body * 0.45


def wood_tap(sr: int, vel: float = 0.7) -> list[float]:
    """Acoustic knock/body tap on the wooden soundboard (foot tap / golpe)."""
    samples = int(0.06 * sr)
    out = [0.0] * samples
    lp = Biquad('lp', 280.0, 1.2, sr)
    for i in range(samples):
        t = float(i) / float(sr)
        freq = 190.0 * math.exp(-t / 0.012)
        sine = math.sin(2.0 * math.pi * freq * t) * math.exp(-t / 0.022)
        noise = (random.uniform(-1.0, 1.0) if i < int(0.008 * sr) else 0.0) * 0.6
        val = lp(sine + noise) * vel
        out[i] = val
    return out


# --- Music Generation: Extended 4-Movement Open-Sea Maritime Suite ------------

def build_beggar_music() -> tuple[list[float], list[float]]:
    """Synthesize an extended, multi-rhythmic open-sea seafaring suite (~58s)."""
    rng = random.Random(1042)
    sr = SR_MUSIC
    body = OudBody(sr)
    reverb = SchroederReverb(sr)

    NOTES = {
        'G2': 98.00, 'A2': 110.00, 'B2': 123.47, 'C3': 130.81, 'D3': 146.83, 'E3': 164.81, 'F#3': 185.00,
        'G3': 196.00, 'A3': 220.00, 'B3': 246.94, 'C4': 261.63, 'D4': 293.66,
        'E4': 329.63, 'F4': 349.23, 'F#4': 369.99, 'G4': 392.00, 'A4': 440.00,
        'B4': 493.88, 'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'G5': 783.99
    }

    CHORDS = {
        'G': ('G2', ['G3', 'B3', 'D4']),
        'C': ('C3', ['G3', 'C4', 'E4']),
        'D': ('D3', ['F#3', 'A3', 'D4']),
        'Em': ('E3', ['G3', 'B3', 'E4']),
        'Am': ('A2', ['E3', 'A3', 'C4']),
        'Bm': ('B2', ['F#3', 'B3', 'D4'])
    }

    # Movement timing parameters
    # M1: 6/8 Sailor Gigue (12 measures, dotted-quarter=96 BPM -> eighth=0.2083s)
    M1_EIGHTH = (60.0 / 96.0) / 3.0
    M1_MEASURE = M1_EIGHTH * 6.0
    M1_START = 0.0
    M1_DUR = 12 * M1_MEASURE  # ~15.00s

    # M2: 4/4 Malfuf / Sea Reel (16 measures, quarter=128 BPM -> quarter=0.46875s)
    M2_BEAT = 60.0 / 128.0
    M2_MEASURE = M2_BEAT * 4.0
    M2_START = M1_START + M1_DUR
    M2_DUR = 16 * M2_MEASURE  # ~15.00s

    # M3: 3/4 Sunset Sea Waltz (16 measures, quarter=84 BPM -> quarter=0.71428s)
    M3_BEAT = 60.0 / 84.0
    M3_MEASURE = M3_BEAT * 3.0
    M3_START = M2_START + M2_DUR
    M3_DUR = 16 * M3_MEASURE  # ~17.14s

    # M4: 6/8 Grand Horizon Finale (12 measures, dotted-quarter=104 BPM -> eighth=0.1923s)
    M4_EIGHTH = (60.0 / 104.0) / 3.0
    M4_MEASURE = M4_EIGHTH * 6.0
    M4_START = M3_START + M3_DUR
    M4_DUR = 12 * M4_MEASURE  # ~13.84s

    total_seconds = M4_START + M4_DUR + 2.0
    total_samples = int(total_seconds * sr)
    buffer = [0.0] * total_samples

    # Helper function to add note to buffer
    def add_note(time_s: float, note_name: str, dur_s: float, vel: float, has_vib: bool = False, gain: float = 1.0):
        s_idx = int(time_s * sr)
        if s_idx >= total_samples:
            return
        freq = NOTES[note_name]
        st = OudString(freq, sr, brightness=0.92)
        st.pluck(rng, vel)
        dur = int(dur_s * 1.8 * sr)
        for i in range(min(dur, total_samples - s_idx)):
            if has_vib and i > int(0.18 * sr):
                t_vib = (i - 0.18 * sr) / sr
                vib = math.sin(2.0 * math.pi * 5.8 * t_vib) * 0.003
                st.frac = (st.frac + vib) % 1.0
            buffer[s_idx + i] += st.sample() * gain

    def add_tap(time_s: float, vel: float = 0.65):
        s_idx = int(time_s * sr)
        tap = wood_tap(sr, vel)
        for i in range(min(len(tap), total_samples - s_idx)):
            buffer[s_idx + i] += tap[i]

    # =========================================================================
    # MOVEMENT 1: 6/8 Giga dos Pescadores (Departure from the Port)
    # =========================================================================
    M1_CHORDS = ['G', 'G', 'C', 'D', 'G', 'Em', 'C', 'D', 'G', 'C', 'D', 'G']
    for m in range(12):
        m_time = M1_START + m * M1_MEASURE
        chord = M1_CHORDS[m]
        bass, triad = CHORDS[chord]

        # Beat 1 (eighth 0): Bass + tap
        add_note(m_time, bass, M1_EIGHTH * 2.5, 0.85, gain=0.9)
        add_tap(m_time, 0.65)

        # Eighths 1, 2: Strum
        for e in (1, 2):
            for sn in triad:
                add_note(m_time + e * M1_EIGHTH, sn, M1_EIGHTH * 1.5, 0.52, gain=0.6)

        # Beat 2 (eighth 3): Alt bass + tap
        alt = 'D3' if bass == 'G2' else bass
        add_note(m_time + 3 * M1_EIGHTH, alt, M1_EIGHTH * 2.2, 0.78, gain=0.85)
        add_tap(m_time + 3 * M1_EIGHTH, 0.55)

        # Eighths 4, 5: Strum
        for e in (4, 5):
            for sn in triad:
                add_note(m_time + e * M1_EIGHTH, sn, M1_EIGHTH * 1.5, 0.50, gain=0.6)

    # M1 Melody: Rolling waves
    M1_MELODY = [
        (0, 0, 'D4', 1.0, 0.85, False), (0, 1, 'G4', 1.0, 0.90, False), (0, 2, 'A4', 1.0, 0.80, False),
        (0, 3, 'B4', 2.0, 0.95, True), (0, 5, 'D5', 1.0, 0.90, False),
        (1, 0, 'B4', 1.5, 0.85, False), (1, 2, 'A4', 1.0, 0.80, False),
        (1, 3, 'G4', 2.0, 0.90, True), (1, 5, 'D4', 1.0, 0.75, False),
        (2, 0, 'E4', 1.0, 0.80, False), (2, 1, 'G4', 1.0, 0.85, False), (2, 2, 'C5', 1.0, 0.90, False),
        (2, 3, 'B4', 1.5, 0.85, True), (2, 5, 'G4', 1.0, 0.80, False),
        (3, 0, 'A4', 2.5, 0.90, True), (3, 3, 'D4', 1.5, 0.80, False), (3, 5, 'F#4', 1.0, 0.85, False),
        (4, 0, 'G4', 1.0, 0.85, False), (4, 1, 'A4', 1.0, 0.80, False), (4, 2, 'B4', 1.0, 0.90, False),
        (4, 3, 'D5', 2.0, 0.95, True), (4, 5, 'B4', 1.0, 0.85, False),
        (5, 0, 'G4', 1.0, 0.85, False), (5, 1, 'B4', 1.0, 0.85, False), (5, 2, 'E5', 1.5, 0.95, True),
        (5, 4, 'D5', 1.0, 0.90, False), (5, 5, 'B4', 1.0, 0.85, False),
        (6, 0, 'C5', 1.0, 0.90, False), (6, 1, 'B4', 1.0, 0.80, False), (6, 2, 'A4', 1.0, 0.85, False),
        (6, 3, 'G4', 1.5, 0.85, False), (6, 5, 'A4', 1.0, 0.80, False),
        (7, 0, 'G4', 3.0, 0.95, True), (7, 4, 'D4', 1.0, 0.75, False), (7, 5, 'G4', 1.0, 0.80, False),
        (8, 0, 'B4', 1.0, 0.85, False), (8, 1, 'C5', 1.0, 0.85, False), (8, 2, 'D5', 1.0, 0.90, False),
        (8, 3, 'D5', 2.0, 0.95, True), (8, 5, 'B4', 1.0, 0.85, False),
        (9, 0, 'C5', 1.5, 0.90, False), (9, 2, 'B4', 1.0, 0.85, False), (9, 3, 'A4', 2.0, 0.85, True),
        (10, 0, 'F#4', 1.0, 0.80, False), (10, 1, 'G4', 1.0, 0.85, False), (10, 2, 'A4', 1.0, 0.90, False),
        (10, 3, 'D5', 2.5, 0.95, True),
        (11, 0, 'B4', 1.0, 0.85, False), (11, 1, 'A4', 1.0, 0.85, False), (11, 2, 'G4', 2.0, 0.95, True)
    ]
    for m_i, e_i, note, dur_e, vel, vib in M1_MELODY:
        t = M1_START + m_i * M1_MEASURE + e_i * M1_EIGHTH
        add_note(t, note, dur_e * M1_EIGHTH, vel, vib, gain=1.15)

    # =========================================================================
    # MOVEMENT 2: 4/4 Reel do Marujo / Dança do Vento Bravo (Fast Maritime Reel)
    # =========================================================================
    # Driving Malfuf / Balkan sailor pulse: DUM (beat 0) .. tek (beat 1.5) .. tek (beat 2.5) .. DUM (beat 3)
    M2_CHORDS = [
        'G', 'G', 'C', 'D',
        'G', 'Em', 'Am', 'D',
        'G', 'C', 'G', 'D',
        'Em', 'C', 'D', 'G'
    ]
    for m in range(16):
        m_time = M2_START + m * M2_MEASURE
        chord = M2_CHORDS[m]
        bass, triad = CHORDS[chord]

        # Beat 0: Heavy bass + wood knock
        add_note(m_time, bass, M2_BEAT * 1.5, 0.90, gain=0.95)
        add_tap(m_time, 0.75)

        # Offbeat syncopated strums at 0.5, 1.5, 2.5
        for off in (0.75, 1.5, 2.25):
            for sn in triad:
                add_note(m_time + off * M2_BEAT, sn, M2_BEAT * 0.7, 0.55, gain=0.62)

        # Beat 3: Anchor stroke + soft tap
        add_note(m_time + 3.0 * M2_BEAT, bass, M2_BEAT * 0.9, 0.82, gain=0.85)
        add_tap(m_time + 3.0 * M2_BEAT, 0.58)

    # Fast virtuosic reel melody in sixteenths and eighths
    M2_MELODY = [
        # Phrase 1: Spirited reel hook
        (0, 0.0, 'G4', 0.5, 0.85), (0, 0.5, 'A4', 0.5, 0.85), (0, 1.0, 'B4', 0.5, 0.90), (0, 1.5, 'C5', 0.5, 0.90),
        (0, 2.0, 'D5', 1.0, 0.95), (0, 3.0, 'B4', 1.0, 0.85),
        (1, 0.0, 'D5', 0.5, 0.90), (1, 0.5, 'C5', 0.5, 0.85), (1, 1.0, 'B4', 0.5, 0.85), (1, 1.5, 'A4', 0.5, 0.85),
        (1, 2.0, 'G4', 1.0, 0.90), (1, 3.0, 'D4', 1.0, 0.80),
        # Phrase 2: C to D gallop
        (2, 0.0, 'E4', 0.5, 0.85), (2, 0.5, 'G4', 0.5, 0.85), (2, 1.0, 'C5', 1.0, 0.95),
        (2, 2.0, 'B4', 0.5, 0.85), (2, 2.5, 'A4', 0.5, 0.85), (2, 3.0, 'G4', 1.0, 0.85),
        (3, 0.0, 'A4', 1.5, 0.90), (3, 1.5, 'B4', 0.5, 0.85), (3, 2.0, 'A4', 1.0, 0.90), (3, 3.0, 'D5', 1.0, 0.95),
        # Phrase 3: High sailor leaps
        (4, 0.0, 'D5', 0.5, 0.95), (4, 0.5, 'E5', 0.5, 0.95), (4, 1.0, 'D5', 0.5, 0.90), (4, 1.5, 'B4', 0.5, 0.90),
        (4, 2.0, 'G4', 1.0, 0.90), (4, 3.0, 'B4', 1.0, 0.85),
        (5, 0.0, 'E5', 1.5, 1.00), (5, 1.5, 'D5', 0.5, 0.90), (5, 2.0, 'B4', 1.0, 0.90), (5, 3.0, 'G4', 1.0, 0.85),
        (6, 0.0, 'C5', 0.5, 0.85), (6, 0.5, 'D5', 0.5, 0.90), (6, 1.0, 'E5', 0.5, 0.95), (6, 1.5, 'D5', 0.5, 0.90),
        (6, 2.0, 'C5', 0.5, 0.85), (6, 2.5, 'B4', 0.5, 0.85), (6, 3.0, 'A4', 1.0, 0.85),
        (7, 0.0, 'D5', 1.5, 0.95), (7, 1.5, 'F#4', 0.5, 0.85), (7, 2.0, 'G4', 2.0, 0.95),
        # Phrase 4: Staccato sailor dance variations
        (8, 0.0, 'B4', 0.5, 0.90), (8, 0.5, 'D5', 0.5, 0.90), (8, 1.0, 'B4', 0.5, 0.85), (8, 1.5, 'G4', 0.5, 0.85),
        (8, 2.0, 'A4', 0.5, 0.85), (8, 2.5, 'B4', 0.5, 0.85), (8, 3.0, 'G4', 1.0, 0.90),
        (9, 0.0, 'C5', 0.5, 0.90), (9, 0.5, 'E5', 0.5, 0.95), (9, 1.0, 'D5', 0.5, 0.90), (9, 1.5, 'C5', 0.5, 0.85),
        (9, 2.0, 'B4', 1.0, 0.85), (9, 3.0, 'A4', 1.0, 0.85),
        (10, 0.0, 'G4', 0.5, 0.85), (10, 0.5, 'B4', 0.5, 0.85), (10, 1.0, 'D5', 1.0, 0.95),
        (10, 2.0, 'E5', 0.5, 0.95), (10, 2.5, 'D5', 0.5, 0.90), (10, 3.0, 'B4', 1.0, 0.90),
        (11, 0.0, 'A4', 1.0, 0.90), (11, 1.0, 'B4', 1.0, 0.90), (11, 2.0, 'D5', 2.0, 0.98),
        # Phrase 5: Ascending wave into transition
        (12, 0.0, 'E5', 1.0, 0.95), (12, 1.0, 'D5', 1.0, 0.90), (12, 2.0, 'B4', 1.0, 0.90), (12, 3.0, 'G4', 1.0, 0.85),
        (13, 0.0, 'A4', 0.5, 0.85), (13, 0.5, 'B4', 0.5, 0.85), (13, 1.0, 'C5', 1.0, 0.90),
        (13, 2.0, 'B4', 1.0, 0.85), (13, 3.0, 'A4', 1.0, 0.85),
        (14, 0.0, 'D5', 1.0, 0.95), (14, 1.0, 'C5', 0.5, 0.85), (14, 1.5, 'B4', 0.5, 0.85),
        (14, 2.0, 'A4', 1.0, 0.90), (14, 3.0, 'F#4', 1.0, 0.85),
        (15, 0.0, 'G4', 3.0, 0.95)
    ]
    for m_i, b_i, note, dur_b, vel in M2_MELODY:
        t = M2_START + m_i * M2_MEASURE + b_i * M2_BEAT
        add_note(t, note, dur_b * M2_BEAT, vel, gain=1.18)

    # =========================================================================
    # MOVEMENT 3: 3/4 Valsa da Maré ao Pôr do Sol (Poetic Open Sea Waltz)
    # =========================================================================
    # Rolling 3/4 sea waltz: Bass on beat 0, rolling nylon arpeggio on beats 1 & 2
    M3_CHORDS = [
        'G', 'Em', 'C', 'D',
        'G', 'Bm', 'C', 'D',
        'Em', 'C', 'G', 'D',
        'C', 'D', 'G', 'G'
    ]
    for m in range(16):
        m_time = M3_START + m * M3_MEASURE
        chord = M3_CHORDS[m]
        bass, triad = CHORDS[chord]

        # Beat 0: Deep resonant bass
        add_note(m_time, bass, M3_BEAT * 2.8, 0.85, gain=0.92)
        add_tap(m_time, 0.45)

        # Beats 1 & 2: Arpeggiated waltz strum
        for b in (1, 2):
            for sn_i, sn in enumerate(triad):
                delay = sn_i * 0.028
                add_note(m_time + b * M3_BEAT + delay, sn, M3_BEAT * 1.8, 0.48, gain=0.55)

    # Lyrical, soaring, romantic sea melody
    M3_MELODY = [
        (0, 0.0, 'D5', 2.0, 0.95, True), (0, 2.0, 'C5', 1.0, 0.85, False),
        (1, 0.0, 'B4', 2.0, 0.90, True), (1, 2.0, 'G4', 1.0, 0.85, False),
        (2, 0.0, 'E4', 1.0, 0.85, False), (2, 1.0, 'G4', 1.0, 0.85, False), (2, 2.0, 'C5', 1.0, 0.90, False),
        (3, 0.0, 'B4', 1.5, 0.90, True), (3, 1.5, 'A4', 1.5, 0.85, False),
        (4, 0.0, 'G4', 2.0, 0.90, True), (4, 2.0, 'B4', 1.0, 0.85, False),
        (5, 0.0, 'D5', 2.0, 0.95, True), (5, 2.0, 'B4', 1.0, 0.85, False),
        (6, 0.0, 'C5', 1.0, 0.90, False), (6, 1.0, 'D5', 1.0, 0.92, False), (6, 2.0, 'E5', 1.0, 0.96, True),
        (7, 0.0, 'D5', 3.0, 0.95, True),
        (8, 0.0, 'E5', 2.0, 0.96, True), (8, 2.0, 'D5', 1.0, 0.90, False),
        (9, 0.0, 'C5', 2.0, 0.90, True), (9, 2.0, 'B4', 1.0, 0.85, False),
        (10, 0.0, 'G4', 1.5, 0.85, False), (10, 1.5, 'B4', 1.5, 0.90, True),
        (11, 0.0, 'A4', 3.0, 0.90, True),
        (12, 0.0, 'C5', 1.0, 0.90, False), (12, 1.0, 'B4', 1.0, 0.85, False), (12, 2.0, 'A4', 1.0, 0.85, False),
        (13, 0.0, 'D5', 2.0, 0.95, True), (13, 2.0, 'F#4', 1.0, 0.85, False),
        (14, 0.0, 'G4', 3.0, 0.95, True),
        (15, 0.0, 'B4', 1.0, 0.85, False), (15, 1.0, 'D5', 1.0, 0.90, False), (15, 2.0, 'G5', 1.0, 0.98, True)
    ]
    for m_i, b_i, note, dur_b, vel, vib in M3_MELODY:
        t = M3_START + m_i * M3_MEASURE + b_i * M3_BEAT
        add_note(t, note, dur_b * M3_BEAT, vel, vib, gain=1.12)

    # =========================================================================
    # MOVEMENT 4: 6/8 Grande Final do Horizonte (Return of the Sea Wind)
    # =========================================================================
    # Energetic, driving return to 6/8 at brisk 104 BPM
    M4_CHORDS = ['G', 'C', 'D', 'G', 'Em', 'C', 'D', 'G', 'C', 'D', 'G', 'G']
    for m in range(12):
        m_time = M4_START + m * M4_MEASURE
        chord = M4_CHORDS[m]
        bass, triad = CHORDS[chord]

        # Beat 1 (eighth 0): Bass + strong wood tap
        add_note(m_time, bass, M4_EIGHTH * 2.8, 0.92, gain=0.95)
        add_tap(m_time, 0.78)

        # Eighths 1, 2: Energetic chord strums
        for e in (1, 2):
            for sn in triad:
                add_note(m_time + e * M4_EIGHTH, sn, M4_EIGHTH * 1.6, 0.58, gain=0.65)

        # Beat 2 (eighth 3): Secondary bass + tap
        alt = 'D3' if bass == 'G2' else bass
        add_note(m_time + 3 * M4_EIGHTH, alt, M4_EIGHTH * 2.4, 0.84, gain=0.88)
        add_tap(m_time + 3 * M4_EIGHTH, 0.65)

        # Eighths 4, 5: Strums
        for e in (4, 5):
            for sn in triad:
                add_note(m_time + e * M4_EIGHTH, sn, M4_EIGHTH * 1.6, 0.55, gain=0.65)

    # Triumphant finale melody climbing to soaring high G5!
    M4_MELODY = [
        (0, 0, 'D5', 1.5, 0.95, False), (0, 2, 'B4', 1.0, 0.90, False), (0, 3, 'G4', 2.0, 0.90, True), (0, 5, 'B4', 1.0, 0.85, False),
        (1, 0, 'C5', 1.0, 0.90, False), (1, 1, 'D5', 1.0, 0.92, False), (1, 2, 'E5', 1.0, 0.96, False),
        (1, 3, 'G5', 2.5, 1.05, True), # High crest of the journey!
        (2, 0, 'F#4', 1.0, 0.85, False), (2, 1, 'G4', 1.0, 0.85, False), (2, 2, 'A4', 1.0, 0.90, False),
        (2, 3, 'D5', 2.5, 0.98, True),
        (3, 0, 'B4', 1.0, 0.90, False), (3, 1, 'A4', 1.0, 0.85, False), (3, 2, 'G4', 1.0, 0.85, False),
        (3, 3, 'D4', 2.5, 0.85, False),
        (4, 0, 'E5', 1.5, 1.00, True), (4, 2, 'D5', 1.0, 0.90, False), (4, 3, 'B4', 2.0, 0.90, True), (4, 5, 'G4', 1.0, 0.85, False),
        (5, 0, 'C5', 1.0, 0.90, False), (5, 1, 'B4', 1.0, 0.85, False), (5, 2, 'A4', 1.0, 0.85, False),
        (5, 3, 'G4', 1.5, 0.85, False), (5, 5, 'A4', 1.0, 0.85, False),
        (6, 0, 'B4', 1.0, 0.90, False), (6, 1, 'C5', 1.0, 0.90, False), (6, 2, 'D5', 1.0, 0.95, False),
        (6, 3, 'D5', 2.0, 0.98, True), (6, 5, 'F#4', 1.0, 0.85, False),
        (7, 0, 'G4', 3.0, 1.00, True),
        (8, 0, 'C5', 1.0, 0.90, False), (8, 1, 'D5', 1.0, 0.92, False), (8, 2, 'E5', 1.0, 0.96, False),
        (8, 3, 'E5', 2.0, 0.95, True), (8, 5, 'C5', 1.0, 0.85, False),
        (9, 0, 'D5', 1.0, 0.95, False), (9, 1, 'C5', 1.0, 0.90, False), (9, 2, 'B4', 1.0, 0.90, False),
        (9, 3, 'A4', 2.0, 0.92, True), (9, 5, 'D4', 1.0, 0.85, False),
        (10, 0, 'G4', 1.0, 0.90, False), (10, 1, 'B4', 1.0, 0.92, False), (10, 2, 'D5', 1.0, 0.96, False),
        (10, 3, 'G5', 2.5, 1.05, True),
        # Measure 11: Grand ringing final chord that resolves directly into Movement 1
        (11, 0, 'G4', 3.0, 1.00, True), (11, 3, 'D4', 1.5, 0.85, False), (11, 5, 'G4', 1.0, 0.90, False)
    ]
    for m_i, e_i, note, dur_e, vel, vib in M4_MELODY:
        t = M4_START + m_i * M4_MEASURE + e_i * M4_EIGHTH
        add_note(t, note, dur_e * M4_EIGHTH, vel, vib, gain=1.20)

    # 4. Apply Resonant Acoustic Wooden Body & Pier Reverberation
    out = [0.0] * total_samples
    for i in range(total_samples):
        x = body.process(buffer[i])
        rev = reverb.process_sample(x)
        out[i] = x * 0.78 + rev * 0.22

    # Seamless loop: crossfade 2.0s
    fade_len = int(2.0 * sr)
    looped_melody = crossfade_loop(out, fade_len)

    peak = max(abs(v) for v in looped_melody) or 1.0
    looped_melody = [v * 0.85 / peak for v in looped_melody]

    # --- Blessing Riff: Upbeat Sailor Flourish ---
    RIFF = [
        (0.0, 'G3', 0.6, 0.85),
        (0.12, 'B3', 0.6, 0.85),
        (0.24, 'D4', 0.6, 0.90),
        (0.36, 'G4', 0.6, 0.92),
        (0.48, 'B4', 0.7, 0.95),
        (0.62, 'D5', 0.8, 0.98),
        (0.78, 'G5', 1.8, 1.00)
    ]
    riff_total_sec = 2.4
    riff_samples = int(riff_total_sec * sr)
    riff_buf = [0.0] * riff_samples

    tap_start = wood_tap(sr, 0.7)
    for i in range(min(len(tap_start), riff_samples)):
        riff_buf[i] += tap_start[i]

    for t_s, n_name, dur_s, vel in RIFF:
        s_idx = int(t_s * sr)
        freq = NOTES[n_name]
        st = OudString(freq, sr, brightness=0.95)
        st.pluck(rng, vel)
        dur = int(dur_s * 1.8 * sr)
        for i in range(min(dur, riff_samples - s_idx)):
            riff_buf[s_idx + i] += st.sample()

    riff_out = [0.0] * riff_samples
    for i in range(riff_samples):
        x = body.process(riff_buf[i])
        rev = reverb.process_sample(x)
        riff_out[i] = x * 0.74 + rev * 0.26

    fade_tail = int(0.12 * sr)
    for i in range(fade_tail):
        riff_out[-1 - i] *= float(i) / float(fade_tail)
    peak_riff = max(abs(v) for v in riff_out) or 1.0
    riff_out = [v * 0.86 / peak_riff for v in riff_out]

    return looped_melody, riff_out


# --- Ambient Generation: Harbor Wind & Sacred Sanctuary -----------------------

def build_harbor_wind() -> list[float]:
    """Continuous evocative coastal desert night wind through stone colonnades."""
    rng = random.Random(42)
    sr = SR_AMBIENT
    seconds = 14.0
    total_samples = int(seconds * sr)

    lp = Biquad('lp', 380.0, 0.8, sr)
    bp = Biquad('bp', 240.0, 1.4, sr)
    sub = Biquad('lp', 95.0, 1.2, sr)

    out = [0.0] * total_samples
    for i in range(total_samples):
        t = float(i) / float(sr)
        mod1 = 0.5 + 0.35 * math.sin(2.0 * math.pi * 0.14 * t) + 0.15 * math.sin(2.0 * math.pi * 0.37 * t)
        mod2 = 0.5 + 0.4 * math.sin(2.0 * math.pi * 0.08 * t + 1.2)
        n = rng.uniform(-1.0, 1.0)
        low_gust = lp(n) * mod1
        whistle = bp(n) * mod2 * 0.55
        deep_rumble = sub(n) * 0.4
        out[i] = low_gust + whistle + deep_rumble

    fade_len = int(2.0 * sr)
    looped = crossfade_loop(out, fade_len)
    peak = max(abs(v) for v in looped) or 1.0
    return [v * 0.75 / peak for v in looped]


def build_sanctuary_drone() -> list[float]:
    """Ancient Egyptian sacred temple Pythagorean harmonic drone."""
    sr = SR_AMBIENT
    seconds = 12.0
    total_samples = int(seconds * sr)

    partials = [
        (110.0, 0.45, 0.12),
        (165.0, 0.35, 0.17),
        (220.0, 0.28, 0.23),
        (275.0, 0.16, 0.19),
        (330.0, 0.18, 0.29),
        (550.0, 0.08, 0.35)
    ]

    out = [0.0] * total_samples
    for freq, gain, lfo_rate in partials:
        phase = 0.0
        step = 2.0 * math.pi * freq / sr
        for i in range(total_samples):
            t = float(i) / float(sr)
            amp = gain * (0.8 + 0.2 * math.sin(2.0 * math.pi * lfo_rate * t))
            out[i] += math.sin(phase) * amp
            phase += step

    out = [math.tanh(v * 1.2) / math.tanh(1.2) for v in out]
    fade_len = int(2.0 * sr)
    looped = crossfade_loop(out, fade_len)
    peak = max(abs(v) for v in looped) or 1.0
    return [v * 0.70 / peak for v in looped]


# --- Main --------------------------------------------------------------------

def main():
    print("Synthesizing O Nono Véu audio suite...")

    print("1. Synthesizing Harbor Wind Ambience (22050 Hz)...")
    wind = build_harbor_wind()
    write_wav(AMBIENT_OUT / 'harbor_wind_loop.wav', wind, SR_AMBIENT, loop=True)
    print(f"   -> Wrote {len(wind)} samples to {AMBIENT_OUT / 'harbor_wind_loop.wav'}")

    print("2. Synthesizing Sacred Sanctuary Drone (22050 Hz)...")
    drone = build_sanctuary_drone()
    write_wav(AMBIENT_OUT / 'sanctuary_drone_loop.wav', drone, SR_AMBIENT, loop=True)
    print(f"   -> Wrote {len(drone)} samples to {AMBIENT_OUT / 'sanctuary_drone_loop.wav'}")

    print("3. Synthesizing Beggar's Extended Maritime Suite (44100 Hz, 4 Movements)...")
    melody, riff = build_beggar_music()
    write_wav(MUSIC_OUT / 'beggar_oud_melody.wav', melody, SR_MUSIC, loop=True)
    print(f"   -> Wrote {len(melody)} samples ({len(melody)/SR_MUSIC:.2f}s) to {MUSIC_OUT / 'beggar_oud_melody.wav'}")
    write_wav(MUSIC_OUT / 'beggar_oud_riff.wav', riff, SR_MUSIC, loop=False)
    print(f"   -> Wrote {len(riff)} samples to {MUSIC_OUT / 'beggar_oud_riff.wav'}")

    print("All audio generated successfully!")


if __name__ == '__main__':
    main()
