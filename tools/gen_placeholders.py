"""Genera los sprites provisionales de la fase 1 y una hoja de vista previa.

Uso: python tools/gen_placeholders.py
Salida: art/sprites/*.png y art/preview/fase1.png (ampliada x8).
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"
PREVIEW = ROOT / "art" / "preview"

# Paleta propia de 16 colores: grises fríos, verdes de hospital, carne y sangre.
P = {
    "black": (11, 11, 16),
    "night": (29, 31, 42),
    "slate": (52, 56, 74),
    "gray": (86, 93, 110),
    "light": (138, 147, 160),
    "white": (201, 209, 211),
    "moss": (61, 74, 63),
    "sick": (107, 125, 106),
    "tile": (169, 181, 154),
    "blood": (90, 42, 42),
    "red": (143, 58, 58),
    "skin": (217, 199, 176),
    "flesh": (184, 154, 134),
    "bruise": (122, 92, 88),
    "yellow": (232, 197, 71),
    "scrubs": (47, 111, 143),
}
CLEAR = (0, 0, 0, 0)


def canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), CLEAR)


def px(img: Image.Image, points, color: str) -> None:
    for x, y in points:
        img.putpixel((x, y), P[color] + (255,))


def rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, color: str) -> None:
    ImageDraw.Draw(img).rectangle((x0, y0, x1, y1), fill=P[color])


def outline(img: Image.Image, color: str = "black") -> Image.Image:
    """Añade un contorno de 1 px alrededor de los píxeles opacos."""
    out = img.copy()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and img.getpixel((nx, ny))[3] != 0:
                    out.putpixel((x, y), P[color] + (255,))
                    break
    return out


def floor_tile(stained: bool) -> Image.Image:
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 15, "tile")
    # Azulejos de 8x8 con junta oscura.
    for i in range(16):
        px(img, [(i, 7), (7, i)], "sick")
    px(img, [(i, 15) for i in range(16)] + [(15, i) for i in range(16)], "sick")
    px(img, [(1, 1), (9, 1), (1, 9), (9, 9)], "white")
    if stained:
        px(img, [(10, 11), (11, 11), (11, 12), (12, 12), (10, 12), (12, 13)], "blood")
        px(img, [(3, 2), (4, 3), (4, 4), (5, 5)], "gray")
    return img


def wall_tile() -> Image.Image:
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 15, "slate")
    rect(img, 0, 0, 15, 2, "gray")
    px(img, [(i, 3) for i in range(16)], "night")
    for y in (7, 11, 15):
        px(img, [(i, y) for i in range(16)], "night")
    px(img, [(4, y) for y in range(4, 7)] + [(12, y) for y in range(8, 11)], "night")
    px(img, [(8, y) for y in range(12, 15)], "night")
    return img


def player() -> Image.Image:
    img = canvas(16, 24)
    rect(img, 5, 2, 10, 4, "night")       # pelo
    rect(img, 5, 5, 10, 9, "skin")        # cara
    px(img, [(5, 5), (5, 6)], "night")
    px(img, [(9, 7)], "black")            # ojo, mira a la derecha
    rect(img, 4, 10, 11, 17, "scrubs")    # pijama de hospital
    rect(img, 3, 11, 3, 15, "scrubs")     # brazo trasero
    rect(img, 12, 11, 13, 13, "skin")     # mano con linterna
    px(img, [(14, 12)], "yellow")
    rect(img, 5, 18, 7, 21, "slate")      # piernas
    rect(img, 8, 18, 10, 21, "slate")
    px(img, [(5, 22), (6, 22), (9, 22), (10, 22)], "black")
    px(img, [(6, 12), (6, 13), (6, 14)], "night")
    return outline(img)


def monster() -> Image.Image:
    img = canvas(40, 40)
    d = ImageDraw.Draw(img)
    # Brazos largos apoyados en el suelo.
    d.line((13, 27, 5, 36), fill=P["flesh"], width=2)
    d.line((27, 27, 35, 36), fill=P["flesh"], width=2)
    px(img, [(3, 37), (5, 37), (7, 37), (33, 37), (35, 37), (37, 37)], "black")
    # Cuerpo encogido.
    d.ellipse((12, 23, 28, 35), fill=P["flesh"])
    d.ellipse((14, 25, 24, 33), fill=P["skin"])
    # Cordón umbilical arrastrado.
    d.line((20, 33, 24, 37), fill=P["red"], width=1)
    d.line((24, 37, 31, 38), fill=P["red"], width=1)
    d.line((31, 38, 36, 37), fill=P["blood"], width=1)
    # Cabeza hinchada.
    # Cabeza hinchada y asimétrica: el lado derecho abulta más.
    d.ellipse((6, 2, 32, 26), fill=P["skin"])
    d.ellipse((18, 1, 36, 20), fill=P["skin"])
    d.ellipse((10, 4, 20, 11), fill=P["white"])
    d.arc((6, 2, 32, 26), 20, 160, fill=P["flesh"], width=3)
    d.arc((18, 1, 36, 20), 300, 60, fill=P["flesh"], width=2)
    # Venas y moratones.
    px(img, [(28, 4), (29, 5), (29, 6), (30, 7), (28, 7), (27, 8), (31, 8), (32, 9)], "red")
    px(img, [(9, 9), (10, 10), (10, 11), (9, 12), (8, 13)], "bruise")
    px(img, [(25, 18), (26, 19), (27, 19), (28, 18)], "bruise")
    # Ojos hundidos y desiguales, sin pupila.
    rect(img, 12, 13, 15, 17, "black")
    rect(img, 22, 12, 27, 18, "black")
    px(img, [(12, 12), (15, 12), (21, 13), (21, 17), (28, 14)], "bruise")
    # Boca abierta en vertical con babeo.
    rect(img, 18, 20, 20, 23, "black")
    px(img, [(17, 21), (21, 21), (17, 22), (21, 22)], "bruise")
    px(img, [(19, 24), (19, 25)], "red")
    return outline(img)


def battery() -> Image.Image:
    img = canvas(8, 8)
    rect(img, 2, 1, 5, 6, "yellow")
    rect(img, 3, 0, 4, 0, "light")
    px(img, [(2, 4), (3, 4), (4, 4), (5, 4)], "black")
    px(img, [(2, 1), (2, 2)], "white")
    return outline(img)


def lamp() -> Image.Image:
    img = canvas(8, 8)
    rect(img, 1, 2, 6, 5, "gray")
    rect(img, 2, 3, 5, 4, "white")
    return outline(img)


def save_preview(items: list[tuple[str, Image.Image]]) -> None:
    scale, pad = 8, 16
    width = sum(img.width * scale + pad for _, img in items) + pad
    height = max(img.height for _, img in items) * scale + pad * 2
    sheet = Image.new("RGBA", (width, height), P["black"] + (255,))
    x = pad
    for _, img in items:
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x, pad))
        x += big.width + pad
    sheet.save(PREVIEW / "fase1.png")


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)

    tiles = canvas(48, 16)
    tiles.paste(floor_tile(False), (0, 0))
    tiles.paste(wall_tile(), (16, 0))
    tiles.paste(floor_tile(True), (32, 0))
    sprites = {
        "tiles": tiles,
        "player": player(),
        "monster": monster(),
        "battery": battery(),
        "lamp": lamp(),
    }
    for name, img in sprites.items():
        img.save(SPRITES / f"{name}.png")
    save_preview([(n, sprites[n]) for n in ("tiles", "player", "monster", "battery", "lamp")])
    print("ok:", ", ".join(f"{n} {i.size}" for n, i in sprites.items()))


if __name__ == "__main__":
    main()
