"""Recorta la hoja de arte generada (art/raw/hoja_gemini.jpg) y la convierte en sprites del juego.

Uso (en este orden, porque este script sobrescribe parte de lo que genera el primero):
  python tools/gen_placeholders.py
  python tools/cut_sheet.py
Salida: art/sprites/gemini/*.png (cada recorte a su tamaño final, con la paleta del juego),
        art/preview/gemini.png (vista previa x6) y los sprites finales en art/sprites.

Las cajas están en píxeles de la hoja original (1696x2528). Las cajas magenta se midieron
detectando el fondo magenta; las baldosas se midieron alineándolas con esas columnas.
"""
from pathlib import Path

from PIL import Image, ImageFilter

from gen_placeholders import P, outline
from pixelize import nearest, remove_background

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "art" / "raw" / "hoja_gemini.jpg"
OUT = ROOT / "art" / "sprites" / "gemini"
PREVIEW = ROOT / "art" / "preview" / "gemini.png"
MAGENTA = (255, 0, 255)

# nombre: (caja x0, y0, x1, y1), tamaño final, tipo
# tipo "sprite": quita el fondo magenta y añade contorno. "tile": baldosa completa sin fondo.
ASSETS = {
    "player_front": ((346, 497, 546, 806), (16, 24), "sprite"),
    "player_back": ((591, 498, 791, 806), (16, 24), "sprite"),
    "player_side": ((834, 498, 1035, 806), (16, 24), "sprite"),
    "monster": ((1071, 497, 1448, 875), (40, 40), "sprite"),
    "generator": ((347, 885, 557, 1191), (16, 24), "sprite"),
    "battery": ((644, 996, 791, 1144), (8, 8), "sprite"),
    "lamp": ((1165, 996, 1313, 1144), (8, 8), "sprite"),
    "gurney": ((348, 1266, 572, 1453), (16, 16), "sprite"),
    "wheelchair": ((626, 1266, 814, 1453), (16, 16), "sprite"),
    "incubator": ((882, 1266, 1071, 1453), (16, 16), "sprite"),
    "table": ((1141, 1266, 1331, 1453), (16, 16), "sprite"),
    "floor": ((368, 1536, 557, 1725), (16, 16), "tile"),
    "floor_stained": ((625, 1536, 814, 1725), (16, 16), "tile"),
    "concrete": ((883, 1536, 1072, 1725), (16, 16), "tile"),
    "wall": ((368, 1808, 557, 1999), (16, 16), "tile"),
    "door": ((625, 1808, 814, 1999), (16, 16), "tile"),
    "stairs": ((883, 1808, 1072, 1999), (16, 16), "tile"),
    "asphalt": ((1141, 1808, 1330, 1999), (16, 16), "tile"),
    "logo": ((366, 2085, 1063, 2297), (160, 40), "sprite"),
    "icon": ((1124, 2089, 1328, 2292), (64, 64), "tile"),
}
## Margen recortado en las baldosas para no arrastrar bordes ni sombras del papel.
TILE_INSET = 6
## Píxeles de la hoja que se comen alrededor de cada sprite para quitar el halo magenta del JPEG.
HALO = 2


def to_palette(img: Image.Image) -> Image.Image:
    out = img.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = nearest((r, g, b)) + (255,) if a >= 128 else (0, 0, 0, 0)
    return out


def cut_sprite(sheet: Image.Image, box, size) -> Image.Image:
    img = remove_background(sheet.crop(box), MAGENTA, 90)
    alpha = img.getchannel("A").filter(ImageFilter.MinFilter(HALO * 2 + 1))
    img.putalpha(alpha)
    bbox = img.getbbox()
    img = img.crop(bbox)
    room = (size[0] - 2, size[1] - 2)
    scale = min(room[0] / img.width, room[1] / img.height)
    small = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.BOX)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(small, ((size[0] - small.width) // 2, size[1] - small.height - 1))
    return outline(to_palette(out))


def cut_tile(sheet: Image.Image, box, size) -> Image.Image:
    x0, y0, x1, y1 = box
    img = sheet.crop((x0 + TILE_INSET, y0 + TILE_INSET, x1 - TILE_INSET, y1 - TILE_INSET)).convert("RGBA")
    return to_palette(img.resize(size, Image.BOX))


SPRITES = ROOT / "art" / "sprites"
## Colores del pijama en la hoja (oscuro, claro) y sus sustitutos para los jugadores 1 a 3.
CLOTH = ("scrubs", "light")
CLOTH_VARIANTS = [("scrubs", "light"), ("moss", "sick"), ("blood", "red"), ("night", "slate")]
## Coordenadas del atlas de tiles.png (ver scripts/level.gd) que se sustituyen.
ATLAS = {"stairs": 5, "door": 6, "gurney": 7, "wheelchair": 8, "incubator": 9, "table": 10}
FLOOR_INDEX = 0


def recolor(img: Image.Image, mapping: dict[str, str]) -> Image.Image:
    swap = {P[a]: P[b] for a, b in mapping.items()}
    out = img.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) in swap:
                pixels[x, y] = swap[(r, g, b)] + (255,)
    return out


# Piernas de cada vista medidas sobre los sprites de 16x24: fila donde empiezan,
# fila del pie y columna izquierda de cada pierna (2 px de ancho).
LEGS = {
    "front": {"top": 18, "foot": 22, "x": (6, 10)},
    "back": {"top": 16, "foot": 22, "x": (5, 8)},
    "side": {"top": 15, "foot": 22, "x": (3, 4)},
}
PANTS_DARK, PANTS_LIGHT, SHOE = "scrubs", "light", "white"


def _leg(layer: Image.Image, x: int, top: int, foot: int, dx_at_foot: int, color: str) -> None:
    """Pierna de 2 px que se inclina dx_at_foot píxeles en el pie. El último píxel es el zapato."""
    for y in range(top, foot + 1):
        t = (y - top) / max(1, foot - top)
        lean = round(dx_at_foot * t)
        shade = SHOE if y == foot else color
        for i in range(2):
            layer.putpixel((x + i + lean, y), P[shade] + (255,))


def step_frame(view: str, base: Image.Image, frame: int) -> Image.Image:
    """Ciclo de paso de 4 fotogramas a partir de una pose: se borran las piernas y se redibujan.
    Fotogramas 0 y 2: piernas juntas. 1 y 3: zancada alterna y el cuerpo sube 1 px."""
    leg = LEGS[view]
    top, foot = leg["top"], leg["foot"]
    stride = frame % 2 == 1
    lift = 1 if stride else 0
    body = base.crop((0, 0, base.width, top))
    legs = Image.new("RGBA", base.size, (0, 0, 0, 0))
    left, right = leg["x"]
    if view == "side":
        # De lado: una pierna adelante y otra atrás; cambian de color para que se note cuál avanza.
        front_color, back_color = (PANTS_LIGHT, PANTS_DARK) if frame == 1 else (PANTS_DARK, PANTS_LIGHT)
        reach = 2 if stride else 0
        _leg(legs, left, top - lift, foot, -reach, back_color)
        _leg(legs, right, top - lift, foot, reach, front_color)
    else:
        # De frente o espalda: la pierna que avanza se acorta 2 px (rodilla doblada).
        left_foot = foot - (2 if frame == 1 else 0)
        right_foot = foot - (2 if frame == 3 else 0)
        _leg(legs, left, top - lift, left_foot, 0, PANTS_LIGHT)
        _leg(legs, right, top - lift, right_foot, 0, PANTS_DARK)
    out = outline(legs)
    out.alpha_composite(body, (0, -lift))
    return out


def crawl_frame(base: Image.Image, frame: int) -> Image.Image:
    """Arrastre: la cabeza y el cuerpo suben 1 px o se desplazan 1 px; las manos se quedan en el suelo."""
    if frame % 2 == 0:
        return base.copy()
    hands = base.height - 8
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out.alpha_composite(base.crop((0, hands, base.width, base.height)), (0, hands))
    shift = (0, -1) if frame == 1 else (1, 0)
    out.alpha_composite(base.crop((0, 0, base.width, hands)), shift)
    return out


def build_game_sprites(r: dict[str, Image.Image]) -> None:
    views = [r["player_front"], r["player_back"], r["player_side"]]
    for i, (dark, light) in enumerate(CLOTH_VARIANTS):
        sheet = Image.new("RGBA", (64, 72), (0, 0, 0, 0))
        for row, (view_name, view) in enumerate(zip(("front", "back", "side"), views)):
            for frame in range(4):
                # Se recolorea después de redibujar las piernas para que el pantalón cambie también.
                step = step_frame(view_name, view, frame)
                colored = recolor(step, {CLOTH[0]: dark, CLOTH[1]: light})
                sheet.alpha_composite(colored, (frame * 16, row * 24))
        sheet.save(SPRITES / f"player_{i}.png")
    monster = Image.new("RGBA", (160, 40), (0, 0, 0, 0))
    for frame in range(4):
        monster.alpha_composite(crawl_frame(r["monster"], frame), (frame * 40, 0))
    monster.save(SPRITES / "monster.png")
    for name in ("generator", "battery", "lamp", "logo", "icon"):
        r[name].save(SPRITES / f"{name}.png")
    # Atlas: se conservan suelos, paredes y asfalto dibujados por código (a 16 px conservan
    # mejor las juntas) y se sustituyen escaleras, puerta y obstáculos.
    atlas = Image.open(SPRITES / "tiles.png").convert("RGBA")
    floor = atlas.crop((FLOOR_INDEX * 16, 0, FLOOR_INDEX * 16 + 16, 16))
    for name, index in ATLAS.items():
        tile = r[name]
        if name in ("gurney", "wheelchair", "incubator", "table"):
            tile = floor.copy()
            tile.alpha_composite(r[name])
        atlas.paste(tile, (index * 16, 0))
    atlas.save(SPRITES / "tiles.png")


def main() -> None:
    sheet = Image.open(SHEET).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    results = {}
    for name, (box, size, kind) in ASSETS.items():
        img = cut_sprite(sheet, box, size) if kind == "sprite" else cut_tile(sheet, box, size)
        img.save(OUT / f"{name}.png")
        results[name] = img
        print(f"{name}: {size[0]}x{size[1]}")
    # Vista previa con todo ampliado x6 sobre fondo oscuro.
    scale, pad = 6, 12
    rows = [list(results)[i:i + 7] for i in range(0, len(results), 7)]
    width = max(sum(results[n].width * scale + pad for n in row) for row in rows) + pad
    height = sum(max(results[n].height for n in row) * scale + pad for row in rows) + pad
    preview = Image.new("RGBA", (width, height), P["night"] + (255,))
    y = pad
    for row in rows:
        x = pad
        for n in row:
            big = results[n].resize((results[n].width * scale, results[n].height * scale), Image.NEAREST)
            preview.alpha_composite(big, (x, y))
            x += big.width + pad
        y += max(results[n].height for n in row) * scale + pad
    preview.save(PREVIEW)
    build_game_sprites(results)
    print("sprites del juego actualizados en art/sprites")


if __name__ == "__main__":
    main()
