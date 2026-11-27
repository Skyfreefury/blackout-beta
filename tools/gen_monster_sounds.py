"""Voz del Nonato: llanto de bebé deformado, gruñido y respiración al arrastrarse.

Uso: python tools/gen_monster_sounds.py
Sustituye a los sonidos del Nonato de tools/gen_sounds.py:
  audio/monster_scream.wav  chillido (agarre, chillido del mejorado, muerte), 1,6 s
  audio/monster_freeze.wav  quejido corto al recibir la linterna
  audio/monster_cry.wav     llanto al empezar a perseguir
  audio/monster_growl.wav   gruñido corto y húmedo, 0,8 s
  audio/monster_loop.wav    respiración gutural y arrastre en bucle, 3 s
Chillido: llanto de bebé con pulsos glotales tipo Rosenberg, formantes de tracto vocal pequeño,
saltos de tono, inspiraciones entrecortadas y una voz más grave debajo para deformarlo.
Gruñido y respiración: tren de pulsos filtrado por formantes, saturación y reverberación.
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


def glottal(f0: np.ndarray, open_q: float = 0.6) -> np.ndarray:
    """Pulso glotal tipo Rosenberg: subida suave y cierre brusco, como una garganta real."""
    phase = np.cumsum(f0 / RATE) % 1.0
    rise = open_q * 0.66
    pulse = np.where(phase < rise, 0.5 * (1 - np.cos(np.pi * phase / rise)),
                     np.where(phase < open_q, np.cos(0.5 * np.pi * (phase - rise) / (open_q - rise)), 0.0))
    return np.diff(pulse, prepend=0.0) * RATE / 2000.0


def cry_unit(seconds: float, peak: float, wobble: float) -> np.ndarray:
    """Un "uaaaa" de bebé: tono que sube rápido a peak Hz, se sostiene temblando y cae al final.
    Formantes de un tracto vocal pequeño (1100, 2600 y 4200 Hz), saltos de tono hacia arriba
    (hiperfonación) y voz quebrada al final."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    k = t / seconds
    contour = np.clip(k / 0.12, 0, 1) ** 0.5 * (1 - 0.35 * np.clip((k - 0.7) / 0.3, 0, 1))
    f0 = 300 + (peak - 300) * contour
    f0 *= 1 + 0.03 * np.sin(2 * np.pi * 6.5 * t) + wobble * signal.lfilter([1], [1, -0.99], RNG.standard_normal(n)) * 0.003
    # Hiperfonación: un tramo corto con el tono casi al doble.
    jump_at = RNG.uniform(0.35, 0.55)
    jump = np.exp(-((k - jump_at) / 0.06) ** 2)
    f0 *= 1 + 0.8 * jump
    src = glottal(f0) * (1 + 0.05 * RNG.standard_normal(n))      # brillo y ronquera
    src += 0.05 * RNG.standard_normal(n) * contour                  # aire
    # Vocal "a" que se cierra a "e" en el final.
    out = formants(src, [(1100, 220, 1.0), (2600, 300, 0.7), (4200, 450, 0.35)]) * (1 - k * 0.4)
    out += formants(src, [(700, 160, 0.6), (2900, 300, 0.5)]) * k * 0.4
    amp = np.clip(k / 0.05, 0, 1) * np.clip((1 - k) / 0.12, 0, 1)
    return out * amp


def gasp(seconds: float) -> np.ndarray:
    """Inspiración entrecortada entre llantos: ruido agudo con un silbido."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    noise = signal.lfilter(*signal.butter(2, [1500 / (RATE / 2), 5000 / (RATE / 2)], "band"), RNG.standard_normal(n))
    whistle = np.sin(2 * np.pi * np.cumsum(900 + 400 * t / seconds) / RATE) * 0.3
    return (noise * 0.35 + whistle * 0.6) * np.sin(np.pi * t / seconds) ** 2


def cry(parts: list[tuple[str, float, float]], monster: float) -> np.ndarray:
    """Llanto de bebé encadenado. monster de 0 a 1: baja el tono, añade una voz una octava
    más grave y aspereza, para que suene a algo que no es del todo un bebé."""
    pieces = [cry_unit(d, peak, 1.0) if kind == "cry" else gasp(d) for kind, d, peak in parts]
    x = np.concatenate(pieces)
    if monster > 0:
        # Bajada de tono por remuestreo y voz subarmónica (tono a la mitad) mezclada debajo.
        low = signal.resample(x, int(len(x) * (1 + 0.18 * monster)))[: len(x)]
        x = x * (1 - 0.4 * monster) + low * 0.6 * monster
        t = np.arange(len(x)) / RATE
        x *= 1 + 0.35 * monster * np.sin(2 * np.pi * 47 * t)        # aspereza
    x = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 1.8)
    return x


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
    scream = cry([("cry", 1.05, 560), ("gasp", 0.28, 0), ("cry", 1.25, 620), ("gasp", 0.22, 0)], monster=0.6)
    save("monster_scream", reverb(scream, 1.0, 0.3), 0.85)
    # Quejido corto al recibir la linterna: sustituye al chillido de tools/gen_sounds.py.
    yelp = cry([("cry", 0.75, 700)], monster=0.6)
    save("monster_freeze", reverb(yelp, 0.7, 0.3), 0.8)
    # Llanto al ver a un jugador y empezar a perseguirlo.
    sob = cry([("gasp", 0.2, 0), ("cry", 0.9, 520), ("gasp", 0.18, 0), ("cry", 0.6, 480)], monster=0.7)
    save("monster_cry", reverb(sob, 1.0, 0.35), 0.8)
    save("monster_growl", reverb(growl(0.8), 0.6, 0.25), 0.85)
    save("monster_loop", breathing(3.0), 0.7)


if __name__ == "__main__":
    main()
