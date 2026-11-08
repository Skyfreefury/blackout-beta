class_name DebugRun
extends Node
## Pruebas automáticas y capturas. Solo se activa con argumentos tras "--".
## Sin red (lanzando res://scenes/main.tscn):
##   --scenario=lit|dark|chase|lamp|spawn   pruebas de luz (usar con --map=res://maps/test.txt)
##   --scenario=repair|door|revive|bleed    bucle de partida en el hospital
##   --nomonster                            congela al monstruo
## En red (lanzando el menú con --host=N o --join=IP):
##   --walk     el jugador local camina a la derecha
##   --pickup   el jugador local va a la pila 0 y la pide al anfitrión
## Comunes:
##   --frames=N     fotogramas antes de medir (120 por defecto)
##   --linger=N     fotogramas extra antes de cerrar (0 por defecto)
##   --shot=ruta    guarda una captura ampliada x4
## Ejemplo: godot --path . res://scenes/main.tscn -- --scenario=repair --nomonster --frames=700

const PLAYER_WAIT_FRAMES := 300

var _args := {}
var _monster_start := Vector2.ZERO
var _player_start := Vector2.ZERO
var _dummy: Player


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
	if _args.has("nomonster"):
		main.monster.process_mode = Node.PROCESS_MODE_DISABLED
	await _setup(main)
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
	# Parar el audio antes de salir evita avisos de recursos sin liberar.
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
	for node in get_tree().root.find_children("*", "AudioStreamPlayer2D", true, false):
		node.stop()
	await get_tree().process_frame
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
		get_tree().create_timer(0.5).timeout.connect(player.start_interact)
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
			# --aim=dx,dy cambia hacia dónde apunta, relativo al jugador.
			var aim := Vector2(80, 30)
			if _args.has("aim"):
				var parts: PackedStringArray = _args["aim"].split(",")
				aim = Vector2(float(parts[0]), float(parts[1]))
			player.aim_override = player.global_position + aim
		"repair":
			var gen: Generator = main.generators[0]
			player.global_position = gen.global_position + Vector2(0, 14)
			player.aim_override = gen.global_position
			await _wait(2)
			player.start_interact()
		"door":
			for gen: Generator in main.generators:
				gen.progress = Generator.REPAIR_TIME
				gen.repaired = true
			await _wait(5)
			player.global_position = level.cell_center(Vector2i(29, 5))
			player.move_override = Vector2.UP
		"revive":
			main.spawner.spawn([2, player.global_position + Vector2(12, 0)])
			await _wait(2)
			_dummy = main.entities.get_node("2")
			_dummy.hit()
			await _wait(2)
			player.start_interact()
		"bleed":
			player.hit()
		"trap":
			# El generador 1 se repara con el monstruo dentro de la luz de una lámpara.
			monster.global_position = level.cell_center(Vector2i(6, 10))
			player.light_on = false
			player.global_position = level.cell_center(Vector2i(29, 16))
			await _wait(2)
			main.generators[0].progress = Generator.REPAIR_TIME
			main.generators[0].repaired = true
		"safe":
			# Jugador sin linterna bajo una lámpara encendida: el monstruo no debe alcanzarle.
			main.generators[0].progress = Generator.REPAIR_TIME
			main.generators[0].repaired = true
			player.light_on = false
			player.global_position = level.cell_center(Vector2i(5, 9))
			monster.global_position = level.cell_center(Vector2i(12, 16))
	player.camera.reset_smoothing()


func _report(main: Node) -> void:
	var monster: Monster = main.monster
	var p: Player = main.player
	var gens := (main.generators as Array).filter(func(g): return g.repaired).size()
	var line := "RESULT id=%d scenario=%s frozen=%s monster_in_light=%s monster_moved=%.1f downed=%s dead=%s escaped=%s downs=%d battery=%.1f walked=%.1f batteries=%d gens=%d door=%s ended=%s players=%d" % [
		multiplayer.get_unique_id(),
		_args.get("scenario", "-"),
		monster.frozen,
		main.level.is_lamp_zone(monster.global_position),
		monster.global_position.distance_to(_monster_start),
		p.is_down, p.is_dead, p.escaped, p.down_count,
		p.battery,
		p.global_position.distance_to(_player_start),
		get_tree().get_nodes_in_group("batteries").size(),
		gens,
		main.level.door_open,
		main._ended,
		get_tree().get_nodes_in_group("players").size(),
	]
	if _dummy != null:
		line += " dummy_down=%s dummy_dead=%s dummy_downs=%d" % [_dummy.is_down, _dummy.is_dead, _dummy.down_count]
		# Segundo golpe tras la reanimación: debe matar.
		_dummy.hit()
		line += " dummy_dead_after_2nd_hit=%s" % _dummy.is_dead
	print(line)
