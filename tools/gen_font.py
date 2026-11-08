"""Genera la fuente pixel del juego: mayúsculas de 5x7, cifras, signos y acentos del español.

Uso: python tools/gen_font.py
Salida: art/font/blackout.png y art/font/blackout.fnt (formato BMFont de texto, que Godot importa).

Diseño propio, sin licencias de terceros. Las minúsculas usan los mismos dibujos que las
mayúsculas: la fuente es solo de mayúsculas, como en muchos juegos retro de terror.
Cada glifo ocupa 10 filas: 2 para acentos, 7 de letra y 1 para la parte que baja de , y ;.
"""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "art" / "font"
CELL_H = 10
CAP_TOP = 2
COLOR = (255, 255, 255, 255)

# 7 filas por letra (de la fila 2 a la 8 de la celda).
LETTERS = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    ".": [".", ".", ".", ".", ".", ".", "#"],
    ":": [".", ".", "#", ".", ".", "#", "."],
    "!": ["#", "#", "#", "#", "#", ".", "#"],
    "¡": ["#", ".", "#", "#", "#", "#", "#"],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    "¿": ["..#..", ".....", "..#..", ".#...", "#....", "#...#", ".###."],
    "-": ["...", "...", "...", "###", "...", "...", "..."],
    "+": ["...", "...", ".#.", "###", ".#.", "...", "..."],
    "=": ["...", "...", "###", "...", "###", "...", "..."],
    "*": ["...", "#.#", ".#.", "#.#", "...", "...", "..."],
    "/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
    "(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
    "'": ["#", "#", ".", ".", ".", ".", "."],
    '"': ["#.#", "#.#", "...", "...", "...", "...", "..."],
    "%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
    "_": ["....", "....", "....", "....", "....", "....", "####"],
    "€": ["..###", ".#...", "####.", ".#...", "####.", ".#...", "..###"],
}
# Signos con parte bajo la línea: 8 filas (la última es la fila 9 de la celda).
DESCENDERS = {
    ",": [".", ".", ".", ".", ".", ".", "#", "#"],
    ";": [".", ".", "#", ".", ".", ".", "#", "#"],
}
# Acentos: 2 filas encima de la letra base.
ACCENTS = {
    "Á": ("A", ["...#.", "..#.."]), "É": ("E", ["...#.", "..#.."]), "Í": ("I", [".#", "#."]),
    "Ó": ("O", ["...#.", "..#.."]), "Ú": ("U", ["...#.", "..#.."]), "Ü": ("U", [".....", ".#.#."]),
    "Ñ": ("N", [".##.#", "#..#."]),
}
SPACE_ADVANCE = 3


def glyph_rows(ch: str) -> list[str]:
    """Las 10 filas de la celda para un carácter en mayúsculas."""
    if ch in DESCENDERS:
        rows = DESCENDERS[ch]
        width = len(rows[0])
        return ["." * width] * CAP_TOP + rows
    if ch in ACCENTS:
        base, accent = ACCENTS[ch]
        rows = LETTERS[base]
        width = len(rows[0])
        return [a.ljust(width, ".")[:width] for a in accent] + rows + ["." * width]
    rows = LETTERS[ch]
    width = len(rows[0])
    return ["." * width] * CAP_TOP + rows + ["." * width]


def main() -> None:
    upper = list(LETTERS) + list(DESCENDERS) + list(ACCENTS)
    # Minúsculas con el mismo dibujo que su mayúscula.
    chars = {c: c for c in upper}
    for c in upper:
        low = c.lower()
        if low != c and low not in chars:
            chars[low] = c
    per_row, cell_w = 16, 7
    items = sorted(chars.items(), key=lambda kv: ord(kv[0]))
    rows_needed = (len(items) + per_row - 1) // per_row
    atlas = Image.new("RGBA", (per_row * cell_w, rows_needed * CELL_H), (0, 0, 0, 0))
    lines = []
    for i, (ch, src) in enumerate(items):
        rows = glyph_rows(src)
        width = len(rows[0])
        x0, y0 = (i % per_row) * cell_w, (i // per_row) * CELL_H
        for y, row in enumerate(rows):
            for x, v in enumerate(row):
                if v == "#":
                    atlas.putpixel((x0 + x, y0 + y), COLOR)
        lines.append(f"char id={ord(ch)} x={x0} y={y0} width={width} height={CELL_H} "
                     f"xoffset=0 yoffset=0 xadvance={width + 1} page=0 chnl=15")
    lines.append(f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={SPACE_ADVANCE} page=0 chnl=15")
    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / "blackout.png")
    header = [
        'info face="Blackout" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 '
        'padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={CELL_H + 1} base={CELL_H - 1} scaleW={atlas.width} scaleH={atlas.height} "
        "pages=1 packed=0",
        'page id=0 file="blackout.png"',
        f"chars count={len(lines)}",
    ]
    (OUT / "blackout.fnt").write_text("\n".join(header + lines) + "\n", encoding="utf-8")
    preview = Image.new("RGBA", (atlas.width, atlas.height), (11, 11, 16, 255))
    preview.alpha_composite(atlas)
    preview.resize((atlas.width * 6, atlas.height * 6), Image.NEAREST).save(
        OUT.parent / "preview" / "fuente.png")
    print(f"ok: {len(lines)} caracteres, atlas {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    main()
