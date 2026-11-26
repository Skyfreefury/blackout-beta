"""Voz del Nonato: llanto de bebé deformado, gruñido y respiración al arrastrarse.

Uso: python tools/gen_monster_sounds.py
Sustituye a los sonidos del Nonato de tools/gen_sounds.py:
  audio/monster_scream.wav  chillido (agarre, chillido del mejorado, muerte), 1,6 s
  audio/monster_growl.wav   gruñido corto y húmedo, 0,8 s
  audio/monster_loop.wav    respiración gutural y arrastre en bucle, 3 s
Fuente de voz: tren de pulsos con tono que cambia, filtrado por formantes de vocal (a, u),
más una copia una octava más grave, saturación, tartamudeo y reverberación.
"""
import wave
from pathlib import Path

import numpy as np
from scipy import signal

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "audio"
RNG = np.random.default_rng(13)


def pulses(f0: np.ndarray) -> np.ndarray:
    """Fuente de voz: diente de sierra suavizado con el tono f0 en cada muestra."""
    phase = np.cumsum(f0 / RATE) % 1.0
    saw = 2.0 * phase - 1.0
    return signal.lfilter(*signal.butter(2, 3500 / (RATE / 2)), saw)


def formants(x: np.ndarray, freqs: list[tuple[float, float, float]]) -> np.ndarray:
    """Suma de resonadores de banda: (frecuencia, ancho de banda, ganancia)."""
    out = np.zeros_like(x)
    for f, bw, g in freqs:
        b, a = signal.iirpeak(f / (RATE / 2), f / bw)
        out += signal.lfilter(b, a, x) * g
    return out


def reverb(x: np.ndarray, seconds: float = 1.1, mix: float = 0.35) -> np.ndarray:
    n = int(seconds * RATE)
    ir = RNG.standard_normal(n) * np.exp(-np.linspace(0, 7, n))
    ir = signal.lfilter(*signal.butter(2, 2500 / (RATE / 2)), ir)
    wet = signal.fftconvolve(x, ir)[: len(x) + n - 1]
    dry = np.pad(x, (0, n - 1))
    wet /= np.max(np.abs(wet)) + 1e-9
    return dry * (1 - mix) + wet * mix * np.max(np.abs(x))


def envelope(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n)
    a, r = int(attack * RATE), int(release * RATE)
    e[:a] = np.linspace(0, 1, a)
    e[n - r:] *= np.linspace(1, 0, r)
    return e


def voice(seconds: float, f0_start: float, f0_end: float, vowel: str, sob: float) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    k = t / seconds
    # Tono que sube y se quiebra, con vibrato nervioso y temblor aleatorio.
    f0 = f0_start + (f0_end - f0_start) * np.sin(k * np.pi * 0.8)
    f0 *= 1 + 0.04 * np.sin(2 * np.pi * 7.5 * t) + 0.02 * signal.lfilter([1], [1, -0.995], RNG.standard_normal(n)) * 0.05
    vowels = {
        "a": [(800, 120, 1.0), (1150, 150, 0.6), (2900, 250, 0.25)],
        "u": [(350, 80, 1.0), (700, 120, 0.5), (2400, 300, 0.15)],
    }
    source = pulses(f0) + 0.08 * RNG.standard_normal(n)
    child = formants(source, vowels[vowel])
    # Segunda voz una octava más grave y ronca: el monstruo debajo del bebé.
    beast = formants(pulses(f0 * 0.5) + 0.15 * RNG.standard_normal(n), vowels["u"])
    mix = child / (np.max(np.abs(child)) + 1e-9) + 0.8 * beast / (np.max(np.abs(beast)) + 1e-9)
    # Tartamudeo de sollozo y saturación.
    mix *= 1 - sob * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 6.0 * t)))
    mix = np.tanh(mix * 2.5)
    return mix * envelope(n, 0.04, seconds * 0.45)


def growl(seconds: float) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    f0 = 70 + 25 * np.sin(2 * np.pi * 3 * t) + 10 * RNG.standard_normal(n).cumsum() / np.sqrt(n)
    rough = pulses(f0) * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t))
    wet = formants(rough + 0.25 * RNG.standard_normal(n), [(300, 90, 1.0), (650, 120, 0.7), (1800, 300, 0.2)])
    wet = np.tanh(wet / (np.max(np.abs(wet)) + 1e-9) * 3.0)
    return wet * envelope(n, 0.02, seconds * 0.6)


def breathing(seconds: float) -> np.ndarray:
    """Respiración gutural lenta y golpes de carne arrastrada, en bucle."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    air = formants(RNG.standard_normal(n), [(250, 100, 1.0), (500, 150, 0.6), (1100, 300, 0.25)])
    air /= np.max(np.abs(air)) + 1e-9
    # Inspirar y espirar dos veces por bucle; en la espiración, ronquido grave.
    cycle = 0.5 - 0.5 * np.cos(2 * np.pi * t / (seconds / 2))
    snore = formants(pulses(55 + 8 * np.sin(2 * np.pi * t)), [(250, 80, 1.0), (520, 120, 0.5)])
    snore /= np.max(np.abs(snore)) + 1e-9
    out = air * cycle * 0.7 + snore * cycle ** 2 * 0.5
    # Arrastres: golpes húmedos cortos al ritmo de los brazos.
    for at in np.arange(0.15, seconds, 0.5):
        i = int(at * RATE)
        m = int(0.12 * RATE)
        hit = signal.lfilter(*signal.butter(2, 600 / (RATE / 2)), RNG.standard_normal(m)) * np.exp(-np.linspace(0, 9, m))
        out[i:i + m] += hit[: max(0, min(m, n - i))] * 3.0
    # Fundido del final con el principio para que el bucle no haga clic.
    f = int(0.08 * RATE)
    out[:f] = out[:f] * np.linspace(0, 1, f) + out[-f:] * np.linspace(1, 0, f)
    return np.tanh(out * 1.5)[: n - f]


def save(name: str, x: np.ndarray, peak: float = 0.9) -> None:
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    pcm = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    print(f"{name}.wav {len(x) / RATE:.2f} s")


def main() -> None:
    scream = voice(1.6, 380, 620, "a", sob=0.35)
    save("monster_scream", reverb(scream, 1.2, 0.4), 0.85)
    save("monster_growl", reverb(growl(0.8), 0.6, 0.25), 0.85)
    save("monster_loop", breathing(3.0), 0.7)


if __name__ == "__main__":
    main()
