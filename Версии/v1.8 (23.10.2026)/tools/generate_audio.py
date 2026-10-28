#!/usr/bin/env python3
"""
Генератор звуков и музыки для «В погоне за бензином».
Всё синтезируется кодом (numpy + scipy), поэтому звуки полностью свои — без чужих сэмплов.

Запуск:  python3 tools/generate_audio.py
Нужны:   numpy, scipy, ffmpeg (с libvorbis) в PATH.
Результат: audio/sfx/*.ogg и audio/music/*.ogg
"""
import os
import sys
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
rng = np.random.default_rng(1716)   # 1716 — год основания Омска :)


# ---------------------------------------------------------------------------
# Базовые инструменты
# ---------------------------------------------------------------------------
def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_adsr(n, a=0.005, d=0.05, s=0.6, r=0.1):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1), endpoint=False),
        np.linspace(1, s, max(d_n, 1), endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR / decay)


def osc(kind, freq, dur, phase=0.0):
    t = t_axis(dur)
    if np.isscalar(freq):
        ph = 2 * np.pi * freq * t + phase
    else:
        ph = 2 * np.pi * np.cumsum(freq) / SR + phase
    if kind == "sine":
        return np.sin(ph)
    if kind == "saw":
        return 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    if kind == "square":
        return np.sign(np.sin(ph))
    if kind == "pulse":
        return np.where(((ph / (2 * np.pi)) % 1.0) < 0.25, 1.0, -1.0)
    if kind == "tri":
        return 2.0 * np.abs(2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(kind)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, SR * 0.45) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def normalize(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def make_loop(x, fade=0.08):
    """Бесшовная петля: конец плавно переходит в начало."""
    n = int(fade * SR)
    head, tail = x[:n].copy(), x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = tail * (1 - w) + head * w
    return x


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def place(buf, x, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(x))
    buf[i:end] += x[:end - i]


def save(x, path, quality=4):
    x = np.clip(x, -1, 1)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                    "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(wav_path)
    print("  ", os.path.relpath(path, ROOT), f"{len(x) / SR:.1f} c")


def note_freq(name):
    """'A4', 'C#5', 'Eb3' -> частота"""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[name[0]]
    rest = name[1:]
    if rest[0] in "#b":
        n += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    octave = int(rest)
    midi = 12 * (octave + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------------------------------------------------------------------------
# Звуковые эффекты
# ---------------------------------------------------------------------------
def sfx_engine():
    # Петля 1 с ровно из целого числа периодов: высота меняется через pitch_scale в игре
    f0 = 55.0
    dur = 1.0
    t = t_axis(dur)
    x = np.zeros_like(t)
    for h, amp in [(1, 1.0), (2, 0.55), (3, 0.35), (4, 0.22), (6, 0.12), (8, 0.06)]:
        x += amp * osc("saw", f0 * h, dur, phase=h * 0.7)
    firing = 0.65 + 0.35 * np.sin(2 * np.pi * 27.5 * t) ** 2        # «тарахтение» цилиндров
    rumble = lowpass(noise(dur), 300) * 0.6
    x = lowpass(x * firing + rumble, 1400)
    return normalize(make_loop(x, 0.05), 0.8)


def sfx_engine_ev():
    dur = 1.0
    t = t_axis(dur)
    x = 0.6 * np.sin(2 * np.pi * 220 * t) + 0.25 * np.sin(2 * np.pi * 440 * t) \
        + 0.15 * np.sin(2 * np.pi * 663 * t) + 0.3 * np.sin(2 * np.pi * 50 * t)
    # Все частоты целые, а длина ровно 1 с — петля получается идеально бесшовной
    return normalize(x, 0.6)


def sfx_drone():
    # Жужжание квадрокоптера: целые частоты и длина ровно 1 с — бесшовная петля
    dur = 1.0
    t = t_axis(dur)
    x = np.zeros_like(t)
    for f, amp in [(180, 1.0), (183, 0.8), (360, 0.45), (366, 0.35), (540, 0.2), (720, 0.12)]:
        x += amp * osc("saw", f, dur)
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * 6 * t)               # «плавающие» обороты винтов
    return normalize(lowpass(x, 2500), 0.6)


def sfx_alarm():
    # Тревожный двойной сигнал «вас засекли»
    a = 0.6 * osc("square", 880, 0.12) * env_adsr(int(SR * 0.12), 0.003, 0.03, 0.8, 0.03)
    b = 0.6 * osc("square", 660, 0.16) * env_adsr(int(SR * 0.16), 0.003, 0.03, 0.8, 0.05)
    buf = np.zeros(int(SR * 0.36))
    place(buf, lowpass(a, 4000), 0.0)
    place(buf, lowpass(b, 4000), 0.17)
    return normalize(buf, 0.8)


def sfx_skid():
    dur = 1.2
    t = t_axis(dur)
    squeal = np.sin(2 * np.pi * (1150 + 60 * np.sin(2 * np.pi * 7 * t)) * t)
    hiss = bandpass(noise(dur), 1500, 4500)
    x = squeal * 0.5 + hiss * 0.8
    return normalize(make_loop(x, 0.1), 0.6)


def sfx_crash():
    dur = 1.1
    t = t_axis(dur)
    n = len(t)
    thump = np.sin(2 * np.pi * (90 * np.exp(-t * 8) + 40) * t) * env_exp(n, 0.18)
    burst = lowpass(noise(dur), 3500) * env_exp(n, 0.12)
    metal = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * env_exp(n, d)
                for f, d in [(830, 0.35), (1270, 0.25), (1910, 0.18), (2650, 0.12), (3420, 0.1)]) * 0.35
    glass = np.zeros(n)
    for _ in range(14):
        at = rng.uniform(0.05, 0.6)
        f = rng.uniform(3000, 7000)
        g = np.sin(2 * np.pi * f * t_axis(0.08)) * env_exp(int(0.08 * SR), 0.015) * rng.uniform(0.1, 0.3)
        place(glass, g, at)
    return normalize(thump * 1.2 + burst + metal + glass, 0.95)


def sfx_hit():
    dur = 0.35
    t = t_axis(dur)
    n = len(t)
    knock = np.sin(2 * np.pi * (220 * np.exp(-t * 20) + 120) * t) * env_exp(n, 0.06)
    plastic = bandpass(noise(dur), 600, 2500) * env_exp(n, 0.03)
    return normalize(knock + plastic * 0.8, 0.8)


def sfx_bump():
    dur = 0.45
    t = t_axis(dur)
    n = len(t)
    x = np.sin(2 * np.pi * (70 * np.exp(-t * 6) + 35) * t) * env_exp(n, 0.12)
    x += lowpass(noise(dur), 500) * env_exp(n, 0.05) * 0.8
    return normalize(x, 0.9)


def sfx_splash():
    dur = 0.7
    t = t_axis(dur)
    n = len(t)
    x = bandpass(noise(dur), 400, 3000) * env_adsr(n, 0.02, 0.1, 0.4, 0.4)
    for _ in range(10):
        f = rng.uniform(500, 1500)
        place(x, np.sin(2 * np.pi * np.linspace(f, f * 1.8, int(0.05 * SR)) * t_axis(0.05)) * 0.2
              * env_exp(int(0.05 * SR), 0.02), rng.uniform(0.05, 0.5))
    return normalize(x, 0.7)


def chime(notes, step=0.07, decay=0.35, kind="sine", length=0.9):
    buf = np.zeros(int(length * SR))
    for i, nm in enumerate(notes):
        f = note_freq(nm)
        d = length - i * step
        tone = (osc(kind, f, d) * 0.6 + osc("sine", f * 2, d) * 0.25 + osc("sine", f * 3.01, d) * 0.1)
        tone *= env_exp(len(tone), decay)
        place(buf, tone, i * step)
    return buf


def sfx_pickup():
    return normalize(chime(["C6", "E6", "G6", "C7"], 0.06, 0.25), 0.7)


def sfx_fuel():
    buf = np.zeros(int(0.9 * SR))
    for i in range(4):  # «бульканье»
        d = 0.09
        f = np.linspace(180 + i * 40, 520 + i * 60, int(d * SR))
        place(buf, osc("sine", f, d) * env_adsr(int(d * SR), 0.005, 0.02, 0.6, 0.04) * 0.6, i * 0.08)
    place(buf, chime(["G5", "D6", "G6"], 0.06, 0.3, length=0.6) * 0.7, 0.3)
    return normalize(buf, 0.75)


def sfx_repair():
    buf = np.zeros(int(0.9 * SR))
    for i in range(6):  # трещотка ключа
        place(buf, highpass(noise(0.015), 2500) * env_exp(int(0.015 * SR), 0.004), i * 0.045)
    place(buf, chime(["E5", "A5", "C#6", "E6"], 0.06, 0.3, length=0.6) * 0.7, 0.3)
    return normalize(buf, 0.75)


def sfx_nitro():
    dur = 1.2
    t = t_axis(dur)
    n = len(t)
    sweep = np.zeros(n)
    hp = noise(dur)
    # шипение с нарастающей частотой
    for k, (lo, hi) in enumerate([(300, 900), (600, 1800), (1200, 3600), (2400, 7000)]):
        seg = bandpass(hp, lo, hi) * np.clip(1 - np.abs(t / dur * 4 - k - 0.5), 0, 1)
        sweep += seg
    boom = np.sin(2 * np.pi * (60 + 40 * np.exp(-t * 10)) * t) * env_exp(n, 0.25)
    return normalize(sweep * env_adsr(n, 0.02, 0.2, 0.7, 0.4) + boom * 0.8, 0.85)


def sfx_coin():
    return normalize(chime(["B5", "E6"], 0.08, 0.3, length=0.6), 0.7)


def sfx_buy():
    buf = chime(["C6", "E6", "G6", "C7", "E7"], 0.05, 0.4, length=1.1)
    for i in range(8):  # звон монет
        f = rng.uniform(3000, 5500)
        place(buf, osc("sine", f, 0.12) * env_exp(int(0.12 * SR), 0.03) * 0.25, 0.35 + i * 0.05)
    return normalize(buf, 0.75)


def sfx_click():
    dur = 0.05
    n = int(dur * SR)
    return normalize(osc("sine", 1300, dur) * env_exp(n, 0.012) + highpass(noise(dur), 3000) * env_exp(n, 0.004) * 0.3, 0.5)


def sfx_hover():
    dur = 0.04
    n = int(dur * SR)
    return normalize(osc("sine", 2100, dur) * env_exp(n, 0.008), 0.25)


def sfx_beep(freq=660, dur=0.18):
    n = int(dur * SR)
    return normalize((osc("square", freq, dur) * 0.4 + osc("sine", freq, dur)) * env_adsr(n, 0.003, 0.03, 0.7, 0.05), 0.55)


def sfx_warn():
    buf = np.zeros(int(0.22 * SR))
    for i in range(2):
        place(buf, osc("sine", 1500, 0.06) * env_adsr(int(0.06 * SR), 0.002, 0.01, 0.8, 0.02), i * 0.1)
    return normalize(buf, 0.35)


def sfx_horn():
    dur = 0.55
    n = int(dur * SR)
    x = osc("square", 415, dur) + osc("square", 523, dur) * 0.8
    return normalize(lowpass(x, 1800) * env_adsr(n, 0.01, 0.05, 0.9, 0.08), 0.6)


def sfx_siren():
    dur = 2.0
    t = t_axis(dur)
    f = np.where((t % 1.0) < 0.5, 650.0, 900.0)
    f = lowpass(f, 30, 1)   # мягкие переходы тона
    x = osc("tri", f, dur) * 0.8 + osc("sine", f * 2, dur) * 0.2
    return normalize(make_loop(x, 0.05), 0.45)


def sfx_thunder():
    dur = 3.5
    t = t_axis(dur)
    n = len(t)
    crack = highpass(noise(dur), 1500) * env_exp(n, 0.05)
    rumble = lowpass(noise(dur), 160, 3) * env_adsr(n, 0.05, 0.4, 0.6, 2.5)
    rumble *= 0.7 + 0.3 * np.sin(2 * np.pi * 3 * t)
    return normalize(crack * 0.4 + rumble * 2.0, 0.95)


def sfx_rain():
    dur = 4.0
    x = bandpass(noise(dur), 800, 6000) * 0.5 + lowpass(noise(dur), 400) * 0.3
    for _ in range(220):  # капли
        f = rng.uniform(2000, 6000)
        place(x, osc("sine", f, 0.02) * env_exp(int(0.02 * SR), 0.004) * rng.uniform(0.05, 0.2),
              rng.uniform(0, dur - 0.03))
    return normalize(make_loop(x, 0.3), 0.6)


def sfx_wind():
    dur = 5.0
    t = t_axis(dur)
    x = bandpass(noise(dur), 200, 1200) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.4 * t) ** 2)
    x += bandpass(noise(dur), 1200, 3000) * 0.2 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.6 * t + 1))
    return normalize(make_loop(x, 0.5), 0.6)


def sfx_city():
    dur = 5.0
    t = t_axis(dur)
    x = lowpass(noise(dur), 250) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.3 * t))   # далёкий гул машин
    return normalize(make_loop(x, 0.5), 0.5)


def sfx_gameover():
    buf = np.zeros(int(2.0 * SR))
    for i, nm in enumerate(["G4", "F#4", "F4", "E4"]):
        d = 0.35 if i < 3 else 1.0
        tone = (osc("square", note_freq(nm), d) * 0.35 + osc("saw", note_freq(nm) * 0.5, d) * 0.3)
        tone = lowpass(tone, 2500) * env_adsr(len(tone), 0.01, 0.05, 0.7, 0.15)
        if i == 3:
            tone *= 1 + 0.15 * np.sin(2 * np.pi * 6 * t_axis(d))
        place(buf, tone, i * 0.32)
    return normalize(buf, 0.8)


def sfx_record():
    buf = np.zeros(int(2.2 * SR))
    seq = [("C5", 0.0), ("E5", 0.12), ("G5", 0.24), ("C6", 0.36), ("G5", 0.6), ("C6", 0.72)]
    for nm, at in seq:
        d = 0.25 if at < 0.7 else 1.3
        tone = osc("saw", note_freq(nm), d) * 0.4 + osc("square", note_freq(nm) * 1.002, d) * 0.3
        tone = lowpass(tone, 4000) * env_adsr(len(tone), 0.01, 0.08, 0.7, 0.2)
        place(buf, tone, at)
    place(buf, chime(["C7", "E7", "G7"], 0.08, 0.5, length=1.0) * 0.4, 0.75)
    return normalize(buf, 0.8)


def sfx_whoosh():
    dur = 0.45
    t = t_axis(dur)
    n = len(t)
    x = noise(dur)
    lo = bandpass(x, 300, 1200) * np.clip(1 - t / dur * 2, 0, 1)
    hi = bandpass(x, 1200, 5000) * np.clip(t / dur * 2 - 0.2, 0, 1)
    return normalize((lo + hi) * env_adsr(n, 0.05, 0.1, 0.8, 0.2), 0.45)


def sfx_bird():
    # «Курлык» омской птицы
    buf = np.zeros(int(0.9 * SR))
    for i in range(3):
        d = 0.16
        f = np.linspace(420, 300, int(d * SR)) * (1 + 0.05 * np.sin(2 * np.pi * 30 * t_axis(d)))
        tone = (osc("sine", f, d) + osc("sine", f * 2.0, d) * 0.4) * env_adsr(int(d * SR), 0.01, 0.03, 0.7, 0.06)
        place(buf, tone, i * 0.22)
    return normalize(lowpass(buf, 2500), 0.6)


def sfx_splat():
    dur = 0.35
    n = int(dur * SR)
    x = lowpass(noise(dur), 900) * env_exp(n, 0.06)
    x += osc("sine", np.linspace(300, 90, n), dur) * env_exp(n, 0.08) * 0.6
    return normalize(x, 0.7)


def sfx_heartbeat():
    dur = 1.0
    buf = np.zeros(int(dur * SR))
    for at, amp in [(0.0, 1.0), (0.22, 0.7)]:
        d = 0.15
        beat = osc("sine", np.linspace(70, 45, int(d * SR)), d) * env_exp(int(d * SR), 0.05) * amp
        place(buf, beat, at)
    return normalize(lowpass(buf, 300), 0.8)


def sfx_nearmiss():
    w = sfx_whoosh() * 0.7
    buf = np.zeros(len(w) + int(0.4 * SR))
    place(buf, w, 0)
    place(buf, chime(["A6", "E7"], 0.05, 0.15, length=0.4) * 0.5, 0.15)
    return normalize(buf, 0.6)


# ---------------------------------------------------------------------------
# Музыка: маленький секвенсор
# ---------------------------------------------------------------------------
class Song:
    def __init__(self, bpm, bars, beats=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.beats = beats
        self.length = bars * beats * self.beat
        self.buf = np.zeros(int(self.length * SR) + SR)

    def at(self, bar, beat):
        return (bar * self.beats + beat) * self.beat

    def add(self, x, bar, beat, gain=1.0):
        place(self.buf, x * gain, self.at(bar, beat))

    def render(self):
        out = self.buf[:int(self.length * SR)]
        # петля: хвосты последнего такта переносим в начало
        tail = self.buf[int(self.length * SR):]
        out[:len(tail)] += tail
        return normalize(out, 0.85)


# Ударные
def kick(dur=0.35):
    t = t_axis(dur)
    return osc("sine", 50 + 110 * np.exp(-t * 30), dur) * env_exp(len(t), 0.12)


def snare(dur=0.25):
    t = t_axis(dur)
    n = len(t)
    return highpass(noise(dur), 1200) * env_exp(n, 0.06) * 0.8 + osc("sine", 190, dur) * env_exp(n, 0.04) * 0.5


def hat(dur=0.06, open_=False):
    n = int(dur * SR)
    return highpass(noise(dur), 7000) * env_exp(n, 0.08 if open_ else 0.015) * 0.5


def tom(freq, dur=0.3):
    t = t_axis(dur)
    return osc("sine", freq * (1 + 0.5 * np.exp(-t * 20)), dur) * env_exp(len(t), 0.12)


def bell_hit(dur=0.15):
    n = int(dur * SR)
    t = t_axis(dur)
    return (np.sin(2 * np.pi * 5200 * t) + np.sin(2 * np.pi * 6930 * t)) * env_exp(n, 0.03) * 0.15


# Инструменты
def synth(kind, nm, dur, cutoff=3000, a=0.01, d=0.1, s=0.7, r=0.15, detune=0.0, vib=0.0):
    f = note_freq(nm) if isinstance(nm, str) else nm
    t = t_axis(dur)
    freq = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t)) if vib else f
    x = osc(kind, freq, dur)
    if detune:
        x = x * 0.6 + osc(kind, (freq if np.isscalar(freq) else freq) * (1 + detune), dur) * 0.4
    x = lowpass(x, cutoff)
    return x * env_adsr(len(x), a, d, s, r)


def pluck(nm, dur, bright=4000):
    f = note_freq(nm)
    x = osc("saw", f, dur) * 0.6 + osc("square", f * 1.003, dur) * 0.3
    n = len(x)
    # фильтр «закрывается» после щипка: смешиваем яркую и глухую версии
    bright_x = lowpass(x, bright)
    dark_x = lowpass(x, 450)
    k = np.exp(-np.arange(n) / SR / 0.12)
    return (dark_x + (bright_x - dark_x) * k) * env_exp(n, 0.35)


def epiano(nm, dur):
    f = note_freq(nm)
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * f * 2 * t) * 1.2 * env_exp(len(t), 0.2)
    x = np.sin(2 * np.pi * f * t + mod) * env_exp(len(t), 0.8)
    return x * env_adsr(len(t), 0.005, 0.05, 1.0, 0.1)


def glock(nm, dur):
    f = note_freq(nm)
    t = t_axis(dur)
    x = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) + 0.2 * np.sin(2 * np.pi * f * 5.4 * t)
    return x * env_exp(len(t), 0.5)


def accordion(nm, dur):
    f = note_freq(nm)
    t = t_axis(dur)
    x = osc("square", f * (1 + 0.004 * np.sin(2 * np.pi * 6 * t)), dur) * 0.5 \
        + osc("square", f * 1.006, dur) * 0.4 + osc("saw", f * 2, dur) * 0.15
    return lowpass(x, 2800) * env_adsr(len(t), 0.03, 0.05, 0.85, 0.08)


def balalaika(nm, dur):
    # быстрое тремоло щипками
    buf = np.zeros(int(dur * SR))
    step = 0.07
    k = 0
    while k * step < dur - 0.02:
        place(buf, pluck(nm, min(0.25, dur - k * step), 3000) * (0.8 if k % 2 else 1.0), k * step)
        k += 1
    return buf


def chord_notes(root, kind="min", octave=3):
    base = note_freq(f"{root}{octave}")
    iv = {"maj": [0, 4, 7], "min": [0, 3, 7], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10], "dom7": [0, 4, 7, 10]}[kind]
    return [base * 2 ** (i / 12) for i in iv]


def pad(freqs, dur, cutoff=1800, kind="saw"):
    x = sum(synth(kind, f, dur, cutoff, a=0.3, d=0.2, s=0.8, r=0.4, detune=0.006) for f in freqs)
    return x / len(freqs)


def bassline(song, roots, pattern, octave=2, kind="saw", cutoff=900, gain=0.5):
    """roots: аккорд на такт, pattern: доли, где играет бас (+ длительность)"""
    for bar in range(song.bars):
        root = roots[bar % len(roots)]
        for beat, length, oct_shift in pattern:
            nm = f"{root}{octave + oct_shift}"
            song.add(synth(kind, nm, length * song.beat, cutoff, a=0.005, d=0.08, s=0.6, r=0.05), bar, beat, gain)


def drums(song, kick_beats, snare_beats, hat_step=0.5, hat_gain=0.3, swing=0.0, skip_bars=()):
    for bar in range(song.bars):
        if bar in skip_bars:
            continue
        for b in kick_beats:
            song.add(kick(), bar, b, 0.9)
        for b in snare_beats:
            song.add(snare(), bar, b, 0.55)
        b = 0.0
        i = 0
        while b < song.beats:
            off = swing if i % 2 else 0.0
            song.add(hat(open_=(i % 4 == 3)), bar, b + off, hat_gain)
            b += hat_step
            i += 1


def melody(song, notes, instrument, gain=0.4, start_bar=0):
    """notes: список (нота|None, длительность в долях)"""
    pos = start_bar * song.beats
    total = song.bars * song.beats
    while pos < total:
        for nm, length in notes:
            if pos >= total:
                break
            if nm:
                bar, beat = divmod(pos, song.beats)
                song.add(instrument(nm, length * song.beat * 1.05), int(bar), beat, gain)
            pos += length


def track_menu():
    s = Song(96, 16)
    prog = [("A", "min"), ("F", "maj"), ("C", "maj"), ("G", "maj")]
    for bar in range(s.bars):
        r, k = prog[bar % 4]
        s.add(pad(chord_notes(r, k, 3), s.beat * 4, 1500), bar, 0, 0.35)
    bassline(s, [p[0] for p in prog], [(0, 1.5, 0), (1.5, 0.5, 0), (2, 1.5, 0), (3.5, 0.5, 1)], gain=0.35, cutoff=600)
    drums(s, [0, 2.5], [1, 3], 0.5, 0.18, skip_bars=(0, 1))
    arp = []
    for r, k in prog:
        fs = chord_notes(r, k, 4)
        for i in range(8):
            arp.append(fs[[0, 1, 2, 1][i % 4]])
    pos = 0
    for bar in range(4, s.bars):
        for i in range(8):
            f = arp[(bar % 4) * 8 + i]
            s.add(synth("pulse", f, s.beat * 0.45, 2500, a=0.003, d=0.1, s=0.4, r=0.05), bar, i * 0.5, 0.12)
    melody(s, [("E5", 2), ("D5", 1), ("C5", 1), ("C5", 2), ("A4", 2), ("G4", 3), ("E5", 1), ("D5", 4),
               ("E5", 2), ("G5", 1), ("A5", 1), ("C6", 2), ("A5", 2), ("G5", 3), ("E5", 1), ("D5", 4)],
           lambda n, d: synth("tri", n, d, 3000, a=0.03, s=0.6, r=0.3, vib=0.004), 0.25, start_bar=8)
    return s.render()


def track_city():
    s = Song(112, 16)
    prog = ["E", "C", "G", "D"]
    kinds = ["min", "maj", "maj", "maj"]
    for bar in range(s.bars):
        s.add(pad(chord_notes(prog[bar % 4], kinds[bar % 4], 3), s.beat * 4, 1600), bar, 0, 0.25)
    bassline(s, prog, [(b * 0.5, 0.45, 1 if b % 4 == 3 else 0) for b in range(8)], gain=0.4, cutoff=700)
    drums(s, [0, 1, 2, 3], [1, 3], 0.5, 0.2, skip_bars=(0,))
    for bar in range(2, s.bars):
        fs = chord_notes(prog[bar % 4], kinds[bar % 4], 4)
        for i in range(16):
            s.add(synth("saw", fs[[0, 1, 2, 1, 2, 0, 1, 2][i % 8]] * (2 if i % 8 >= 6 else 1),
                        s.beat * 0.22, 3500, a=0.002, d=0.05, s=0.3, r=0.03), bar, i * 0.25, 0.08)
    melody(s, [("B4", 1.5), ("E5", 1.5), ("G5", 1), ("F#5", 2), ("E5", 2), ("G5", 1.5), ("A5", 1.5), ("B5", 1),
               ("A5", 2), ("F#5", 2)],
           lambda n, d: synth("square", n, d, 2600, a=0.01, s=0.5, r=0.2, vib=0.003), 0.18, start_bar=8)
    return s.render()


def track_winter():
    s = Song(100, 16)
    prog = [("D", "min"), ("A#", "maj"), ("F", "maj"), ("C", "maj")]
    for bar in range(s.bars):
        r, k = prog[bar % 4]
        s.add(pad(chord_notes(r, k, 3), s.beat * 4, 1200, "tri"), bar, 0, 0.4)
    bassline(s, [p[0] for p in prog], [(0, 2, 0), (2, 2, 0)], gain=0.35, kind="sine", cutoff=500)
    for bar in range(s.bars):            # бубенцы
        for i in range(8):
            s.add(bell_hit(), bar, i * 0.5, 0.6 if i % 2 == 0 else 0.35)
        if bar >= 2:
            s.add(kick(), bar, 0, 0.6)
            s.add(kick(), bar, 2, 0.6)
    melody(s, [("A5", 1), ("F5", 1), ("D5", 1), ("F5", 1), ("A#5", 2), ("A5", 2), ("G5", 1), ("F5", 1), ("E5", 1),
               ("G5", 1), ("A5", 4), ("D6", 1), ("C6", 1), ("A#5", 1), ("A5", 1), ("G5", 2), ("F5", 2),
               ("E5", 1), ("F5", 1), ("G5", 1), ("E5", 1), ("D5", 4)], glock, 0.35, start_bar=4)
    return s.render()


def track_desert():
    s = Song(104, 16)
    prog = ["E", "F", "G", "F"]
    for bar in range(s.bars):
        s.add(pad([note_freq(f"{prog[bar % 4]}3"), note_freq(f"{prog[bar % 4]}3") * 1.5], s.beat * 4, 900), bar, 0, 0.2)
        for i, b in enumerate([0, 1.5, 2, 3, 3.5]):
            s.add(tom(110 if i % 2 else 80), bar, b, 0.5)
        s.add(snare(), bar, 3, 0.25)
    bassline(s, prog, [(0, 0.75, 0), (1, 0.5, 0), (1.5, 0.5, 1), (2, 1, 0), (3, 0.5, 0)], gain=0.4, kind="tri", cutoff=800)
    # «твэнг»-гитара: щипки с вибрато
    melody(s, [("E4", 0.5), ("G4", 0.5), ("B4", 0.5), ("E5", 1.5), ("D5", 0.5), ("C5", 0.5), ("B4", 2),
               ("F4", 0.5), ("A4", 0.5), ("C5", 0.5), ("F5", 1.5), ("E5", 0.5), ("D5", 0.5), ("C5", 2),
               ("G4", 0.5), ("B4", 0.5), ("D5", 0.5), ("G5", 1.5), ("F5", 0.5), ("E5", 0.5), ("D5", 2),
               ("F5", 1), ("E5", 1), ("D#5", 1), ("E5", 1)], lambda n, d: pluck(n, d + 0.3, 3500), 0.35, start_bar=2)
    return s.render()


def track_rain():
    s = Song(84, 16)
    prog = [("C", "maj7"), ("A", "min7"), ("F", "maj7"), ("G", "dom7")]
    for bar in range(s.bars):
        r, k = prog[bar % 4]
        fs = chord_notes(r, k, 4)
        for beat in [0, 1.5, 2.5]:
            for f in fs:
                s.add(epiano_f(f, s.beat * 1.4), bar, beat, 0.12)
    bassline(s, [p[0] for p in prog], [(0, 1.5, 0), (1.5, 1, 0), (3, 1, 0)], gain=0.4, kind="sine", cutoff=400)
    drums(s, [0, 2.25], [1, 3], 0.5, 0.15, swing=0.12)
    # «шум винила»
    vinyl = lowpass(noise(s.length + 1), 3000) * 0.015
    s.buf[:len(vinyl)] += vinyl[:len(s.buf)]
    melody(s, [("E5", 1.5), ("G5", 0.5), ("D5", 2), (None, 1), ("C5", 1), ("A4", 2), ("C5", 1.5), ("D5", 0.5),
               ("E5", 2), ("G5", 1), ("F5", 1), ("E5", 2), ("D5", 2)], epiano, 0.25, start_bar=4)
    return s.render()


def epiano_f(f, dur):
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * f * 2 * t) * 1.0 * env_exp(len(t), 0.2)
    return np.sin(2 * np.pi * f * t + mod) * env_exp(len(t), 0.7) * env_adsr(len(t), 0.005, 0.05, 1.0, 0.1)


def track_neon():
    s = Song(128, 16)
    prog = ["F#", "D", "A", "E"]
    kinds = ["min", "maj", "maj", "maj"]
    for bar in range(s.bars):
        s.add(pad(chord_notes(prog[bar % 4], kinds[bar % 4], 3), s.beat * 4, 2200), bar, 0, 0.22)
    bassline(s, prog, [(b * 0.25, 0.22, 0) for b in range(16)], gain=0.35, cutoff=1100)
    drums(s, [0, 1, 2, 3], [1, 3], 0.25, 0.15)
    melody(s, [("C#5", 0.5), ("F#5", 0.5), ("A5", 0.5), ("C#6", 1), ("B5", 0.5), ("A5", 1),
               ("F#5", 0.5), ("A5", 0.5), ("D6", 1), ("C#6", 1), ("A5", 1), ("E5", 0.5), ("G#5", 0.5),
               ("B5", 1), ("A5", 1), ("G#5", 1), ("E5", 1)],
           lambda n, d: synth("saw", n, d, 3200, a=0.005, d=0.1, s=0.6, r=0.1, detune=0.008), 0.18, start_bar=4)
    return s.render()


def track_omsk():
    # Народно-электронный трек в ля миноре: аккордеон, балалайка и «ум-па» ритм
    s = Song(118, 16, 4)
    prog = [("A", "min"), ("D", "min"), ("E", "maj"), ("A", "min")]
    for bar in range(s.bars):
        r, k = prog[bar % 4]
        fs = chord_notes(r, k, 3)
        for beat in range(4):          # «ум-па»
            if beat % 2 == 0:
                s.add(synth("tri", fs[0] / 2, s.beat * 0.4, 600, a=0.005, s=0.6, r=0.05), bar, beat, 0.45)
                s.add(kick(), bar, beat, 0.7)
            else:
                for f in fs:
                    s.add(synth("square", f, s.beat * 0.3, 1800, a=0.005, s=0.5, r=0.05), bar, beat, 0.07)
                s.add(snare(0.15), bar, beat, 0.3)
        for i in range(8):
            s.add(hat(), bar, i * 0.5, 0.12)
    melody(s, [("E5", 1), ("A5", 1), ("C6", 1), ("B5", 0.5), ("A5", 0.5), ("D6", 1), ("C6", 0.5), ("B5", 0.5),
               ("A5", 2), ("G#5", 1), ("B5", 1), ("E5", 2), ("A5", 1), ("C6", 1), ("E6", 1), ("D6", 0.5),
               ("C6", 0.5), ("B5", 1), ("C6", 0.5), ("B5", 0.5), ("A5", 2)], accordion, 0.22, start_bar=0)
    melody(s, [("A4", 2), ("E4", 2), ("D4", 2), ("F4", 2), ("E4", 2), ("G#4", 2), ("A4", 4)],
           lambda n, d: balalaika(n, d), 0.18, start_bar=8)
    return s.render()


def main():
    print("Звуки:")
    sfx = {
        "engine": sfx_engine, "engine_ev": sfx_engine_ev, "skid": sfx_skid, "crash": sfx_crash,
        "hit": sfx_hit, "bump": sfx_bump, "splash": sfx_splash, "pickup": sfx_pickup, "fuel": sfx_fuel,
        "repair": sfx_repair, "nitro": sfx_nitro, "coin": sfx_coin, "buy": sfx_buy, "click": sfx_click,
        "hover": sfx_hover, "beep": lambda: sfx_beep(660), "go": lambda: sfx_beep(1320, 0.45),
        "warn": sfx_warn, "horn": sfx_horn, "siren": sfx_siren, "thunder": sfx_thunder, "rain": sfx_rain,
        "wind": sfx_wind, "city": sfx_city, "gameover": sfx_gameover, "record": sfx_record,
        "whoosh": sfx_whoosh, "bird": sfx_bird, "splat": sfx_splat, "heartbeat": sfx_heartbeat,
        "nearmiss": sfx_nearmiss, "drone": sfx_drone, "alarm": sfx_alarm,
    }
    # python generate_audio.py drone alarm — пересоздать только указанные звуки
    only = [a for a in sys.argv[1:]]
    if only:
        sfx = {k: v for k, v in sfx.items() if k in only}
    for name, fn in sfx.items():
        save(fn(), os.path.join(SFX_DIR, name + ".ogg"))
    if only:
        return
    print("Музыка:")
    tracks = {"menu": track_menu, "city": track_city, "winter": track_winter, "desert": track_desert,
              "rain": track_rain, "neon": track_neon, "omsk": track_omsk}
    for name, fn in tracks.items():
        save(fn(), os.path.join(MUSIC_DIR, name + ".ogg"), quality=3)


if __name__ == "__main__":
    main()
