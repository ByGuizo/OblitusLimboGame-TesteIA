"""Sintetiza toda a trilha e os efeitos do Oblitus Limbo (porte de versao_web/src/audio.js).

Gera WAVs em OblitusLimbo/assets/audio/:
  music/<faixa>.wav (+ camadas <faixa>__intense|harmonic|viktor.wav), em loop perfeito;
  sfx/<nome>_<1..3>.wav (variações) e sfx/loop_<ambiente>.wav.
Uso: python tools/synth_audio.py
"""
import os
import wave
import zlib
import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "OblitusLimbo", "assets", "audio")
rng = np.random.default_rng(7)


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def rnd(a, b):
    return a + rng.random() * (b - a)


# ---------------------------------------------------------------------------
#  Filtros (biquads RBJ)
# ---------------------------------------------------------------------------
def biquad(kind, f, q):
    f = min(max(f, 10.0), SR * 0.45)
    w = 2 * np.pi * f / SR
    cw, sw = np.cos(w), np.sin(w)
    alpha = sw / (2 * max(q, 0.0001))
    if kind == "lowpass":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
    elif kind == "highpass":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    else:  # bandpass (pico 0 dB, como o WebAudio)
        b = [alpha, 0, -alpha]
    a = [1 + alpha, -2 * cw, 1 - alpha]
    return np.array(b) / a[0], np.array(a) / a[0]


def filt(x, kind, f, q=0.7):
    b, a = biquad(kind, f, q)
    return signal.lfilter(b, a, x)


def filt_sweep(x, kind, f0, f1, q, dur):
    """Filtro com frequência em rampa exponencial f0->f1 durante dur (blocos de 256)."""
    out = np.zeros_like(x)
    zi = np.zeros(2)
    n = len(x)
    blk = 256
    for s in range(0, n, blk):
        t = s / SR
        k = min(1.0, t / max(dur, 1e-4))
        f = f0 * (f1 / f0) ** k
        b, a = biquad(kind, f, q)
        seg, zi = signal.lfilter(b, a, x[s:s + blk], zi=zi)
        out[s:s + blk] = seg
    return out


# ---------------------------------------------------------------------------
#  Envelopes e osciladores
# ---------------------------------------------------------------------------
def envelope(n, vol, attack, hold, release):
    t = np.arange(n) / SR
    e = np.zeros(n)
    a = max(attack, 1e-4)
    e = np.where(t < a, vol * t / a, vol)
    h = max(attack, hold)
    rel = t > h
    if release > 0:
        # rampa exponencial até 0.0001 em `release`
        k = np.clip((t - h) / release, 0, 1)
        e = np.where(rel, vol * (0.0001 / max(vol, 1e-6)) ** k, e)
        e = np.where(t > h + release, 0.0, e)
    return e


def wave_from_freq(kind, freq):
    ph = np.cumsum(freq) / SR
    ph = ph - np.floor(ph)
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    if kind == "triangle":
        return 2 * np.abs(2 * ph - 1) - 1
    if kind == "square":
        return np.where(ph < 0.5, 1.0, -1.0) * 0.8
    # sawtooth
    return 2 * ph - 1


def osc(kind, f, dur, vol, attack=0.01, release=0.2, cutoff=4000, q=0.7, detune=0.0, vib=0.0, glide=0.0):
    total = dur + release + 0.05
    n = int(total * SR)
    t = np.arange(n) / SR
    fr = np.full(n, f * 2 ** (detune / 1200.0))
    if glide:
        g = np.clip(t / 0.08, 0, 1)
        fr = fr * glide ** (1 - g)
    if vib:
        depth = np.clip(t / 0.4, 0, 1) * f * vib
        fr = fr + depth * np.sin(2 * np.pi * 5.2 * t)
    x = wave_from_freq(kind, fr)
    if cutoff < 20000 and kind != "sine":
        x = filt(x, "lowpass", cutoff, q)
    return x * envelope(n, vol, attack, max(attack, dur), release)


NOISE = rng.random(SR * 4) * 2 - 1
_b = np.zeros(SR * 4)
_last = 0.0
for _i in range(len(_b)):
    _last = (_last + 0.02 * (rng.random() * 2 - 1)) / 1.02
    _b[_i] = _last * 3.5
BROWN = _b


def noise_hit(vol=0.3, dur=0.15, kind="bandpass", freq=1500, q=1.0, attack=0.002, freq_end=None, brown=False):
    n = int((dur + 0.06) * SR)
    src = BROWN if brown else NOISE
    if n >= len(src) - 2:
        src = np.tile(src, n // len(src) + 2)
    off = rng.integers(0, len(src) - n - 1)
    x = src[off:off + n].copy()
    if freq_end:
        x = filt_sweep(x, kind, freq, freq_end, q, dur)
    else:
        x = filt(x, kind, freq, q)
    t = np.arange(n) / SR
    a = max(attack, 1e-4)
    e = np.where(t < a, 0.0001 * (vol / 0.0001) ** (t / a), vol * (0.0001 / vol) ** np.clip((t - a) / max(dur - a, 1e-3), 0, 1))
    e[t > dur] = 0
    return x * e


_ks_cache = {}


def ks(freq, bright=0.5, dur=2.4):
    key = (round(freq * 10), bright)
    if key in _ks_cache:
        return _ks_cache[key]
    n = int(SR * dur)
    N = max(2, int(round(SR / freq)))
    line = rng.random(N) * 2 - 1
    for _ in range(1 if bright > 0.6 else 3):
        line[1:] = (line[1:] + line[:-1]) * 0.5
    damp = 0.4985 + bright * 0.0012
    out = np.zeros(n)
    buf = line.copy()
    pos = 0
    while pos < n:
        m = min(N, n - pos)
        out[pos:pos + m] = buf[:m]
        nxt = np.roll(buf, -1)
        buf = (buf + nxt) * damp
        pos += N
    _ks_cache[key] = out
    return out


# ---------------------------------------------------------------------------
#  Mixer estéreo com envio de reverb
# ---------------------------------------------------------------------------
class Mix:
    def __init__(self, seconds, rev=0.45):
        self.n = int(seconds * SR)
        self.L = np.zeros(self.n)
        self.R = np.zeros(self.n)
        self.send = np.zeros(self.n)
        self.rev = rev

    def add(self, t, x, pan=0.0, vol=1.0):
        s = int(t * SR)
        if s >= self.n or s + len(x) <= 0:
            return
        if s < 0:
            x = x[-s:]
            s = 0
        e = min(self.n, s + len(x))
        x = x[: e - s] * vol
        gl = np.sqrt(0.5 * (1 - pan))
        gr = np.sqrt(0.5 * (1 + pan))
        self.L[s:e] += x * gl * 1.414
        self.R[s:e] += x * gr * 1.414
        self.send[s:e] += x

    # ---- instrumentos ----
    def pluck(self, m, t, vol=0.3, bright=0.5, pan=0.0):
        self.add(t, ks(mtof(m), bright) * vol, pan)

    def strum(self, notes, t, vol=0.22, spread=0.018, down=True):
        ns = notes if down else list(reversed(notes))
        for i, n in enumerate(ns):
            self.pluck(n, t + i * spread, vol, 0.5, (i - 1.5) * 0.15)

    def osc(self, kind, f, t, dur, vol, pan=0.0, **k):
        self.add(t, osc(kind, f, dur, vol, **k), pan)

    def pad(self, notes, t, dur, vol=0.05, cutoff=1200):
        for i, n in enumerate(notes):
            for j, dt in enumerate((-9, 0, 8)):
                self.osc("sawtooth", mtof(n), t, dur, vol / 3, pan=(j - 1) * 0.35, attack=dur * 0.35, release=dur * 0.4, cutoff=cutoff, detune=dt)

    def strings(self, m, t, dur, vol=0.06):
        self.osc("sawtooth", mtof(m), t, dur, vol, -0.2, attack=0.12, release=0.3, cutoff=2400, vib=0.006, detune=-5)
        self.osc("sawtooth", mtof(m), t, dur, vol * 0.7, 0.2, attack=0.14, release=0.3, cutoff=2000, vib=0.005, detune=6)

    def lead(self, m, t, dur, vol=0.07):
        self.osc("triangle", mtof(m), t, dur, vol, attack=0.03, release=0.25, cutoff=3500, vib=0.008, glide=0.98)
        self.osc("sawtooth", mtof(m), t, dur, vol * 0.25, attack=0.05, release=0.2, cutoff=1800, vib=0.008)

    def choir(self, m, t, dur, vol=0.05, vowel="a"):
        forms = [(450, 8), (800, 10), (2830, 14)] if vowel == "o" else [(800, 8), (1150, 10), (2900, 14)]
        n = int((dur + 0.8) * SR)
        tt = np.arange(n) / SR
        acc = np.zeros(n)
        for k, dt in enumerate((-12, 0, 11)):
            f0 = mtof(m) * 2 ** (dt / 1200)
            fr = f0 + mtof(m) * 0.006 * np.sin(2 * np.pi * rnd(4.5, 5.8) * tt + rnd(0, 6))
            x = wave_from_freq("sawtooth", fr)
            for f, q in forms:
                acc += filt(x, "bandpass", f, q)
        e = np.interp(tt, [0, dur * 0.3, dur * 0.7, dur + 0.6, dur + 0.8], [0, vol, vol, 0.0, 0.0])
        self.add(t, acc * e * 1.6)

    def bell(self, m, t, vol=0.08, length=3.0):
        for i, r in enumerate((1, 2.76, 5.4, 8.93)):
            self.osc("sine", mtof(m) * r, t, 0.005, vol / (i + 1), pan=rnd(-0.3, 0.3), attack=0.002, release=length / (i + 1), cutoff=20000)

    def organ(self, notes, t, dur, vol=0.04):
        for n in notes:
            for h in (1, 2, 4):
                self.osc("sine", mtof(n) * h, t, dur, vol / h, attack=0.08, release=0.5, cutoff=20000)

    def bass(self, m, t, dur, vol=0.14):
        self.osc("sine", mtof(m), t, dur, vol, attack=0.01, release=0.15, cutoff=20000)
        self.osc("sawtooth", mtof(m), t, dur, vol * 0.3, attack=0.01, release=0.1, cutoff=400)

    def noise(self, t, pan=0.0, **k):
        self.add(t, noise_hit(**k), pan)

    def drum(self, kind, t, vol=1.0):
        if kind in ("kick", "taiko"):
            f0, f1 = (140, 48) if kind == "taiko" else (120, 42)
            ln = 0.7 if kind == "taiko" else 0.35
            n = int(0.8 * SR)
            tt = np.arange(n) / SR
            fr = f0 * (f1 / f0) ** np.clip(tt / 0.18, 0, 1)
            x = wave_from_freq("sine", fr)
            e = np.where(tt < 0.004, 0.0001 * (0.55 * vol / 0.0001) ** (tt / 0.004), 0.55 * vol * (0.0001 / (0.55 * vol)) ** np.clip((tt - 0.004) / ln, 0, 1))
            e[tt > ln + 0.004] = 0
            self.add(t, x * e)
            if kind == "taiko":
                self.noise(t, vol=0.12 * vol, dur=0.12, freq=600)
        elif kind == "snare":
            self.noise(t, vol=0.22 * vol, dur=0.16, freq=2200, q=0.6)
            self.osc("triangle", 180, t, 0.02, 0.12 * vol, attack=0.001, release=0.08, cutoff=20000)
        elif kind == "frame":
            self.noise(t, vol=0.12 * vol, dur=0.1, freq=900, q=2)
            self.osc("sine", 95, t, 0.01, 0.2 * vol, attack=0.002, release=0.18)
        elif kind == "shaker":
            self.noise(t, pan=rnd(-0.4, 0.4), vol=0.05 * vol, dur=0.06, kind="highpass", freq=6000)
        elif kind == "heart":
            self.osc("sine", 52, t, 0.02, 0.4 * vol, attack=0.005, release=0.18)
            self.osc("sine", 48, t + 0.22, 0.02, 0.3 * vol, attack=0.005, release=0.2)
        elif kind == "anvil":
            self.bell(84, t, 0.05 * vol, 0.6)

    # ---- saída ----
    def render(self, loop=False, loop_len=None, rev_len=3.2, rev_decay=2.6):
        L, R = self.L.copy(), self.R.copy()
        if self.rev > 0:
            n = int(rev_len * SR)
            tt = np.arange(n) / n
            irl = (rng.random(n) * 2 - 1) * (1 - tt) ** rev_decay
            irr = (rng.random(n) * 2 - 1) * (1 - tt) ** rev_decay
            irl[:int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
            irr[:int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
            s = filt(self.send, "highpass", 180)
            wl = signal.fftconvolve(s, irl)[: self.n] * 0.012 * self.rev
            wr = signal.fftconvolve(s, irr)[: self.n] * 0.012 * self.rev
            L += wl
            R += wr
        out = np.stack([L, R])
        if loop and loop_len:
            m = int(loop_len * SR)
            body = out[:, :m].copy()
            tail = out[:, m:]
            k = 0
            while k < tail.shape[1]:
                e = min(m, tail.shape[1] - k)
                body[:, :e] += tail[:, k:k + e]
                k += m
            out = body
        return out


def soft(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def write_wav(path, stereo, gain=1.0):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = soft(stereo * gain, 1.1)
    x = np.clip(x, -1, 1)
    data = (x.T * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------------------
#  Músicas
# ---------------------------------------------------------------------------
SONG_CHORDS = [[57, 60, 64, 69], [53, 57, 60, 65], [55, 59, 62, 67], [52, 55, 59, 64],
               [53, 57, 60, 65], [52, 55, 60, 64], [50, 53, 57, 62], [52, 56, 59, 64]]
SONG_MELODY = [
    [(69, 1), (72, 1), (76, 1.5), (74, .5)], [(72, 1), (71, 1), (69, 2)],
    [(67, 1), (69, 1), (71, 1.5), (72, .5)], [(71, 1), (67, 1), (64, 2)],
    [(65, 1), (69, 1), (72, 1.5), (74, .5)], [(76, 1), (74, 1), (72, 1), (71, 1)],
    [(69, 1), (71, 1), (72, 1), (76, 1)], [(69, 4)],
]


def play_melody(bar, t, beat, fn):
    acc = 0.0
    for n, d in SONG_MELODY[bar % 8]:
        fn(n, t + acc * beat, d * beat)
        acc += d


def bar_title(A, i, t, b, layer):
    if layer:
        return
    ch = SONG_CHORDS[i % 8]
    A.pad([n - 12 for n in ch], t, b * 4, 0.035, 900)
    A.strum(ch, t, 0.12)
    A.strum(ch, t + b * 2, 0.09, 0.02, False)
    if i >= 2:
        play_melody(i, t, b, lambda n, tt, d: A.pluck(n + 12, tt, 0.26, 0.7))
    A.bass(ch[0] - 12, t, b * 3.5, 0.08)


def bar_vardun(A, i, t, b, layer):
    if layer:
        return
    prog = [[50, 57, 62, 65], [46, 53, 58, 62], [53, 60, 65, 69], [45, 52, 57, 61]]
    ch = prog[i % 4]
    A.pad(ch, t, b * 4, 0.03, 700)
    for k in range(8):
        A.pluck(ch[(k * 3) % 4] + (12 if k > 3 else 0), t + k * b / 2, 0.11, 0.4, 0.3 if k % 2 else -0.3)
    if i % 2 == 1:
        A.lead(ch[3] + 12, t + b * 2, b * 1.8, 0.03)
    A.bass(ch[0] - 12, t, b * 4, 0.07)


def bar_battle(A, i, t, b, layer):
    r = [45, 45, 41, 43][i % 4]
    if layer == "intense":
        A.drum("snare", t + b, 0.8)
        A.drum("snare", t + b * 3, 0.8)
        A.strings(r + 36, t, b * 2, 0.02)
        return
    if layer:
        return
    for k in range(8):
        A.osc("sawtooth", mtof(r), t + k * b / 2, b * 0.4, 0.06, cutoff=900, release=0.05)
    A.drum("taiko", t, 1)
    A.drum("taiko", t + b * 1.5, 0.7)
    A.drum("taiko", t + b * 2, 0.9)
    A.drum("frame", t + b * 3, 0.8)
    A.drum("frame", t + b * 3.5, 0.6)
    for k in range(8):
        A.drum("shaker", t + k * b / 2, 0.7)
    if i % 8 >= 4:
        play_melody(i * 2, t, b / 2, lambda n, tt, d: A.strings(n, tt, d * 0.9, 0.05))
    elif i % 2 == 0:
        A.strings(r + 24, t, b * 4, 0.035)


def bar_boss_darius(A, i, t, b, layer):
    if layer:
        return
    r = [40, 40, 43, 38][i % 4]
    for k in range(4):
        A.drum("kick", t + k * b, 1)
    A.drum("taiko", t + b * 0.5, 0.6)
    A.drum("taiko", t + b * 2.5, 0.6)
    A.drum("snare", t + b, 1)
    A.drum("snare", t + b * 3, 1)
    for k in range(8):
        A.osc("sawtooth", mtof(r + (3 if k % 4 == 3 else 0)), t + k * b / 2, b * 0.35, 0.07, cutoff=700)
    A.pad([r + 12, r + 15, r + 19], t, b * 0.5, 0.09, 1600)
    A.pad([r + 12, r + 15, r + 19], t + b * 1.5, b * 0.5, 0.07, 1600)
    if i % 2 == 0:
        A.choir(r + 24, t, b * 4, 0.035)
    if i % 4 == 3:
        A.drum("anvil", t + b * 3.5, 1)


def bar_valley(A, i, t, b, layer):
    if layer:
        return
    ch = [52, 53, 59] if i % 2 else [52, 55, 58]
    A.pad(ch, t, b * 4, 0.035, 600)
    A.drum("heart", t, 0.8)
    A.drum("heart", t + b * 2, 0.6)
    scale = [64, 65, 67, 70, 71, 74, 76]
    for k in range(3):
        if rng.random() < 0.6:
            A.bell(scale[int(rng.random() * len(scale))] + 12, t + rng.random() * b * 4, 0.025, 2.5)
    if i % 4 == 0:
        A.choir(64, t, b * 4, 0.02, "o")


def bar_boss_elemental(A, i, t, b, layer):
    if layer:
        return
    r = [45, 46, 45, 43][i % 4]
    for k in range(4):
        A.drum("kick", t + k * b, 0.9)
    A.drum("snare", t + b, 0.9)
    A.drum("snare", t + b * 3, 0.9)
    A.drum("taiko", t + b * 2.5, 0.7)
    for k in range(16):
        A.drum("shaker", t + k * b / 4, 0.5)
    arp = [0, 7, 12, 15, 12, 7, 3, 7]
    for k in range(8):
        A.osc("square", mtof(r + 12 + arp[k]), t + k * b / 2, b * 0.3, 0.025, cutoff=2200, release=0.05)
    A.bass(r - 12, t, b * 2, 0.12)
    A.bass(r - 12, t + b * 2, b * 2, 0.12)
    if i % 8 >= 4:
        A.strings(r + 24 + (3 if i % 2 else 0), t, b * 4, 0.05)
    if i % 2 == 0:
        A.choir(r + 12, t, b * 4, 0.03)


def bar_throne(A, i, t, b, layer):
    if layer:
        return
    prog = [[45, 52, 57, 60], [44, 51, 56, 60], [43, 50, 55, 58], [44, 52, 56, 59]]
    A.organ(prog[i % 4], t, b * 4, 0.03)
    A.choir(prog[i % 4][2] + 12, t, b * 4, 0.025, "o")
    if i % 2 == 0:
        A.bell(69, t, 0.04, 4)


def bar_boss_krauser(A, i, t, b, layer):
    prog = [[45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59], [44, 52, 56, 59]]
    ch = prog[i % 4]
    r = ch[0]
    if layer == "harmonic":
        sc = SONG_CHORDS[i % 8]
        A.strum([n + 12 for n in sc], t, 0.1, 0.012)
        A.strum([n + 12 for n in sc], t + b * 2, 0.08, 0.012, False)
        play_melody(i, t, b, lambda n, tt, d: A.pluck(n + 12, tt, 0.3, 0.75))
        return
    if layer == "viktor":
        A.strings(r + 24, t, b * 2, 0.05)
        A.strings(r + 31, t + b * 2, b * 2, 0.05)
        return
    if layer:
        return
    A.drum("taiko", t, 1)
    A.drum("kick", t + b, 0.8)
    A.drum("taiko", t + b * 2, 1)
    A.drum("taiko", t + b * 2.75, 0.6)
    A.drum("kick", t + b * 3, 0.8)
    A.drum("snare", t + b, 0.6)
    A.drum("snare", t + b * 3, 0.7)
    for k in range(8):
        A.osc("sawtooth", mtof(r - 12 + (1 if k == 7 else 0)), t + k * b / 2, b * 0.4, 0.06, cutoff=600)
    A.choir(ch[2] + 12, t, b * 2, 0.04)
    A.choir(ch[3] + 12, t + b * 2, b * 2, 0.04)
    A.organ([ch[1], ch[2]], t, b * 4, 0.02)
    if i % 4 == 3:
        A.bell(r + 36, t + b * 3, 0.05, 2)


def bar_flashback(A, i, t, b, layer):
    if layer:
        return
    ch = SONG_CHORDS[i % 8]
    play_melody(i, t, b, lambda n, tt, d: A.bell(n + 12, tt, 0.05, 2.2))
    A.pad([n - 12 for n in ch], t, b * 4, 0.02, 500)


def bar_limbo(A, i, t, b, layer):
    if layer:
        return
    A.pad([33, 34, 40], t, b * 4, 0.05, 260)
    A.noise(t, vol=0.12, dur=b * 4, kind="lowpass", freq=120, attack=b * 1.5, brown=True)
    A.drum("heart", t + b, 0.9)
    A.drum("heart", t + b * 3, 0.7)
    if i % 2 == 1:
        A.choir(46, t, b * 4, 0.03, "o")


TRACKS = {
    "title": (72, 16, bar_title, []),
    "vardun": (66, 8, bar_vardun, []),
    "battle": (138, 16, bar_battle, ["intense"]),
    "boss_darius": (150, 16, bar_boss_darius, []),
    "valley": (56, 8, bar_valley, []),
    "boss_elemental": (160, 16, bar_boss_elemental, []),
    "throne": (60, 8, bar_throne, []),
    "boss_krauser": (132, 16, bar_boss_krauser, ["harmonic", "viktor"]),
    "flashback": (64, 8, bar_flashback, []),
    "limbo": (40, 8, bar_limbo, []),
}


def render_track(name):
    bpm, bars, fn, layers = TRACKS[name]
    beat = 60.0 / bpm
    length = bars * beat * 4
    outs = {}
    for layer in [None] + layers:
        global rng
        rng = np.random.default_rng(zlib.crc32(("%s|%s" % (name, layer)).encode()))
        A = Mix(length + 7.0, rev=0.55)
        for i in range(bars):
            fn(A, i, i * beat * 4, beat, layer)
        outs[layer] = A.render(loop=True, loop_len=length)
    # normaliza pelo pico da soma de todas as camadas (mantém o equilíbrio entre elas)
    total = sum(outs.values())
    peak = np.max(np.abs(total)) + 1e-6
    gain = 0.82 / peak
    for layer, x in outs.items():
        fn_out = os.path.join(ROOT, "music", name + ("" if layer is None else "__" + layer) + ".wav")
        write_wav(fn_out, x, gain)
    print("música", name, "%.1fs" % length, "camadas", layers)


# ---------------------------------------------------------------------------
#  Efeitos
# ---------------------------------------------------------------------------
def sfx(name, A, v=1.0, o=None):
    o = o or {}
    t = 0.0
    if name == "swing":
        A.noise(t, vol=0.25 * v, dur=0.18, freq=rnd(1800, 2600), freq_end=rnd(500, 800), q=1.4, attack=0.04)
    elif name == "swingHeavy":
        A.noise(t, vol=0.35 * v, dur=0.32, freq=900, freq_end=220, q=1.2, attack=0.08)
    elif name == "hit":
        A.noise(t, vol=0.4 * v, dur=0.09, freq=rnd(1200, 1800), q=0.8)
        A.osc("sine", rnd(110, 140), t, 0.02, 0.4 * v, attack=0.002, release=0.12)
        A.noise(t, vol=0.15 * v, dur=0.2, kind="lowpass", freq=500)
    elif name == "hitHeavy":
        A.noise(t, vol=0.5 * v, dur=0.18, freq=700, q=0.7)
        A.osc("sine", 70, t, 0.04, 0.6 * v, attack=0.002, release=0.3, glide=2)
    elif name == "crit":
        sfx("hitHeavy", A, v)
        A.osc("square", 1760, t, 0.01, 0.05 * v, attack=0.001, release=0.25, cutoff=6000)
    elif name == "block":
        for i, r in enumerate((1, 2.7, 4.1)):
            A.osc("triangle", 520 * r, t, 0.005, 0.12 * v / (i + 1), attack=0.001, release=0.35, cutoff=9000)
        A.noise(t, vol=0.2 * v, dur=0.07, freq=3500)
    elif name == "parry":
        for i, r in enumerate((1, 2.4, 3.9, 6.1)):
            A.osc("sine", 880 * r, t, 0.005, 0.15 * v / (i + 1), attack=0.001, release=0.9, cutoff=20000)
        A.noise(t, vol=0.3 * v, dur=0.1, freq=5000)
    elif name == "dodge":
        A.noise(t, vol=0.2 * v, dur=0.28, freq=600, freq_end=2400, q=2, attack=0.05)
    elif name in ("step", "step_wood"):
        wood = name == "step_wood"
        A.noise(t, vol=0.06 * v * rnd(0.7, 1), dur=0.06, kind="lowpass", freq=900 if wood else rnd(1500, 2200))
        if wood:
            A.osc("sine", rnd(90, 120), t, 0.01, 0.05 * v, attack=0.001, release=0.06)
    elif name == "hurt":
        A.osc("sawtooth", rnd(260, 320), t, 0.08, 0.08 * v, attack=0.005, release=0.15, cutoff=1200, glide=1.3)
        sfx("hit", A, v * 0.8)
    elif name == "grunt":
        A.osc("sawtooth", rnd(110, 150), t, 0.12, 0.08 * v, attack=0.01, release=0.2, cutoff=700, glide=1.2)
    elif name == "die":
        A.osc("sawtooth", rnd(150, 180), t, 0.3, 0.08 * v, attack=0.01, release=0.5, cutoff=600, glide=1.5)
        A.noise(t + 0.25, vol=0.2 * v, dur=0.25, kind="lowpass", freq=300)
    elif name == "roar":
        for f in (55, 82, 110):
            A.osc("sawtooth", f * rnd(0.95, 1.05), t, 1.0, 0.1 * v, attack=0.1, release=0.6, cutoff=900, vib=0.03)
        A.noise(t, vol=0.25 * v, dur=1.4, kind="bandpass", freq=400, q=0.5, attack=0.15)
    elif name == "fire":
        A.noise(t, vol=0.35 * v, dur=0.6, kind="lowpass", freq=2000, freq_end=300, attack=0.03)
        A.osc("sine", 80, t, 0.1, 0.25 * v, attack=0.01, release=0.4, glide=1.6)
    elif name == "ice":
        for k in range(5):
            A.osc("sine", rnd(2000, 5000), t + k * 0.02, 0.005, 0.04 * v, attack=0.001, release=0.25)
        A.noise(t, vol=0.25 * v, dur=0.25, kind="highpass", freq=3000)
    elif name == "shatter":
        for k in range(9):
            A.osc("triangle", rnd(1800, 6000), t + k * 0.015, 0.005, 0.05 * v, attack=0.001, release=0.4, cutoff=14000)
        A.noise(t, vol=0.4 * v, dur=0.3, freq=4000, q=0.5)
    elif name == "magic":
        for i, n in enumerate((0, 4, 7, 12)):
            A.osc("sine", mtof(76 + n), t + i * 0.04, 0.05, 0.05 * v, attack=0.005, release=0.5)
    elif name == "soundBlade":
        ch = [[69, 72, 76, 81], [65, 69, 72, 77], [67, 71, 74, 79], [64, 67, 71, 76]][int(rng.random() * 4)]
        A.strum(ch, t, 0.32 * v, 0.012)
        A.noise(t, vol=0.18 * v, dur=0.25, freq=3000, freq_end=800, q=3)
    elif name.startswith("chord"):
        k = int(name[5:])
        A.strum([[69, 72, 76, 81], [65, 69, 72, 77], [67, 71, 74, 79], [64, 67, 71, 76]][k], t, 0.35 * v, 0.015)
    elif name == "shock":
        A.osc("sine", 60, t, 0.1, 0.6 * v, attack=0.002, release=0.6, glide=3)
        A.noise(t, vol=0.35 * v, dur=0.5, kind="lowpass", freq=1200, freq_end=100)
        A.strum([57, 64, 69, 72, 76], t, 0.3 * v, 0.01)
    elif name == "blink":
        A.noise(t, vol=0.25 * v, dur=0.2, freq=4000, freq_end=300, q=4)
        A.osc("sine", 1200, t, 0.05, 0.08 * v, attack=0.002, release=0.2, glide=0.4)
    elif name == "fury":
        A.osc("sine", 40, t, 0.6, 0.6 * v, attack=0.01, release=1.2, glide=2.5)
        A.noise(t, vol=0.4 * v, dur=1.2, kind="lowpass", freq=3000, freq_end=80, attack=0.01)
        A.osc("sawtooth", 110, t, 0.5, 0.06 * v, attack=0.2, release=0.6, cutoff=500, vib=0.05)
    elif name == "potion":
        for k in range(4):
            A.osc("sine", rnd(400, 900), t + k * 0.07, 0.03, 0.08 * v, attack=0.005, release=0.1, glide=0.7)
        for i, n in enumerate((0, 4, 7, 12)):
            A.osc("sine", mtof(76 + n), 0.3 + i * 0.04, 0.05, 0.03 * v, attack=0.005, release=0.5)
    elif name == "ui":
        A.osc("triangle", 1100, t, 0.01, 0.06 * v, attack=0.001, release=0.08, cutoff=20000)
    elif name == "uiOk":
        A.osc("triangle", 880, t, 0.02, 0.07 * v, attack=0.001, release=0.15, cutoff=20000)
        A.osc("triangle", 1320, t + 0.06, 0.02, 0.07 * v, attack=0.001, release=0.25, cutoff=20000)
    elif name == "explosion":
        A.osc("sine", 50, t, 0.2, 0.7 * v, attack=0.002, release=1.0, glide=2.5)
        A.noise(t, vol=0.6 * v, dur=1.2, kind="lowpass", freq=2500, freq_end=60)
    elif name == "arrow":
        A.noise(t, vol=0.15 * v, dur=0.22, freq=2500, freq_end=1200, q=6)
        A.osc("triangle", 220, t, 0.01, 0.1 * v, attack=0.001, release=0.1)
    elif name == "splash":
        A.noise(t, vol=0.4 * v, dur=0.5, kind="lowpass", freq=3000, freq_end=400)
        for k in range(4):
            A.osc("sine", rnd(500, 1300), t + k * 0.05, 0.02, 0.06 * v, attack=0.002, release=0.08, glide=0.6)
    elif name == "wind":
        A.noise(t, vol=0.3 * v, dur=1.4, freq=500, freq_end=1600, q=3, attack=0.4)
    elif name == "tentacle":
        A.osc("sawtooth", 70, t, 0.2, 0.15 * v, attack=0.02, release=0.3, cutoff=500, glide=0.5)
        A.noise(t, vol=0.25 * v, dur=0.35, kind="lowpass", freq=900)
    elif name == "telegraph":
        A.osc("sine", 220, t, 0.25, 0.06 * v, attack=0.05, release=0.2, glide=0.5)
    elif name == "portal":
        A.osc("sawtooth", 30, t, 3, 0.2 * v, attack=1, release=2, cutoff=300, vib=0.1)
        A.noise(t, vol=0.4 * v, dur=4, kind="lowpass", freq=200, freq_end=2000, attack=2, brown=True)
        A.choir(40, t, 3, 0.05 * v, "o")
    elif name == "bell":
        A.bell(69, t, 0.1 * v, 3)
    elif name == "heartbeat":
        A.drum("heart", t, v)
    elif name == "gong":
        A.bell(45, t, 0.3 * v, 6)
        A.drum("taiko", t, v)
    elif name == "whoosh":
        A.noise(t, vol=0.3 * v, dur=0.8, freq=300, freq_end=3000, q=1, attack=0.5)
    elif name == "reveal":
        A.osc("sine", 50, t, 0.3, 0.6 * v, attack=0.002, release=1.5, glide=2)
        A.choir(57, t, 1.5, 0.05 * v)
        A.choir(64, t, 1.5, 0.04 * v)


SFX_LIST = {
    "swing": 4, "swingHeavy": 3, "hit": 4, "hitHeavy": 3, "crit": 2, "block": 3, "parry": 2, "dodge": 3,
    "step": 5, "step_wood": 4, "hurt": 3, "grunt": 3, "die": 3, "roar": 2, "fire": 3, "ice": 3, "shatter": 2,
    "magic": 2, "soundBlade": 4, "chord0": 1, "chord1": 1, "chord2": 1, "chord3": 1, "shock": 2, "blink": 2,
    "fury": 1, "potion": 1, "ui": 1, "uiOk": 1, "explosion": 2, "arrow": 3, "splash": 2, "wind": 2,
    "tentacle": 3, "telegraph": 2, "portal": 1, "bell": 1, "heartbeat": 1, "gong": 1, "whoosh": 2, "reveal": 1,
}
SFX_TAIL = {"portal": 6.0, "gong": 6.5, "reveal": 3.5, "explosion": 2.5, "fury": 2.5, "roar": 2.5, "bell": 3.5, "parry": 1.5}


def render_sfx():
    global rng
    for name, count in SFX_LIST.items():
        for k in range(count):
            rng = np.random.default_rng(1000 + k * 97 + zlib.crc32(name.encode()) % 1000)
            dur = SFX_TAIL.get(name, 1.4)
            A = Mix(dur + 1.0, rev=0.25)
            sfx(name, A)
            x = A.render(rev_len=1.6, rev_decay=3.0)
            # corta o silêncio do fim
            env = np.max(np.abs(x), axis=0)
            nz = np.nonzero(env > 0.0008)[0]
            end = min(x.shape[1], (nz[-1] + int(0.05 * SR)) if len(nz) else int(0.1 * SR))
            x = x[:, :end]
            fade = min(end, int(0.03 * SR))
            x[:, end - fade:] *= np.linspace(1, 0, fade)
            write_wav(os.path.join(ROOT, "sfx", "%s_%d.wav" % (name, k + 1)), x, 2.2)
    print("efeitos:", sum(SFX_LIST.values()), "arquivos")


# ---------------------------------------------------------------------------
#  Ambientes em loop
# ---------------------------------------------------------------------------
def seamless(x, xf=1.0):
    """Faz loop perfeito com crossfade do fim sobre o começo."""
    n = int(xf * SR)
    body = x[:, :-n].copy()
    tail = x[:, -n:]
    ramp = np.linspace(0, 1, n)
    body[:, :n] = body[:, :n] * ramp + tail * (1 - ramp)
    return body


def render_loops():
    global rng
    rng = np.random.default_rng(99)
    L = 16.0
    n = int((L + 1.0) * SR)
    t = np.arange(n) / SR

    def noise_n(brown=False):
        if brown:
            out = np.zeros(n)
            last = 0.0
            w = rng.random(n) * 2 - 1
            out = signal.lfilter([0.02 / 1.02], [1, -1 / 1.02], w) * 3.5
            return out
        return rng.random(n) * 2 - 1

    # vento: banda modulada por LFO lento (2 ciclos em 16 s)
    xs = []
    for ch in range(2):
        b = noise_n(True)
        fc = 500 + 300 * np.sin(2 * np.pi * 0.125 * t + ch * 0.8)
        out = np.zeros(n)
        zi = np.zeros(2)
        for s in range(0, n, 512):
            bb, aa = biquad("bandpass", fc[s], 0.6)
            seg, zi = signal.lfilter(bb, aa, b[s:s + 512], zi=zi)
            out[s:s + 512] = seg
        gust = 0.75 + 0.25 * np.sin(2 * np.pi * 0.0625 * t + ch)
        xs.append(out * gust * 0.9)
    write_wav(os.path.join(ROOT, "sfx", "loop_wind.wav"), seamless(np.stack(xs)), 1.6)
    # fogueira: chiado grave + estalos
    xs = []
    for ch in range(2):
        x = filt(noise_n(), "lowpass", 1400) * 0.18
        x += filt(noise_n(True), "lowpass", 300) * 0.15
        for _ in range(int(L * 9)):
            p = int(rng.random() * (n - 2000))
            ln = int(rnd(80, 600))
            click = (rng.random(ln) * 2 - 1) * np.exp(-np.arange(ln) / (ln * 0.25)) * rnd(0.2, 0.7)
            x[p:p + ln] += filt(click, "highpass", rnd(1500, 4000))
        xs.append(x)
    write_wav(os.path.join(ROOT, "sfx", "loop_fire.wav"), seamless(np.stack(xs)), 1.5)
    # rumor grave do Limbo
    xs = []
    for ch in range(2):
        x = filt(filt(noise_n(True), "lowpass", 140), "lowpass", 140) * 1.4
        x *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.25 * t + ch)
        xs.append(x)
    write_wav(os.path.join(ROOT, "sfx", "loop_rumble.wav"), seamless(np.stack(xs)), 1.4)
    # murmúrio de taverna: vozes formantes aleatórias + louça
    xs = []
    for ch in range(2):
        x = filt(noise_n(), "bandpass", 700, 0.4) * 0.05
        for _ in range(int(L * 3)):
            st = rnd(0, L - 1.5)
            d = rnd(0.4, 1.4)
            m = int(d * SR)
            tt = np.arange(m) / SR
            f0 = rnd(95, 210)
            fr = f0 * (1 + 0.08 * np.sin(2 * np.pi * rnd(2, 5) * tt))
            v = wave_from_freq("sawtooth", fr)
            vv = filt(v, "bandpass", rnd(500, 900), 6) + filt(v, "bandpass", rnd(1100, 1700), 8) * 0.6
            e = np.sin(np.pi * tt / d) ** 2 * (0.5 + 0.5 * np.sin(2 * np.pi * rnd(3, 6) * tt) ** 2)
            p = int(st * SR)
            x[p:p + m] += filt(vv * e, "lowpass", 1800) * rnd(0.01, 0.03)
        for _ in range(int(L * 0.8)):
            p = int(rng.random() * (n - 30000))
            for i, r in enumerate((1, 2.76, 5.4)):
                ding = osc("sine", rnd(1800, 3200) * r, 0.003, 0.012 / (i + 1), attack=0.001, release=0.4)
                x[p:p + len(ding)] += ding
        xs.append(x)
    write_wav(os.path.join(ROOT, "sfx", "loop_tavern.wav"), seamless(np.stack(xs)), 2.0)
    print("ambientes: wind, fire, rumble, tavern")


if __name__ == "__main__":
    import sys
    what = sys.argv[1:] or ["music", "sfx", "loops"]
    if "loops" in what:
        render_loops()
    if "sfx" in what:
        render_sfx()
    if "music" in what:
        for name in TRACKS:
            render_track(name)
