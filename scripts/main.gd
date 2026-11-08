extends Node2D
## Escena de partida. Todos los equipos montan el mapa, lámparas, pilas, tareas y monstruo
## con los mismos nombres. El anfitrión crea un jugador por conexión cuando todos han cargado,
## abre la salida al completar todas las tareas y decide el final.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MONSTER_SCENE := preload("res://scenes/monster.tscn")
const TASK_SCENE := preload("res://scenes/task.tscn")
const SPAWN_OFFSETS: Array[Vector2] = [Vector2(0, 0), Vector2(14, 0), Vector2(0, 14), Vector2(14, 14)]
## Distancia al monstruo a la que empieza a oírse el latido.
const HEARTBEAT_RANGE := 220.0

## Jugador controlado en este equipo.
var player: Player
var monster: Monster
## Tareas de esta partida. Las primeras son los generadores, ordenados por zona.
var tasks: Array[Task] = []
var elapsed := 0.0

var _started := false
var _ended := false
var _victory := false
var _heartbeat: AudioStreamPlayer

@onready var level: Level = $Level
@onready var entities: Node2D = $Entities
@onready var hud: Hud = $HUD/Hud
@onready var spawner: MultiplayerSpawner = $PlayerSpawner


func _ready() -> void:
	var map_arg := _user_arg("map")
	if not map_arg.is_empty():
		level.map_path = map_arg
	# --seed=N fija el reparto en pruebas lanzadas sin menú.
	var seed_arg := _user_arg("seed")
	level.map_seed = int(seed_arg) if not seed_arg.is_empty() else Net.map_seed
	# Desde el menú: nivel + 1 tareas. Pruebas sin menú: todas las tareas, salvo --level=N.
	var level_arg := _user_arg("level")
	if not level_arg.is_empty():
		Net.game_level = maxi(int(level_arg), 1)
	if not level_arg.is_empty() or not Net.players.is_empty():
		level.task_count = Net.game_level + 1
	level.build()
	_spawn_world()
	Sfx.make_loop(self, "ambient_loop", -8.0).play()
	_heartbeat = Sfx.make_loop(self, "heartbeat_loop")

	# La posición inicial viaja en los datos de aparición: el sincronizador del
	# jugador pertenece a su dueño y no la incluye al crearlo.
	spawner.spawn_function = _create_player
	entities.child_entered_tree.connect(_on_entity_added)
	if multiplayer.is_server():
		Net.all_loaded.connect(_on_all_loaded)
		multiplayer.peer_disconnected.connect(_on_peer_left)
	hud.leave_requested.connect(Net.leave)
	if not OS.get_cmdline_user_args().is_empty():
		add_child(DebugRun.new())
		# Partida de prueba sin menú: --role=N elige el rol del jugador local.
		if Net.players.is_empty() and not _user_arg("role").is_empty():
			Net.player_role = Roles.clamp_id(int(_user_arg("role")))
	Net.report_loaded()


func _spawn_world() -> void:
	var by_zone := {}
	for i in level.task_spawns.size():
		var task: Task = TASK_SCENE.instantiate()
		task.name = "Task%d" % i
		task.position = level.task_spawns[i][0]
		task.kind = level.task_spawns[i][1]
		task.zone = level.task_spawns[i][2]
		entities.add_child(task)
		tasks.append(task)
		if task.zone > 0:
			by_zone[task.zone] = task
	for entry in level.lamp_spawns:
		var lamp := Lamp.new()
		lamp.position = entry[0]
		lamp.generator = by_zone.get(entry[1])
		lamp.level = level
		entities.add_child(lamp)
	for i in level.battery_spawns.size():
		var pickup := BatteryPickup.new()
		pickup.name = "Battery%d" % i
		pickup.position = level.battery_spawns[i]
		entities.add_child(pickup)
	monster = MONSTER_SCENE.instantiate()
	monster.name = "Monster"
	monster.level = level
	monster.position = level.monster_spawn
	entities.add_child(monster)


func _physics_process(delta: float) -> void:
	if not _started or _ended:
		return
	elapsed += delta
	hud.objective = _objective_text()
	_follow_spectated()
	_update_heartbeat()
	if not multiplayer.is_server():
		return
	if not level.door_open and not tasks.is_empty() and tasks.all(func(t): return t.repaired):
		_open_door.rpc()
	_check_end()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and multiplayer.is_server() and (_ended or not Net.is_online()):
		Net.start_game(Net.game_level + 1 if _victory else Net.game_level)
	elif event.is_action_pressed("ui_cancel") and not _ended:
		hud.toggle_pause()


func _on_all_loaded() -> void:
	var synced: Array[Node] = [monster]
	synced.append_array(tasks)
	for node in synced:
		node.get_node("Sync").public_visibility = true
	var ids := Net.players.keys()
	ids.sort()
	for i in ids.size():
		spawner.spawn([ids[i], level.player_spawn + SPAWN_OFFSETS[i % SPAWN_OFFSETS.size()], i % 4, Net.roles.get(ids[i], 0)])
	_mark_started.rpc()


@rpc("authority", "call_local", "reliable")
func _mark_started() -> void:
	_started = true


## Corre en todos los equipos con los datos [id, posición, color, rol] que envía el anfitrión.
func _create_player(data: Array) -> Node:
	var p: Player = PLAYER_SCENE.instantiate()
	p.name = str(data[0])
	p.position = data[1]
	p.color_index = data[2] if data.size() > 2 else 0
	p.role = data[3] if data.size() > 3 else 0
	p.level = level
	return p


func _on_entity_added(node: Node) -> void:
	if node is Player:
		node.ready.connect(_setup_player.bind(node), CONNECT_ONE_SHOT)


func _setup_player(p: Player) -> void:
	var px := level.pixel_size()
	p.camera.limit_left = 0
	p.camera.limit_top = 0
	p.camera.limit_right = px.x
	p.camera.limit_bottom = px.y
	if p.name.to_int() == multiplayer.get_unique_id():
		player = p
		hud.player = p


## Si el jugador local ya no juega, la cámara sigue a otro que siga activo.
func _follow_spectated() -> void:
	if player == null or player.is_active():
		hud.spectating = ""
		return
	var current := get_viewport().get_camera_2d()
	var watched := current.get_parent() as Player if current != null else null
	if watched != null and watched != player and watched.is_active():
		return
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p != player and p.is_active():
			player.camera.enabled = false
			p.camera.enabled = true
			p.camera.make_current()
			hud.spectating = str(Net.players.get(p.name.to_int(), p.name))
			return


## Latido más fuerte y rápido cuanto más cerca está el monstruo de la cámara activa.
func _update_heartbeat() -> void:
	var camera := get_viewport().get_camera_2d()
	var dist := INF if camera == null else camera.global_position.distance_to(monster.global_position)
	if dist >= HEARTBEAT_RANGE:
		if _heartbeat.playing:
			_heartbeat.stop()
		return
	var closeness := 1.0 - dist / HEARTBEAT_RANGE
	_heartbeat.volume_db = lerpf(-24.0, 0.0, closeness)
	_heartbeat.pitch_scale = 1.0 + 0.6 * closeness
	if not _heartbeat.playing:
		_heartbeat.play()


func _objective_text() -> String:
	if tasks.is_empty():
		return ""
	var title := "Nivel %d" % Net.game_level
	if level.door_open:
		return title + "\nEscapa por la salida"
	var pending := tasks.filter(func(t): return not t.repaired)
	var lines := PackedStringArray(["%s   Tareas %d/%d" % [title, tasks.size() - pending.size(), tasks.size()]])
	# Tareas iguales en una línea: "Reparar el generador x2".
	var counts := {}
	for t: Task in pending:
		counts[t.label()] = counts.get(t.label(), 0) + 1
	for label: String in counts:
		lines.append("- " + label + (" x%d" % counts[label] if counts[label] > 1 else ""))
	return "\n".join(lines)


@rpc("authority", "call_local", "reliable")
func _open_door() -> void:
	level.open_door()
	Sfx.play_at("door_open", level.door_position())
	hud.flash_message("La salida está abierta")


func _check_end() -> void:
	var all_players := get_tree().get_nodes_in_group("players")
	if all_players.is_empty():
		return
	var survivors := PackedStringArray()
	for p: Player in all_players:
		if p.is_active():
			return
		if p.escaped:
			survivors.append(str(Net.players.get(p.name.to_int(), p.name)))
	_end_game.rpc(not survivors.is_empty(), elapsed, survivors)


@rpc("authority", "call_local", "reliable")
func _end_game(victory: bool, time: float, survivors: PackedStringArray) -> void:
	_ended = true
	_victory = victory
	hud.show_end(victory, time, survivors, multiplayer.is_server(), Net.game_level)


func _on_peer_left(id: int) -> void:
	var node := entities.get_node_or_null(str(id))
	if node != null:
		node.queue_free()


func _user_arg(key: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.split("=", true, 1)[1]
	return ""
