class_name Monster
extends CharacterBody2D
## El Nonato: caza a oscuras y huye de las linternas.
## Al darle una linterna se aturde 0,5 s, recula fuera del haz y busca otra ruta: las casillas
## por donde le dio la luz le cuestan más durante 6 s. Prefiere a quien no le está apuntando,
## así que un jugador vigilando no protege al resto.
## Las lámparas fijas son refugio: no entra en su luz y, si se encienden con él dentro, sale.
## Existe en todos los equipos con el mismo nombre; la autoridad es el anfitrión.
## Mejorado (partidas de 2 o 4 jugadores): un 15% más rápido, se aturde 0,3 s y chilla
## cuando le iluminan. El chillido apaga 2 s las linternas a 150 px. Recarga en 30 s.

const SPEED := 110.0
const FLEE_SPEED := 90.0
const ROAM_SPEED := 55.0
const RETREAT_SPEED := 66.0
const ATTACK_RANGE := 18.0
const RETREAT_TIME := 3.0
const REPATH_TIME := 0.25
const ROAM_TIME := 5.0
const WAYPOINT_REACHED := 4.0
const FREEZE_SOUND_COOLDOWN := 2.0
const STUN_TIME := 0.5
const ENHANCED_SPEED := 1.15
const ENHANCED_STUN_TIME := 0.3
const ENHANCED_TINT := Color(1.0, 0.7, 0.7)
const ENHANCED_SCALE := 1.15
const SCREAM_RANGE := 150.0
const SCREAM_BLIND := 2.0
const SCREAM_COOLDOWN := 30.0
## Un jugador que ya persigue otro Nonato parece un 50% más lejos: se reparten las presas.
const SHARED_TARGET_FACTOR := 1.5
## Segundos sin luz necesarios para que la siguiente linterna vuelva a aturdirlo.
const STUN_COOLDOWN := 1.5
const RECOIL_SPEED := 100.0
## Segundos que recuerda las casillas iluminadas al planear rutas.
const LIT_MEMORY := 6.0
## Puntos del cuerpo que se comprueban contra las linternas. Basta con que uno esté iluminado.
const PROBES: Array[Vector2] = [
	Vector2(0, -10), Vector2(-12, -18), Vector2(12, -18), Vector2(-12, 2), Vector2(12, 2),
]

var level: Level
## Aturdido por una linterna. Se sincroniza: los demás lo ven temblar.
var frozen := false
## Hora (ms) hasta la que duerme por un dardo, en todos los equipos. Solo para efectos.
var asleep_until := 0
## Versión mejorada. Se decide al crearlo, igual en todos los equipos.
var enhanced := false

var _path := PackedVector2Array()
var _path_index := 0
var _repath_timer := 0.0
var _retreat_timer := 0.0
var _roam_timer := 0.0
var _target: Player
var _anim_time := 0.0
var _last_pos := Vector2.ZERO
var _crawl_sound: AudioStreamPlayer2D
var _was_frozen := false
var _freeze_cooldown := 0.0
var _stun_timer := 0.0
## Segundos dormido por un dardo tranquilizante. No se mueve, no ataca ni chilla.
var _sleep_timer := 0.0
var _unlit_time := 99.0
## Jugadores que le están dando con la linterna en este fotograma (solo en el anfitrión).
var _watchers: Array[Player] = []
## Jugadores que le iluminaron hace poco -> segundos que le quedan en la memoria.
var _recent_watchers := {}
var _scream_timer := SCREAM_COOLDOWN / 2.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("monster")
	if enhanced:
		sprite.modulate = ENHANCED_TINT
		sprite.scale = Vector2.ONE * ENHANCED_SCALE
	_crawl_sound = Sfx.make_loop_2d(self, "monster_loop", -2.0, 300.0)


func _physics_process(delta: float) -> void:
	# Solo el anfitrión mueve al monstruo. Los demás reciben posición y estado.
	if multiplayer.is_server():
		_update_light_reaction(delta)
	_animate(delta)
	if frozen:
		velocity = Vector2.ZERO
		var asleep := Time.get_ticks_msec() < asleep_until
		sprite.position = Vector2.ZERO if asleep else Vector2(randi_range(-1, 1), randi_range(-1, 1))
		return
	sprite.position = Vector2.ZERO
	if not multiplayer.is_server():
		return
	if level.is_lamp_zone(global_position):
		_flee_light()
	elif not _watchers.is_empty():
		_recoil()
	elif _retreat_timer > 0.0:
		_retreat_timer -= delta
		_retreat()
	else:
		_hunt(delta)
	move_and_slide()
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0


## True si la linterna de ese jugador le da en alguna parte del cuerpo.
func is_lit_by(player: Player) -> bool:
	for probe in PROBES:
		if player.is_lighting(global_position + probe):
			return true
	return false


## Solo en el anfitrión: aturdimiento corto al primer contacto y memoria de casillas iluminadas.
func _update_light_reaction(delta: float) -> void:
	_watchers.clear()
	for player: Player in get_tree().get_nodes_in_group("players"):
		if is_lit_by(player):
			_watchers.append(player)
	if _watchers.is_empty():
		_unlit_time += delta
	else:
		if _unlit_time >= STUN_COOLDOWN:
			_stun_timer = ENHANCED_STUN_TIME if enhanced else STUN_TIME
		_unlit_time = 0.0
		for player in _watchers:
			level.mark_lit_path(player.global_position, global_position, LIT_MEMORY)
			_recent_watchers[player] = LIT_MEMORY
	for player in _recent_watchers.keys():
		_recent_watchers[player] -= delta
		if _recent_watchers[player] <= 0.0 or not is_instance_valid(player):
			_recent_watchers.erase(player)
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	_sleep_timer = maxf(_sleep_timer - delta, 0.0)
	frozen = _stun_timer > 0.0 or _sleep_timer > 0.0
	if enhanced and _sleep_timer == 0.0:
		_scream_timer = maxf(_scream_timer - delta, 0.0)
		if _scream_timer == 0.0 and not _watchers.is_empty():
			_scream()


## Solo en el anfitrión: lo duerme un dardo tranquilizante.
func tranquilize(seconds: float) -> void:
	_sleep_timer = maxf(_sleep_timer, seconds)
	_sleep_fx.rpc(seconds)


## Dormido se ve azulado y sin temblar.
@rpc("authority", "call_local", "reliable")
func _sleep_fx(seconds: float) -> void:
	var base := sprite.modulate
	sprite.modulate = Color(0.55, 0.65, 1.0)
	var tween := create_tween()
	tween.tween_interval(seconds - 0.5)
	tween.tween_property(sprite, "modulate", base, 0.5)
	asleep_until = Time.get_ticks_msec() + int(seconds * 1000.0)


## Solo en el anfitrión: apaga las linternas cercanas durante unos segundos.
func _scream() -> void:
	_scream_timer = SCREAM_COOLDOWN
	_scream_fx.rpc()
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.can_act() and global_position.distance_to(player.global_position) <= SCREAM_RANGE:
			player.blind.rpc_id(player.get_multiplayer_authority(), SCREAM_BLIND)


@rpc("authority", "call_local", "reliable")
func _scream_fx() -> void:
	Sfx.play_at("monster_scream", global_position, 2.0)


## Se aleja de quien le ilumina y pide ruta nueva en cuanto sale del haz.
func _recoil() -> void:
	var away := Vector2.ZERO
	for player in _watchers:
		away += player.global_position.direction_to(global_position)
	velocity = away.normalized() * RECOIL_SPEED
	_path = PackedVector2Array()
	_repath_timer = 0.0
	_stop_at_light()


func _hunt(delta: float) -> void:
	_target = _nearest_player()
	_repath_timer -= delta
	if _target == null:
		_roam(delta)
		return
	_roam_timer = 0.0
	if global_position.distance_to(_target.global_position) <= ATTACK_RANGE:
		_target.hit()
		_retreat_timer = RETREAT_TIME
		velocity = Vector2.ZERO
		return
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_TIME
		_set_path(level.get_monster_path(global_position, _target.global_position))
	_follow_path(_target.global_position, SPEED * (ENHANCED_SPEED if enhanced else 1.0))


## Nadie al alcance: deambula hacia casillas al azar.
func _roam(delta: float) -> void:
	_roam_timer -= delta
	if _roam_timer <= 0.0 or _path_index >= _path.size():
		_roam_timer = ROAM_TIME
		_set_path(level.get_monster_path(global_position, level.random_monster_point()))
	var goal := _path[_path.size() - 1] if not _path.is_empty() else global_position
	_follow_path(goal, ROAM_SPEED)


## Sale de la luz de una lámpara hacia la casilla libre más cercana.
func _flee_light() -> void:
	var exit := level.nearest_dark_point(global_position)
	velocity = global_position.direction_to(exit) * FLEE_SPEED
	_path = PackedVector2Array()
	_repath_timer = 0.0


func _retreat() -> void:
	if _target == null:
		velocity = Vector2.ZERO
		return
	velocity = _target.global_position.direction_to(global_position) * RETREAT_SPEED
	_stop_at_light()


func _set_path(path: PackedVector2Array) -> void:
	_path = path
	_path_index = 1 if _path.size() > 1 else 0


func _follow_path(fallback: Vector2, speed: float) -> void:
	var next := fallback
	while _path_index < _path.size():
		if global_position.distance_to(_path[_path_index]) > WAYPOINT_REACHED:
			next = _path[_path_index]
			break
		_path_index += 1
	velocity = global_position.direction_to(next) * speed
	_stop_at_light()


## Sin camino, el movimiento directo nunca le mete en una zona iluminada.
func _stop_at_light() -> void:
	var ahead := global_position + velocity.normalized() * Level.TILE
	if level.is_lamp_zone(ahead):
		velocity = Vector2.ZERO


## Jugador más cercano que puede actuar y no está a salvo bajo una lámpara.
## Quien le acaba de iluminar solo es objetivo si no queda nadie más.
## El ruido de reparar un generador atrae al monstruo: quien repara tiene prioridad.
func _nearest_player() -> Player:
	var best := _pick_target(true)
	return best if best != null else _pick_target(false)


func _pick_target(skip_watchers: bool) -> Player:
	var best: Player = null
	var best_dist := INF
	var best_repairing := false
	for player: Player in get_tree().get_nodes_in_group("players"):
		if not player.can_act() or level.is_lamp_zone(player.global_position):
			continue
		if skip_watchers and _recent_watchers.has(player):
			continue
		var repairing := player.is_repairing()
		if best_repairing and not repairing:
			continue
		var dist := player.lure_distance(global_position)
		if _chased_by_other(player):
			dist *= SHARED_TARGET_FACTOR
		if dist < best_dist or (repairing and not best_repairing):
			best_repairing = repairing
			best_dist = dist
			best = player
	return best


func _chased_by_other(player: Player) -> bool:
	for other: Monster in get_tree().get_nodes_in_group("monster"):
		if other != self and other._target == player:
			return true
	return false


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
