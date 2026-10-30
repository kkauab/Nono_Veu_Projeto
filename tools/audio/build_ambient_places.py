"""Leitos sonoros de cada lugar do Porto (docs/MUNDO_PROPOSTA_2026-10-30.md).

Python puro e determinístico, como build_ambient_and_music.py: cada laço usa uma
semente fixa e termina onde começa (os eventos são somados "dando a volta" no
buffer e a reverberação roda duas voltas), com o bloco `smpl` para o Godot.

Saída, em assets/audio/ambient/:
  place_surf_loop.wav    ondas na praia e no cais (docas, ilhas, farol)
  place_crowd_loop.wav   murmúrio de gente (mercado, caravanas, armazém)
  place_forge_loop.wav   fornalha, brasas e o martelo distante (Fornos)
  place_crypt_loop.wav   pingos e um zumbido grave (criptas, Arquivo, Catacumbas)
  place_water_loop.wav   água correndo nos canais (Aqueduto, Cisterna, Comportas)
  place_night_loop.wav   grilos e sapos (jardins, claustro, ilhas)
  place_chimes_loop.wav  sinos ao longe (Praça dos Três Sinos)

Uso: python tools/audio/build_ambient_places.py
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from build_ambient_and_music import Biquad, SchroederReverb, write_wav  # noqa: E402

ROOT = HERE.parents[1]
OUT = ROOT / 'assets/audio/ambient'
BABBLE = ROOT / 'assets/audio/dialogue_babble'
SR = 22050
SECONDS = 12.0
N = int(SECONDS * SR)


def normalize(samples: list[float], peak: float = 0.7) -> list[float]:
    top = max(abs(v) for v in samples) or 1.0
    return [v * peak / top for v in samples]


def add_wrapped(buffer: list[float], start: int, event: list[float], gain: float = 1.0) -> None:
    """Soma o evento no buffer circular: o que passa do fim volta pelo começo."""
    size = len(buffer)
    for index, value in enumerate(event):
        buffer[(start + index) % size] += value * gain


def loop_filter(samples: list[float], process) -> list[float]:
    """Aplica um filtro com memória em duas voltas e guarda a segunda: o estado no
    começo do laço é o do fim, e a emenda não estala."""
    for value in samples:
        process(value)
    return [process(value) for value in samples]


def loop_reverb(samples: list[float], wet: float) -> list[float]:
    reverb = SchroederReverb(SR)
    tail = loop_filter(samples, reverb.process_sample)
    return [dry * (1.0 - wet) + late * wet for dry, late in zip(samples, tail)]


def smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


# --- Ondas -------------------------------------------------------------------

def build_surf() -> list[float]:
    rng = random.Random(7101)
    # Três ondas por laço, com respiros desiguais: (início, subida, queda).
    waves = [(0.2, 1.7, 2.3), (4.3, 1.5, 2.0), (8.1, 1.9, 2.6)]

    def swell(t: float) -> tuple[float, float]:
        body = 0.0
        foam = 0.0
        for start, rise, fall in waves:
            for shift in (-SECONDS, 0.0, SECONDS):
                local = t - start - shift
                if 0.0 <= local < rise:
                    body = max(body, smooth(0.0, rise, local))
                elif rise <= local < rise + fall:
                    after = local - rise
                    body = max(body, math.exp(-after / (fall * 0.45)))
                    foam = max(foam, math.exp(-after / 0.55))
        return body, foam

    wash = Biquad('lp', 600.0, 0.7, SR)
    hiss = Biquad('hp', 2600.0, 0.7, SR)
    rumble = Biquad('lp', 150.0, 0.8, SR)
    out = []
    for i in range(N):
        t = i / SR
        body, foam = swell(t)
        if i % 64 == 0:
            wash.set(320.0 + 1600.0 * body, 0.7)
        noise = rng.uniform(-1.0, 1.0)
        out.append(rumble(noise) * (0.35 + 0.5 * body) + wash(noise) * (0.12 + 0.8 * body) + hiss(noise) * foam * 0.28)
    # Os filtros foram usados em uma volta só: a emenda é suavizada pelo próprio mar.
    fade = int(0.08 * SR)
    for k in range(fade):
        w = k / fade
        out[k] = out[k] * w + out[-fade + k] * (1.0 - w)
    return normalize(out[:-fade], 0.7)


# --- Murmúrio ----------------------------------------------------------------

def read_wav(path: Path) -> list[float]:
    with wave.open(str(path), 'rb') as handle:
        frames = handle.readframes(handle.getnframes())
        count = handle.getnframes() * handle.getnchannels()
        values = struct.unpack('<%dh' % count, frames)
        step = handle.getnchannels()
        return [values[i] / 32768.0 for i in range(0, count, step)]


def build_crowd() -> list[float]:
    rng = random.Random(5150)
    voices = [read_wav(path) for path in sorted(BABBLE.glob('*passage*.wav')) + sorted(BABBLE.glob('*emphasis*.wav'))]
    buffer = [0.0] * N
    if voices:
        # Frases curtas de várias pessoas, em alturas diferentes, sem nunca formar uma voz.
        for _ in range(170):
            voice = voices[rng.randrange(len(voices))]
            pitch = rng.uniform(0.78, 1.22)
            length = int(len(voice) / pitch)
            event = []
            for k in range(length):
                position = k * pitch
                a = int(position)
                b = min(a + 1, len(voice) - 1)
                event.append(voice[a] + (voice[b] - voice[a]) * (position - a))
            add_wrapped(buffer, rng.randrange(N), event, rng.uniform(0.12, 0.4))
    floor = Biquad('lp', 420.0, 0.7, SR)
    noise = [floor(rng.uniform(-1.0, 1.0)) * 0.05 for _ in range(N)]
    mixed = [a + b for a, b in zip(buffer, noise)]
    distance = Biquad('lp', 1700.0, 0.7, SR)
    mixed = loop_filter(mixed, distance)
    return normalize(loop_reverb(mixed, 0.38), 0.7)


# --- Fornos ------------------------------------------------------------------

def build_forge() -> list[float]:
    rng = random.Random(3307)
    buffer = [0.0] * N
    low = Biquad('lp', 170.0, 0.9, SR)
    leak = 0.0
    for i in range(N):
        t = i / SR
        leak = leak * 0.995 + rng.uniform(-1.0, 1.0) * 0.1
        buffer[i] = low(leak) * (0.7 + 0.3 * math.sin(2.0 * math.pi * t / 4.0)) * 1.6
    # Brasas estalando.
    crackle = Biquad('bp', 2600.0, 1.2, SR)
    for _ in range(int(SECONDS * 7)):
        size = rng.randint(30, 140)
        event = [crackle(rng.uniform(-1.0, 1.0)) * math.exp(-k / (size * 0.3)) for k in range(size)]
        add_wrapped(buffer, rng.randrange(N), event, rng.uniform(0.3, 0.9))
    # O fole: duas puxadas por laço.
    bellows = Biquad('bp', 520.0, 0.9, SR)
    for start in (1.4, 7.4):
        size = int(2.2 * SR)
        event = []
        for k in range(size):
            local = k / SR
            env = smooth(0.0, 0.8, local) * (1.0 - smooth(0.8, 2.2, local))
            event.append(bellows(rng.uniform(-1.0, 1.0)) * env)
        add_wrapped(buffer, int(start * SR), event, 0.9)
    # O martelo no bronze, longe.
    partials = [(523.0, 0.9, 1.0), (1307.0, 0.5, 0.55), (2213.0, 0.3, 0.35), (3120.0, 0.2, 0.22)]
    clangs = []
    for start in (0.9, 5.0, 9.2):
        size = int(1.2 * SR)
        event = [0.0] * size
        for freq, decay, gain in partials:
            detune = freq * rng.uniform(0.985, 1.015)
            for k in range(size):
                event[k] += math.sin(2.0 * math.pi * detune * k / SR) * math.exp(-(k / SR) / decay) * gain
        clangs.append((start, event))
    metal = [0.0] * N
    for start, event in clangs:
        add_wrapped(metal, int(start * SR), event, 0.16)
    metal = loop_reverb(metal, 0.55)
    return normalize([a + b for a, b in zip(buffer, metal)], 0.7)


# --- Criptas -----------------------------------------------------------------

def build_crypt() -> list[float]:
    rng = random.Random(9091)
    air = Biquad('lp', 240.0, 0.8, SR)
    buffer = []
    for i in range(N):
        t = i / SR
        # 55 Hz e uma quinta, com batimento lento; frequências que fecham o laço.
        hum = (math.sin(2.0 * math.pi * 55.0 * t) * 0.6 + math.sin(2.0 * math.pi * 82.5 * t) * 0.3) * (0.75 + 0.25 * math.sin(2.0 * math.pi * t / 6.0))
        buffer.append(hum * 0.22 + air(rng.uniform(-1.0, 1.0)) * 0.5)
    drips = [0.0] * N
    time = 0.0
    while time < SECONDS:
        time += rng.uniform(0.6, 2.1)
        if time >= SECONDS:
            break
        freq = rng.uniform(1300.0, 2500.0)
        size = int(0.09 * SR)
        phase = 0.0
        event = []
        for k in range(size):
            local = k / SR
            phase += 2.0 * math.pi * freq * (1.0 - 0.45 * min(1.0, local / 0.05)) / SR
            event.append(math.sin(phase) * math.exp(-local / 0.03))
        add_wrapped(drips, int(time * SR), event, rng.uniform(0.35, 0.8))
    drips = loop_reverb(drips, 0.6)
    return normalize([a + b * 0.9 for a, b in zip(buffer, drips)], 0.7)


# --- Canais ------------------------------------------------------------------

def build_water() -> list[float]:
    rng = random.Random(4422)
    flow = Biquad('bp', 900.0, 0.7, SR)
    wobble = Biquad('lp', 9.0, 0.7, SR)
    deep = Biquad('lp', 300.0, 0.8, SR)
    raw = []
    for i in range(N):
        noise = rng.uniform(-1.0, 1.0)
        mod = 0.55 + 4.0 * wobble(rng.uniform(-1.0, 1.0))
        raw.append(flow(noise) * max(0.1, mod) + deep(noise) * 0.4)
    gurgles = [0.0] * N
    for _ in range(int(SECONDS * 3.2)):
        freq = rng.uniform(240.0, 620.0)
        size = int(0.1 * SR)
        phase = 0.0
        event = []
        for k in range(size):
            local = k / SR
            phase += 2.0 * math.pi * freq * (1.0 + 0.7 * local / 0.1) / SR
            event.append(math.sin(phase) * math.sin(math.pi * local / 0.1) ** 2)
        add_wrapped(gurgles, rng.randrange(N), event, rng.uniform(0.1, 0.3))
    mixed = [a + b for a, b in zip(raw, gurgles)]
    soft = Biquad('lp', 2800.0, 0.7, SR)
    return normalize(loop_filter(mixed, soft), 0.7)


# --- Noite -------------------------------------------------------------------

def build_night() -> list[float]:
    rng = random.Random(2718)
    buffer = [0.0] * N
    # Grilos: (altura, intervalo que fecha o laço, pulsos por canto, volume).
    for pitch, interval, pulses, gain in [(4400.0, 0.5, 3, 0.26), (4850.0, 0.6, 4, 0.18), (5300.0, 0.75, 3, 0.12)]:
        count = int(round(SECONDS / interval))
        offset = rng.uniform(0.0, interval)
        for c in range(count):
            start = offset + c * interval + rng.uniform(-0.015, 0.015)
            for p in range(pulses):
                size = int(0.014 * SR)
                event = [math.sin(2.0 * math.pi * pitch * k / SR) * math.sin(math.pi * k / size) for k in range(size)]
                add_wrapped(buffer, int((start + p * 0.033) * SR), event, gain)
    # Sapos ao longe: três coaxadas por laço.
    for start in (2.3, 6.1, 10.4):
        size = int(0.28 * SR)
        event = []
        for k in range(size):
            local = k / SR
            buzz = sum(math.sin(2.0 * math.pi * 180.0 * h * local) / h for h in range(1, 6))
            event.append(buzz * (0.5 + 0.5 * math.sin(2.0 * math.pi * 26.0 * local)) * math.sin(math.pi * local / 0.28))
        add_wrapped(buffer, int(start * SR), event, 0.12)
    leaves = Biquad('lp', 1100.0, 0.7, SR)
    for i in range(N):
        t = i / SR
        buffer[i] += leaves(rng.uniform(-1.0, 1.0)) * (0.06 + 0.04 * math.sin(2.0 * math.pi * t / 4.0))
    return normalize(loop_reverb(buffer, 0.2), 0.7)


# --- Sinos -------------------------------------------------------------------

def build_chimes() -> list[float]:
    rng = random.Random(1618)
    notes = [196.0, 220.0, 261.63, 293.66, 329.63]
    ratios = [(0.5, 3.2, 0.5), (1.0, 2.6, 1.0), (1.183, 1.9, 0.45), (1.506, 1.5, 0.35), (2.0, 1.2, 0.3), (2.514, 0.8, 0.18), (3.011, 0.6, 0.12)]
    buffer = [0.0] * N
    for start in (0.6, 3.7, 6.9, 9.8):
        base = notes[rng.randrange(len(notes))]
        size = int(3.6 * SR)
        event = [0.0] * size
        for ratio, decay, gain in ratios:
            freq = base * ratio
            for k in range(size):
                event[k] += math.sin(2.0 * math.pi * freq * k / SR) * math.exp(-(k / SR) / decay) * gain
        add_wrapped(buffer, int(start * SR), event, rng.uniform(0.18, 0.3))
    soft = Biquad('lp', 2200.0, 0.7, SR)
    buffer = loop_filter(buffer, soft)
    breeze = Biquad('lp', 380.0, 0.8, SR)
    for i in range(N):
        buffer[i] += breeze(rng.uniform(-1.0, 1.0)) * 0.12
    return normalize(loop_reverb(buffer, 0.45), 0.6)


BEDS = {
    'surf': build_surf,
    'crowd': build_crowd,
    'forge': build_forge,
    'crypt': build_crypt,
    'water': build_water,
    'night': build_night,
    'chimes': build_chimes,
}


def main() -> None:
    for name, build in BEDS.items():
        samples = build()
        path = OUT / ('place_%s_loop.wav' % name)
        write_wav(path, samples, SR, loop=True)
        print('%-7s %6d amostras (%.1f s) -> %s' % (name, len(samples), len(samples) / SR, path.relative_to(ROOT)))


if __name__ == '__main__':
    main()
