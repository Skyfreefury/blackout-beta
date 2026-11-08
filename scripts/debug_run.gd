class_name DebugRun
extends Node
## Pruebas automáticas y capturas. Solo se activa con argumentos tras "--":
##   --scenario=lit|dark|lamp|spawn  coloca jugador y monstruo
##   --frames=N                      fotogramas antes de medir (120 por defecto)
##   --shot=ruta.png                 guarda una captura ampliada x4
## Ejemplo: godot --path . -- --scenario=lit --shot=C:/tmp/lit.png

var _args := {}
var _monster_start := Vector2.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else ""
	var main := get_parent()
	await get_tree().process_frame
	_setup(main, _args.get("scenario", "spawn"))
	_monster_start = main.monster.global_position
	for i in int(_args.get("frames", "120")):
		await get_tree().physics_frame
	_report(main)
	if _args.has("shot"):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		img.save_png(_args["shot"])
	get_tree().quit()


func _setup(main: Node, scenario: String) -> void:
	var level: Level = main.level
	var player: Player = main.player
	var monster: Monster = main.monster
	match scenario:
		"lit", "dark":
			player.global_position = level.cell_center(Vector2i(20, 5))
			monster.global_position = level.cell_center(Vector2i(27, 5))
			var aim := monster.global_position + Vector2(0, -10)
			player.aim_override = aim if scenario == "lit" else player.global_position + Vector2(-50, 0)
		"chase":
			# Linterna apagada y lejos de la lámpara: el monstruo cruza el mapa.
			player.light_on = false
			player.global_position = level.cell_center(Vector2i(28, 2))
			player.aim_override = player.global_position + Vector2(50, 0)
		"lamp":
			player.light_on = false
			monster.global_position = level.cell_center(Vector2i(4, 6))
			player.aim_override = player.global_position + Vector2(-50, 0)
		_:
			player.aim_override = player.global_position + Vector2(80, 30)
	player.camera.reset_smoothing()


func _report(main: Node) -> void:
	var monster: Monster = main.monster
	print("RESULT scenario=%s frozen=%s moved=%.1f downed=%s battery=%.1f" % [
		_args.get("scenario", "spawn"),
		monster.frozen,
		monster.global_position.distance_to(_monster_start),
		main.player.is_down,
		main.player.battery,
	])
