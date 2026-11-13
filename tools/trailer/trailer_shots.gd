extends Node
## Planos del tráiler. Lo carga scripts/debug_run.gd con --trailer=nombre.
## Graba con el Movie Maker de Godot, por ejemplo:
##   godot --path . --write-movie builds/trailer/raw/walk.avi --fixed-fps 30 res://scenes/main.tscn -- --trailer=walk --frames=300
## Los planos "future_*" cambian el color del mapa y el sprite del monstruo por los de
## builds/trailer/sprites (tools/trailer/gen_future_monsters.py). Son maquetas: no están en el juego.

const FUTURE := {
	"future_stalker": ["stalker", Color(0.62, 0.86, 0.7)],
	"future_girl": ["girl", Color(1.0, 0.78, 0.6)],
	"future_corpse": ["corpse", Color(0.6, 0.85, 1.0)],
}

var _main: Node
var _shot := ""
var _t := 0.0
var _dummies: Array[Player] = []
var _dummy_aims: Array[float] = []


func setup(main: Node, args: Dictionary) -> void:
	_main = main
	_shot = args.get("trailer", "")
	var level: Level = main.level
	var player: Player = main.player
	var monster: Monster = main.monster
	if args.has("nohud"):
		main.hud.visible = false
	match _shot:
		"walk":
			# Pasillo principal hacia el este, barriendo con la linterna.
			_freeze_monsters()
			player.global_position = level.cell_center(Vector2i(6, 16))
			player.move_override = Vector2.RIGHT
		"approach":
			# A oscuras en el pasillo. El Nonato llega desde el oeste; a los 2,4 s se enciende la luz.
			player.light_on = false
			player.global_position = level.cell_center(Vector2i(40, 16))
			player.aim_override = player.global_position + Vector2(-60, 0)
			monster.global_position = level.cell_center(Vector2i(22, 16))
			get_tree().create_timer(2.4).timeout.connect(func(): player.light_on = true)
		"door":
			# Salida abierta: el jugador cruza urgencias y sale al exterior.
			_freeze_monsters()
			for task: Task in main.tasks:
				task.progress = task.hold_time()
				task.repaired = true
			main.money = main.quota
			await _wait(5)
			player.global_position = level.cell_center(Vector2i(29, 13))
			player.move_override = Vector2.UP
		"scream":
			# Nonato mejorado en el pasillo: al darle la luz chilla y apaga la linterna.
			monster.enhanced = true
			monster.sprite.modulate = Monster.ENHANCED_TINT
			monster.sprite.scale = Vector2.ONE * Monster.ENHANCED_SCALE
			monster._scream_timer = 0.0
			player.global_position = level.cell_center(Vector2i(40, 16))
			monster.global_position = level.cell_center(Vector2i(31, 16))
		"gens":
			# Reparar el generador: al terminar se encienden las luces rojas de la zona.
			_freeze_monsters()
			var gen: Task = main.tasks[0]
			gen.progress = gen.hold_time() - 1.6
			player.global_position = gen.global_position + Vector2(0, 14)
			player.aim_override = gen.global_position
			player.light_on = false
			await _wait(2)
			player.start_interact()
		"coop":
			# Cuatro supervivientes en urgencias, cada uno con su linterna. El Nonato entra.
			for i in 3:
				var id := i + 2
				main.spawner.spawn([id, player.global_position + Vector2(18 * (i + 1) - 30, 10 + 8 * (i % 2)), i + 1])
			await _wait(2)
			for i in 3:
				var dummy: Player = main.entities.get_node(str(i + 2))
				dummy.light_on = true
				_dummies.append(dummy)
				_dummy_aims.append(PI * 0.5 + i * 1.6)
			player.aim_override = player.global_position + Vector2(0, 60)
			monster.global_position = level.cell_center(Vector2i(29, 15))
		"dart":
			# El Nonato se acerca, se le dispara un dardo y se queda dormido.
			Net.bank = 1000
			Net.buy("dart")
			player.global_position = level.cell_center(Vector2i(42, 16))
			monster.global_position = level.cell_center(Vector2i(28, 16))
			player.light_on = false
			player.aim_override = player.global_position + Vector2(-60, 0)
			get_tree().create_timer(1.6).timeout.connect(func():
				player.light_on = true
				player._request_dart(PI))
		_:
			if FUTURE.has(_shot):
				_future(FUTURE[_shot][0], FUTURE[_shot][1])
	player.camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_t += delta
	if _main == null or _main.player == null:
		return
	var player: Player = _main.player
	match _shot:
		"walk", "future_stalker", "future_girl", "future_corpse":
			if player.move_override != null:
				var sweep := sin(_t * 1.3) * 0.45
				player.aim_override = player.global_position + Vector2.from_angle(
						(player.move_override as Vector2).angle() + sweep) * 60.0
		"coop":
			for i in _dummies.size():
				_dummy_aims[i] += delta * (0.6 if i % 2 == 0 else -0.5)
				_dummies[i].flashlight.rotation = _dummy_aims[i]
		"approach", "scream":
			player.aim_override = _main.monster.global_position + Vector2(0, -6)
		"dart":
			if _t > 1.6 and player.light_on:
				player.aim_override = _main.monster.global_position + Vector2(0, -6)


## Maqueta de escenario futuro: mapa teñido, monstruo nuevo y el jugador avanza hacia él.
func _future(sprite_name: String, tint: Color) -> void:
	var level: Level = _main.level
	var player: Player = _main.player
	var monster: Monster = _main.monster
	level.tiles.modulate = tint
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://builds/trailer/sprites/%s.png" % sprite_name))
	monster.sprite.texture = ImageTexture.create_from_image(image)
	monster.sprite.modulate = Color.WHITE
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = level.cell_center(Vector2i(6, 16))
	monster.global_position = level.cell_center(Vector2i(17, 16))
	player.move_override = Vector2.RIGHT
	# A los 2 s se queda quieto apuntando al monstruo.
	get_tree().create_timer(2.0).timeout.connect(func():
		player.move_override = null
		player.aim_override = monster.global_position + Vector2(0, -8))


func _freeze_monsters() -> void:
	for m: Monster in _main.monsters:
		m.process_mode = Node.PROCESS_MODE_DISABLED
		m.global_position = Vector2(-500, -500)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
