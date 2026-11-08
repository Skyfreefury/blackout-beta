"""Genera los sprites provisionales de la fase 1 y una hoja de vista previa.

Uso: python tools/gen_placeholders.py
Salida: art/sprites/*.png y art/preview/sprites.png (ampliada x8).
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


def concrete_tile() -> Image.Image:
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 15, "gray")
    px(img, [(2, 3), (9, 1), (13, 6), (5, 10), (11, 13), (1, 14), (7, 7)], "slate")
    px(img, [(4, 5), (12, 10), (8, 14)], "light")
    px(img, [(i, 15) for i in range(16)], "slate")
    return img


def asphalt_tile() -> Image.Image:
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 15, "night")
    px(img, [(3, 2), (10, 4), (6, 9), (13, 12), (1, 13), (8, 15)], "slate")
    px(img, [(7, y) for y in range(0, 16, 2)], "yellow")
    return img


def stairs_tile() -> Image.Image:
    img = canvas(16, 16)
    for y in range(0, 16, 4):
        rect(img, 0, y, 15, y + 1, "light")
        rect(img, 0, y + 2, 15, y + 3, "slate")
    px(img, [(0, y) for y in range(16)] + [(15, y) for y in range(16)], "night")
    return img


def door_tile() -> Image.Image:
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 15, "slate")
    for i in range(-16, 16, 4):
        for j in range(2):
            pts = [(x, x - i - j) for x in range(16) if 0 <= x - i - j < 16]
            px(img, pts, "red")
    rect(img, 0, 0, 15, 1, "gray")
    rect(img, 0, 14, 15, 15, "night")
    return img


def gurney_tile() -> Image.Image:
    img = floor_tile(False)
    rect(img, 3, 1, 12, 14, "gray")
    rect(img, 4, 2, 11, 13, "white")
    rect(img, 5, 2, 10, 4, "light")
    px(img, [(7, 9), (8, 9), (8, 10), (7, 11)], "blood")
    return img


def wheelchair_tile() -> Image.Image:
    img = floor_tile(False)
    rect(img, 2, 4, 3, 12, "night")
    rect(img, 12, 4, 13, 12, "night")
    rect(img, 4, 5, 11, 11, "scrubs")
    rect(img, 4, 3, 11, 4, "slate")
    px(img, [(5, 13), (10, 13)], "light")
    return img


def incubator_tile() -> Image.Image:
    img = floor_tile(False)
    rect(img, 1, 3, 14, 13, "gray")
    rect(img, 2, 4, 13, 12, "light")
    rect(img, 6, 6, 9, 9, "flesh")
    px(img, [(6, 6), (9, 6)], "skin")
    px(img, [(3, 5), (4, 5)], "white")
    return img


def table_tile() -> Image.Image:
    img = floor_tile(False)
    rect(img, 1, 2, 14, 12, "gray")
    rect(img, 2, 3, 13, 11, "light")
    px(img, [(1, 13), (14, 13)], "night")
    px(img, [(10, 5), (11, 5), (11, 6)], "blood")
    return img


def generator() -> Image.Image:
    img = canvas(16, 24)
    rect(img, 1, 6, 14, 22, "slate")
    rect(img, 1, 6, 14, 8, "gray")
    rect(img, 3, 11, 12, 18, "night")
    for x in range(3, 13, 2):
        px(img, [(x, 12), (x, 14), (x, 16)], "gray")
    rect(img, 1, 20, 14, 21, "yellow")
    px(img, [(2, 20), (5, 20), (8, 20), (11, 20), (14, 20)], "black")
    rect(img, 6, 3, 9, 5, "night")      # foco de estado, se ilumina en el juego
    px(img, [(12, 4), (13, 3), (14, 2)], "light")  # antena
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
    sheet.save(PREVIEW / "sprites.png")


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)

    # El orden fija las coordenadas del atlas que usa scripts/level.gd.
    atlas = [
        floor_tile(False), wall_tile(), floor_tile(True), concrete_tile(), asphalt_tile(),
        stairs_tile(), door_tile(), gurney_tile(), wheelchair_tile(), incubator_tile(), table_tile(),
    ]
    tiles = canvas(16 * len(atlas), 16)
    for i, tile in enumerate(atlas):
        tiles.paste(tile, (16 * i, 0))
    sprites = {
        "tiles": tiles,
        "player": player(),
        "monster": monster(),
        "battery": battery(),
        "lamp": lamp(),
        "generator": generator(),
    }
    for name, img in sprites.items():
        img.save(SPRITES / f"{name}.png")
    save_preview([(n, sprites[n]) for n in ("tiles", "player", "monster", "generator", "battery", "lamp")])
    print("ok:", ", ".join(f"{n} {i.size}" for n, i in sprites.items()))


if __name__ == "__main__":
    main()
