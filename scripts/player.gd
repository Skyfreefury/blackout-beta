class_name Player
extends CharacterBody2D
## Jugador: movimiento, carrera con resistencia, linterna con batería y pilas.
## El nodo se llama con el id de red de su dueño. El dueño mueve y apunta;
## el anfitrión decide derribos y entrega de pilas.

signal downed

const WALK_SPEED := 60.0
const RUN_SPEED := 100.0
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
const PICKUP_RADIUS := 14.0
## Margen extra que acepta el anfitrión por el retraso de red al validar una pila.
const PICKUP_TOLERANCE := 10.0

var battery := BATTERY_MAX
var stamina := STAMINA_MAX
var light_on := true
var is_down := false
## Punto al que apuntar en lugar del ratón. Lo usan las pruebas automáticas.
var aim_override: Variant = null
## Dirección fija en lugar del teclado. La usan las pruebas automáticas.
var move_override: Variant = null

var _exhausted := false

@onready var sprite: Sprite2D = $Sprite
@onready var flashlight: PointLight2D = $Flashlight
@onready var glow: PointLight2D = $Glow
@onready var camera: Camera2D = $Camera


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int() if name.is_valid_int() else 1)


func _ready() -> void:
	add_to_group("players")
	flashlight.texture = LightTextures.cone(LIGHT_RANGE, LIGHT_ANGLE)
	glow.texture = LightTextures.radial(28.0)
	camera.enabled = is_local()


func is_local() -> bool:
	return is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if is_local() and not is_down:
		_move(delta)
		_aim()
		_drain_battery(delta)
	_update_light()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or is_down:
		return
	if event.is_action_pressed("toggle_light") and battery > 0.0:
		light_on = not light_on
	elif event.is_action_pressed("interact"):
		_try_pickup()


## True si la linterna ilumina ese punto: dentro del cono, del alcance y sin paredes en medio.
func is_lighting(point: Vector2) -> bool:
	if is_down or not flashlight.enabled or flashlight.energy < 0.5:
		return false
	var origin := flashlight.global_position
	var to := point - origin
	if to.length() > LIGHT_RANGE * 0.95:
		return false
	if absf(angle_difference(flashlight.global_rotation, to.angle())) > deg_to_rad(LIGHT_ANGLE / 2.0):
		return false
	return LightTextures.has_line_of_sight(get_world_2d(), origin, point)


## Solo en el anfitrión. Derriba al jugador en todos los equipos.
func hit() -> void:
	if multiplayer.is_server() and not is_down:
		_set_down.rpc()


@rpc("any_peer", "call_local", "reliable")
func _set_down() -> void:
	if not _from_server():
		return
	is_down = true
	light_on = false
	sprite.rotation_degrees = 90.0
	downed.emit()


func _move(delta: float) -> void:
	var dir: Vector2 = move_override if move_override != null \
		else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if stamina <= 0.0:
		_exhausted = true
	elif stamina >= STAMINA_RECOVER:
		_exhausted = false
	var running := Input.is_action_pressed("sprint") and dir != Vector2.ZERO and not _exhausted
	if running:
		stamina = maxf(stamina - delta, 0.0)
	else:
		stamina = minf(stamina + delta * STAMINA_MAX / STAMINA_REGEN_TIME, STAMINA_MAX)
	velocity = dir * (RUN_SPEED if running else WALK_SPEED)
	move_and_slide()


func _aim() -> void:
	var target: Vector2 = aim_override if aim_override != null else get_global_mouse_position()
	flashlight.rotation = (target - flashlight.global_position).angle()
	sprite.flip_h = target.x < global_position.x


func _drain_battery(delta: float) -> void:
	if light_on:
		battery = maxf(battery - delta, 0.0)
		if battery == 0.0:
			light_on = false


## Corre en todos los equipos con los valores sincronizados.
func _update_light() -> void:
	flashlight.enabled = light_on and not is_down
	# Con poca batería la luz parpadea, y en esos instantes el monstruo puede moverse.
	if flashlight.enabled and battery < BATTERY_MAX * LOW_BATTERY:
		flashlight.energy = 0.15 if randf() < 0.08 else LIGHT_ENERGY
	else:
		flashlight.energy = LIGHT_ENERGY


func _try_pickup() -> void:
	for pickup: Node2D in get_tree().get_nodes_in_group("batteries"):
		if global_position.distance_to(pickup.global_position) <= PICKUP_RADIUS:
			_request_pickup.rpc_id(1, pickup.get_path())
			return


@rpc("any_peer", "call_local", "reliable")
func _request_pickup(pickup_path: NodePath) -> void:
	if not multiplayer.is_server() or _sender() != get_multiplayer_authority():
		return
	var pickup := get_node_or_null(pickup_path) as BatteryPickup
	if pickup == null or pickup.is_queued_for_deletion():
		return
	if global_position.distance_to(pickup.global_position) > PICKUP_RADIUS + PICKUP_TOLERANCE:
		return
	pickup.take.rpc()
	_grant_battery.rpc_id(get_multiplayer_authority())


@rpc("any_peer", "call_local", "reliable")
func _grant_battery() -> void:
	if _from_server():
		battery = minf(battery + BATTERY_MAX * BATTERY_PICKUP, BATTERY_MAX)


## id del emisor del RPC en curso. En llamadas locales sin red devuelve el id propio.
func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


func _from_server() -> bool:
	return _sender() == 1
