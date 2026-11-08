"""Convierte cualquier imagen (dibujo propio o generada por IA) en un sprite del juego.

Recorta el fondo, reduce al tamaño de destino, ajusta cada píxel a la paleta de 16 colores
de tools/gen_placeholders.py y añade contorno negro de 1 px.

Uso:
  python tools/pixelize.py entrada.png art/sprites/salida.png --size 40x40
  python tools/pixelize.py entrada.png salida.png --size 16x24 --bg ff00ff --no-outline

Fondo: se elimina el color de --bg (magenta por defecto) y lo que ya sea transparente.
"""
import argparse
from pathlib import Path

from PIL import Image

from gen_placeholders import P, outline

PALETTE = list(P.values())


def nearest(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    return min(PALETTE, key=lambda c: sum((a - b) ** 2 for a, b in zip(rgb, c)))


def remove_background(img: Image.Image, bg: tuple[int, int, int], tolerance: int) -> Image.Image:
    out = img.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a < 128 or max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2])) <= tolerance:
                pixels[x, y] = (0, 0, 0, 0)
    return out


def pixelize(src: Path, size: tuple[int, int], bg: tuple[int, int, int], tolerance: int,
             add_outline: bool) -> Image.Image:
    img = remove_background(Image.open(src), bg, tolerance)
    bbox = img.getbbox()
    if bbox is None:
        raise SystemExit("La imagen queda vacía tras quitar el fondo.")
    img = img.crop(bbox)
    # Encaja manteniendo proporción y deja 1 px libre para el contorno.
    room = (size[0] - 2, size[1] - 2) if add_outline else size
    scale = min(room[0] / img.width, room[1] / img.height)
    small = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.BOX)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(small, ((size[0] - small.width) // 2, size[1] - small.height - (1 if add_outline else 0)))
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = nearest((r, g, b)) + (255,) if a >= 128 else (0, 0, 0, 0)
    return outline(out) if add_outline else out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("src", type=Path)
    parser.add_argument("dst", type=Path)
    parser.add_argument("--size", required=True, help="ancho x alto en píxeles, p. ej. 40x40")
    parser.add_argument("--bg", default="ff00ff", help="color de fondo a eliminar en hex")
    parser.add_argument("--tolerance", type=int, default=60)
    parser.add_argument("--no-outline", action="store_true")
    args = parser.parse_args()
    w, h = (int(v) for v in args.size.lower().split("x"))
    bg = tuple(int(args.bg[i:i + 2], 16) for i in (0, 2, 4))
    img = pixelize(args.src, (w, h), bg, args.tolerance, not args.no_outline)
    args.dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(args.dst)
    preview = img.resize((w * 8, h * 8), Image.NEAREST)
    preview.save(args.dst.with_name(args.dst.stem + "_x8.png"))
    print(f"ok: {args.dst} {w}x{h}")


if __name__ == "__main__":
    main()
