"""Sprites de tareas (archivador, ordenador, válvula), objetos de valor y carro de entrega.

Uso: python tools/gen_task_sprites.py
Tareas a 16x24 como el generador, objetos a 10x10 y carro a 16x16. Paleta de gen_placeholders.py.
También los objetos de la tienda (shop_*.png, 10x10) que se ven sobre los mostradores.
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


def loot_samples():
    """Gradilla con tubos de muestras."""
    img = canvas(10, 10)
    rect(img, 1, 6, 8, 8, "gray")
    for x, c in ((2, "red"), (4, "sick"), (6, "yellow")):
        rect(img, x, 2, x + 1, 7, "white")
        rect(img, x, 5, x + 1, 7, c)
    return outline(img)


def loot_tools():
    """Bandeja de instrumental quirúrgico."""
    img = canvas(10, 10)
    rect(img, 0, 5, 9, 8, "light")
    px(img, [(1, 4), (2, 4), (3, 4), (4, 4), (5, 4)], "white")   # bisturí
    px(img, [(6, 3), (7, 4), (8, 3)], "white")                    # pinzas
    px(img, [(2, 6), (4, 6), (6, 6), (8, 6)], "gray")
    return outline(img)


def loot_watch():
    """Reloj de oro con cadena."""
    img = canvas(10, 10)
    rect(img, 2, 3, 7, 8, "yellow")
    rect(img, 3, 4, 6, 7, "white")
    px(img, [(4, 5), (5, 5), (4, 6)], "black")
    px(img, [(4, 1), (5, 2), (6, 1), (7, 0)], "yellow")
    return outline(img)


def loot_microscope():
    """Microscopio de laboratorio."""
    img = canvas(10, 10)
    rect(img, 1, 8, 8, 9, "slate")
    rect(img, 6, 2, 7, 8, "gray")
    rect(img, 2, 1, 4, 5, "light")
    px(img, [(3, 6), (4, 6), (5, 6)], "gray")
    px(img, [(3, 0)], "white")
    return outline(img)


def cart():
    """Carro de hospital donde se entrega el botín."""
    img = canvas(16, 16)
    rect(img, 1, 3, 14, 10, "slate")
    rect(img, 2, 4, 13, 9, "night")
    rect(img, 0, 2, 15, 3, "light")
    rect(img, 13, 0, 14, 2, "light")                # asa
    px(img, [(3, 12), (12, 12)], "black")
    rect(img, 2, 11, 4, 13, "gray")                 # ruedas
    rect(img, 11, 11, 13, 13, "gray")
    rect(img, 5, 5, 10, 7, "yellow")                # cinta amarilla
    return outline(img)


def shop_battery():
    """Pila de litio grande con rayo."""
    img = canvas(10, 10)
    rect(img, 2, 2, 7, 9, "slate")
    rect(img, 4, 0, 5, 1, "light")
    rect(img, 3, 3, 6, 8, "yellow")
    px(img, [(5, 4), (4, 5), (5, 5), (4, 6)], "black")
    return outline(img)


def shop_shoes():
    """Zapatillas de correr."""
    img = canvas(10, 10)
    rect(img, 1, 5, 6, 7, "white")
    rect(img, 1, 3, 3, 5, "white")
    rect(img, 1, 8, 8, 8, "gray")
    rect(img, 6, 6, 8, 7, "white")
    px(img, [(2, 4), (4, 6), (5, 6)], "scrubs")
    return outline(img)


def shop_bag():
    """Mochila grande con correas."""
    img = canvas(10, 10)
    rect(img, 1, 2, 8, 9, "moss")
    rect(img, 3, 0, 6, 1, "moss")
    rect(img, 2, 5, 7, 8, "sick")
    px(img, [(2, 3), (7, 3)], "black")
    rect(img, 4, 5, 5, 5, "yellow")
    return outline(img)


def shop_medkit():
    """Botiquín blanco con cruz roja."""
    img = canvas(10, 10)
    rect(img, 0, 2, 9, 9, "white")
    rect(img, 3, 0, 6, 1, "gray")
    rect(img, 4, 3, 5, 8, "red")
    rect(img, 2, 5, 7, 6, "red")
    return outline(img)


def shop_dart():
    """Pistola de dardos con un dardo naranja."""
    img = canvas(10, 10)
    rect(img, 0, 3, 7, 4, "gray")
    rect(img, 1, 5, 3, 8, "slate")
    px(img, [(8, 3), (9, 3)], "light")
    rect(img, 4, 7, 8, 7, "light")
    px(img, [(9, 7)], "yellow")
    px(img, [(4, 6), (4, 8)], "red")
    return outline(img)


def main() -> None:
    for name, make in (("task_archive", archive), ("task_computer", computer), ("task_valve", valve),
                       ("loot_samples", loot_samples), ("loot_tools", loot_tools),
                       ("loot_watch", loot_watch), ("loot_microscope", loot_microscope), ("cart", cart),
                       ("shop_battery", shop_battery), ("shop_shoes", shop_shoes), ("shop_bag", shop_bag),
                       ("shop_medkit", shop_medkit), ("shop_dart", shop_dart)):
        make().save(OUT / f"{name}.png")
        print(f"ok: {name}.png")


if __name__ == "__main__":
    main()
