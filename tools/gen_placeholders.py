"""Genera los sprites provisionales de la fase 1 y una hoja de vista previa.

Uso: python tools/gen_placeholders.py
Salida: art/sprites/*.png y art/preview/sprites.png (ampliada x8).
"""
import random
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


def _speckle(img: Image.Image, seed: int, count: int, colors: list[str], box=(0, 0, 15, 15)) -> None:
    rng = random.Random(seed)
    x0, y0, x1, y1 = box
    for _ in range(count):
        px(img, [(rng.randint(x0, x1), rng.randint(y0, y1))], rng.choice(colors))


def hospital_floor(variant: int) -> Image.Image:
    """Azulejos de 8x8 con bisel: borde claro arriba a la izquierda, junta oscura abajo a la derecha.
    variant 0 limpio, 1 sucio, 2 roto, 3 sangre, 4 charco."""
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 15, "tile")
    for ox in (0, 8):
        for oy in (0, 8):
            px(img, [(ox + i, oy) for i in range(7)] + [(ox, oy + i) for i in range(7)], "white")
            px(img, [(ox + 7, oy + i) for i in range(8)] + [(ox + i, oy + 7) for i in range(8)], "sick")
            px(img, [(ox + 6, oy + i) for i in range(1, 7)] + [(ox + i, oy + 6) for i in range(1, 7)], "light")
    _speckle(img, 11 + variant, 4, ["light"], (1, 1, 14, 14))
    if variant == 1:
        _speckle(img, 21, 14, ["light", "gray", "sick"], (1, 1, 14, 14))
    elif variant == 2:
        # Azulejo partido con una esquina saltada.
        px(img, [(9, 1), (10, 2), (10, 3), (11, 4), (12, 4), (13, 5)], "moss")
        rect(img, 1, 9, 3, 10, "gray")
        px(img, [(1, 11), (4, 9)], "slate")
    elif variant == 3:
        px(img, [(4, 5), (5, 5), (6, 6), (5, 6), (7, 7), (8, 8), (9, 8), (8, 9), (10, 9), (11, 10)], "blood")
        px(img, [(5, 5), (8, 8), (9, 9)], "red")
        px(img, [(12, 11), (13, 12), (3, 4)], "blood")
    elif variant == 4:
        rect(img, 4, 8, 11, 12, "moss")
        rect(img, 6, 7, 10, 13, "moss")
        px(img, [(6, 9), (7, 9)], "sick")
    return img


def concrete(variant: int) -> Image.Image:
    """Hormigón del sótano. variant 0 liso, 1 manchado, 2 agrietado."""
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 15, "gray")
    _speckle(img, 31 + variant, 18, ["slate", "light"])
    px(img, [(i, 15) for i in range(16)] + [(15, i) for i in range(16)], "slate")
    if variant == 1:
        rect(img, 3, 4, 9, 9, "slate")
        rect(img, 5, 3, 8, 10, "slate")
        px(img, [(6, 6), (7, 7)], "night")
    elif variant == 2:
        px(img, [(2, 1), (3, 2), (3, 3), (4, 4), (6, 5), (7, 6), (7, 7), (8, 8), (10, 9), (11, 10), (12, 12)], "night")
    return img


def wall_front() -> Image.Image:
    """Pared vista de frente (tiene suelo debajo): remate oscuro, yeso sucio y zócalo verde."""
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 2, "night")
    px(img, [(i, 3) for i in range(16)], "gray")
    rect(img, 0, 4, 15, 8, "light")
    _speckle(img, 41, 8, ["gray", "white"], (0, 4, 15, 8))
    px(img, [(i, 9) for i in range(16)], "sick")
    rect(img, 0, 10, 15, 14, "moss")
    px(img, [(3, 10), (3, 11), (11, 10), (11, 11), (11, 12), (7, 13)], "slate")
    px(img, [(i, 15) for i in range(16)], "black")
    return img


def wall_top() -> Image.Image:
    """Parte de arriba de una pared gruesa o pared sin suelo debajo."""
    img = canvas(16, 16)
    rect(img, 0, 0, 15, 15, "night")
    _speckle(img, 51, 6, ["slate"])
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


PLAYER_COLORS = ["scrubs", "sick", "red", "bruise"]
# Desplazamiento vertical de cada pierna por fotograma de paso: (izquierda, derecha).
STEP = [(0, 0), (-1, 1), (0, 0), (1, -1)]


def player_frame(direction: str, frame: int, cloth: str) -> Image.Image:
    """direction: down, up o side (mirando a la derecha). frame: 0 a 3 del ciclo de paso."""
    img = canvas(16, 24)
    bob = 1 if frame in (1, 3) else 0
    left, right = STEP[frame]
    # Piernas.
    if direction == "side":
        rect(img, 6 + left, 18, 7 + left, 21, "slate")
        rect(img, 8 - left, 18, 9 - left, 21, "night")
        px(img, [(6 + left, 22), (7 + left, 22), (8 - left, 22), (9 - left, 22)], "black")
    else:
        rect(img, 5, 18, 7, 21 + left, "slate")
        rect(img, 8, 18, 10, 21 + right, "slate")
        px(img, [(5, 22 + left), (6, 22 + left), (9, 22 + right), (10, 22 + right)], "black")
    y = -bob
    # Cuerpo.
    rect(img, 4, 10 + y, 11, 17 + y, cloth)
    # Cabeza.
    if direction == "down":
        rect(img, 5, 2 + y, 10, 4 + y, "night")
        rect(img, 5, 5 + y, 10, 9 + y, "skin")
        px(img, [(6, 7 + y), (9, 7 + y)], "black")
        px(img, [(7, 9 + y), (8, 9 + y)], "flesh")
        px(img, [(7, 12 + y), (7, 13 + y), (7, 14 + y)], "night")  # cremallera
    elif direction == "up":
        rect(img, 5, 2 + y, 10, 8 + y, "night")
        rect(img, 5, 9 + y, 10, 9 + y, "skin")
    else:
        rect(img, 5, 2 + y, 10, 4 + y, "night")
        rect(img, 5, 5 + y, 10, 9 + y, "skin")
        px(img, [(5, 5 + y), (5, 6 + y), (6, 5 + y)], "night")
        px(img, [(9, 7 + y)], "black")
    # Brazos: el de la linterna adelante, el otro balanceándose.
    if direction == "side":
        rect(img, 12, 11 + y, 13, 13 + y, "skin")
        px(img, [(14, 12 + y)], "yellow")
        rect(img, 3, 11 + y + left, 3, 15 + y + left, cloth)
    else:
        rect(img, 3, 11 + y + right, 3, 15 + y + right, cloth)
        rect(img, 12, 11 + y + left, 12, 15 + y + left, cloth)
        px(img, [(12, 16 + y + left)], "skin")
        if direction == "down":
            px(img, [(13, 16 + y + left)], "yellow")
    return outline(img)


def player_sheet(cloth: str) -> Image.Image:
    """4 columnas (fotogramas de paso) x 3 filas (abajo, arriba, lado)."""
    sheet = canvas(64, 72)
    for row, direction in enumerate(("down", "up", "side")):
        for frame in range(4):
            sheet.paste(player_frame(direction, frame, cloth), (frame * 16, row * 24))
    return sheet


def monster_frame(frame: int) -> Image.Image:
    img = canvas(40, 40)
    d = ImageDraw.Draw(img)
    reach = [(0, 0), (-2, 1), (0, 0), (2, -1)][frame]
    lift = 1 if frame in (1, 3) else 0
    # Brazos largos que se alternan al arrastrarse.
    d.line((13, 27, 5 + reach[0], 36 - reach[0]), fill=P["flesh"], width=2)
    d.line((27, 27, 35 + reach[1] * 2, 36 + reach[1]), fill=P["flesh"], width=2)
    px(img, [(3 + reach[0], 37 - reach[0]), (5 + reach[0], 37 - reach[0]), (7 + reach[0], 37 - reach[0])], "black")
    px(img, [(33 + reach[1] * 2, 37 + min(reach[1], 1)), (35 + reach[1] * 2, 37 + min(reach[1], 1)),
             (37 + min(reach[1] * 2, 2), 37 + min(reach[1], 1))], "black")
    # Cuerpo encogido.
    d.ellipse((12, 23 - lift, 28, 35 - lift), fill=P["flesh"])
    d.ellipse((14, 25 - lift, 24, 33 - lift), fill=P["skin"])
    # Cordón umbilical que serpentea.
    wig = [0, 1, 0, -1][frame]
    d.line((20, 33, 24, 37 + wig), fill=P["red"], width=1)
    d.line((24, 37 + wig, 31, 38 - wig), fill=P["red"], width=1)
    d.line((31, 38 - wig, 36, 37 + wig), fill=P["blood"], width=1)
    # Cabeza hinchada y asimétrica: el lado derecho abulta más.
    o = -lift
    d.ellipse((6, 2 + o, 32, 26 + o), fill=P["skin"])
    d.ellipse((18, 1 + o, 36, 20 + o), fill=P["skin"])
    d.ellipse((10, 4 + o, 20, 11 + o), fill=P["white"])
    d.arc((6, 2 + o, 32, 26 + o), 20, 160, fill=P["flesh"], width=3)
    d.arc((18, 1 + o, 36, 20 + o), 300, 60, fill=P["flesh"], width=2)
    # Venas y moratones.
    px(img, [(x, y + o) for x, y in ((28, 4), (29, 5), (29, 6), (30, 7), (28, 7), (27, 8), (31, 8), (32, 9))], "red")
    px(img, [(x, y + o) for x, y in ((9, 9), (10, 10), (10, 11), (9, 12), (8, 13))], "bruise")
    px(img, [(x, y + o) for x, y in ((25, 18), (26, 19), (27, 19), (28, 18))], "bruise")
    # Ojos hundidos y desiguales, sin pupila.
    rect(img, 12, 13 + o, 15, 17 + o, "black")
    rect(img, 22, 12 + o, 27, 18 + o, "black")
    px(img, [(x, y + o) for x, y in ((12, 12), (15, 12), (21, 13), (21, 17), (28, 14))], "bruise")
    # Boca abierta que se abre y cierra.
    rect(img, 18, 20 + o, 20, 22 + o + (1 if frame % 2 == 0 else 0), "black")
    px(img, [(17, 21 + o), (21, 21 + o), (17, 22 + o), (21, 22 + o)], "bruise")
    px(img, [(19, 24 + o), (19, 25 + o)], "red")
    return outline(img)


def monster_sheet() -> Image.Image:
    sheet = canvas(160, 40)
    for frame in range(4):
        sheet.paste(monster_frame(frame), (frame * 40, 0))
    return sheet


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
    img = hospital_floor(0)
    rect(img, 3, 1, 12, 14, "gray")
    rect(img, 4, 2, 11, 13, "white")
    rect(img, 5, 2, 10, 4, "light")
    px(img, [(7, 9), (8, 9), (8, 10), (7, 11)], "blood")
    return img


def wheelchair_tile() -> Image.Image:
    img = hospital_floor(0)
    rect(img, 2, 4, 3, 12, "night")
    rect(img, 12, 4, 13, 12, "night")
    rect(img, 4, 5, 11, 11, "scrubs")
    rect(img, 4, 3, 11, 4, "slate")
    px(img, [(5, 13), (10, 13)], "light")
    return img


def incubator_tile() -> Image.Image:
    img = hospital_floor(0)
    rect(img, 1, 3, 14, 13, "gray")
    rect(img, 2, 4, 13, 12, "light")
    rect(img, 6, 6, 9, 9, "flesh")
    px(img, [(6, 6), (9, 6)], "skin")
    px(img, [(3, 5), (4, 5)], "white")
    return img


def table_tile() -> Image.Image:
    img = hospital_floor(0)
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
        hospital_floor(0), wall_front(), hospital_floor(3), concrete(0), asphalt_tile(),
        stairs_tile(), door_tile(), gurney_tile(), wheelchair_tile(), incubator_tile(), table_tile(),
        wall_top(), hospital_floor(1), hospital_floor(2), concrete(1), concrete(2), hospital_floor(4),
    ]
    tiles = canvas(16 * len(atlas), 16)
    for i, tile in enumerate(atlas):
        tiles.paste(tile, (16 * i, 0))
    sprites = {
        "tiles": tiles,
        "monster": monster_sheet(),
        "battery": battery(),
        "lamp": lamp(),
        "generator": generator(),
    }
    for i, cloth in enumerate(PLAYER_COLORS):
        sprites[f"player_{i}"] = player_sheet(cloth)
    for name, img in sprites.items():
        img.save(SPRITES / f"{name}.png")
    (SPRITES / "player.png").unlink(missing_ok=True)
    save_preview([(n, sprites[n]) for n in ("player_0", "player_1", "player_2", "player_3", "monster")])
    sheet_tiles = Image.new("RGBA", tiles.size, P["black"] + (255,))
    sheet_tiles.alpha_composite(tiles)
    sheet_tiles.resize((tiles.width * 6, tiles.height * 6), Image.NEAREST).save(PREVIEW / "tiles.png")
    print("ok:", ", ".join(f"{n} {i.size}" for n, i in sprites.items()))


if __name__ == "__main__":
    main()
