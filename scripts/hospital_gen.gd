class_name HospitalGen
extends RefCounted
## Genera un hospital nuevo con una semilla. Misma semilla y nivel, mismo hospital en todos los equipos.
## Devuelve filas de texto con la leyenda de tools/gen_hospital_map.py, que lee scripts/level.gd.
##
## Plano en tres franjas: arriba urgencias y las alas (zonas 1 oeste y 2 este), un pasillo,
## salas del medio (zonas 1 y 2) y el sótano (zona 3), unido por una escalera.
## Anchos de sala, puertas, escalera, muebles y sitios candidatos cambian con la semilla.
## Cada plano se valida como en gen_hospital_map.py. Si falla, se genera otro.

## [ancho, alto de la franja de arriba, alto de la del medio, alto del sótano] por tamaño.
const SIZES := [[48, 8, 6, 9], [60, 9, 7, 11], [74, 10, 8, 13]]
const MAX_ATTEMPTS := 40
const TILE := 16
## Lo mismo que Lamp.EMERGENCY_RADIUS * 0.9 + Level.ZONE_MARGIN.
const LAMP_RANGE := 42.0
## Casillas libres que dejan los muebles y las tareas alrededor de cada puerta.
const DOOR_CLEARANCE := 3
const PLAYER_BLOCKING := "#ciwt123aov"
const MONSTER_BLOCKING := "#XEciwt123aov"
const MONSTER_SPOTS := 5
## Muebles por tipo de sala: [símbolo, cantidad, lado de la pared].
const DECOR := {
	"maternidad": [["i", 4, "top"]],
	"quirofano": [["t", 2, "top"], ["c", 1, "left"]],
	"espera": [["w", 5, "bottom"]],
	"consultas": [["t", 2, "top"], ["c", 2, "right"]],
	"enfermeria": [["c", 3, "left"], ["c", 3, "right"]],
	"farmacia": [["t", 4, "top"]],
	"rayos": [["t", 2, "right"]],
	"morgue": [["c", 5, "left"]],
	"laboratorio": [["t", 4, "bottom"], ["i", 2, "top"]],
	"calderas": [],
}
const UPPER_KINDS := ["maternidad", "quirofano", "espera", "consultas"]
const MIDDLE_KINDS := ["enfermeria", "farmacia", "rayos", "consultas"]
const BASEMENT_KINDS := ["morgue", "laboratorio", "calderas"]

var _rng: RandomNumberGenerator
var _w := 0
var _h := 0
var _cells: Array[String] = []
## Salas: {rect (interior), band ("up", "mid", "base", "cor"), zone, kind, openings}.
var _rooms: Array[Dictionary] = []
## Casilla central de cada paso: el Nonato debe llegar a todas con las luces encendidas.
var _door_centers: Array[Vector2i] = []
## Casillas ocupadas o reservadas para que nada se pegue a otra cosa.
var _used := {}


## Tamaño del hospital: pequeño en el nivel 1, mediano en 2 y 3, grande desde el 4.
static func size_tier(level: int) -> int:
	if level <= 1:
		return 0
	return 1 if level <= 3 else 2


## Filas del hospital, o vacío si ningún intento pasa la validación.
static func generate(seed_value: int, level: int) -> PackedStringArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for attempt in MAX_ATTEMPTS:
		var gen := HospitalGen.new()
		gen._rng = rng
		gen._build(SIZES[size_tier(level)])
		if gen._validate():
			return gen._to_rows()
	return PackedStringArray()


func _build(dims: Array) -> void:
	_w = dims[0]
	var up_h: int = dims[1]
	var mid_h: int = dims[2]
	var base_h: int = dims[3]
	var y_up := 5
	var y_cw1 := y_up + up_h
	var y_cor := y_cw1 + 1
	var y_cw2 := y_cor + 3
	var y_mid := y_cw2 + 1
	var y_bw := y_mid + mid_h
	var y_base := y_bw + 1
	_h = y_base + base_h + 1
	_cells.resize(_w * _h)
	_cells.fill("#")

	# Exterior y puerta de salida, centrados más o menos.
	var ex := _rng.randi_range(_w / 2 - 6, _w / 2 + 6)
	_fill(Rect2i(ex - 5, 1, 12, 3), "E")
	_fill(Rect2i(ex - 1, 4, 3, 1), "X")

	# Pasillo principal de lado a lado.
	var corridor := _add_room(Rect2i(1, y_cor, _w - 2, 3), "cor", 0, "", ".")

	# Franja de arriba: urgencias contiene la puerta de salida.
	var up_rooms: Array[Dictionary] = []
	for span: Array in _partition(1, _w - 2, 9, 18, ex - 9, ex + 9):
		var rect := Rect2i(span[0], y_up, span[1] - span[0] + 1, up_h)
		var is_er: bool = span[0] <= ex and ex <= span[1]
		var kind := "urgencias" if is_er else _pick(UPPER_KINDS)
		up_rooms.append(_add_room(rect, "up", 0 if is_er else _zone_of(rect), kind, "."))
	var er: Dictionary = up_rooms.filter(func(r: Dictionary) -> bool: return r.kind == "urgencias")[0]
	for x in range(ex - 1, ex + 2):
		er.openings.append(Vector2i(x, 4))

	# Escalera al sótano: ninguna pared de sala cae cerca de ella.
	var sx := _rng.randi_range(_w / 4, _w * 3 / 4)
	var mid_rooms: Array[Dictionary] = []
	for span: Array in _partition(1, _w - 2, 8, 16, sx - 3, sx + 5):
		var rect := Rect2i(span[0], y_mid, span[1] - span[0] + 1, mid_h)
		mid_rooms.append(_add_room(rect, "mid", _zone_of(rect), _pick(MIDDLE_KINDS), "."))
	var base_rooms: Array[Dictionary] = []
	for span: Array in _partition(1, _w - 2, 10, 22, sx - 3, sx + 5):
		var rect := Rect2i(span[0], y_base, span[1] - span[0] + 1, base_h)
		base_rooms.append(_add_room(rect, "base", 3, _pick(BASEMENT_KINDS), ","))

	# Puertas: cada sala de arriba y del medio da al pasillo. Entre vecinas, a veces.
	for room in up_rooms:
		_door_horizontal(room, corridor, y_cw1)
	for room in mid_rooms:
		_door_horizontal(room, corridor, y_cw2)
	for band: Array in [up_rooms, mid_rooms]:
		for i in band.size() - 1:
			if _rng.randf() < 0.5:
				_door_vertical(band[i], band[i + 1])
	# En el sótano todas las vecinas se unen: solo se entra por la escalera.
	for i in base_rooms.size() - 1:
		_door_vertical(base_rooms[i], base_rooms[i + 1])

	# Escalera: últimas 3 filas de la sala del medio y la pared de debajo.
	var stairs := Rect2i(sx, y_bw - 3, 3, 4)
	_fill(stairs, "S")
	_door_centers.append(Vector2i(sx + 1, y_bw))
	for room in mid_rooms + base_rooms:
		if room.rect.grow(1).intersects(stairs):
			for y in range(stairs.position.y, stairs.end.y):
				for x in range(sx, sx + 3):
					room.openings.append(Vector2i(x, y))
	for y in range(stairs.position.y - 1, stairs.end.y + 1):
		for x in range(sx - 1, sx + 4):
			_used[Vector2i(x, y)] = true

	# Jugadores y carro de entrega en urgencias, junto a la salida.
	_put(Vector2i(ex, y_up + 4), "P")
	_put(Vector2i(ex + 3, y_up + 2), "D")
	_reserve_around(Vector2i(ex, y_up + 4))
	_reserve_around(Vector2i(ex + 3, y_up + 2))

	# Muebles pegados a las paredes.
	for room in _rooms:
		if room.kind == "urgencias":
			_place_on_wall(room, "t", 3, "top")
			_place_on_wall(room, "w", 4, "bottom")
		elif DECOR.has(room.kind):
			for entry: Array in DECOR[room.kind]:
				_place_on_wall(room, entry[0], entry[1], entry[2])

	# Catálogo de tareas: 3 sitios por generador y zona, y el resto de tareas.
	var work_rooms := _rooms.filter(func(r: Dictionary) -> bool: return r.band != "cor" and r.kind != "urgencias")
	for zone in [1, 2, 3]:
		var in_zone := work_rooms.filter(func(r: Dictionary) -> bool: return r.zone == zone)
		_spread(in_zone, str(zone), 3)
	var upper := work_rooms.filter(func(r: Dictionary) -> bool: return r.band != "base")
	_spread(upper, "a", 2)
	_spread(upper + [er], "o", 2)
	_spread(base_rooms, "v", 3)

	# Luces de emergencia: 3 o 4 por zona, lejos de las puertas.
	for zone in [1, 2, 3]:
		var in_zone := work_rooms.filter(func(r: Dictionary) -> bool: return r.zone == zone)
		_place_lamps(in_zone, str(zone + 3), 3 + (zone % 2))

	# Monstruos en el sótano, lejos de la escalera.
	var stair_cell := Vector2i(sx + 1, y_bw)
	_place_free(base_rooms, "M", MONSTER_SPOTS, 2, func(c: Vector2i) -> bool: return (c - stair_cell).length() >= 8)
	# Pilas y botín repartidos por todo el hospital.
	var tier := SIZES.find(dims)
	var all_rooms := _rooms.duplicate()
	_place_free(all_rooms, "B", 10 + tier * 4, 1, Callable())
	_place_free(all_rooms, "$", 20 + tier * 8, 1, Callable())


func _validate() -> bool:
	var spawn := _find("P")
	if spawn.is_empty():
		return false
	# Jugadores con la puerta abierta: todo lo transitable es alcanzable.
	var walk := _bfs(spawn[0], func(c: Vector2i) -> bool: return not PLAYER_BLOCKING.contains(_at(c)))
	for y in _h:
		for x in _w:
			var cell := Vector2i(x, y)
			var c := _at(cell)
			if (c == "." or c == "," or "BM$D456".contains(c)) and not walk.has(cell):
				return false
			if "123aov".contains(c) and not _touches_any(cell, walk):
				return false
	# Monstruo: rejilla reducida para su cuerpo. Con todas las luces de emergencia encendidas
	# llega a todas las salas y a todos los pasos.
	var lit := {}
	for lamp in _find("4") + _find("5") + _find("6"):
		for c in _lamp_cells(lamp):
			lit[c] = true
	for door in _door_centers:
		if lit.has(door):
			return false
	for start in _find("M"):
		var hunt := _bfs(start, func(c: Vector2i) -> bool: return not lit.has(c) and not _near_monster_blocking(c))
		for door in _door_centers:
			if not hunt.has(door):
				return false
		for room in _rooms:
			var reached := false
			for cell in hunt:
				if room.rect.has_point(cell):
					reached = true
					break
			if not reached:
				return false
	return true


## Reparte un tramo [a, b] en salas de min_w a max_w con paredes de 2 entre ellas.
## Ninguna pared cae dentro de [forbid_a, forbid_b].
func _partition(a: int, b: int, min_w: int, max_w: int, forbid_a: int, forbid_b: int) -> Array:
	var out := []
	var cur := a
	while true:
		var remain := b - cur + 1
		if remain <= max_w:
			out.append([cur, b])
			break
		var options: Array[int] = []
		for width in range(min_w, remain):
			if width > max_w and not options.is_empty():
				break
			var wall := cur + width
			if wall + 1 >= forbid_a and wall <= forbid_b:
				continue
			if b - (wall + 2) + 1 < min_w:
				continue
			options.append(width)
		if options.is_empty():
			out.append([cur, b])
			break
		var chosen: int = options[_rng.randi_range(0, options.size() - 1)]
		out.append([cur, cur + chosen - 1])
		cur += chosen + 2
	return out


func _add_room(rect: Rect2i, band: String, zone: int, kind: String, floor_char: String) -> Dictionary:
	_fill(rect, floor_char)
	var room := {"rect": rect, "band": band, "zone": zone, "kind": kind, "openings": []}
	_rooms.append(room)
	return room


func _zone_of(rect: Rect2i) -> int:
	return 1 if rect.get_center().x < _w / 2 else 2


## Puerta de 3 casillas en la pared de una fila entre una sala y el pasillo.
func _door_horizontal(room: Dictionary, corridor: Dictionary, wall_y: int) -> void:
	var rect: Rect2i = room.rect
	var x := _rng.randi_range(rect.position.x + 1, rect.end.x - 4)
	for dx in 3:
		var cell := Vector2i(x + dx, wall_y)
		_put(cell, ".")
		room.openings.append(cell)
		corridor.openings.append(cell)
	_door_centers.append(Vector2i(x + 1, wall_y))


## Puerta de 3 casillas en la pared doble entre dos salas vecinas de la misma franja.
func _door_vertical(left: Dictionary, right: Dictionary) -> void:
	var rect: Rect2i = left.rect
	var wall_x := rect.end.x
	var y := _rng.randi_range(rect.position.y + 1, rect.end.y - 4)
	var floor_char := _at(Vector2i(wall_x - 1, y))
	for dy in 3:
		for dx in 2:
			var cell := Vector2i(wall_x + dx, y + dy)
			_put(cell, floor_char)
			left.openings.append(cell)
			right.openings.append(cell)
	_door_centers.append(Vector2i(wall_x, y + 1))
	_door_centers.append(Vector2i(wall_x + 1, y + 1))


## Casillas del interior pegadas a un lado de la pared, lejos de las puertas y libres.
func _wall_slots(room: Dictionary, side: String) -> Array[Vector2i]:
	var rect: Rect2i = room.rect
	var cells: Array[Vector2i] = []
	match side:
		"top":
			for x in range(rect.position.x, rect.end.x):
				cells.append(Vector2i(x, rect.position.y))
		"bottom":
			for x in range(rect.position.x, rect.end.x):
				cells.append(Vector2i(x, rect.end.y - 1))
		"left":
			for y in range(rect.position.y + 1, rect.end.y - 1):
				cells.append(Vector2i(rect.position.x, y))
		"right":
			for y in range(rect.position.y + 1, rect.end.y - 1):
				cells.append(Vector2i(rect.end.x - 1, y))
		_:
			for s in ["top", "bottom", "left", "right"]:
				cells.append_array(_wall_slots(room, s))
			return cells
	return cells.filter(func(c: Vector2i) -> bool: return _is_free_slot(room, c))


func _is_free_slot(room: Dictionary, cell: Vector2i) -> bool:
	if _used.has(cell) or not (_at(cell) == "." or _at(cell) == ","):
		return false
	for door: Vector2i in room.openings:
		if maxi(absi(door.x - cell.x), absi(door.y - cell.y)) < DOOR_CLEARANCE:
			return false
	return true


func _place_on_wall(room: Dictionary, symbol: String, count: int, side: String) -> int:
	var placed := 0
	for i in count:
		var slots := _wall_slots(room, side)
		if slots.is_empty():
			break
		var cell: Vector2i = slots[_rng.randi_range(0, slots.size() - 1)]
		_put(cell, symbol)
		_reserve_around(cell)
		placed += 1
	return placed


## Coloca count símbolos en salas distintas mientras haya, contra la pared.
func _spread(rooms: Array, symbol: String, count: int) -> void:
	if rooms.is_empty():
		return
	var order := rooms.duplicate()
	_shuffle(order)
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 4:
		placed += _place_on_wall(order[tries % order.size()], symbol, 1, "any")
		tries += 1


## Lámparas de emergencia en salas distintas, en el tercio de la sala más lejano a sus puertas.
func _place_lamps(rooms: Array, symbol: String, count: int) -> void:
	if rooms.is_empty():
		return
	var order := rooms.duplicate()
	_shuffle(order)
	for i in count:
		var room: Dictionary = order[i % order.size()]
		var rect: Rect2i = room.rect
		var best := Vector2i(-1, -1)
		var best_score := -1.0
		for t in 12:
			var cell := Vector2i(_rng.randi_range(rect.position.x + 1, rect.end.x - 2),
					_rng.randi_range(rect.position.y + 1, rect.end.y - 2))
			if _used.has(cell) or not (_at(cell) == "." or _at(cell) == ","):
				continue
			var score := INF
			for door: Vector2i in room.openings:
				score = minf(score, Vector2(door - cell).length())
			if score > best_score:
				best_score = score
				best = cell
		if best != Vector2i(-1, -1):
			_put(best, symbol)
			_reserve_around(best)


## Sitios en suelo libre, a margin casillas de las paredes, que cumplen accept si se da.
func _place_free(rooms: Array, symbol: String, count: int, margin: int, accept: Callable) -> void:
	var cells: Array[Vector2i] = []
	for room: Dictionary in rooms:
		var rect: Rect2i = room.rect.grow(-margin)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells.append(Vector2i(x, y))
	_shuffle(cells)
	var placed := 0
	for cell in cells:
		if placed >= count:
			break
		if _used.has(cell) or not (_at(cell) == "." or _at(cell) == ","):
			continue
		if accept.is_valid() and not accept.call(cell):
			continue
		_put(cell, symbol)
		_reserve_around(cell)
		placed += 1


## Igual que Level._cells_lit_by: casillas a LAMP_RANGE px que la lámpara ve.
func _lamp_cells(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var r := ceili(LAMP_RANGE / TILE)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := origin + Vector2i(dx, dy)
			if Vector2(dx, dy).length() * TILE <= LAMP_RANGE and _sight(origin, c):
				cells.append(c)
	return cells


func _sight(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, steps):
		var p := Vector2i(Vector2(a).lerp(Vector2(b), float(i) / steps).round())
		if _at(p) == "#":
			return false
	return true


func _near_monster_blocking(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if MONSTER_BLOCKING.contains(_at(cell + Vector2i(dx, dy))):
				return true
	return false


func _bfs(start: Vector2i, ok: Callable) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := cell + d
			if not seen.has(n) and _in_bounds(n) and ok.call(n):
				seen[n] = true
				queue.append(n)
	return seen


func _touches_any(cell: Vector2i, cells: Dictionary) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if cells.has(cell + d):
			return true
	return false


func _find(symbol: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in _cells.size():
		if _cells[i] == symbol:
			out.append(Vector2i(i % _w, i / _w))
	return out


func _reserve_around(cell: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_used[cell + Vector2i(dx, dy)] = true


func _pick(options: Array) -> String:
	return options[_rng.randi_range(0, options.size() - 1)]


## Fisher-Yates con el generador propio: mismo orden en todos los equipos.
func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


func _fill(rect: Rect2i, c: String) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_put(Vector2i(x, y), c)


func _put(cell: Vector2i, c: String) -> void:
	_cells[cell.y * _w + cell.x] = c


func _at(cell: Vector2i) -> String:
	if not _in_bounds(cell):
		return "#"
	return _cells[cell.y * _w + cell.x]


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _w and cell.y < _h


func _to_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for y in _h:
		rows.append("".join(PackedStringArray(_cells.slice(y * _w, (y + 1) * _w))))
	return rows
