"""Monta el tráiler de Blackout: 1920x1080, 30 fps, unos 67 s.

Uso:
  bash tools/trailer/record_shots.sh            # graba los planos del juego
  python tools/trailer/gen_future_monsters.py   # monstruos de escenarios futuros
  python tools/trailer/build_trailer.py         # imagen, sonido y MP4

Entradas: builds/trailer/raw/<plano>/f*.png (320x180), art/sprites, art/font, audio/*.wav
y builds/trailer/maps/*.txt (hospitales aleatorios de tools/check_hospital_gen.gd).
Salida: builds/trailer/blackout_trailer.mp4
"""
import math
import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "builds" / "trailer" / "raw"
OUT = ROOT / "builds" / "trailer"
FPS = 30
W, H = 1920, 1080
SCALE = 6
SR = 48000

# ---------------------------------------------------------------- texto con la fuente del juego


class BMFont:
    def __init__(self, fnt: Path):
        self.chars = {}
        self.line = 11
        page = None
        for line in fnt.read_text(encoding="utf-8").splitlines():
            parts = dict(p.split("=", 1) for p in line.split()[1:] if "=" in p)
            if line.startswith("common"):
                self.line = int(parts["lineHeight"])
            elif line.startswith("page"):
                page = Image.open(fnt.parent / parts["file"].strip('"')).convert("RGBA")
            elif line.startswith("char "):
                self.chars[int(parts["id"])] = {k: int(v) for k, v in parts.items() if k != "chnl"}
        self.page = page

    def width(self, text: str) -> int:
        return sum(self.chars.get(ord(ch), self.chars[32])["xadvance"] for ch in text)

    def render(self, text: str, scale: int, color=(201, 209, 211)) -> Image.Image:
        lines = text.upper().split("\n")
        w = max(self.width(l) for l in lines)
        img = Image.new("RGBA", (w, self.line * len(lines)), (0, 0, 0, 0))
        for row, line in enumerate(lines):
            x = (w - self.width(line)) // 2
            for ch in line:
                g = self.chars.get(ord(ch), self.chars[32])
                if g["width"] > 0:
                    glyph = self.page.crop((g["x"], g["y"], g["x"] + g["width"], g["y"] + g["height"]))
                    tint = Image.new("RGBA", glyph.size, color + (255,))
                    tint.putalpha(glyph.getchannel("A"))
                    img.alpha_composite(tint, (x + g["xoffset"], row * self.line + g["yoffset"]))
                x += g["xadvance"]
        return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


FONT = BMFont(ROOT / "art" / "font" / "blackout.fnt")
WHITE = (201, 209, 211)
RED = (143, 58, 58)
YELLOW = (232, 197, 71)

# ---------------------------------------------------------------- fuentes de imagen

_frame_cache: dict[str, list[Path]] = {}
GAMMA = [int(255 * (i / 255) ** 0.78) for i in range(256)] * 3


def shot_frame(shot: str, t: float) -> Image.Image:
    files = _frame_cache.setdefault(shot, sorted((RAW / shot).glob("*.png")))
    img = Image.open(files[min(int(t * FPS), len(files) - 1)]).convert("RGB")
    return img.resize((320 * SCALE, 180 * SCALE), Image.NEAREST).point(GAMMA)


TILE_ATLAS = Image.open(ROOT / "art" / "sprites" / "tiles.png").convert("RGBA")
TILE_FOR = {"#": 1, "X": 6, "E": 4, "S": 5, ",": 3, "c": 7, "w": 8, "i": 9, "t": 10}


def render_map(rows: list[str]) -> Image.Image:
    """Plano completo de un hospital aleatorio con las casillas del juego, a oscuras."""
    h, w = len(rows), len(rows[0])
    img = Image.new("RGBA", (w * 16, h * 16))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                below = rows[y + 1][x] if y + 1 < h else "#"
                idx = 11 if below in "#X" else 1
            elif ch in TILE_FOR:
                idx = TILE_FOR[ch]
            else:
                concrete = ch == "," or any(
                    0 <= y + dy < h and 0 <= x + dx < w and rows[y + dy][x + dx] == ","
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                idx = 3 if concrete else 0
            img.paste(TILE_ATLAS.crop((idx * 16, 0, idx * 16 + 16, 16)), (x * 16, y * 16))
    dark = Image.new("RGBA", img.size, (5, 5, 10, 205))
    img.alpha_composite(dark)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in "456":
                for r, a in ((40, 40), (26, 60), (12, 90)):
                    gd.ellipse([x * 16 + 8 - r, y * 16 + 8 - r, x * 16 + 8 + r, y * 16 + 8 + r], fill=(220, 60, 50, a))
            elif ch == "P":
                gd.ellipse([x * 16 - 20, y * 16 - 20, x * 16 + 36, y * 16 + 36], fill=(200, 210, 230, 70))
    img.alpha_composite(glow)
    return img.convert("RGB")


MAPS = [render_map([l for l in p.read_text(encoding="utf-8").splitlines() if l.strip()])
        for p in sorted((OUT / "maps").glob("*.txt"))]


def map_frame(i: int, t: float, dur: float) -> Image.Image:
    m = MAPS[i % len(MAPS)]
    scale = max(W / m.width, H / m.height) * 1.25
    big = m.resize((int(m.width * scale), int(m.height * scale)), Image.NEAREST)
    k = t / dur
    x = int((big.width - W) * (0.15 + 0.7 * k)) if i % 2 == 0 else int((big.width - W) * (0.85 - 0.7 * k))
    y = int((big.height - H) * 0.5)
    return big.crop((x, y, x + W, y + H))


def sprite_portrait(path: str, frame: int, tint=None) -> Image.Image:
    sheet = Image.open(ROOT / path).convert("RGBA")
    spr = sheet.crop((frame * 40, 0, frame * 40 + 40, 40)).resize((800, 800), Image.NEAREST)
    if tint:
        r, g, b, a = spr.split()
        spr = Image.merge("RGBA", (r.point(lambda v: int(v * tint[0])), g.point(lambda v: int(v * tint[1])),
                                   b.point(lambda v: int(v * tint[2])), a))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    img.alpha_composite(spr, ((W - 800) // 2, (H - 800) // 2 + 40))
    return img.convert("RGB")


LOGO = Image.open(ROOT / "art" / "sprites" / "logo.png").convert("RGBA")
LOGO = LOGO.resize((LOGO.width * 9, LOGO.height * 9), Image.NEAREST)

# ---------------------------------------------------------------- guion
# (inicio, duración, tipo, datos). Tipos: card, shot, map, portrait, logo, black.

SHOTS = [
    (0.0, 3.5, "card", "Hace años cerraron\nel hospital Santa Lucía."),
    (3.5, 4.5, "shot", ("walk", 0.3)),
    (8.0, 3.0, "card", "Nadie volvió a encender las luces."),
    (11.0, 4.0, "shot", ("gens", 0.6)),
    (15.0, 2.5, "card", "Algo vive en la oscuridad."),
    (17.5, 5.5, "shot", ("approach", 0.0)),
    (23.0, 2.0, "card", "Tu linterna es lo único\nque lo detiene."),
    (25.0, 4.5, "shot", ("coop", 1.0)),
    (29.5, 2.0, "shot", ("revive", 1.5)),
    (31.5, 1.6, "shot", ("scream", 0.4)),
    (33.1, 2.9, "shot", ("dart", 1.0)),
    (36.0, 1.0, "map", 0),
    (37.0, 1.0, "map", 1),
    (38.0, 1.0, "map", 2),
    (39.0, 2.0, "card", "Y esto es solo el principio."),
    (41.0, 3.5, "shot", ("future_stalker", 0.8)),
    (44.5, 3.5, "shot", ("future_girl", 0.8)),
    (48.0, 3.5, "shot", ("future_corpse", 0.8)),
    (51.5, 0.5, "portrait", ("art/sprites/monster.png", None)),
    (52.0, 0.5, "portrait", ("builds/trailer/sprites/stalker.png", None)),
    (52.5, 0.5, "portrait", ("builds/trailer/sprites/girl.png", None)),
    (53.0, 0.5, "portrait", ("builds/trailer/sprites/corpse.png", None)),
    (53.5, 2.5, "shot", ("door", 0.2)),
    (56.0, 1.0, "black", None),
    (57.0, 6.0, "logo", None),
    (63.0, 4.0, "card", "Beta en desarrollo\n\ngithub.com/Skyfreefury/blackout-beta"),
]
TOTAL = 67.0

# Rótulos encima de los planos: (inicio, fin, texto, color, posición).
OVERLAYS = [
    (25.4, 29.3, "Cooperativo de 1 a 4 jugadores", WHITE, "bottom"),
    (29.6, 31.4, "Reanima a tus compañeros", WHITE, "bottom"),
    (33.3, 35.9, "Botín, mejoras y un dardo tranquilizante", WHITE, "bottom"),
    (36.1, 38.9, "Cada partida, un hospital distinto", WHITE, "bottom"),
    (41.3, 44.3, "Psiquiátrico", RED, "top"),
    (44.8, 47.8, "Orfanato", RED, "top"),
    (48.3, 51.3, "Morgue", RED, "top"),
    (41.3, 51.3, "Próximamente", (138, 147, 160), "bottom"),
    (53.7, 55.9, "Sal con vida.", WHITE, "bottom"),
]

_text_cache: dict[tuple, Image.Image] = {}


def text_img(text: str, scale: int, color) -> Image.Image:
    key = (text, scale, color)
    if key not in _text_cache:
        _text_cache[key] = FONT.render(text, scale, color)
    return _text_cache[key]


def fade(t: float, start: float, end: float, edge: float = 0.35) -> float:
    return max(0.0, min(1.0, (t - start) / edge, (end - t) / edge))


VIGNETTE = Image.new("L", (W, H))
_vd = ImageDraw.Draw(VIGNETTE)
for i in range(60):
    k = i / 60
    _vd.ellipse([int(-W * 0.25 + k * W * 0.3), int(-H * 0.35 + k * H * 0.3),
                 int(W * 1.25 - k * W * 0.3), int(H * 1.35 - k * H * 0.3)], fill=int(255 * k ** 0.6))
BLACK = Image.new("RGB", (W, H), (0, 0, 0))


def frame_at(t: float, rng: np.random.Generator) -> Image.Image:
    seg = next(s for s in SHOTS if s[0] <= t < s[0] + s[1]) if t < TOTAL else SHOTS[-1]
    start, dur, kind, data = seg
    local = t - start
    if kind == "card":
        img = BLACK.copy()
        txt = text_img(data, 6 if "github" not in data else 5, WHITE)
        a = fade(t, start, start + dur, 0.5)
        layer = Image.new("RGBA", (W, H))
        layer.alpha_composite(txt, ((W - txt.width) // 2, (H - txt.height) // 2))
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * a)))
        img.paste(layer, (0, 0), layer)
    elif kind == "shot":
        img = shot_frame(data[0], data[1] + local)
        # Fundido corto a negro en los bordes de cada plano.
        a = fade(t, start, start + dur, 0.12)
        if a < 1.0:
            img = Image.blend(BLACK, img, a)
    elif kind == "map":
        img = map_frame(data, local, dur)
    elif kind == "portrait":
        path, tint = data
        img = sprite_portrait(path, int(local * 8) % 4, tint)
        if local < 0.08:
            img = Image.blend(img, Image.new("RGB", (W, H), (255, 255, 255)), 0.7)
    elif kind == "logo":
        img = BLACK.copy()
        # El logo parpadea como una luz que falla y luego se queda encendido.
        on = local > 1.2 or rng.random() < local / 1.4
        if on:
            a = min(1.0, local / 0.6) * (0.55 if local < 1.2 else 1.0)
            logo = LOGO.copy()
            logo.putalpha(logo.getchannel("A").point(lambda v: int(v * a)))
            img.paste(logo, ((W - LOGO.width) // 2, 330), logo)
        if local > 2.0:
            sub = text_img("Terror cooperativo para 1 a 4 jugadores", 5, (138, 147, 160))
            layer = Image.new("RGBA", (W, H))
            layer.alpha_composite(sub, ((W - sub.width) // 2, 760))
            a = fade(t, start + 2.0, start + dur, 0.5)
            layer.putalpha(layer.getchannel("A").point(lambda v: int(v * a)))
            img.paste(layer, (0, 0), layer)
        if local > dur - 0.4:
            img = Image.blend(img, BLACK, (local - (dur - 0.4)) / 0.4)
    else:
        img = BLACK.copy()
    # Rótulos encima.
    for o_start, o_end, text, color, pos in OVERLAYS:
        if o_start <= t < o_end:
            txt = text_img(text, 5 if pos == "bottom" else 9, color)
            a = fade(t, o_start, o_end, 0.3)
            y = H - txt.height - 70 if pos == "bottom" else 90
            layer = Image.new("RGBA", (W, H))
            shadow = Image.new("RGBA", txt.size, (0, 0, 0, 255))
            shadow.putalpha(txt.getchannel("A"))
            layer.alpha_composite(shadow, ((W - txt.width) // 2 + 6, y + 6))
            layer.alpha_composite(txt, ((W - txt.width) // 2, y))
            layer.putalpha(layer.getchannel("A").point(lambda v: int(v * a)))
            img.paste(layer, (0, 0), layer)
    # Viñeta y grano.
    img = Image.composite(img, BLACK, VIGNETTE)
    return img


# ---------------------------------------------------------------- sonido


def load_wav(name: str) -> np.ndarray:
    with wave.open(str(ROOT / "audio" / f"{name}.wav")) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
        rate = w.getframerate()
        if w.getnchannels() == 2:
            data = data.reshape(-1, 2).mean(axis=1)
    idx = np.arange(0, len(data), rate / SR)
    return np.interp(idx, np.arange(len(data)), data)


def place(track: np.ndarray, sound: np.ndarray, at: float, gain: float = 1.0) -> None:
    i = int(at * SR)
    n = min(len(sound), len(track) - i)
    if n > 0:
        track[i:i + n] += sound[:n] * gain


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = math.exp(-2 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def boom(seconds: float = 2.5) -> np.ndarray:
    t = np.arange(int(seconds * SR)) / SR
    freq = 30 + 60 * np.exp(-t * 6)
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 1.6)
    rng = np.random.default_rng(3)
    hit = lowpass(rng.standard_normal(len(t)) * np.exp(-t * 18), 1200) * 2.5
    return np.tanh((body + hit) * 1.6) * 0.9


def riser(seconds: float) -> np.ndarray:
    t = np.arange(int(seconds * SR)) / SR
    k = t / seconds
    rng = np.random.default_rng(5)
    noise = rng.standard_normal(len(t))
    # Ruido que se abre poco a poco: filtro que sube de 200 a 6000 Hz por tramos.
    out = np.zeros(len(t))
    steps = 12
    for s in range(steps):
        a, b = int(len(t) * s / steps), int(len(t) * (s + 1) / steps)
        out[a:b] = lowpass(noise[a:b], 200 + 5800 * (s / steps) ** 2)
    tone = np.sin(2 * np.pi * np.cumsum(110 + 660 * k ** 2) / SR) * 0.3
    return (out * 2.0 + tone) * k ** 2


def music_box(seconds: float) -> np.ndarray:
    """Caja de música desafinada en la menor, para los escenarios futuros."""
    notes = [69, 72, 76, 74, 72, 71, 72, 69, 64, 69, 72, 71, 68, 69]
    beat = 0.42
    out = np.zeros(int(seconds * SR))
    for i in range(int(seconds / beat)):
        n = notes[i % len(notes)]
        f = 440 * 2 ** ((n - 69) / 12) * (1 + 0.006 * math.sin(i))
        t = np.arange(int(1.6 * SR)) / SR
        note = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.01 * t)) * np.exp(-t * 3.2)
        place(out, note * 0.35, i * beat)
    # Eco simple.
    echo = np.zeros_like(out)
    d = int(0.31 * SR)
    echo[d:] = out[:-d] * 0.45
    return out + echo


def build_audio() -> np.ndarray:
    n = int(TOTAL * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(1)
    mix = np.zeros(n)
    # Zumbido grave de fondo durante todo el tráiler, más fuerte en la acción.
    drone = np.sin(2 * np.pi * 41 * t) * 0.5 + np.sin(2 * np.pi * 61.7 * t + np.sin(t * 0.5)) * 0.25
    wind = lowpass(rng.standard_normal(n), 180) * 2.2
    level = np.interp(t, [0, 3, 17, 25, 36, 39, 41, 51.5, 56, 57, 63, 67],
                      [0.0, 0.5, 0.6, 0.8, 0.9, 0.5, 0.6, 0.7, 0.0, 0.0, 0.5, 0.0])
    mix += (drone + wind) * level * 0.5
    # Latido: lento al principio, rápido en la acción.
    heart = load_wav("heartbeat_loop")
    for start, end, every, gain in ((1.0, 15.0, 1.25, 0.55), (17.5, 23.0, 0.9, 0.7), (25.0, 36.0, 0.62, 0.8), (53.5, 56.0, 0.5, 0.9)):
        x = start
        while x < end:
            place(mix, heart, x, gain)
            x += every
    # Golpes graves al entrar en cada rótulo y en el logo.
    for at in (0.2, 8.0, 15.0, 23.0, 39.0, 57.2):
        place(mix, boom(), at, 0.9)
    # Percusión de tensión en la parte de acción.
    tom = boom(0.5) * 0.5
    x = 25.0
    while x < 36.0:
        place(mix, tom, x, 0.5)
        x += 0.62 * 2
    # Efectos del juego en su momento.
    place(mix, load_wav("generator_on"), 12.0, 0.9)
    place(mix, load_wav("monster_loop"), 17.5, 0.6)
    place(mix, load_wav("monster_loop"), 19.0, 0.6)
    place(mix, load_wav("flashlight"), 19.9, 0.9)
    place(mix, load_wav("monster_freeze"), 19.95, 1.0)
    place(mix, load_wav("revive"), 30.6, 0.6)
    place(mix, load_wav("monster_scream"), 31.5, 1.0)
    place(mix, load_wav("dart"), 33.7, 1.0)
    place(mix, load_wav("monster_freeze"), 33.8, 0.6)
    place(mix, load_wav("door_open"), 53.5, 0.9)
    for at in (51.5, 52.0, 52.5, 53.0):
        place(mix, load_wav("monster_scream")[: int(0.4 * SR)], at, 0.7)
    # Caja de música en los escenarios futuros.
    place(mix, music_box(10.5) * env(int(10.5 * SR), 0.6, 1.0), 41.0, 0.8)
    # Subida antes del logo y silencio de 1 s.
    place(mix, riser(2.6), 53.4, 0.5)
    mix[int(56.0 * SR):int(57.15 * SR)] *= 0.0
    peak = np.max(np.abs(mix))
    return np.tanh(mix / peak * 1.3) * 0.89


def write_wav(path: Path, data: np.ndarray) -> None:
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    stereo = np.column_stack([pcm, pcm]).ravel()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(stereo.tobytes())


# ---------------------------------------------------------------- montaje


def main() -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    wav = OUT / "trailer_audio.wav"
    write_wav(wav, build_audio())
    print("audio ok")
    out = OUT / "blackout_trailer.mp4"
    proc = subprocess.Popen([
        ffmpeg, "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", str(wav),
        "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(out),
    ], stdin=subprocess.PIPE)
    rng = np.random.default_rng(7)
    frames = int(TOTAL * FPS)
    for i in range(frames):
        img = frame_at(i / FPS, rng)
        proc.stdin.write(img.tobytes())
        if i % 150 == 0:
            print(f"{i}/{frames}")
    proc.stdin.close()
    proc.wait()
    print("ok:", out)


if __name__ == "__main__":
    main()
