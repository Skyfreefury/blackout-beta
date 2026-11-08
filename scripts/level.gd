class_name Level
extends Node2D
## Construye el mapa desde un archivo de texto. La leyenda está en tools/gen_hospital_map.py.

const TILE := 16
const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
const FLOOR_STAINED := Vector2i(2, 0)
const CONCRETE := Vector2i(3, 0)
const ASPHALT := Vector2i(4, 0)
const STAIRS := Vector2i(5, 0)
const DOOR := Vector2i(6, 0)
const OBSTACLES := {"c": Vector2i(7, 0), "w": Vector2i(8, 0), "i": Vector2i(9, 0), "t": Vector2i(10, 0)}
const TILES_TEXTURE := preload("res://art/sprites/tiles.png")
## Capa de física de los obstáculos: frenan el paso pero no cortan la luz.
const OBSTACLE_LAYER := 16
## Caracteres que el monstruo trata como bloqueo al planear su camino.
const MONSTER_BLOCKING := "#XEciwt123"

@export_file("*.txt") var map_path := "res://maps/hospital.txt"

var tiles: TileMapLayer
var size := Vector2i.ZERO
var player_spawn := Vector2.ZERO
var monster_spawn := Vector2.ZERO
var battery_spawns: Array[Vector2] = []
## Lámparas como pares [posición, zona]. Zona 0: siempre encendida.
var lamp_spawns: Array = []
## Generadores como pares [posición, zona].
var generator_spawns: Array = []
var door_open := false
## Rejilla de caminos del monstruo. Las casillas junto a paredes cuentan como
## bloqueadas para que su cuerpo de 28 px no se enganche en las esquinas.
var monster_grid := AStarGrid2D.new()

## Margen alrededor de la luz de una lámpara para que el cuerpo del monstruo no la roce.
const ZONE_MARGIN := 6.0

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
	_rows = _load_rows(map_path)
	size = Vector2i(_rows[0].length(), _rows.size())
	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = _make_tile_set()
	add_child(tiles)
	for y in size.y:
		for x in size.x:
			_place(Vector2i(x, y))
	_build_monster_grid()


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
			tiles.set_cell(cell, 0, WALL)
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
		"M": monster_spawn = center
		"B": battery_spawns.append(center)
		"L": lamp_spawns.append([center, 0])
		"1", "2", "3": generator_spawns.append([center, int(c)])
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
	if concrete:
		return CONCRETE
	return FLOOR_STAINED if (cell.x * 7 + cell.y * 13) % 11 == 0 else FLOOR


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
	ts.add_occlusion_layer()

	var source := TileSetAtlasSource.new()
	source.texture = TILES_TEXTURE
	source.texture_region_size = Vector2i(TILE, TILE)
	for x in TILES_TEXTURE.get_width() / TILE:
		source.create_tile(Vector2i(x, 0))
	ts.add_source(source, 0)

	var h := TILE / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for coords: Vector2i in [WALL, DOOR]:
		var data := source.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)
		var occluder := OccluderPolygon2D.new()
		occluder.polygon = square
		# Solo proyectan sombra los bordes del fondo: la cara de la pared que mira
		# a la luz queda iluminada y lo que hay detrás sigue a oscuras.
		occluder.cull_mode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
		data.set_occluder_polygons_count(0, 1)
		data.set_occluder_polygon(0, 0, occluder)
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
	var cells := _lit_cells(center, radius + ZONE_MARGIN)
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


func _lit_cells(center: Vector2, radius: float) -> Array[Vector2i]:
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
