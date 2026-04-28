#!/usr/bin/env python3
"""生成坦克大戰音效 .wav 檔案（使用 Python 標準庫，不需要額外安裝）"""
import wave
import struct
import math
import random
import os

SAMPLE_RATE = 22050
MAX_AMP = 32767

def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    clamped = [max(-32768, min(32767, int(s))) for s in samples]
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack(f'<{len(clamped)}h', *clamped))

def sr(seconds):
    return int(SAMPLE_RATE * seconds)

def mix_down(tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    peak = max(abs(v) for v in out) if out else 1
    if peak > MAX_AMP:
        out = [v * MAX_AMP / peak for v in out]
    return out

# ── 1. 射擊音效 shoot.wav ──
def gen_shoot():
    n = sr(0.14)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 380 - 240 * (t / 0.14)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        env = max(0.0, 1.0 - (t / 0.14) ** 0.6)
        samples.append(MAX_AMP * 0.65 * math.sin(phase) * env)
    return samples

# ── 2. 磚牆命中 hit_brick.wav ──
def gen_hit_brick():
    n = sr(0.18)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        noise = random.uniform(-1, 1)
        env = max(0.0, 1.0 - t / 0.18 * 1.2)
        samples.append(MAX_AMP * 0.55 * noise * env)
    return samples

# ── 3. 鋼牆命中 hit_steel.wav ──
def gen_hit_steel():
    n = sr(0.22)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = (math.sin(2 * math.pi * 820 * t)
             + 0.45 * math.sin(2 * math.pi * 1350 * t)
             + 0.2 * math.sin(2 * math.pi * 2100 * t))
        env = math.exp(-t * 22)
        samples.append(MAX_AMP * 0.5 * s * env)
    return samples

# ── 4. 敵軍爆炸 explosion_enemy.wav ──
def gen_explosion_enemy():
    n = sr(0.55)
    noise_layer = [random.uniform(-1, 1) for _ in range(n)]
    rumble = []
    for i in range(n):
        t = i / SAMPLE_RATE
        rumble.append(0.45 * math.sin(2 * math.pi * 58 * t))
    combined = [noise_layer[i] * 0.6 + rumble[i] for i in range(n)]
    result = []
    for i, v in enumerate(combined):
        t = i / SAMPLE_RATE
        env = max(0.0, 1.0 - (t / 0.55) ** 0.5)
        result.append(MAX_AMP * v * env)
    return result

# ── 5. 玩家爆炸 explosion_player.wav ──
def gen_explosion_player():
    n = sr(0.75)
    noise_layer = [random.uniform(-1, 1) for _ in range(n)]
    rumble = []
    for i in range(n):
        t = i / SAMPLE_RATE
        rumble.append(0.55 * math.sin(2 * math.pi * 38 * t)
                      + 0.25 * math.sin(2 * math.pi * 72 * t))
    combined = [noise_layer[i] * 0.65 + rumble[i] for i in range(n)]
    result = []
    for i, v in enumerate(combined):
        t = i / SAMPLE_RATE
        env = max(0.0, 1.0 - (t / 0.75) ** 0.45)
        result.append(MAX_AMP * v * env)
    return result

# ── 6. 過關音效 stage_clear.wav ──
def gen_stage_clear():
    notes = [262, 330, 392, 523, 659, 784, 1047]
    samples = []
    for freq in notes:
        dur = 0.13
        n = sr(dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            s = (math.sin(2 * math.pi * freq * t)
                 + 0.3 * math.sin(2 * math.pi * freq * 2 * t))
            env = 1.0 - (t / dur) * 0.4
            samples.append(MAX_AMP * 0.45 * s * env)
    # 延音最後一個音
    freq = 1047
    dur = 0.5
    for i in range(sr(dur)):
        t = i / SAMPLE_RATE
        s = math.sin(2 * math.pi * freq * t)
        env = max(0.0, 1.0 - t / dur)
        samples.append(MAX_AMP * 0.45 * s * env)
    return samples

# ── 7. Game Over 音效 game_over.wav ──
def gen_game_over():
    # 下行三連音，每組降調
    pattern = [(494, 0.22), (440, 0.22), (392, 0.22),
               (370, 0.22), (330, 0.22), (294, 0.22),
               (262, 0.6)]
    samples = []
    for freq, dur in pattern:
        n = sr(dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            s = (math.sin(2 * math.pi * freq * t)
                 + 0.25 * math.sin(2 * math.pi * freq * 2 * t))
            env = max(0.0, 1.0 - t / dur * 0.5)
            samples.append(MAX_AMP * 0.45 * s * env)
        samples.extend([0] * sr(0.04))
    return samples

# ── 8. Boss 出現警告 boss_warning.wav ──
def gen_boss_warning():
    samples = []
    for _ in range(4):
        n_on = sr(0.12)
        for i in range(n_on):
            t = i / SAMPLE_RATE
            s = (math.sin(2 * math.pi * 880 * t)
                 + 0.35 * math.sin(2 * math.pi * 1760 * t))
            env = 1.0 if t < 0.08 else max(0.0, (0.12 - t) / 0.04)
            samples.append(MAX_AMP * 0.55 * s * env)
        samples.extend([0] * sr(0.09))
    return samples

# ── 9. 道具拾取 powerup.wav ──
def gen_powerup():
    notes = [523, 659, 784, 1047, 1319]
    samples = []
    for freq in notes:
        dur = 0.09
        n = sr(dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            s = (math.sin(2 * math.pi * freq * t)
                 + 0.2 * math.sin(2 * math.pi * freq * 3 * t))
            env = 1.0 - t / dur * 0.3
            samples.append(MAX_AMP * 0.5 * s * env)
    return samples

# ── 10. 背景音樂 bgm.wav (8-bit 風格循環) ──
def gen_bgm():
    # C大調五聲音階旋律，BPM ≈ 180，使用方波近似（奇次諧波）
    def note(freq, beats):
        dur = beats * (60.0 / 180)
        n = sr(dur)
        track = []
        for i in range(n):
            t = i / SAMPLE_RATE
            s = (math.sin(2 * math.pi * freq * t)
                 + 0.33 * math.sin(2 * math.pi * freq * 3 * t)
                 + 0.2  * math.sin(2 * math.pi * freq * 5 * t))
            gate = 1.0 if t < dur * 0.85 else max(0.0, (dur - t) / (dur * 0.15))
            track.append(MAX_AMP * 0.28 * s * gate)
        return track

    REST = lambda beats: [0.0] * sr(beats * (60.0 / 180))

    melody = (
        note(523, 0.5) + note(659, 0.5) + note(784, 0.5) + note(659, 0.5) +
        note(523, 0.5) + note(784, 0.5) + note(880, 1.0) +
        note(784, 0.5) + note(659, 0.5) + note(523, 0.5) + note(659, 0.5) +
        note(392, 0.5) + note(523, 1.0) + REST(0.5) +
        note(440, 0.5) + note(523, 0.5) + note(659, 0.5) + note(784, 0.5) +
        note(880, 0.5) + note(784, 0.5) + note(659, 1.0) +
        note(523, 0.5) + note(392, 0.5) + note(523, 0.5) + note(659, 0.5) +
        note(523, 2.0) + REST(0.5)
    )

    bass_notes = [
        (131, 2.0), (131, 2.0), (131, 2.0), (131, 2.0),
        (98,  2.0), (131, 2.0), (131, 2.0), (131, 2.0),
    ]
    bass = []
    for freq, beats in bass_notes:
        dur = beats * (60.0 / 180)
        n = sr(dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            s = math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(2 * math.pi * freq * 2 * t)
            gate = 1.0 if t < dur * 0.7 else max(0.0, (dur - t) / (dur * 0.3))
            bass.append(MAX_AMP * 0.18 * s * gate)

    # 補齊長度
    max_len = max(len(melody), len(bass))
    melody += [0.0] * (max_len - len(melody))
    bass   += [0.0] * (max_len - len(bass))
    return mix_down([melody, bass])

BASE = os.path.join(os.path.dirname(__file__), "audio")

SOUNDS = {
    "sfx/shoot":            gen_shoot,
    "sfx/hit_brick":        gen_hit_brick,
    "sfx/hit_steel":        gen_hit_steel,
    "sfx/explosion_enemy":  gen_explosion_enemy,
    "sfx/explosion_player": gen_explosion_player,
    "sfx/stage_clear":      gen_stage_clear,
    "sfx/game_over":        gen_game_over,
    "sfx/boss_warning":     gen_boss_warning,
    "sfx/powerup":          gen_powerup,
    "music/bgm":            gen_bgm,
}

if __name__ == "__main__":
    random.seed(42)
    for name, fn in SOUNDS.items():
        path = os.path.join(BASE, name + ".wav")
        samples = fn()
        write_wav(path, samples)
        print(f"  生成 {path}  ({len(samples)/SAMPLE_RATE:.2f}s)")
    print("完成！共生成 10 個音效檔案。")
