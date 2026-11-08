class_name Player
extends CharacterBody2D
## Jugador: movimiento, linterna con batería, interacción mantenida y estados de vida.
## El nodo se llama con el id de red de su dueño. El dueño mueve y apunta (nodo Sync).
## El anfitrión decide derribos, reanimaciones, muerte y huida (nodo ServerSync).

signal state_changed

const WALK_SPEED := 60.0
const RUN_SPEED := 100.0
## Velocidad con la cojera tras el primer derribo.
const WOUNDED_FACTOR := 0.8
const STAMINA_MAX := 4.0
const STAMINA_REGEN_TIME := 6.0
## Resistencia mínima para volver a correr tras agotarse.
const STAMINA_RECOVER := 1.0
const BATTERY_MAX := 90.0
const BATTERY_PICKUP := 0.5
const LOW_BATTERY := 0.2
const LIGHT_RANGE := 120.0
const LIGHT_ANGLE := 50.0
const LIGHT_ENERGY := 1.2
## Apuntar al monstruo gasta la linterna al doble de velocidad: vigilarle tiene un coste.
const MONSTER_DRAIN := 2.0
const PICKUP_RADIUS := 14.0
const REVIVE_RANGE := 18.0
const REVIVE_TIME := 4.0
const BLEED_OUT_TIME := 30.0
## Margen extra que acepta el anfitrión por el retraso de red al validar distancias.
const NET_TOLERANCE := 10.0
## Validación de movimiento en el anfitrión: velocidad máxima x 1,3 y hasta 24 px de más
## por paquetes que llegan juntos. Pasado eso, el jugador vuelve a su última posición válida.
const SPEED_SLACK := 1.3
const BURST_ALLOWANCE := 24.0
const CORRECTION_COOLDOWN := 0.2
const WOUNDED_TINT := Color(1.0, 0.7, 0.7)
const ANIM_FPS := 8.0
const SHEET_PATH := "res://art/sprites/player_%d.png"
## Filas de la hoja de sprites.
const ROW_DOWN := 0
const ROW_UP := 1
const ROW_SIDE := 2

## Rol del cooperativo (índice de Roles.LIST), asignado por el anfitrión al aparecer.
var role := 0
# Valores base multiplicados por el rol. Se calculan en _enter_tree.
var battery_max := BATTERY_MAX
var stamina_max := STAMINA_MAX
var walk_speed := WALK_SPEED
var run_speed := RUN_SPEED
var light_angle := LIGHT_ANGLE
var monster_drain := MONSTER_DRAIN
var battery := BATTERY_MAX
var stamina := STAMINA_MAX
var light_on := true

# Estado decidido por el anfitrión.
var is_down := false:
	set(value):
		if value != is_down:
			is_down = value
			state_changed.emit()
var is_dead := false:
	set(value):
		if value != is_dead:
			is_dead = value
			state_changed.emit()
var escaped := false:
	set(value):
		if value != escaped:
			escaped = value
			state_changed.emit()
## Derribos recibidos. Con 1, el siguiente golpe mata.
var down_count := 0
var down_time := 0.0
var revive_progress := 0.0

var level: Level
## Color del pijama (0 a 3), asignado por orden de llegada.
var color_index := 0
## Punto al que apuntar en lugar del ratón. Lo usan las pruebas automáticas.
var aim_override: Variant = null
## Dirección fija en lugar del teclado. La usan las pruebas automáticas.
var move_override: Variant = null
## Objeto que el jugador local está reparando o reanimando con E mantenida.
var hold_target: Node = null

var _exhausted := false
## Solo en el anfitrión: objetivo que este jugador dice estar trabajando.
var _server_target: Node = null
var _last_worked_frame := -10
var _anim_time := 0.0
var _last_pos := Vector2.ZERO
# Solo en el anfitrión, para jugadores remotos.
var _valid_pos := Vector2.ZERO
var _move_budget := 0.0
var _correction_timer := 0.0
# Valores del fotograma anterior para sonar solo en los cambios.
var _prev_step := 0
var _prev_light := true
var _prev_battery := BATTERY_MAX
var _prev_down := false
var _prev_dead := false

@onready var sprite: Sprite2D = $Sprite
@onready var flashlight: PointLight2D = $Flashlight
@onready var glow: PointLight2D = $Glow
@onready var camera: Camera2D = $Camera
@onready var shape: CollisionShape2D = $Shape


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int() if name.is_valid_int() else 1)
	$ServerSync.set_multiplayer_authority(1)
	_apply_role()


func _apply_role() -> void:
	role = Roles.clamp_id(role)
	battery_max = BATTERY_MAX * Roles.mult(role, "battery")
	stamina_max = STAMINA_MAX * Roles.mult(role, "stamina")
	walk_speed = WALK_SPEED * Roles.mult(role, "walk")
	run_speed = RUN_SPEED * Roles.mult(role, "run")
	light_angle = LIGHT_ANGLE * Roles.mult(role, "angle")
	monster_drain = MONSTER_DRAIN * Roles.mult(role, "monster_drain")
	battery = battery_max
	stamina = stamina_max
	_prev_battery = battery


func _ready() -> void:
	add_to_group("players")
	flashlight.texture = LightTextures.cone(LIGHT_RANGE, light_angle)
	glow.texture = LightTextures.radial(28.0)
	sprite.texture = load(SHEET_PATH % clampi(color_index, 0, 3))
	camera.enabled = is_local()
	_last_pos = global_position
	_valid_pos = global_position


func is_local() -> bool:
	return is_multiplayer_authority()


## Sigue en la partida: no ha muerto ni escapado. Puede estar derribado.
func is_active() -> bool:
	return not is_dead and not escaped


## Puede moverse, alumbrar e interactuar.
func can_act() -> bool:
	return is_active() and not is_down


func is_repairing() -> bool:
	return _server_target is Task


func _physics_process(delta: float) -> void:
	if is_local():
		if can_act():
			_move(delta)
			_aim()
			_drain_battery(delta)
			_check_hold()
		else:
			velocity = Vector2.ZERO
			light_on = false
			_stop_hold()
	if multiplayer.is_server():
		if not is_local():
			_validate_movement(delta)
		_server_tick(delta)
	_update_visuals(delta)


## Solo en el anfitrión: rechaza saltos de posición que no se pueden hacer corriendo.
func _validate_movement(delta: float) -> void:
	_correction_timer = maxf(_correction_timer - delta, 0.0)
	if not is_active() or Net.allow_teleport:
		_valid_pos = global_position
		return
	var max_speed := run_speed if can_act() else 0.0
	_move_budget = minf(_move_budget + max_speed * SPEED_SLACK * delta, max_speed * 0.5 + BURST_ALLOWANCE)
	var moved := global_position.distance_to(_valid_pos)
	if moved <= _move_budget + 0.5:
		_move_budget -= moved
		_valid_pos = global_position
		return
	if _correction_timer == 0.0:
		_correction_timer = CORRECTION_COOLDOWN
		_correct_position.rpc_id(get_multiplayer_authority(), _valid_pos)
	global_position = _valid_pos
	_move_budget = 0.0


@rpc("any_peer", "call_local", "reliable")
func _correct_position(pos: Vector2) -> void:
	if _sender() == 1:
		global_position = pos
		_last_pos = pos


func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or not can_act():
		return
	if event.is_action_pressed("toggle_light") and battery > 0.0:
		light_on = not light_on
	elif event.is_action_pressed("interact"):
		start_interact()
	elif event.is_action_released("interact"):
		_stop_hold()


## True si la linterna ilumina ese punto: dentro del cono, del alcance y sin paredes en medio.
func is_lighting(point: Vector2) -> bool:
	if not can_act() or not flashlight.enabled or flashlight.energy < 0.5:
		return false
	var origin := flashlight.global_position
	var to := point - origin
	if to.length() > LIGHT_RANGE * 0.95:
		return false
	if absf(angle_difference(flashlight.global_rotation, to.angle())) > deg_to_rad(light_angle / 2.0):
		return false
	return LightTextures.has_line_of_sight(get_world_2d(), origin, point)


## Solo en el anfitrión. Primer golpe: derribo. Segundo golpe tras ser reanimado: muerte.
func hit() -> void:
	if not multiplayer.is_server() or not can_act():
		return
	if down_count >= 1:
		is_dead = true
	else:
		down_count = 1
		down_time = BLEED_OUT_TIME
		revive_progress = 0.0
		is_down = true


func needs_work() -> bool:
	return is_down and not is_dead


func work_ratio() -> float:
	return revive_progress / REVIVE_TIME


## Solo en el anfitrión: otro jugador está reanimando a este.
func add_work(delta: float) -> void:
	if not needs_work():
		return
	_last_worked_frame = Engine.get_physics_frames()
	revive_progress += delta
	if revive_progress >= REVIVE_TIME:
		revive_progress = 0.0
		is_down = false


## Busca algo cerca con E: compañero derribado, generador o pila.
func start_interact() -> void:
	var target := _find_hold_target()
	if target != null:
		hold_target = target
		_set_server_target.rpc_id(1, target.get_path())
		return
	for pickup: Node2D in get_tree().get_nodes_in_group("batteries"):
		if global_position.distance_to(pickup.global_position) <= PICKUP_RADIUS:
			_request_pickup.rpc_id(1, pickup.get_path())
			return


func _find_hold_target() -> Node:
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other != self and other.needs_work() \
				and global_position.distance_to(other.global_position) <= REVIVE_RANGE:
			return other
	for task: Task in get_tree().get_nodes_in_group("tasks"):
		if task.needs_work() and global_position.distance_to(task.global_position) <= Task.INTERACT_RANGE:
			return task
	return null


func _check_hold() -> void:
	if hold_target == null:
		return
	if not is_instance_valid(hold_target) or not hold_target.needs_work() \
			or global_position.distance_to(hold_target.global_position) > _range_for(hold_target):
		_stop_hold()


func _stop_hold() -> void:
	if hold_target == null:
		return
	hold_target = null
	_set_server_target.rpc_id(1, NodePath())


func _range_for(target: Node) -> float:
	return REVIVE_RANGE if target is Player else Task.INTERACT_RANGE


@rpc("any_peer", "call_local", "reliable")
func _set_server_target(path: NodePath) -> void:
	if not multiplayer.is_server() or _sender() != get_multiplayer_authority():
		return
	_server_target = get_node_or_null(path) if not path.is_empty() else null


## Multiplicador de velocidad de trabajo del rol: reanimar a jugadores o reparar generadores.
func work_factor(target: Node) -> float:
	return Roles.mult(role, "revive" if target is Player else "repair")


## Distancia que usa el monstruo al elegir presa. El rol corredor parece más cerca por el ruido.
func lure_distance(from: Vector2) -> float:
	return from.distance_to(global_position) * Roles.mult(role, "lure")


func _server_tick(delta: float) -> void:
	if can_act() and level != null and level.door_open and level.is_exit(global_position):
		escaped = true
		return
	if is_down:
		down_time = maxf(down_time - delta, 0.0)
		if down_time == 0.0:
			is_down = false
			is_dead = true
		# La reanimación se pierde si nadie la mantiene.
		if Engine.get_physics_frames() - _last_worked_frame > 2:
			revive_progress = 0.0
	if _server_target != null:
		var valid: bool = is_instance_valid(_server_target) and can_act() and _server_target.needs_work() \
			and global_position.distance_to(_server_target.global_position) <= _range_for(_server_target) + NET_TOLERANCE
		if valid:
			_server_target.add_work(delta * work_factor(_server_target))
		else:
			_server_target = null


func _move(delta: float) -> void:
	var dir: Vector2 = move_override if move_override != null \
		else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if hold_target != null:
		dir = Vector2.ZERO
	if stamina <= 0.0:
		_exhausted = true
	elif stamina >= STAMINA_RECOVER:
		_exhausted = false
	var running := Input.is_action_pressed("sprint") and dir != Vector2.ZERO and not _exhausted
	if running:
		stamina = maxf(stamina - delta, 0.0)
	else:
		stamina = minf(stamina + delta * stamina_max / STAMINA_REGEN_TIME, stamina_max)
	var speed := run_speed if running else walk_speed
	if down_count > 0:
		speed *= WOUNDED_FACTOR
	velocity = dir * speed
	move_and_slide()


func _aim() -> void:
	var target: Vector2 = aim_override if aim_override != null else get_global_mouse_position()
	flashlight.rotation = (target - flashlight.global_position).angle()


func _drain_battery(delta: float) -> void:
	if light_on:
		var monster := get_tree().get_first_node_in_group("monster") as Monster
		var rate := monster_drain if monster != null and monster.is_lit_by(self) else 1.0
		battery = maxf(battery - delta * rate, 0.0)
		if battery == 0.0:
			light_on = false


## Corre en todos los equipos con los valores sincronizados.
func _update_visuals(delta: float) -> void:
	_animate(delta)
	_play_sounds()
	visible = is_active()
	shape.disabled = not is_active()
	glow.enabled = can_act()
	flashlight.enabled = light_on and can_act()
	# Con poca batería la luz parpadea, y en esos instantes el monstruo puede moverse.
	if flashlight.enabled and battery < battery_max * LOW_BATTERY:
		flashlight.energy = 0.15 if randf() < 0.08 else LIGHT_ENERGY
	else:
		flashlight.energy = LIGHT_ENERGY
	sprite.rotation_degrees = 90.0 if is_down else 0.0
	sprite.modulate = WOUNDED_TINT if down_count > 0 else Color.WHITE


## Elige fila según hacia dónde apunta la linterna y avanza el paso si se mueve.
## Usa la posición recibida, así funciona igual para jugadores remotos.
func _animate(delta: float) -> void:
	var moved := global_position.distance_to(_last_pos) > 0.05 and can_act()
	_last_pos = global_position
	_anim_time = _anim_time + delta * ANIM_FPS if moved else 0.0
	var facing := Vector2.from_angle(flashlight.rotation)
	var row := ROW_SIDE
	if absf(facing.x) < 0.6:
		row = ROW_DOWN if facing.y > 0.0 else ROW_UP
	sprite.flip_h = row == ROW_SIDE and facing.x < 0.0
	var step := int(_anim_time) % 4 if moved else 0
	sprite.frame = row * 4 + step
	# Un paso suena cuando el pie toca el suelo (fotogramas 1 y 3).
	if step != _prev_step and step % 2 == 1:
		Sfx.play_at("step", global_position, -10.0)
	_prev_step = step


## Sonidos que se deducen de cambios en valores sincronizados, igual en todos los equipos.
func _play_sounds() -> void:
	if light_on != _prev_light and can_act():
		Sfx.play_at("flashlight", global_position, -6.0)
	if battery > _prev_battery + 10.0:
		Sfx.play_at("battery", global_position, -4.0)
	if is_down and not _prev_down:
		Sfx.play_at("down", global_position)
	elif _prev_down and not is_down and not is_dead:
		Sfx.play_at("revive", global_position, -4.0)
	if is_dead and not _prev_dead:
		Sfx.play_at("death", global_position)
	_prev_light = light_on
	_prev_battery = battery
	_prev_down = is_down
	_prev_dead = is_dead


@rpc("any_peer", "call_local", "reliable")
func _request_pickup(pickup_path: NodePath) -> void:
	if not multiplayer.is_server() or _sender() != get_multiplayer_authority():
		return
	var pickup := get_node_or_null(pickup_path) as BatteryPickup
	if pickup == null or pickup.is_queued_for_deletion():
		return
	if global_position.distance_to(pickup.global_position) > PICKUP_RADIUS + NET_TOLERANCE:
		return
	pickup.take.rpc()
	_grant_battery.rpc_id(get_multiplayer_authority())


@rpc("any_peer", "call_local", "reliable")
func _grant_battery() -> void:
	if _sender() == 1:
		battery = minf(battery + battery_max * BATTERY_PICKUP, battery_max)


## id del emisor del RPC en curso. En llamadas locales sin red devuelve el id propio.
func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()
