extends Node2D
## Monta la partida de prueba: mapa, lámparas, pilas, jugador y monstruo.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MONSTER_SCENE := preload("res://scenes/monster.tscn")

var player: Player
var monster: Monster

@onready var level: Level = $Level
@onready var entities: Node2D = $Entities
@onready var hud: Hud = $HUD/Hud


func _ready() -> void:
	level.build()
	for pos in level.lamp_spawns:
		var lamp := Lamp.new()
		lamp.position = pos
		entities.add_child(lamp)
	for pos in level.battery_spawns:
		var pickup := BatteryPickup.new()
		pickup.position = pos
		entities.add_child(pickup)

	player = PLAYER_SCENE.instantiate()
	player.position = level.player_spawn
	entities.add_child(player)
	player.downed.connect(_on_player_downed)
	_limit_camera(player.camera)

	monster = MONSTER_SCENE.instantiate()
	monster.level = level
	monster.position = level.monster_spawn
	entities.add_child(monster)

	hud.player = player
	if not OS.get_cmdline_user_args().is_empty():
		add_child(DebugRun.new())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _limit_camera(camera: Camera2D) -> void:
	var px := level.pixel_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = px.x
	camera.limit_bottom = px.y


func _on_player_downed() -> void:
	hud.show_message("DERRIBADO\nR para reiniciar")
