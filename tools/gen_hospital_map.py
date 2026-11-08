"""Genera maps/hospital.txt y comprueba que todo sea alcanzable.

Uso: python tools/gen_hospital_map.py

Leyenda (la misma que lee scripts/level.gd):
  #  pared              X  puerta de salida (pared hasta abrirse)
  .  suelo de hospital  ,  hormigón (sótano)   E  exterior   S  escaleras
  c  camilla  w  silla de ruedas  i  incubadora  t  mesa   (obstáculos)
  P  jugadores  M  monstruo  B  pila
  1-3  generador de la zona   4-6  lámpara de la zona 1-3 (se enciende al repararlo)
  a  archivador   o  ordenador   v  válvula   (tareas de mantener E)
  $  objeto de valor (sitio candidato)   D  carro de entrega del botín

Generadores, monstruo y pilas tienen varios sitios candidatos. scripts/level.gd elige
uno de cada generador y del monstruo, y 8 pilas, con la semilla de la partida.
Luego deja nivel + 1 tareas del catálogo: los 3 generadores y las 7 tareas a, o, v.
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
for x, y in ((29, 34), (12, 30), (52, 36)):
    put(x, y, "M")
for x, y in ((9, 6), (13, 25), (3, 12)):
    put(x, y, "1")
for x, y in ((56, 6), (52, 19), (43, 25)):
    put(x, y, "2")
for x, y in ((57, 37), (14, 38), (45, 27)):
    put(x, y, "3")
# Resto del catálogo de tareas, pegado a paredes y lejos de las puertas.
for x, y in ((6, 19), (34, 19)):
    put(x, y, "a")                       # archivadores de enfermería y escaleras
for x, y in ((32, 5), (30, 38)):
    put(x, y, "o")                       # ordenadores de urgencias y laboratorio
for x, y in ((58, 30), (18, 36), (41, 37)):
    put(x, y, "v")                       # válvulas del sótano
for x, y in ((5, 9), (12, 12), (14, 23)):
    put(x, y, "4")
for x, y in ((47, 9), (55, 12), (45, 23), (56, 24)):
    put(x, y, "5")
for x, y in ((48, 30), (54, 35), (10, 33)):
    put(x, y, "6")
for x, y in ((10, 16), (48, 16), (4, 21), (46, 24), (4, 36), (25, 20), (37, 7), (44, 30),
             (33, 11), (15, 7), (53, 7), (40, 16), (33, 30), (56, 21)):
    put(x, y, "B")

# Carro de entrega junto a la entrada y sitios candidatos para objetos de valor.
put(32, 8, "D")
LOOT_SPOTS = (
    (2, 8), (15, 10), (8, 12), (22, 11), (37, 12), (44, 6), (57, 9), (50, 12),
    (20, 15), (36, 17), (12, 20), (8, 24), (26, 24), (34, 22), (47, 21), (53, 23),
    (5, 28), (16, 31), (8, 37), (23, 30), (36, 33), (27, 36), (43, 33), (56, 28), (50, 38),
)
for x, y in LOOT_SPOTS:
    assert grid[y][x] in ".,", f"sitio de botín ocupado: {(x, y)} = {grid[y][x]}"
    put(x, y, "$")

WALKABLE = set(".,ESPMB456$D")
BLOCKING = set("#Xciwt123aov")


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


# Debe coincidir con scripts/lamp.gd (EMERGENCY_RADIUS * 0.9) y scripts/level.gd (ZONE_MARGIN).
LAMP_ZONE_PX = 40 * 0.9 + 6
TILE = 16


def grid_sight(a: tuple[int, int], b: tuple[int, int]) -> bool:
    steps = max(abs(b[0] - a[0]), abs(b[1] - a[1]))
    for i in range(1, steps):
        t = i / steps
        x, y = round(a[0] + (b[0] - a[0]) * t), round(a[1] + (b[1] - a[1]) * t)
        if grid[y][x] == "#":
            return False
    return True


def lamp_zone_cells() -> set[tuple[int, int]]:
    """Casillas que el monstruo evita con todas las luces de emergencia encendidas."""
    cells = set()
    r = int(LAMP_ZONE_PX // TILE) + 1
    for lx, ly in find("4") + find("5") + find("6"):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                c = (lx + dx, ly + dy)
                if 0 <= c[0] < W and 0 <= c[1] < H and (dx * dx + dy * dy) ** 0.5 * TILE <= LAMP_ZONE_PX \
                        and grid_sight((lx, ly), c):
                    cells.add(c)
    return cells


# Un punto libre por sala y por paso entre zonas. Con todas las luces encendidas el monstruo
# debe seguir llegando a todos: una luz nunca puede cerrar una puerta.
MONSTER_TARGETS = {
    "urgencias": (29, 10), "ala A": (9, 9), "puerta urgencias-ala A": (18, 9),
    "ala B": (50, 11), "puerta urgencias-ala B": (41, 9), "pasillo oeste": (5, 16),
    "pasillo este": (55, 16), "enfermería": (4, 24), "escaleras": (29, 22),
    "rayos X": (54, 21), "morgue": (14, 29), "laboratorio": (29, 31), "calderas": (50, 33),
}


def validate() -> None:
    spawn = find("P")[0]
    # Jugadores con la puerta abierta: todo lo transitable debe ser alcanzable.
    walk = bfs(spawn, lambda c: grid[c[1]][c[0]] in WALKABLE or grid[c[1]][c[0]] == "X")
    unreachable = [c for c in find(".") + find(",") if c not in walk]
    assert not unreachable, f"suelo inalcanzable: {unreachable[:5]}"
    # Todos los candidatos cuentan como colocados a la vez: es el caso con más bloqueos.
    for g in "123aov":
        for gx, gy in find(g):
            assert any((gx + dx, gy + dy) in walk for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))), \
                f"tarea {g} en {(gx, gy)} sin acceso"
    lost = [c for c in find("B") + find("M") + find("$") + find("D") if c not in walk]
    assert not lost, f"pila, monstruo, botín o carro inalcanzable: {lost}"
    # Monstruo: rejilla reducida para su cuerpo grande. Desde cada sitio donde puede aparecer
    # debe llegar a las 3 zonas y a la entrada.
    zones = lamp_zone_cells()
    for monster, lights_on in ((m, on) for m in find("M") for on in (False, True)):
        blocked = zones if lights_on else set()
        hunt = bfs(monster, lambda c: not near_blocking(c) and c not in blocked)
        for name, cell in MONSTER_TARGETS.items():
            assert cell not in blocked, f"{name} {cell} queda dentro de una luz de emergencia"
            assert cell in hunt, f"el monstruo no llega a {name} {cell} (luces {'encendidas' if lights_on else 'apagadas'})"


def main() -> None:
    validate()
    OUT.write_text("\n".join("".join(row) for row in grid) + "\n", encoding="utf-8", newline="\n")
    print(f"ok: {OUT.name} {W}x{H}, pilas={len(find('B'))}")
    print("\n".join("".join(row) for row in grid))


if __name__ == "__main__":
    main()
