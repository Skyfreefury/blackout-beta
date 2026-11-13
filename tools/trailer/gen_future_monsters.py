"""Monstruos de escenarios futuros para el tráiler (aún no están en el juego).

Uso: python tools/trailer/gen_future_monsters.py
Salida: builds/trailer/sprites/{stalker,girl,corpse}.png, hojas de 4 fotogramas de 40x40
como art/sprites/monster.png, con la paleta y el contorno de tools/gen_placeholders.py.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from gen_placeholders import P, outline  # noqa: E402

OUT = ROOT / "builds" / "trailer" / "sprites"
S = 40


def c(name: str, a: int = 255) -> tuple[int, int, int, int]:
    return P[name] + (a,)


def frame() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def stalker(f: int) -> Image.Image:
    """Acechador del psiquiátrico: altísimo, cuello largo, camisa de fuerza."""
    img, d = frame()
    tilt = (0, 1, 0, -1)[f]
    # Piernas finas.
    d.line([(17, 30), (16, 39)], fill=c("light"), width=2)
    d.line([(22, 30), (23, 39)], fill=c("light"), width=2)
    # Torso con camisa de fuerza y correas.
    d.rectangle([14, 16, 25, 30], fill=c("white"))
    d.rectangle([14, 16, 15, 30], fill=c("light"))
    for y in (19, 24, 28):
        d.line([(14, y), (25, y)], fill=c("bruise"))
    d.rectangle([19, 18, 20, 29], fill=c("gray"))
    # Brazos largos colgando hasta las rodillas.
    d.line([(13, 17), (11, 35)], fill=c("white"), width=2)
    d.line([(26, 17), (28 + tilt, 35)], fill=c("white"), width=2)
    d.point([(10, 36), (11, 37), (28 + tilt, 36), (29 + tilt, 37)], fill=c("skin"))
    # Cuello larguísimo y cabeza pequeña inclinada.
    hx = 19 + tilt
    d.line([(19, 16), (hx, 7)], fill=c("flesh"), width=2)
    d.ellipse([hx - 3, 0, hx + 4, 9], fill=c("white"))
    d.rectangle([hx - 2, 2, hx - 1, 4], fill=c("black"))
    d.rectangle([hx + 2, 2, hx + 3, 4], fill=c("black"))
    # Boca demasiado ancha, abierta hasta la barbilla.
    d.rectangle([hx - 2, 6, hx + 3, 8], fill=c("black"))
    d.line([(hx - 2, 6), (hx + 3, 6)], fill=c("blood"))
    return outline(img)


def girl(f: int) -> Image.Image:
    """Niña de la cuna del orfanato: a cuatro patas, pelo negro sobre la cara."""
    img, d = frame()
    sway = (0, 1, 2, 1)[f]
    # Vestido blanco sucio, cuerpo agachado.
    d.ellipse([10, 22, 30, 34], fill=c("white"))
    d.ellipse([12, 26, 28, 34], fill=c("light"))
    # Brazos y piernas como patas.
    for x0, x1 in ((11, 8), (16, 14), (25, 27), (29, 32)):
        d.line([(x0, 31), (x1, 38)], fill=c("skin"), width=2)
    # Cabeza baja: cara pálida entre mechones de pelo largo de distinta longitud.
    d.ellipse([12, 11, 24, 23], fill=c("skin"))
    d.ellipse([12, 9, 24, 16], fill=c("night"))
    lengths = (24, 30, 27, 22, 26, 31, 25)
    for i, x in enumerate(range(12, 25, 2)):
        if x in (18, 20):
            continue  # hueco por donde asoma la cara
        d.line([(x, 12), (x + sway - 1, lengths[i])], fill=c("night"), width=2)
    # Un solo ojo blanco y una boca torcida.
    d.rectangle([18, 16, 19, 17], fill=c("white"))
    d.point([(19, 17)], fill=c("black"))
    d.line([(18, 21), (20, 20)], fill=c("blood"))
    # Sonajero roto.
    d.ellipse([31, 33, 35, 37], fill=c("red"))
    d.line([(30, 34), (28, 31)], fill=c("light"))
    return outline(img)


def corpse(f: int) -> Image.Image:
    """Cadáver de la morgue: se incorpora bajo la sábana, puntos de autopsia en Y."""
    img, d = frame()
    jaw = (0, 1, 2, 1)[f]
    # Sábana sobre las piernas.
    d.polygon([(4, 30), (36, 30), (38, 39), (2, 39)], fill=c("white"))
    d.line([(6, 33), (34, 33)], fill=c("light"))
    d.line([(10, 36), (30, 36)], fill=c("light"))
    # Torso hinchado gris verdoso con la Y de la autopsia.
    d.ellipse([11, 13, 29, 32], fill=c("sick"))
    d.ellipse([13, 15, 27, 31], fill=c("tile"))
    d.line([(14, 17), (20, 22)], fill=c("blood"))
    d.line([(26, 17), (20, 22)], fill=c("blood"))
    d.line([(20, 22), (20, 30)], fill=c("blood"))
    for y in (24, 27):
        d.point([(19, y), (21, y)], fill=c("blood"))
    # Brazos apoyados para levantarse.
    d.line([(11, 20), (7, 30)], fill=c("sick"), width=3)
    d.line([(29, 20), (33, 30)], fill=c("sick"), width=3)
    # Cabeza calva con ojos lechosos y mandíbula colgando.
    d.ellipse([14, 1, 26, 15], fill=c("tile"))
    d.rectangle([16, 6, 18, 7], fill=c("white"))
    d.rectangle([22, 6, 24, 7], fill=c("white"))
    d.rectangle([18, 10, 22, 11 + jaw], fill=c("black"))
    # Etiqueta del dedo del pie asomando.
    d.rectangle([34, 34, 37, 36], fill=c("yellow"))
    return outline(img)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in (("stalker", stalker), ("girl", girl), ("corpse", corpse)):
        sheet = Image.new("RGBA", (S * 4, S), (0, 0, 0, 0))
        for f in range(4):
            sheet.paste(draw(f), (f * S, 0))
        sheet.save(OUT / f"{name}.png")
        preview = sheet.resize((S * 4 * 6, S * 6), Image.NEAREST)
        bg = Image.new("RGBA", preview.size, (40, 40, 48, 255))
        bg.alpha_composite(preview)
        bg.save(OUT / f"{name}_preview.png")
        print(name, "ok")


if __name__ == "__main__":
    main()
