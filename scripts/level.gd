class_name Level
extends Node2D
## Construye el mapa desde un archivo de texto. La leyenda está en tools/gen_hospital_map.py.

const TILE := 16
# Coordenadas del atlas art/sprites/tiles.png (orden fijado en tools/gen_placeholders.py).
const FLOOR := Vector2i(0, 0)
## Pared con suelo debajo: se ve su cara frontal.
const WALL_FRONT := Vector2i(1, 0)
## Pared con pared debajo: solo se ve la parte de arriba.
const WALL_TOP := Vector2i(11, 0)
const CONCRETE := Vector2i(3, 0)
const ASPHALT := Vector2i(4, 0)
const STAIRS := Vector2i(5, 0)
const DOOR := Vector2i(6, 0)
## Variantes de suelo de hospital con su probabilidad en %: limpio, sucio, roto, sangre, charco.
const FLOOR_VARIANTS := [[Vector2i(0, 0), 70], [Vector2i(12, 0), 14], [Vector2i(13, 0), 8], [Vector2i(2, 0), 5], [Vector2i(16, 0), 3]]
## Variantes de hormigón: liso, manchado, agrietado.
const CONCRETE_VARIANTS := [[Vector2i(3, 0), 70], [Vector2i(14, 0), 15], [Vector2i(15, 0), 15]]
const OBSTACLES := {"c": Vector2i(7, 0), "w": Vector2i(8, 0), "i": Vector2i(9, 0), "t": Vector2i(10, 0)}
const TILES_TEXTURE := preload("res://art/sprites/tiles.png")
## Capa de física de los obstáculos: frenan el paso pero no cortan la luz.
const OBSTACLE_LAYER := 16
## Caracteres que el monstruo trata como bloqueo al planear su camino.
const MONSTER_BLOCKING := "#XEciwt123aov"

@export_file("*.txt") var map_path := "res://maps/hospital.txt"
## Semilla del reparto de objetos. El anfitrión la elige y la envía, así todos ven el mismo mapa.
var map_seed := 0
## Nivel del hospital aleatorio (fija su tamaño). 0: usa el mapa fijo de map_path.
var procedural_level := 0

var tiles: TileMapLayer
var size := Vector2i.ZERO
var player_spawn := Vector2.ZERO
var monster_spawn := Vector2.ZERO
## Puntos de aparición elegidos, uno por Nonato. El mapa marca 3 candidatos con M.
var monster_spawns: Array[Vector2] = []
## Nonatos de la partida: se quedan tantos sitios M como este número.
var monster_count := 1
var battery_spawns: Array[Vector2] = []
## Lámparas como pares [posición, zona]. Zona 0: siempre encendida.
var lamp_spawns: Array = []
## Tareas como [posición, tipo, zona]. Primero los generadores por zona, luego el resto.
var task_spawns: Array = []
## Tareas que se quedan en el mapa. -1 deja todas las del catálogo.
var task_count := -1
## Objetos de valor como posiciones. El mapa marca sus sitios candidatos con $.
var loot_spawns: Array[Vector2] = []
## Objetos de valor que se quedan en el mapa. -1 deja todos los candidatos.
var loot_count := -1
## Carro donde se entrega el botín (símbolo D).
var cart_position := Vector2.ZERO
var door_open := false
## Rejilla de caminos del monstruo. Las casillas junto a paredes cuentan como
## bloqueadas para que su cuerpo de 28 px no se enganche en las esquinas.
var monster_grid := AStarGrid2D.new()

## Margen alrededor de la luz de una lámpara para que el cuerpo del monstruo no la roce.
const ZONE_MARGIN := 6.0
## Pilas que aparecen por partida. El mapa marca más sitios candidatos con B.
const BATTERY_COUNT := 8
## Objetos con varios sitios candidatos en el mapa: se queda uno de cada.
const SINGLE_PICKS := ["1", "2", "3", "M"]

var _rows := PackedStringArray()
var _door_cells: Array[Vector2i] = []
## Casillas bloqueadas por el propio mapa para el monstruo (paredes y su margen).
var _static_solid := {}
## Casillas libres del mapa, para deambular.
var _open_cells: Array[Vector2i] = []
## Lámparas encendidas: id -> [centro, radio de luz].
var _lamp_zones := {}
## Casillas tapadas por la luz de alguna lámpara: casilla -> número de lámparas.
var _zone_cells := {}


func build() -> void:
	if procedural_level > 0:
		_rows = HospitalGen.generate(map_seed, procedural_level)
		if _rows.is_empty():
			push_warning("Hospital aleatorio no válido con la semilla %d: uso %s" % [map_seed, map_path])
	if _rows.is_empty():
		_rows = _load_rows(map_path)
	size = Vector2i(_rows[0].length(), _rows.size())
	_pick_spawns()
	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = _make_tile_set()
	add_child(tiles)
	for y in size.y:
		for x in size.x:
			_place(Vector2i(x, y))
	# Generadores primero y por zona: tasks[0] es el de la zona 1 si está en el mapa.
	task_spawns.sort_custom(func(a: Array, b: Array) -> bool: return _task_order(a) < _task_order(b))
	_build_occluders()
	_build_monster_grid()


## Reparte generadores, monstruo y pilas entre sus sitios candidatos según map_seed.
## Después deja task_count tareas del catálogo. Lo descartado pasa a ser suelo antes de construir.
func _pick_spawns() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var found := {}
	for y in size.y:
		for x in size.x:
			var c := _rows[y][x]
			if c in SINGLE_PICKS or c == "B" or c == "$":
				if not found.has(c):
					found[c] = []
				found[c].append(Vector2i(x, y))
	for c: String in found:
		var cells: Array = found[c]
		var keep := 1 if c in SINGLE_PICKS else BATTERY_COUNT
		if c == "M":
			keep = monster_count
		if c == "$":
			keep = loot_count if loot_count >= 0 else cells.size()
		_shuffle(cells, rng)
		_clear_cells(cells.slice(keep))
	# Catálogo de tareas: los generadores que quedan y los demás símbolos de tarea.
	if task_count < 0:
		return
	var tasks: Array = []
	for y in size.y:
		for x in size.x:
			var c := _rows[y][x]
			if c in ["1", "2", "3"] or Task.SYMBOLS.has(c):
				tasks.append(Vector2i(x, y))
	_shuffle(tasks, rng)
	_clear_cells(tasks.slice(task_count))


## Fisher-Yates con el generador propio: mismo orden en todos los equipos.
func _shuffle(cells: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp


## Los sitios descartados pasan a ser suelo del mismo tipo que el de alrededor.
func _clear_cells(cells: Array) -> void:
	for cell: Vector2i in cells:
		_set_char(cell, "," if _touches(cell, ",") else ".")


func _task_order(entry: Array) -> int:
	return entry[2] if entry[2] > 0 else 10 + Task.KINDS.keys().find(entry[1])


func _set_char(cell: Vector2i, c: String) -> void:
	var row := _rows[cell.y]
	_rows[cell.y] = row.substr(0, cell.x) + c + row.substr(cell.x + 1)


func _touches(cell: Vector2i, c: String) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _char_at(cell + d) == c:
			return true
	return false


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())


func pixel_size() -> Vector2i:
	return size * TILE


func is_exit(pos: Vector2) -> bool:
	return _char_at(world_to_cell(pos)) == "E"


func door_position() -> Vector2:
	if _door_cells.is_empty():
		return Vector2.ZERO
	return cell_center(_door_cells[_door_cells.size() / 2])


## Abre la puerta de salida: sus casillas pasan a ser suelo sin colisión ni sombra.
func open_door() -> void:
	door_open = true
	for cell in _door_cells:
		tiles.set_cell(cell, 0, FLOOR)
	_build_occluders()


## Camino en coordenadas de mundo desde el monstruo hasta un objetivo.
func get_monster_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _nearest_open(world_to_cell(from))
	var goal := _nearest_open(world_to_cell(to))
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return PackedVector2Array()
	return monster_grid.get_point_path(start, goal, true)


func _place(cell: Vector2i) -> void:
	var c := _char_at(cell)
	var center := cell_center(cell)
	match c:
		"#":
			var below := _char_at(cell + Vector2i.DOWN)
			tiles.set_cell(cell, 0, WALL_TOP if below == "#" or below == "X" else WALL_FRONT)
			return
		"X":
			tiles.set_cell(cell, 0, DOOR)
			_door_cells.append(cell)
			return
		"E":
			tiles.set_cell(cell, 0, ASPHALT)
			return
		"S":
			tiles.set_cell(cell, 0, STAIRS)
			return
	if OBSTACLES.has(c):
		tiles.set_cell(cell, 0, OBSTACLES[c])
		return
	tiles.set_cell(cell, 0, _floor_for(cell))
	match c:
		"P": player_spawn = center
		"M":
			monster_spawns.append(center)
			monster_spawn = monster_spawns[0]
		"B": battery_spawns.append(center)
		"$": loot_spawns.append(center)
		"D": cart_position = center
		"L": lamp_spawns.append([center, 0])
		"1", "2", "3": task_spawns.append([center, "generator", int(c)])
		"a", "o", "v": task_spawns.append([center, Task.SYMBOLS[c], 0])
		"4", "5", "6": lamp_spawns.append([center, int(c) - 3])


## Las casillas con objetos usan el suelo de alrededor: hormigón en el sótano.
func _floor_for(cell: Vector2i) -> Vector2i:
	var c := _char_at(cell)
	var concrete := c == ","
	if not concrete and c != ".":
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _char_at(cell + d) == ",":
				concrete = true
				break
	return _pick_variant(cell, CONCRETE_VARIANTS if concrete else FLOOR_VARIANTS)


## Elige una variante según la posición, siempre la misma en todos los equipos.
func _pick_variant(cell: Vector2i, variants: Array) -> Vector2i:
	var roll := absi(cell.x * 73856093 ^ cell.y * 19349663) % 100
	for entry: Array in variants:
		roll -= entry[1]
		if roll < 0:
			return entry[0]
	return variants[0][0]


func _load_rows(path: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		line = line.strip_edges(false, true)
		if not line.is_empty():
			rows.append(line)
	assert(not rows.is_empty(), "Mapa vacío: %s" % path)
	return rows


func _char_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _rows.size() or cell.x < 0 or cell.x >= _rows[cell.y].length():
		return "#"
	return _rows[cell.y][cell.x]


func _make_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, OBSTACLE_LAYER)
	ts.set_physics_layer_collision_mask(1, 0)

	var source := TileSetAtlasSource.new()
	source.texture = TILES_TEXTURE
	source.texture_region_size = Vector2i(TILE, TILE)
	for x in TILES_TEXTURE.get_width() / TILE:
		source.create_tile(Vector2i(x, 0))
	ts.add_source(source, 0)

	var h := TILE / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for coords: Vector2i in [WALL_FRONT, WALL_TOP, DOOR]:
		var data := source.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)
	var inset := square.duplicate()
	for i in inset.size():
		inset[i] *= 0.75
	for coords: Vector2i in OBSTACLES.values():
		var data := source.get_tile_data(coords, 0)
		data.add_collision_polygon(1)
		data.set_collision_polygon_points(1, 0, inset)
	return ts


func _build_monster_grid() -> void:
	monster_grid.region = Rect2i(Vector2i.ZERO, size)
	monster_grid.cell_size = Vector2(TILE, TILE)
	monster_grid.offset = Vector2(TILE, TILE) / 2.0
	monster_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	monster_grid.update()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if _near_blocking(cell):
				monster_grid.set_point_solid(cell)
				_static_solid[cell] = true
			else:
				_open_cells.append(cell)


## Marca o desmarca la luz de una lámpara como zona prohibida para el monstruo.
## La luz no atraviesa paredes, así que solo cuentan las casillas que la lámpara ve.
func set_lamp_zone(id: int, center: Vector2, radius: float, active: bool) -> void:
	if active == _lamp_zones.has(id):
		return
	var cells := _cells_lit_by(center, radius + ZONE_MARGIN)
	if active:
		_lamp_zones[id] = [center, radius]
		for c in cells:
			_zone_cells[c] = _zone_cells.get(c, 0) + 1
			monster_grid.set_point_solid(c)
	else:
		_lamp_zones.erase(id)
		for c in cells:
			_zone_cells[c] = _zone_cells.get(c, 1) - 1
			if _zone_cells[c] <= 0:
				_zone_cells.erase(c)
				if not _static_solid.has(c):
					monster_grid.set_point_solid(c, false)


## True si la luz de alguna lámpara encendida llega a ese punto.
func is_lamp_zone(pos: Vector2) -> bool:
	var cell := world_to_cell(pos)
	for zone: Array in _lamp_zones.values():
		if pos.distance_to(zone[0]) <= zone[1] and _grid_sight(world_to_cell(zone[0]), cell):
			return true
	return false


## Centro de la casilla libre más cercana fuera de toda luz de lámpara.
func nearest_dark_point(from: Vector2) -> Vector2:
	var start := world_to_cell(from)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty() and seen.size() < 600:
		var cell: Vector2i = queue.pop_front()
		if not _zone_cells.has(cell) and not _static_solid.has(cell) \
				and not is_lamp_zone(cell_center(cell)):
			return cell_center(cell)
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := cell + d
			if not seen.has(n) and _char_at(n) != "#":
				seen[n] = true
				queue.append(n)
	return from


## Punto al azar donde el monstruo puede estar.
func random_monster_point() -> Vector2:
	for i in 20:
		var cell: Vector2i = _open_cells.pick_random()
		if not _zone_cells.has(cell):
			return cell_center(cell)
	return monster_spawn


func _cells_lit_by(center: Vector2, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var origin := world_to_cell(center)
	var r := ceili(radius / TILE)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := origin + Vector2i(dx, dy)
			if monster_grid.is_in_boundsv(c) and cell_center(c).distance_to(center) <= radius \
					and _grid_sight(origin, c):
				cells.append(c)
	return cells


## Línea de visión por casillas: ninguna pared entre las dos.
func _grid_sight(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, steps):
		var p := Vector2(a).lerp(Vector2(b), float(i) / steps).round()
		if _char_at(Vector2i(p)) == "#":
			return false
	return true


func _near_blocking(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if MONSTER_BLOCKING.contains(_char_at(cell + Vector2i(dx, dy))):
				return true
	return false


## Casilla libre más cercana en un radio de 2, o (-1, -1) si no hay.
func _nearest_open(cell: Vector2i) -> Vector2i:
	if monster_grid.is_in_boundsv(cell) and not monster_grid.is_point_solid(cell):
		return cell
	var best := Vector2i(-1, -1)
	var best_dist := INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := cell + Vector2i(dx, dy)
			if not monster_grid.is_in_boundsv(c) or monster_grid.is_point_solid(c):
				continue
			var dist := Vector2(dx, dy).length()
			if dist < best_dist:
				best_dist = dist
				best = c
	return best


## Sombras de las paredes: un segmento por cada borde entre pared y suelo, unidos en tramos.
## Cada segmento solo proyecta sombra a la luz que le llega desde dentro de la pared: la cara
## que mira a la linterna se ilumina entera y detrás queda oscuro, sin dientes de sierra.
func _build_occluders() -> void:
	var old := get_node_or_null("Occluders")
	if old != null:
		old.free()
	var holder := Node2D.new()
	holder.name = "Occluders"
	add_child(holder)
	var t := float(TILE)
	for y in size.y:
		_add_runs(holder, y, Vector2i.UP, func(x0, x1): return [Vector2(x0 * t, y * t), Vector2((x1 + 1) * t, y * t)])
		_add_runs(holder, y, Vector2i.DOWN, func(x0, x1): return [Vector2((x1 + 1) * t, (y + 1) * t), Vector2(x0 * t, (y + 1) * t)])
	for x in size.x:
		_add_runs(holder, x, Vector2i.RIGHT, func(y0, y1): return [Vector2((x + 1) * t, y0 * t), Vector2((x + 1) * t, (y1 + 1) * t)], true)
		_add_runs(holder, x, Vector2i.LEFT, func(y0, y1): return [Vector2(x * t, (y1 + 1) * t), Vector2(x * t, y0 * t)], true)


## Recorre una fila (o columna) y crea un segmento por cada tramo seguido de paredes
## cuyo vecino en la dirección dada no es pared.
func _add_runs(holder: Node2D, line: int, side: Vector2i, to_points: Callable, vertical := false) -> void:
	var length := size.y if vertical else size.x
	var start := -1
	for i in length + 1:
		var cell := Vector2i(line, i) if vertical else Vector2i(i, line)
		var exposed := i < length and _blocks_light(cell) and not _blocks_light(cell + side)
		if exposed and start < 0:
			start = i
		elif not exposed and start >= 0:
			var points: Array = to_points.call(start, i - 1)
			var poly := OccluderPolygon2D.new()
			poly.closed = false
			poly.cull_mode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
			poly.polygon = PackedVector2Array(points)
			var occ := LightOccluder2D.new()
			occ.occluder = poly
			holder.add_child(occ)
			start = -1


func _blocks_light(cell: Vector2i) -> bool:
	var c := _char_at(cell)
	return c == "#" or (c == "X" and not door_open)


## Las casillas por donde una linterna iluminó al monstruo le cuestan más al planear rutas
## durante unos segundos, así busca otro camino. Recorre la línea jugador-monstruo y el
## contorno del monstruo.
const LIT_WEIGHT := 6.0
var _lit_cells := {}


func mark_lit_path(from: Vector2, to: Vector2, seconds: float) -> void:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	var steps := maxi(maxi(absi(b.x - a.x), absi(b.y - a.y)), 1)
	var cells: Array[Vector2i] = []
	for i in steps + 1:
		cells.append(Vector2i(Vector2(a).lerp(Vector2(b), float(i) / steps).round()))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			cells.append(b + Vector2i(dx, dy))
	for c in cells:
		if monster_grid.is_in_boundsv(c):
			_lit_cells[c] = seconds
			monster_grid.set_point_weight_scale(c, LIT_WEIGHT)


func tick_lit(delta: float) -> void:
	for c: Vector2i in _lit_cells.keys():
		_lit_cells[c] -= delta
		if _lit_cells[c] <= 0.0:
			_lit_cells.erase(c)
			monster_grid.set_point_weight_scale(c, 1.0)
