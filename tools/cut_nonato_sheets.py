"""Recorta las hojas de Gemini del Nonato y las pasa al estilo del juego.

Uso: python tools/cut_nonato_sheets.py
Entradas (fuera del repositorio, art/raw/gemini/):
  nonato_a.jpg  ciclo de arrastrarse, 6 fotogramas en fila sobre magenta
  nonato_b.jpg  animación de muerte, 12 fotogramas en 2 filas sobre magenta
Salidas:
  art/sprites/monster_crawl.png  6 fotogramas de 56x40 (sprite del Nonato en el juego)
  art/sprites/nonato_kill.png    12 fotogramas de KILL_W x KILL_H (animación de muerte del HUD)
Cada fotograma: fondo fuera, trozos sueltos de los vecinos fuera, reducción por media de
bloques, paleta de tools/gen_placeholders.py y contorno negro de 1 px.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from gen_placeholders import outline
from pixelize import nearest

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "art" / "raw" / "gemini"
OUT = ROOT / "art" / "sprites"

# Columnas de cada fotograma y filas de cada tira, medidas sobre el magenta.
CRAWL_ROW = (82, 742)
CRAWL_COLS = [(40, 971), (978, 1781), (1804, 2683), (2746, 3384), (3457, 4234), (4278, 5017)]
KILL_ROWS = [((38, 627), [(51, 645), (645, 1190), (1190, 1690), (1761, 2023), (2078, 2573), (2626, 3116)]),
             ((740, 1295), [(107, 469), (618, 1163), (1209, 1597), (1716, 1942), (2040, 2554), (2613, 3112)])]
CRAWL_SIZE = (56, 40)
## Fotogramas del ciclo que miran a la izquierda: se reflejan para que todos miren a la derecha.
CRAWL_FLIP = {0}
KILL_HEIGHT = 112


def cut(img: np.ndarray, rows: tuple[int, int], cols: tuple[int, int]) -> Image.Image:
    """Fotograma sin fondo magenta y sin trozos sueltos de los fotogramas vecinos."""
    part = img[rows[0]:rows[1] + 1, cols[0]:cols[1] + 1].astype(int)
    r, g, b = part[..., 0], part[..., 1], part[..., 2]
    dist = np.sqrt((r - 255) ** 2 + g ** 2 + (b - 255) ** 2)
    solid = dist > 150
    labels, count = ndimage.label(solid)
    if count:
        sizes = ndimage.sum(solid, labels, range(1, count + 1))
        keep = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * 0.03])
        solid &= keep
    rgba = np.dstack([part.astype(np.uint8), (solid * 255).astype(np.uint8)])
    frame = Image.fromarray(rgba, "RGBA")
    return frame.crop(frame.getbbox())


def to_pixels(frame: Image.Image, scale: float) -> Image.Image:
    w, h = max(1, round(frame.width * scale)), max(1, round(frame.height * scale))
    # Media de bloques solo sobre píxeles opacos: el borde no se tiñe de magenta.
    rgb = np.asarray(frame.convert("RGBA")).astype(float)
    alpha = rgb[..., 3:] / 255.0
    premult = Image.fromarray(np.uint8(np.dstack([rgb[..., :3] * alpha, alpha * 255])), "RGBA")
    small = np.asarray(premult.resize((w, h), Image.BOX)).astype(float)
    a = small[..., 3]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = out.load()
    for y in range(h):
        for x in range(w):
            if a[y, x] >= 110:
                k = 255.0 / a[y, x]
                px[x, y] = nearest(tuple(int(min(255, v * k)) for v in small[y, x, :3])) + (255,)
    return out


def sheet(frames: list[Image.Image], size: tuple[int, int]) -> Image.Image:
    """Fotogramas en fila, centrados en horizontal y apoyados abajo."""
    out = Image.new("RGBA", (size[0] * len(frames), size[1]), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        f = outline(f)
        out.alpha_composite(f, (i * size[0] + (size[0] - f.width) // 2, size[1] - f.height))
    return out


def preview(img: Image.Image, path: Path, k: int) -> None:
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (40, 40, 48, 255))
    bg.alpha_composite(big)
    bg.save(path)


def main() -> None:
    crawl_src = np.asarray(Image.open(RAW / "nonato_a.jpg").convert("RGB"))
    crawl = [cut(crawl_src, CRAWL_ROW, c) for c in CRAWL_COLS]
    crawl = [f.transpose(Image.FLIP_LEFT_RIGHT) if i in CRAWL_FLIP else f for i, f in enumerate(crawl)]
    scale = min((CRAWL_SIZE[0] - 2) / max(f.width for f in crawl), (CRAWL_SIZE[1] - 2) / max(f.height for f in crawl))
    crawl_sheet = sheet([to_pixels(f, scale) for f in crawl], CRAWL_SIZE)
    crawl_sheet.save(OUT / "monster_crawl.png")
    preview(crawl_sheet, RAW / "monster_crawl_x6.png", 6)

    kill_src = np.asarray(Image.open(RAW / "nonato_b.jpg").convert("RGB"))
    kill = [cut(kill_src, rows, c) for rows, cols in KILL_ROWS for c in cols]
    scale = (KILL_HEIGHT - 2) / max(f.height for f in kill)
    small = [to_pixels(f, scale) for f in kill]
    width = max(f.width for f in small) + 2
    kill_sheet = sheet(small, (width, KILL_HEIGHT))
    kill_sheet.save(OUT / "nonato_kill.png")
    preview(kill_sheet, RAW / "nonato_kill_x3.png", 3)
    print(f"ok: monster_crawl.png {CRAWL_SIZE} x6, nonato_kill.png {width}x{KILL_HEIGHT} x{len(small)}")


if __name__ == "__main__":
    main()
