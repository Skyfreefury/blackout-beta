"""Sprites de las tareas que no son generadores: archivador, ordenador y válvula.

Uso: python tools/gen_task_sprites.py
Mismo tamaño que el generador (16x24) y la paleta de gen_placeholders.py.
"""
from pathlib import Path

from gen_placeholders import canvas, outline, px, rect

OUT = Path(__file__).resolve().parent.parent / "art" / "sprites"


def archive():
    """Archivador metálico con un cajón abierto y papeles."""
    img = canvas(16, 24)
    rect(img, 2, 5, 13, 22, "gray")
    for y0 in (6, 12, 18):
        rect(img, 3, y0, 12, y0 + 4, "slate")
        rect(img, 6, y0 + 2, 9, y0 + 2, "light")   # tirador
    rect(img, 2, 12, 13, 16, "night")              # cajón abierto
    rect(img, 4, 10, 11, 13, "white")              # historiales
    px(img, [(5, 11), (7, 11), (9, 11), (6, 12), (8, 12)], "light")
    px(img, [(10, 10)], "red")
    return outline(img)


def computer():
    """Ordenador viejo de control con pantalla verde sobre una mesa."""
    img = canvas(16, 24)
    rect(img, 0, 16, 15, 18, "slate")              # mesa
    rect(img, 1, 19, 2, 22, "night")
    rect(img, 13, 19, 14, 22, "night")
    rect(img, 2, 5, 13, 14, "light")               # monitor
    rect(img, 4, 7, 11, 12, "night")               # pantalla, se ilumina en el juego
    px(img, [(5, 8), (6, 8), (7, 8), (5, 10), (6, 10)], "sick")
    rect(img, 6, 15, 9, 15, "gray")                # pie
    rect(img, 3, 16, 12, 16, "white")              # teclado
    return outline(img)


def valve():
    """Tubería de vapor con una rueda de válvula roja."""
    img = canvas(16, 24)
    rect(img, 6, 4, 9, 22, "gray")                 # tubería vertical
    rect(img, 0, 17, 15, 20, "gray")               # tubería horizontal
    px(img, [(7, 4), (7, 10), (3, 18), (12, 18)], "light")
    rect(img, 3, 6, 12, 7, "red")                  # rueda
    rect(img, 3, 13, 12, 14, "red")
    rect(img, 3, 6, 4, 14, "red")
    rect(img, 11, 6, 12, 14, "red")
    rect(img, 7, 6, 8, 14, "blood")                # radios
    rect(img, 3, 10, 12, 10, "blood")
    return outline(img)


def main() -> None:
    for name, make in (("task_archive", archive), ("task_computer", computer), ("task_valve", valve)):
        make().save(OUT / f"{name}.png")
        print(f"ok: {name}.png")


if __name__ == "__main__":
    main()
