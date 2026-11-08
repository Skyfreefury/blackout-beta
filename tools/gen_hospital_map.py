"""Genera maps/hospital.txt y comprueba que todo sea alcanzable.

Uso: python tools/gen_hospital_map.py

Leyenda (la misma que lee scripts/level.gd):
  #  pared              X  puerta de salida (pared hasta abrirse)
  .  suelo de hospital  ,  hormigón (sótano)   E  exterior   S  escaleras
  c  camilla  w  silla de ruedas  i  incubadora  t  mesa   (obstáculos)
  P  jugadores  M  monstruo  B  pila
  1-3  generador de la zona   4-6  lámpara de la zona 1-3 (se enciende al repararlo)
"""
from collections import deque
from pathlib import Path

W, H = 60, 40
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "maps" / "hospital.txt"

grid = [["#"] * W for _ in range(H)]


def fill(x0: int, y0: int, x1: int, y1: int, c: str) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            grid[y][x] = c


def put(x: int, y: int, c: str) -> None:
    grid[y][x] = c


# Exterior y puerta de salida.
fill(24, 1, 35, 3, "E")
fill(28, 4, 30, 4, "X")

# Bloque superior: Ala A (maternidad), urgencias, Ala B (quirófano).
fill(1, 5, 17, 13, ".")
fill(20, 5, 39, 13, ".")
fill(42, 5, 58, 13, ".")
fill(18, 8, 19, 10, ".")   # urgencias <-> Ala A
fill(40, 8, 41, 10, ".")   # urgencias <-> Ala B

# Pasillo principal y sus puertas.
fill(1, 15, 58, 17, ".")
for x0 in (8, 28, 49):
    fill(x0, 14, x0 + 2, 14, ".")
for x0 in (8, 28, 44, 54):
    fill(x0, 18, x0 + 2, 18, ".")

# Bloque medio: control de enfermería, escaleras, farmacia, rayos X.
fill(1, 19, 17, 25, ".")
fill(24, 19, 35, 25, ".")
fill(42, 19, 49, 25, ".")
fill(51, 19, 58, 25, ".")
fill(50, 21, 50, 23, ".")  # farmacia <-> rayos X
fill(28, 23, 30, 26, "S")  # escaleras al sótano

# Sótano: morgue, laboratorio secreto, sala de calderas.
fill(1, 27, 18, 38, ",")
fill(21, 27, 38, 38, ",")
fill(41, 27, 58, 38, ",")
fill(19, 31, 20, 33, ",")
fill(39, 31, 40, 33, ",")

# Obstáculos pegados a las paredes para no cortar pasos de 3 casillas.
for x in (2, 4, 6, 12, 14, 16):
    put(x, 5, "i")                       # incubadoras de maternidad
for x in (23, 24, 25, 26):
    put(x, 6, "t")                       # mostrador de recepción
for x in (21, 23, 25, 34, 36, 38):
    put(x, 13, "w")                      # sala de espera
put(50, 9, "t"); put(51, 9, "t")         # mesa de quirófano
for y in (20, 22, 24):
    put(1, y, "c"); put(17, y, "c")      # camillas de enfermería
for x in (42, 44, 46, 48):
    put(x, 19, "t")                      # estanterías de farmacia
put(58, 20, "t"); put(58, 22, "t")       # máquinas de rayos X
for y in (28, 30, 34, 36, 38):
    put(1, y, "c")                       # camillas de la morgue
for x in (22, 24, 36, 38):
    put(x, 38, "t")                      # mesas del laboratorio
for x in (25, 33):
    put(x, 27, "i")                      # incubadoras del laboratorio

# Puntos de aparición, generadores, lámparas y pilas.
put(29, 9, "P")
put(29, 34, "M")
put(9, 6, "1")
put(56, 6, "2")
put(57, 37, "3")
for x, y in ((5, 9), (14, 9), (9, 22)):
    put(x, y, "4")
for x, y in ((47, 9), (55, 12), (45, 23), (55, 23)):
    put(x, y, "5")
for x, y in ((48, 30), (54, 35), (10, 33)):
    put(x, y, "6")
for x, y in ((10, 16), (48, 16), (4, 21), (46, 24), (4, 36), (25, 20), (37, 7), (44, 30)):
    put(x, y, "B")

WALKABLE = set(".,ESPMB456")
BLOCKING = set("#Xciwt123")


def find(c: str) -> list[tuple[int, int]]:
    return [(x, y) for y in range(H) for x in range(W) if grid[y][x] == c]


def bfs(start: tuple[int, int], ok) -> set[tuple[int, int]]:
    seen = {start}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < W and 0 <= n[1] < H and n not in seen and ok(n):
                seen.add(n)
                queue.append(n)
    return seen


def near_blocking(cell: tuple[int, int]) -> bool:
    x, y = cell
    return any(grid[y + dy][x + dx] in BLOCKING or grid[y + dy][x + dx] == "E"
               for dy in (-1, 0, 1) for dx in (-1, 0, 1)
               if 0 <= x + dx < W and 0 <= y + dy < H)


def validate() -> None:
    spawn = find("P")[0]
    # Jugadores con la puerta abierta: todo lo transitable debe ser alcanzable.
    walk = bfs(spawn, lambda c: grid[c[1]][c[0]] in WALKABLE or grid[c[1]][c[0]] == "X")
    unreachable = [c for c in find(".") + find(",") if c not in walk]
    assert not unreachable, f"suelo inalcanzable: {unreachable[:5]}"
    for g in "123":
        gx, gy = find(g)[0]
        assert any((gx + dx, gy + dy) in walk for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))), \
            f"generador {g} sin acceso"
    # Monstruo: rejilla reducida para su cuerpo grande, debe llegar a las 3 zonas y a la entrada.
    monster = find("M")[0]
    hunt = bfs(monster, lambda c: not near_blocking(c))
    targets = {"entrada": (29, 10), "ala A": (9, 9), "ala B": (50, 11), "pasillo": (5, 16), "calderas": (50, 33)}
    for name, cell in targets.items():
        assert cell in hunt, f"el monstruo no llega a {name} {cell}"


def main() -> None:
    validate()
    OUT.write_text("\n".join("".join(row) for row in grid) + "\n", encoding="utf-8", newline="\n")
    print(f"ok: {OUT.name} {W}x{H}, pilas={len(find('B'))}")
    print("\n".join("".join(row) for row in grid))


if __name__ == "__main__":
    main()
