#!/usr/bin/env python3
"""
迷你华尔街 — 8-bit 风格音效生成器
使用 Python 标准库 wave + struct，零外部依赖
输出: assets/audio/*.wav (16-bit PCM, 44100Hz)
"""

import wave
import struct
import math
import os
import random

SAMPLE_RATE = 44100
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "audio")


def square_wave(freq, duration, volume=0.3, duty=0.5):
    """方波（8-bit 游戏经典音色）"""
    samples = int(SAMPLE_RATE * duration)
    data = []
    for i in range(samples):
        t = i / SAMPLE_RATE
        phase = (t * freq) % 1.0
        val = volume if phase < duty else -volume
        data.append(val)
    return data


def triangle_wave(freq, duration, volume=0.3):
    """三角波（柔和的 8-bit 音色）"""
    samples = int(SAMPLE_RATE * duration)
    data = []
    for i in range(samples):
        t = i / SAMPLE_RATE
        phase = (t * freq) % 1.0
        val = volume * (4.0 * abs(phase - 0.5) - 1.0)
        data.append(val)
    return data


def sawtooth_wave(freq, duration, volume=0.3):
    """锯齿波（粗糙的 8-bit 音色）"""
    samples = int(SAMPLE_RATE * duration)
    data = []
    for i in range(samples):
        t = i / SAMPLE_RATE
        phase = (t * freq) % 1.0
        val = volume * (2.0 * phase - 1.0)
        data.append(val)
    return data


def noise(duration, volume=0.2):
    """白噪声"""
    samples = int(SAMPLE_RATE * duration)
    data = []
    for i in range(samples):
        data.append(volume * (random.random() * 2.0 - 1.0))
    return data


def sweep(freq_start, freq_end, duration, volume=0.3, wave_type="square"):
    """频率扫描（上升/下降音效）"""
    samples = int(SAMPLE_RATE * duration)
    data = []
    for i in range(samples):
        t = i / SAMPLE_RATE
        progress = i / max(samples - 1, 1)
        freq = freq_start + (freq_end - freq_start) * progress
        phase = (t * freq) % 1.0
        if wave_type == "square":
            val = volume if phase < 0.5 else -volume
        elif wave_type == "sawtooth":
            val = volume * (2.0 * phase - 1.0)
        else:
            val = volume * (4.0 * abs(phase - 0.5) - 1.0)
        data.append(val)
    return data


def envelope(data, attack=0.01, release=0.05):
    """ADSR 包络（淡入淡出）"""
    samples = len(data)
    attack_samples = int(attack * SAMPLE_RATE)
    release_samples = int(release * SAMPLE_RATE)
    result = []
    for i in range(samples):
        env = 1.0
        if i < attack_samples:
            env = i / max(attack_samples, 1)
        elif i > samples - release_samples:
            env = (samples - i) / max(release_samples, 1)
        result.append(data[i] * env)
    return result


def mix(*layers):
    """混合多个音层"""
    max_len = max(len(l) for l in layers)
    result = [0.0] * max_len
    for layer in layers:
        for i in range(len(layer)):
            result[i] += layer[i]
    # 归一化防止削波
    peak = max(abs(v) for v in result) if result else 1.0
    if peak > 0.9:
        result = [v * 0.9 / peak for v in result]
    return result


def concat(*segments):
    """拼接多段音频"""
    result = []
    for seg in segments:
        result.extend(seg)
    return result


def save_wav(filename, data):
    """保存为 WAV 文件"""
    filepath = os.path.join(OUTPUT_DIR, filename)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(SAMPLE_RATE)
        for sample in data:
            clamped = max(-1.0, min(1.0, sample))
            wf.writeframes(struct.pack('<h', int(clamped * 32767)))
    print(f"  ✓ {filename} ({len(data)/SAMPLE_RATE:.2f}s, {len(data)} samples)")


# ─── 9 种音效生成 ───────────────────────────────────────────────────────────────

def gen_buy():
    """BUY: 短促上升方波 (440→880Hz, 0.1s)"""
    data = sweep(440, 880, 0.08, volume=0.25, wave_type="square")
    data = envelope(data, attack=0.005, release=0.02)
    save_wav("buy.wav", data)


def gen_sell():
    """SELL: 短促下降方波 (880→440Hz, 0.1s)"""
    data = sweep(880, 440, 0.08, volume=0.25, wave_type="square")
    data = envelope(data, attack=0.005, release=0.02)
    save_wav("sell.wav", data)


def gen_extraction_success():
    """EXTRACTION_SUCCESS: C-E-G 和弦琶音 (0.5s)"""
    c = envelope(square_wave(261.6, 0.15, 0.2), release=0.03)
    e = envelope(square_wave(329.6, 0.15, 0.2), release=0.03)
    g = envelope(square_wave(392.0, 0.20, 0.25), release=0.05)
    data = concat(c, e, g)
    save_wav("extraction_success.wav", data)


def gen_bust():
    """BUST: 低沉下降锯齿波 + 噪声 (0.5s)"""
    saw = sweep(220, 55, 0.4, volume=0.25, wave_type="sawtooth")
    nz = noise(0.4, volume=0.1)
    data = mix(saw, nz)
    data = envelope(data, attack=0.01, release=0.1)
    save_wav("bust.wav", data)


def gen_news_alert():
    """NEWS_ALERT: 短促高频方波 (660Hz, 0.05s)"""
    data = square_wave(660, 0.04, volume=0.2)
    data = envelope(data, attack=0.003, release=0.01)
    save_wav("news_alert.wav", data)


def gen_black_swan():
    """BLACK_SWAN: 低频脉冲 + 高频刺耳 (0.4s)"""
    low = square_wave(80, 0.3, volume=0.2, duty=0.3)
    high = sweep(2000, 500, 0.3, volume=0.15, wave_type="sawtooth")
    data = mix(low, high)
    data = envelope(data, attack=0.005, release=0.08)
    save_wav("black_swan.wav", data)


def gen_boss_enter():
    """BOSS_ENTER: 三声鼓点 (低频脉冲 ×3, 0.3s)"""
    hit = lambda: envelope(square_wave(80, 0.06, volume=0.3, duty=0.2), release=0.03)
    silence = [0.0] * int(SAMPLE_RATE * 0.04)
    data = concat(hit(), silence, hit(), silence, hit())
    save_wav("boss_enter.wav", data)


def gen_window_open():
    """WINDOW_OPEN: 上升琶音 (523Hz→784Hz, 0.15s)"""
    data = sweep(523, 784, 0.12, volume=0.2, wave_type="triangle")
    data = envelope(data, attack=0.005, release=0.03)
    save_wav("window_open.wav", data)


def gen_tick():
    """TICK: 极短脉冲 (1000Hz, 0.02s)"""
    data = square_wave(1000, 0.015, volume=0.1)
    data = envelope(data, attack=0.002, release=0.005)
    save_wav("tick.wav", data)


# ─── 主入口 ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"生成 8-bit 音效 → {OUTPUT_DIR}\n")
    gen_buy()
    gen_sell()
    gen_extraction_success()
    gen_bust()
    gen_news_alert()
    gen_black_swan()
    gen_boss_enter()
    gen_window_open()
    gen_tick()
    print(f"\n✅ 全部 9 个音效文件生成完毕")
