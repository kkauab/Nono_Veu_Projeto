"""Synthesize the combat and harbor-water sound effects.

Swings, impacts, parry, wounds, the enemies' attack tells, the fish in the
water and the sea itself are built from filtered noise, resonators and pitch
sweeps; no recording, network service or third-party package, so the sounds
carry no license. Also writes scripts/audio/sfx_banks.gd with the preload lists.

The output is deterministic: running it again rewrites identical files.

Usage: python tools/audio/build_combat_sfx.py
"""
import math
import random
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/sfx'
BANKS_SCRIPT = ROOT / 'scripts/audio/sfx_banks.gd'
RES_OUT = 'res://assets/audio/sfx'
SR = 44100
LOOP_SR = 22050


# --- building blocks ---------------------------------------------------------

class Biquad:
    """RBJ low-pass, high-pass or band-pass (0 dB peak)."""

    def __init__(self, kind, freq, q=.707, sr=SR):
        self.kind = kind
        self.sr = sr
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self.set(freq, q)

    def set(self, freq, q):
        freq = min(max(freq, 20.0), self.sr * .45)
        w = 2 * math.pi * freq / self.sr
        cw = math.cos(w)
        alpha = math.sin(w) / (2 * q)
        if self.kind == 'lp':
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        elif self.kind == 'hp':
            b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        else:
            b0, b1, b2 = alpha, 0.0, -alpha
        a0 = 1 + alpha
        self.b0, self.b1, self.b2 = b0 / a0, b1 / a0, b2 / a0
        self.a1, self.a2 = -2 * cw / a0, (1 - alpha) / a0

    def __call__(self, x):
        y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x2, self.x1, self.y2, self.y1 = self.x1, x, self.y1, y
        return y


def decay(tau, attack=.0005):
    return lambda s: s / attack if s < attack else math.exp(-(s - attack) / tau)


def swell(seconds, peak=.45, power=1.6):
    """Rises to `peak` (fraction of the length), then falls back to silence."""
    def envelope(s):
        t = s / seconds
        if t < peak:
            return (t / peak) ** power
        return max(0.0, 1 - (t - peak) / (1 - peak)) ** 1.4
    return envelope


def noise(rng, seconds, kind=None, freq=1000.0, q=.707, env=None, sweep=None, sr=SR):
    """Filtered white noise; `sweep(t)` moves the filter over t in 0..1."""
    count = int(seconds * sr)
    filt = Biquad(kind, sweep(0) if sweep else freq, q, sr) if kind else None
    out = []
    for i in range(count):
        s = i / sr
        if sweep and i % 32 == 0:
            filt.set(sweep(i / count), q)
        value = rng.uniform(-1, 1)
        if filt:
            value = filt(value)
        out.append(value * (env(s) if env else 1.0))
    return out


def thump(f_start, f_end, pitch_tau, tau, seconds, drive=1.6):
    """Body of an impact: a sine whose pitch falls fast, softly saturated."""
    out = []
    phase = 0.0
    for i in range(int(seconds * SR)):
        s = i / SR
        phase += 2 * math.pi * (f_end + (f_start - f_end) * math.exp(-s / pitch_tau)) / SR
        out.append(math.tanh(math.sin(phase) * math.exp(-s / tau) * drive) / math.tanh(drive))
    return out


def partials(rng, base, table, seconds, beat=2.5, attack=.0006):
    """Inharmonic struck partials: (ratio, gain, decay). Detuned pairs beat."""
    out = [0.0] * int(seconds * SR)
    for ratio, gain, tau in table:
        for detune in (0.0, rng.uniform(.6, 1.0) * beat):
            freq = base * ratio + detune
            phase = rng.uniform(0, math.tau)
            step = 2 * math.pi * freq / SR
            for i in range(len(out)):
                s = i / SR
                env = s / attack if s < attack else math.exp(-(s - attack) / tau)
                out[i] += math.sin(phase + step * i) * env * gain * .5
    return out


def glide(seconds, f_start, f_end, env, harmonics=((1, 1.0),), tremolo=(0.0, 0.0)):
    """Exponential pitch glide with optional harmonics and tremolo."""
    out = []
    phases = [0.0] * len(harmonics)
    rate, depth = tremolo
    count = int(seconds * SR)
    for i in range(count):
        s = i / SR
        freq = f_start * (f_end / f_start) ** (i / count)
        value = 0.0
        for index, (ratio, gain) in enumerate(harmonics):
            phases[index] += 2 * math.pi * freq * ratio / SR
            value += math.sin(phases[index]) * gain
        out.append(value * env(s) * (1 - depth * (.5 + .5 * math.sin(2 * math.pi * rate * s))))
    return out


def droplet(rng, gain=.35):
    """A water drop: short rising sine chirp."""
    f0 = rng.uniform(1100, 2600)
    rise = rng.uniform(1.4, 2.0)
    length = rng.uniform(.012, .022)
    out = []
    phase = 0.0
    for i in range(int(length * 3 * SR)):
        s = i / SR
        phase += 2 * math.pi * f0 * (1 + (rise - 1) * min(1, s / length)) / SR
        out.append(math.sin(phase) * math.exp(-s / (length * .7)) * gain)
    return out


def bubble(f0, rise, tau, seconds):
    """Minnaert bubble: resonance rising as the bubble surfaces."""
    out = []
    phase = 0.0
    for i in range(int(seconds * SR)):
        s = i / SR
        phase += 2 * math.pi * f0 * (1 + rise * min(1, s / (tau * 2))) / SR
        env = s / .002 if s < .002 else math.exp(-(s - .002) / tau)
        out.append(math.sin(phase) * env)
    return out


def mix(*layers):
    """layers: (samples, start_seconds, gain)."""
    length = max(int(at * SR) + len(samples) for samples, at, _ in layers)
    out = [0.0] * length
    for samples, at, gain in layers:
        start = int(at * SR)
        for i, value in enumerate(samples):
            out[start + i] += value * gain
    return out


def finish(samples, peak=.89, sr=SR):
    """Trim the silent tail, fade the edges and normalize."""
    top = max(abs(v) for v in samples) or 1.0
    end = len(samples)
    while end > 1 and abs(samples[end - 1]) < top * .002:
        end -= 1
    samples = samples[:end]
    fade_in = int(.0015 * sr)
    fade_out = min(int(.012 * sr), len(samples) // 2)
    for i in range(fade_in):
        samples[i] *= i / fade_in
    for i in range(fade_out):
        samples[-1 - i] *= i / fade_out
    top = max(abs(v) for v in samples) or 1.0
    return [v * peak / top for v in samples]


# --- recipes -----------------------------------------------------------------

def swing(rng, seconds, low, high, end, q, body=0.0, grit=0.0):
    j = rng.uniform(.9, 1.1)
    seconds *= rng.uniform(.92, 1.08)
    low, high, end = low * j, high * j, end * j
    env = swell(seconds, .42)
    def sweep(t):
        return low + (high - low) * (t / .45) if t < .45 else high + (end - high) * ((t - .45) / .55)
    air = noise(rng, seconds, 'bp', q=q, env=env, sweep=sweep)
    layers = [(air, 0, 1.0)]
    if body:
        layers.append((noise(rng, seconds, 'lp', 520, env=env), 0, body))
    out = mix(*layers)
    if grit:
        out = [v * (1 + grit * math.sin(2 * math.pi * 63 * i / SR)) for i, v in enumerate(out)]
    return finish(out)


def hit(rng, weight):
    j = rng.uniform(.9, 1.1)
    return finish(mix(
        (noise(rng, .006, 'hp', 3200, env=decay(.0013)), 0, .9),
        (thump((175 - 45 * weight) * j, (52 - 12 * weight) * j, .022 + .02 * weight, .07 + .09 * weight, .5), 0, 1.0),
        (noise(rng, .14, 'bp', 1750 * j, .9, env=decay(.022 + .016 * weight)), .001, 1.5),
        (noise(rng, .25, 'bp', 430 * j, 1.1, env=decay(.04 + .035 * weight)), 0, 1.3),
        (noise(rng, .3, 'hp', 3600, env=decay(.05 + .05 * weight, .004)), .002, .22),
    ))


def kill(rng):
    j = rng.uniform(.94, 1.06)
    dissolve = glide(.8, 760 * j, 300 * j, decay(.26, .03), ((1, 1.0), (1.5, .55), (2.01, .4), (2.98, .25)), (13.0, .55))
    return finish(mix(
        (hit(rng, 1.0), 0, 1.0),
        (dissolve, .05, .22),
        (noise(rng, .7, 'hp', 2400, env=swell(.7, .15, 1.0)), .04, .12),
    ))


def parry(rng, base):
    table = [(1, 1.0, .55), (2.32, .7, .34), (4.25, .5, .2), (6.63, .35, .13), (9.38, .25, .08)]
    ring = partials(rng, base, table, .9)
    return finish(mix(
        ([math.tanh(v * 1.4) for v in ring], 0, 1.0),
        (noise(rng, .02, 'bp', 4200, .7, env=decay(.003)), 0, 2.2),
        (noise(rng, .12, 'bp', 5600, 2.0, env=decay(.03)), .003, 1.1),
        (thump(260, 120, .01, .03, .1), 0, .35),
    ))


def hurt(rng):
    j = rng.uniform(.92, 1.08)
    sting = glide(.22, 196 * j, 185 * j, decay(.09, .004), ((1, 1.0),))
    sting_b = glide(.22, 208 * j, 196 * j, decay(.09, .004), ((1, 1.0),))
    return finish(mix(
        (thump(150 * j, 44, .03, .11, .45, 2.0), 0, 1.0),
        (noise(rng, .3, 'lp', 900, env=decay(.05)), 0, 1.8),
        (noise(rng, .1, 'bp', 2300, 1.0, env=decay(.02)), .001, .9),
        (sting, .01, .22),
        (sting_b, .01, .22),
    ))


def death(rng):
    return finish(mix(
        (thump(120, 34, .05, .26, 1.0, 2.2), 0, 1.0),
        (glide(1.0, 165, 52, decay(.38, .02), ((1, 1.0), (2, .3))), .02, .45),
        (noise(rng, 1.0, 'lp', 620, env=decay(.32, .04)), 0, 1.4),
    ))


def dodge(rng):
    j = rng.uniform(.9, 1.12)
    return finish(mix(
        (noise(rng, .17, 'bp', q=1.0, env=swell(.17, .3), sweep=lambda t: (1000 + 900 * math.sin(math.pi * t)) * j), 0, 1.0),
        (noise(rng, .05, 'lp', 380, env=decay(.015)), 0, .9),
    ))


def windup(rng, base):
    seconds = .5
    rise = lambda s: (s / seconds) ** 2.2 * (1 if s < seconds - .04 else (seconds - s) / .04)
    shimmer = []
    for i in range(int(seconds * SR)):
        s = i / SR
        shimmer.append(math.sin(2 * math.pi * base * (1 + .012 * math.sin(2 * math.pi * 6.5 * s)) * s) * rise(s))
    return finish(mix(
        (noise(rng, seconds, 'bp', q=4.0, env=rise, sweep=lambda t: 260 + 1150 * t ** 1.4), 0, 1.0),
        (shimmer, 0, .09),
    ))


def riposte(rng):
    chime = partials(rng, 1046.5, [(1, 1.0, .5), (2, .5, .34), (3, .3, .24), (4.2, .2, .14)], .9, beat=1.5)
    return finish(mix(
        (swing(rng, .3, 380, 1900, 650, 1.2, body=.6), 0, 1.0),
        (chime, .05, .5),
        (noise(rng, .01, 'hp', 3000, env=decay(.002)), .05, .5),
    ))


def shadow(rng):
    seconds = .5
    env = swell(seconds, .6, 2.0)
    return finish(mix(
        (noise(rng, seconds, 'lp', q=1.1, env=env, sweep=lambda t: 300 + 2200 * math.sin(math.pi * min(1, t * 1.1))), 0, 1.0),
        (glide(seconds, 90, 38, env, ((1, 1.0),)), 0, .55),
        (glide(seconds, 1500, 3100, env, ((1, 1.0),), (17.0, .7)), 0, .06),
    ))


def splash(rng):
    layers = [
        (noise(rng, .12, 'hp', 1300, env=decay(.028, .002)), 0, 1.0),
        (noise(rng, .2, 'bp', 2500, .8, env=decay(.05, .003)), 0, .8),
    ]
    for _ in range(rng.randint(3, 5)):
        layers.append((droplet(rng), rng.uniform(.02, .16), 1.0))
    return finish(mix(*layers))


def plop(rng):
    layers = [
        (bubble(rng.uniform(380, 520), rng.uniform(1.3, 1.9), .03, .14), 0, 1.0),
        (noise(rng, .16, 'lp', 2600, env=decay(.04, .002)), 0, .7),
    ]
    for _ in range(rng.randint(2, 4)):
        layers.append((droplet(rng, .25), rng.uniform(.05, .26), 1.0))
    return finish(mix(*layers))


def small_bubble(rng):
    return finish(bubble(rng.uniform(900, 1500), rng.uniform(.6, 1.0), .012, .06))


def coin(rng, pitch):
    table = [(1, 1.0, .12), (2.0, .3, .06), (3.0, .12, .04)]
    return finish(mix(
        (partials(rng, 1318.5 * pitch, table, .3, beat=0), 0, 1.0),
        (partials(rng, 1975.5 * pitch, table, .35, beat=0), .06, 1.0),
        (noise(rng, .006, 'hp', 4000, env=decay(.0015)), 0, .4),
    ))


def creak(rng, seconds, rate_from, rate_to, center, q=6.0):
    """Wood rubbing on wood: stick-slip pulses rung through two resonances."""
    low = Biquad('bp', center, q)
    high = Biquad('bp', center * 2.3, q)
    out = []
    phase = 0.0
    for i in range(int(seconds * SR)):
        s = i / SR
        t = s / seconds
        phase += (rate_from + (rate_to - rate_from) * t + 8 * math.sin(2 * math.pi * 3.1 * s)) / SR
        pulse = 0.0
        if phase >= 1.0:
            phase -= 1.0
            pulse = rng.uniform(.6, 1.0)
        value = pulse + rng.uniform(-.02, .02)
        out.append((low(value) + .5 * high(value)) * math.sin(math.pi * t) ** .6)
    return out


def latch(rng, base):
    return mix(
        (noise(rng, .01, 'hp', 3000, env=decay(.003)), 0, 1.0),
        (partials(rng, base, [(1, 1.0, .03), (2.7, .5, .02)], .08, beat=0), 0, .6),
    )


def door(rng, center, rate_from, rate_to):
    seconds = rng.uniform(.5, .6)
    return finish(mix(
        (latch(rng, 1800), 0, .8),
        (creak(rng, seconds, rate_from, rate_to, center), .03, 1.0),
        (thump(120, 70, .02, .07, .25), .03 + seconds, .9),
        (noise(rng, .2, 'lp', 400, env=decay(.05)), .03 + seconds, 1.2),
    ))


def chest(rng, center):
    seconds = rng.uniform(.3, .36)
    return finish(mix(
        (latch(rng, 2400), 0, 1.0),
        (creak(rng, seconds, 40, 90, center), .02, .9),
        (thump(180, 100, .015, .05, .2), .02 + seconds, 1.0),
        (noise(rng, .08, 'bp', 900, 1.0, env=decay(.02)), .02 + seconds, 1.1),
    ))


def water_loop(rng):
    """Eight seconds of harbor water that loop without a seam."""
    seconds = 8.0
    count = int(seconds * LOOP_SR)
    fade = int(.6 * LOOP_SR)
    total = count + fade
    # Swells use whole cycles per loop, so their phase also matches at the seam.
    a, b, c = rng.uniform(0, math.tau), rng.uniform(0, math.tau), rng.uniform(0, math.tau)
    swell_at = lambda i: .55 + .22 * math.sin(math.tau * i / count + a) + .14 * math.sin(math.tau * 2 * i / count + b) + .09 * math.sin(math.tau * 3 * i / count + c)
    low = Biquad('lp', 430, .707, LOOP_SR)
    body = []
    brown = 0.0
    for i in range(total):
        brown = brown * .985 + rng.uniform(-1, 1) * .15
        body.append(low(brown) * swell_at(i % count))
    # Crossfading the overlap into the start makes the last sample lead into the first.
    base = []
    for i in range(count):
        if i < fade:
            t = i / fade
            base.append(body[i] * math.sqrt(t) + body[count + i] * math.sqrt(1 - t))
        else:
            base.append(body[i])
    laps = [0.0] * count
    for event in range(7):
        start = int((event + rng.uniform(.1, .8)) * count / 7)
        seconds_lap = rng.uniform(.7, 1.1)
        lap = noise(rng, seconds_lap, 'bp', rng.uniform(650, 1250), .9, env=swell(seconds_lap, .2, 1.3), sr=LOOP_SR)
        slosh = noise(rng, .25, 'hp', 2200, env=decay(.06, .01), sr=LOOP_SR)
        for i, value in enumerate(lap):
            laps[(start + i) % count] += value * .55
        peak = start + int(seconds_lap * .2 * LOOP_SR)
        for i, value in enumerate(slosh):
            laps[(peak + i) % count] += value * .12
    out = [base[i] * 1.4 + laps[i] for i in range(count)]
    top = max(abs(v) for v in out)
    return [v * .6 / top for v in out]


# --- output ------------------------------------------------------------------

def write_wav(path, samples, sr=SR, loop=False):
    """16-bit mono PCM. A looping file carries a `smpl` chunk, which Godot's
    importer reads as a forward loop over the whole file."""
    data = b''.join(struct.pack('<h', max(-32767, min(32767, int(round(v * 32767))))) for v in samples)
    chunks = struct.pack('<4sIHHIIHH', b'fmt ', 16, 1, 1, sr, sr * 2, 2, 16)
    chunks += struct.pack('<4sI', b'data', len(data)) + data
    if loop:
        smpl = struct.pack('<9I', 0, 0, round(1e9 / sr), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack('<6I', 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += struct.pack('<4sI', b'smpl', len(smpl)) + smpl
    path.write_bytes(struct.pack('<4sI4s', b'RIFF', 4 + len(chunks), b'WAVE') + chunks)


# name -> (variant builders, bus, volume_db)
def recipes():
    return {
        'swing_sword': ([lambda r: swing(r, .2, 700, 2600, 1100, 1.5, body=.35) for _ in range(3)], 'SFX', -9.0),
        'swing_dagger': ([lambda r: swing(r, .11, 1500, 4200, 2000, 1.8) for _ in range(3)], 'SFX', -11.0),
        'swing_heavy': ([lambda r: swing(r, .32, 340, 1800, 600, 1.2, body=.7) for _ in range(2)], 'SFX', -7.0),
        'swing_enemy': ([lambda r: swing(r, .26, 300, 1300, 500, 1.0, body=.5, grit=.35) for _ in range(3)], 'SFX', -10.0),
        'hit_light': ([lambda r: hit(r, 0.0) for _ in range(4)], 'SFX', -4.0),
        'hit_heavy': ([lambda r: hit(r, 1.0) for _ in range(3)], 'SFX', -2.0),
        'hit_kill': ([kill for _ in range(2)], 'SFX', -1.0),
        'parry': ([lambda r: parry(r, 620), lambda r: parry(r, 690)], 'SFX', -3.0),
        'hurt': ([hurt for _ in range(3)], 'SFX', -3.0),
        'death': ([death], 'SFX', -2.0),
        'dodge': ([dodge for _ in range(3)], 'SFX', -13.0),
        'enemy_windup': ([lambda r: windup(r, 880), lambda r: windup(r, 830)], 'SFX', -15.0),
        'power_riposte': ([riposte], 'SFX', -4.0),
        'power_shadow': ([shadow], 'SFX', -5.0),
        'water_splash': ([splash for _ in range(3)], 'Ambiente', -12.0),
        'water_plop': ([plop for _ in range(4)], 'Ambiente', -11.0),
        'water_bubble': ([small_bubble for _ in range(3)], 'Ambiente', -20.0),
        'water_loop': ([water_loop], 'Ambiente', -16.0),
        'pickup_coin': ([lambda r: coin(r, 1.0), lambda r: coin(r, 1.06), lambda r: coin(r, .95)], 'SFX', -8.0),
        'door_open': ([lambda r: door(r, 750, 25, 60), lambda r: door(r, 650, 20, 50)], 'SFX', -8.0),
        'chest_open': ([lambda r: chest(r, 1100), lambda r: chest(r, 980)], 'SFX', -7.0),
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    banks = {}
    for bank, (builders, bus, volume) in recipes().items():
        paths = []
        for index, build in enumerate(builders):
            rng = random.Random(f'{bank}:{index}')
            name = f'{bank}_{index + 1:02d}.wav' if len(builders) > 1 else f'{bank}.wav'
            loop = bank == 'water_loop'
            write_wav(OUT / name, build(rng), LOOP_SR if loop else SR, loop)
            paths.append(f'{RES_OUT}/{name}')
        banks[bank] = (paths, bus, volume)
        print(f'{bank}: {len(paths)}')
    lines = [
        'extends RefCounted',
        '## Gerado por tools/audio/build_combat_sfx.py; não edite à mão.',
        '',
        'const BANKS := {',
    ]
    entries = list(banks.items())
    for index, (bank, (paths, _, _)) in enumerate(entries):
        preloads = ', '.join(f'preload("{path}")' for path in paths)
        lines.append(f'\t"{bank}": [{preloads}]' + (',' if index < len(entries) - 1 else ''))
    lines += ['}', '', 'const BUS := {']
    for index, (bank, (_, bus, _)) in enumerate(entries):
        lines.append(f'\t"{bank}": "{bus}"' + (',' if index < len(entries) - 1 else ''))
    lines += ['}', '', 'const VOLUME_DB := {']
    for index, (bank, (_, _, volume)) in enumerate(entries):
        lines.append(f'\t"{bank}": {volume}' + (',' if index < len(entries) - 1 else ''))
    lines += ['}', '']
    BANKS_SCRIPT.write_text('\n'.join(lines), encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
