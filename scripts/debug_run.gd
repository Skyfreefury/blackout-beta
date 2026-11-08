class_name DebugRun
extends Node
## Pruebas automáticas y capturas. Solo se activa con argumentos tras "--".
## Sin red (lanzando res://scenes/main.tscn):
##   --scenario=lit|dark|chase|lamp|spawn  coloca jugador y monstruo
## En red (lanzando el menú con --host=N o --join=IP):
##   --walk     el jugador local camina a la derecha
##   --pickup   el jugador local va a la pila 0 y la pide al anfitrión
## Comunes:
##   --frames=N     fotogramas antes de medir (120 por defecto)
##   --linger=N     fotogramas extra antes de cerrar (0 por defecto)
##   --shot=ruta    guarda una captura ampliada x4
## Ejemplo: godot --path . res://scenes/main.tscn -- --scenario=lit --shot=C:/tmp/lit.png

const PLAYER_WAIT_FRAMES := 300

var _args := {}
var _monster_start := Vector2.ZERO
var _player_start := Vector2.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else ""
	var main := get_parent()
	# En red el jugador local llega del anfitrión unos fotogramas después.
	for i in PLAYER_WAIT_FRAMES:
		if main.player != null:
			break
		await get_tree().physics_frame
	if main.player == null:
		print("RESULT error=sin_jugador_local id=%d" % multiplayer.get_unique_id())
		get_tree().quit(1)
		return
	_setup(main)
	_monster_start = main.monster.global_position
	_player_start = main.player.global_position
	await _wait(int(_args.get("frames", "120")))
	_report(main)
	if _args.has("shot"):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		img.save_png(_args["shot"])
	await _wait(int(_args.get("linger", "0")))
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _setup(main: Node) -> void:
	var level: Level = main.level
	var player: Player = main.player
	var monster: Monster = main.monster
	if _args.has("walk"):
		player.move_override = Vector2.RIGHT
		player.aim_override = player.global_position + Vector2(200, 0)
	if _args.has("pickup"):
		player.battery = 10.0
		player.global_position = level.battery_spawns[0]
		player.aim_override = player.global_position + Vector2(50, 0)
		# Espera a que el anfitrión reciba la nueva posición antes de pedir la pila.
		get_tree().create_timer(0.5).timeout.connect(player._try_pickup)
	match _args.get("scenario", ""):
		"lit", "dark":
			player.global_position = level.cell_center(Vector2i(20, 5))
			monster.global_position = level.cell_center(Vector2i(27, 5))
			var aim := monster.global_position + Vector2(0, -10)
			player.aim_override = aim if _args["scenario"] == "lit" else player.global_position + Vector2(-50, 0)
		"chase":
			# Linterna apagada y lejos de las lámparas: el monstruo cruza el mapa.
			player.light_on = false
			player.global_position = level.cell_center(Vector2i(28, 2))
			player.aim_override = player.global_position + Vector2(50, 0)
		"lamp":
			player.light_on = false
			monster.global_position = level.cell_center(Vector2i(4, 6))
			player.aim_override = player.global_position + Vector2(-50, 0)
		"spawn":
			player.aim_override = player.global_position + Vector2(80, 30)
	player.camera.reset_smoothing()


func _report(main: Node) -> void:
	var monster: Monster = main.monster
	var others := PackedStringArray()
	for p: Player in get_tree().get_nodes_in_group("players"):
		others.append("%s@(%d,%d)" % [p.name, p.global_position.x, p.global_position.y])
	print("RESULT id=%d scenario=%s frozen=%s monster_moved=%.1f monster=(%d,%d) downed=%s battery=%.1f walked=%.1f batteries_left=%d players=[%s]" % [
		multiplayer.get_unique_id(),
		_args.get("scenario", "-"),
		monster.frozen,
		monster.global_position.distance_to(_monster_start),
		monster.global_position.x, monster.global_position.y,
		main.player.is_down,
		main.player.battery,
		main.player.global_position.distance_to(_player_start),
		get_tree().get_nodes_in_group("batteries").size(),
		", ".join(others),
	])
