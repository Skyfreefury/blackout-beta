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
var _anim_time := 0.0
var _last_pos := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite


const FREEZE_SOUND_COOLDOWN := 2.0

var _crawl_sound: AudioStreamPlayer2D
var _was_frozen := false
var _freeze_cooldown := 0.0


func _ready() -> void:
	_crawl_sound = Sfx.make_loop_2d(self, "monster_loop", -2.0, 300.0)


## Arrastre a 6 fotogramas por segundo mientras se mueve; quieto al congelarse.
## También controla sus sonidos, igual en todos los equipos.
func _animate(delta: float) -> void:
	var moved := global_position.distance_to(_last_pos) > 0.05
	_last_pos = global_position
	if moved and not frozen:
		_anim_time += delta * 6.0
	sprite.frame = int(_anim_time) % 4
	var crawling := moved and not frozen
	if crawling and not _crawl_sound.playing:
		_crawl_sound.play()
	elif not crawling and _crawl_sound.playing:
		_crawl_sound.stop()
	_freeze_cooldown = maxf(_freeze_cooldown - delta, 0.0)
	if frozen and not _was_frozen and _freeze_cooldown == 0.0:
		Sfx.play_at("monster_freeze", global_position, -3.0)
		_freeze_cooldown = FREEZE_SOUND_COOLDOWN
	_was_frozen = frozen


func _physics_process(delta: float) -> void:
	# Solo el anfitrión mueve al monstruo. Los demás reciben posición y estado.
	if multiplayer.is_server():
		frozen = _is_lit()
	_animate(delta)
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


## Jugador más cercano que puede actuar. El ruido de reparar un generador
## atrae al monstruo: quien repara tiene prioridad sobre los demás.
func _nearest_player() -> Player:
	var best: Player = null
	var best_dist := INF
	var best_repairing := false
	for player: Player in get_tree().get_nodes_in_group("players"):
		if not player.can_act():
			continue
		var repairing := player.is_repairing()
		if best_repairing and not repairing:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist < best_dist or (repairing and not best_repairing):
			best_repairing = repairing
			best_dist = dist
			best = player
	return best
