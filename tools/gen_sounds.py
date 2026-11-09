"""Sintetiza los efectos de sonido y el ambiente del juego. Todo es original, sin muestras externas.

Uso: python tools/gen_sounds.py
Salida: audio/*.wav (22050 Hz, mono, 16 bits).
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "audio"
rng = random.Random(7)


def silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def tone(freq, seconds: float, shape: str = "sine", amp: float = 1.0) -> list[float]:
    """freq puede ser un número o una función del tiempo (barrido)."""
    out, phase = [], 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        f = freq(t) if callable(freq) else freq
        phase += f / RATE
        p = phase % 1.0
        if shape == "sine":
            v = math.sin(2 * math.pi * p)
        elif shape == "square":
            v = 1.0 if p < 0.5 else -1.0
        elif shape == "saw":
            v = 2 * p - 1
        else:  # triangle
            v = 4 * abs(p - 0.5) - 1
        out.append(v * amp)
    return out


def noise(seconds: float, amp: float = 1.0) -> list[float]:
    return [rng.uniform(-1, 1) * amp for _ in range(int(RATE * seconds))]


def lowpass(samples: list[float], cutoff: float) -> list[float]:
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def envelope(samples: list[float], attack: float, release: float) -> list[float]:
    n = len(samples)
    a, r = max(1, int(RATE * attack)), max(1, int(RATE * release))
    out = []
    for i, s in enumerate(samples):
        g = min(1.0, i / a) * min(1.0, (n - i) / r)
        out.append(s * g)
    return out


def decay(samples: list[float], rate: float) -> list[float]:
    return [s * math.exp(-rate * i / RATE) for i, s in enumerate(samples)]


def mix(*tracks: list[float]) -> list[float]:
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def at(samples: list[float], seconds: float, total: float) -> list[float]:
    """Coloca un sonido en un instante dentro de una pista de duración total."""
    out = silence(total)
    start = int(RATE * seconds)
    for i, s in enumerate(samples):
        if start + i < len(out):
            out[start + i] += s
    return out


def gain(samples: list[float], g: float) -> list[float]:
    return [s * g for s in samples]


def loop_fade(samples: list[float], seconds: float = 0.05) -> list[float]:
    """Funde final con principio para que el bucle no haga clic."""
    n = int(RATE * seconds)
    out = samples[:]
    for i in range(n):
        w = i / n
        out[i] = samples[i] * w + samples[-n + i] * (1 - w)
    return out[:-n]


def save(name: str, samples: list[float], peak: float = 0.9) -> None:
    top = max(1e-9, max(abs(s) for s in samples))
    scale = peak / top
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print(f"{name}.wav {len(samples) / RATE:.2f} s")


def thump(freq: float, seconds: float) -> list[float]:
    body = tone(lambda t: freq * (1 - 0.5 * t / seconds), seconds)
    return decay(mix(body, lowpass(noise(seconds, 0.4), 600)), 18)


def main() -> None:
    # Pasos: golpe sordo de ruido filtrado.
    save("step", envelope(decay(lowpass(noise(0.09), 900), 40), 0.002, 0.03), 0.5)

    # Clic de linterna.
    save("flashlight", decay(mix(noise(0.03, 0.7), tone(2400, 0.03, "square", 0.3)), 120), 0.6)

    # Pila recogida: dos notas ascendentes.
    blip = lambda f: envelope(tone(f, 0.07, "square", 0.4), 0.002, 0.03)
    save("battery", mix(at(blip(660), 0, 0.2), at(blip(990), 0.08, 0.2)), 0.6)

    # Generador reparándose: motor grave con traqueteo, en bucle.
    motor = mix(tone(55, 1.0, "saw", 0.5), tone(110, 1.0, "square", 0.15), lowpass(noise(1.0, 0.5), 400))
    rattle = [s * (0.6 + 0.4 * math.sin(2 * math.pi * 12 * i / RATE)) for i, s in enumerate(motor)]
    save("generator_loop", loop_fade(lowpass(rattle, 1200)), 0.5)

    # Generador reparado: acorde que arranca hacia arriba.
    rise = lambda f: envelope(tone(lambda t: f * (0.6 + 0.4 * min(1, t / 0.4)), 1.0, "saw", 0.25), 0.01, 0.4)
    save("generator_on", lowpass(mix(rise(110), rise(165), rise(220)), 2500), 0.7)

    # Puerta de salida: estruendo grave y golpe metálico.
    rumble = envelope(lowpass(noise(1.4, 1.0), 180), 0.1, 0.6)
    clang = decay(mix(tone(320, 1.0, "square", 0.3), tone(467, 1.0, "square", 0.2)), 6)
    save("door_open", mix(rumble, at(lowpass(clang, 2000), 1.0, 2.0)), 0.8)

    # Monstruo moviéndose: gorgoteo húmedo en bucle.
    gurgle = []
    base = lowpass(noise(2.0, 1.0), 300)
    for i, s in enumerate(base):
        t = i / RATE
        gurgle.append(s * (0.5 + 0.5 * math.sin(2 * math.pi * (7 + 3 * math.sin(2 * math.pi * 0.7 * t)) * t)))
    save("monster_loop", loop_fade(mix(gurgle, tone(lambda t: 70 + 10 * math.sin(2 * math.pi * 0.5 * t), 2.0, "triangle", 0.3))), 0.7)

    # Monstruo congelado: llanto distorsionado que cae.
    wail = tone(lambda t: 900 * (1 - 0.45 * t) + 40 * math.sin(2 * math.pi * 6 * t), 1.2, "saw", 0.6)
    wail = [max(-0.5, min(0.5, s * 2.5)) for s in wail]  # distorsión
    save("monster_freeze", envelope(lowpass(wail, 1800), 0.05, 0.5), 0.7)

    # Chillido del Nonato mejorado: grito agudo que sube, con ruido áspero. Apaga linternas.
    shriek = tone(lambda t: 1200 + 900 * t + 120 * math.sin(2 * math.pi * 11 * t), 1.0, "saw", 0.6)
    shriek = [max(-0.45, min(0.45, x * 3.0)) for x in shriek]
    save("monster_scream", envelope(lowpass(mix(shriek, noise(1.0, 0.35)), 3200), 0.02, 0.6), 0.8)

    # Latido: dos golpes por segundo y medio, en bucle.
    beat = mix(at(thump(55, 0.18), 0.0, 1.0), at(gain(thump(48, 0.2), 0.7), 0.22, 1.0))
    save("heartbeat_loop", beat, 0.9)

    # Derribo: golpe con ruido.
    save("down", mix(thump(70, 0.4), decay(lowpass(noise(0.5, 0.8), 1500), 10)), 0.9)

    # Reanimado: campanita suave.
    chime = mix(decay(tone(784, 0.8, "sine", 0.5), 5), at(decay(tone(1175, 0.6, "sine", 0.4), 6), 0.12, 0.8))
    save("revive", chime, 0.6)

    # Muerte: tono grave que se apaga.
    save("death", envelope(lowpass(mix(tone(lambda t: 90 - 40 * t, 1.5, "saw", 0.5), noise(1.5, 0.2)), 600), 0.01, 1.2), 0.8)

    # Interfaz.
    save("ui_click", decay(tone(1200, 0.05, "square", 0.3), 80), 0.4)

    # Ambiente: zumbido eléctrico débil, viento grave y crujidos metálicos ocasionales. 30 s en bucle.
    total = 30.0
    drone = mix(
        tone(lambda t: 41 + 2 * math.sin(2 * math.pi * t / 15), total, "sine", 0.4),
        tone(lambda t: 61.7 + 1.5 * math.sin(2 * math.pi * t / 10), total, "triangle", 0.15),
    )
    wind = lowpass(noise(total, 1.0), 220)
    wind = [s * (0.5 + 0.5 * math.sin(2 * math.pi * i / RATE / 7.5)) for i, s in enumerate(wind)]
    creaks = silence(total)
    for when in (4.3, 11.8, 19.1, 25.6):
        creak = envelope(tone(lambda t: 180 + 120 * math.sin(2 * math.pi * 3 * t), 0.7, "saw", 0.12), 0.1, 0.3)
        creaks = mix(creaks, at(lowpass(creak, 900), when, total))
    save("ambient_loop", loop_fade(mix(drone, gain(wind, 0.8), creaks), 1.0), 0.5)


if __name__ == "__main__":
    main()
