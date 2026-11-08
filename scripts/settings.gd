extends Node
## Opciones del jugador guardadas en user://settings.cfg: volumen, pantalla completa, nombre y rol.
## F11 alterna pantalla completa en cualquier pantalla.

const PATH := "user://settings.cfg"

## Volumen general de 0 a 1.
var volume := 0.8
var fullscreen := false
var player_name := "Jugador"
## Último rol elegido en la sala de espera.
var role := 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		volume = clampf(cfg.get_value("audio", "volume", volume), 0.0, 1.0)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		player_name = str(cfg.get_value("player", "name", player_name))
		role = int(cfg.get_value("player", "role", role))
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		fullscreen = not fullscreen
		apply()
		save()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "role", role)
	cfg.save(PATH)
