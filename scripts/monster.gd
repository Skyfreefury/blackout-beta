class_name Monster
extends CharacterBody2D
## El Nonato: se congela si cualquier luz lo ilumina y caza a oscuras.
## Existe en todos los equipos con el mismo nombre; la autoridad es el anfitrión.

const SPEED := 110.0
const RETREAT_SPEED := 66.0
const ATTACK_RANGE := 18.0
const RETREAT_TIME := 3.0
const REPATH_TIME := 0.25
const WAYPOINT_REACHED := 4.0
## Puntos del cuerpo que se comprueban contra las luces. Basta con que uno esté iluminado.
const PROBES: Array[Vector2] = [
	Vector2(0, -10), Vector2(-12, -18), Vector2(12, -18), Vector2(-12, 2), Vector2(12, 2),
]

var level: Level
var frozen := false

var _path := PackedVector2Array()
var _path_index := 0
var _repath_timer := 0.0
var _retreat_timer := 0.0
var _target: Player

@onready var sprite: Sprite2D = $Sprite


func _physics_process(delta: float) -> void:
	# Solo el anfitrión mueve al monstruo. Los demás reciben posición y estado.
	if multiplayer.is_server():
		frozen = _is_lit()
	if frozen:
		velocity = Vector2.ZERO
		sprite.position = Vector2(randi_range(-1, 1), randi_range(-1, 1))
		return
	sprite.position = Vector2.ZERO
	if not multiplayer.is_server():
		return
	if _retreat_timer > 0.0:
		_retreat_timer -= delta
		_retreat()
	else:
		_hunt(delta)
	move_and_slide()
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0


func _is_lit() -> bool:
	var lights: Array[Node] = get_tree().get_nodes_in_group("players")
	lights.append_array(get_tree().get_nodes_in_group("lamps"))
	for light in lights:
		for probe in PROBES:
			if light.is_lighting(global_position + probe):
				return true
	return false


func _hunt(delta: float) -> void:
	_target = _nearest_player()
	if _target == null:
		velocity = Vector2.ZERO
		return
	if global_position.distance_to(_target.global_position) <= ATTACK_RANGE:
		_target.hit()
		_retreat_timer = RETREAT_TIME
		velocity = Vector2.ZERO
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_TIME
		_path = level.get_monster_path(global_position, _target.global_position)
		_path_index = 1 if _path.size() > 1 else 0
	var next := _target.global_position
	while _path_index < _path.size():
		if global_position.distance_to(_path[_path_index]) > WAYPOINT_REACHED:
			next = _path[_path_index]
			break
		_path_index += 1
	velocity = global_position.direction_to(next) * SPEED


func _retreat() -> void:
	if _target == null:
		velocity = Vector2.ZERO
		return
	velocity = _target.global_position.direction_to(global_position) * RETREAT_SPEED


func _nearest_player() -> Player:
	var best: Player = null
	var best_dist := INF
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_down:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = player
	return best
