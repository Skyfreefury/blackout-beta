extends Node2D
## Escena de partida. Todos los equipos montan el mapa, lámparas, pilas y monstruo
## con los mismos nombres. El anfitrión crea un jugador por conexión cuando todos han cargado.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MONSTER_SCENE := preload("res://scenes/monster.tscn")
const SPAWN_OFFSETS: Array[Vector2] = [Vector2(0, 0), Vector2(14, 0), Vector2(0, 14), Vector2(14, 14)]

## Jugador controlado en este equipo.
var player: Player
var monster: Monster

@onready var level: Level = $Level
@onready var entities: Node2D = $Entities
@onready var hud: Hud = $HUD/Hud
@onready var spawner: MultiplayerSpawner = $PlayerSpawner


func _ready() -> void:
	level.build()
	for pos in level.lamp_spawns:
		var lamp := Lamp.new()
		lamp.position = pos
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

	# La posición inicial viaja en los datos de aparición: el sincronizador del
	# jugador pertenece a su dueño y no la incluye al crearlo.
	spawner.spawn_function = _create_player
	entities.child_entered_tree.connect(_on_entity_added)
	if multiplayer.is_server():
		Net.all_loaded.connect(_on_all_loaded)
		multiplayer.peer_disconnected.connect(_on_peer_left)
	if not OS.get_cmdline_user_args().is_empty():
		add_child(DebugRun.new())
	Net.report_loaded()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and multiplayer.is_server():
		Net.start_game()
	elif event.is_action_pressed("ui_cancel"):
		Net.leave()


func _on_all_loaded() -> void:
	monster.get_node("Sync").public_visibility = true
	var ids := Net.players.keys()
	ids.sort()
	for i in ids.size():
		spawner.spawn([ids[i], level.player_spawn + SPAWN_OFFSETS[i % SPAWN_OFFSETS.size()]])


## Corre en todos los equipos con los datos [id, posición] que envía el anfitrión.
func _create_player(data: Array) -> Node:
	var p: Player = PLAYER_SCENE.instantiate()
	p.name = str(data[0])
	p.position = data[1]
	return p


func _on_entity_added(node: Node) -> void:
	if node is Player and node.name.to_int() == multiplayer.get_unique_id():
		node.ready.connect(_setup_local_player.bind(node), CONNECT_ONE_SHOT)


func _setup_local_player(p: Player) -> void:
	player = p
	hud.player = p
	p.downed.connect(_on_player_downed)
	var px := level.pixel_size()
	p.camera.limit_left = 0
	p.camera.limit_top = 0
	p.camera.limit_right = px.x
	p.camera.limit_bottom = px.y


func _on_peer_left(id: int) -> void:
	var node := entities.get_node_or_null(str(id))
	if node != null:
		node.queue_free()


func _on_player_downed() -> void:
	var restart := "R para reiniciar" if multiplayer.is_server() else "Espera al anfitrión"
	hud.show_message("DERRIBADO\n" + restart)
