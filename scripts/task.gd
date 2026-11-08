class_name Task
extends StaticBody2D
## Tarea del mapa: se completa manteniendo E. El progreso no se pierde al soltar.
## El anfitrión suma el progreso y lo sincroniza al resto.
## Los generadores además encienden las lámparas de su zona.

const INTERACT_RANGE := 22.0
const PENDING_COLOR := Color(1.0, 0.2, 0.15)
const DONE_COLOR := Color(0.4, 1.0, 0.5)

## Tipos de tarea: símbolo del mapa -> datos. Los generadores usan los dígitos 1 a 3.
const KINDS := {
	"generator": {"label": "Reparar el generador", "time": 10.0, "sprite": "res://art/sprites/generator.png"},
	"archive": {"label": "Recoger los historiales", "time": 6.0, "sprite": "res://art/sprites/task_archive.png"},
	"computer": {"label": "Reiniciar el ordenador", "time": 8.0, "sprite": "res://art/sprites/task_computer.png"},
	"valve": {"label": "Cerrar la válvula de vapor", "time": 5.0, "sprite": "res://art/sprites/task_valve.png"},
}
## Símbolo del mapa de cada tipo que no es generador.
const SYMBOLS := {"a": "archive", "o": "computer", "v": "valve"}

var kind := "generator"
## Zona de lámparas que enciende. 0 si no es un generador.
var zone := 0
var progress := 0.0
var repaired := false

var _motor: AudioStreamPlayer2D
var _prev_progress := 0.0
var _work_timer := 0.0
var _was_repaired := false

@onready var status_light: PointLight2D = $StatusLight


func _ready() -> void:
	add_to_group("tasks")
	$Sprite.texture = load(KINDS[kind]["sprite"])
	status_light.texture = LightTextures.radial(10.0)
	if kind == "generator":
		_motor = Sfx.make_loop_2d(self, "generator_loop", -4.0)


func hold_time() -> float:
	return KINDS[kind]["time"]


func label() -> String:
	return KINDS[kind]["label"]


func _process(delta: float) -> void:
	# El motor suena mientras el progreso sube. El valor llega del anfitrión a saltos,
	# así que se mantiene encendido 0,3 s tras cada subida.
	if progress > _prev_progress:
		_work_timer = 0.3
	_work_timer = maxf(_work_timer - delta, 0.0)
	var working := _work_timer > 0.0 and not repaired
	if _motor != null:
		if working and not _motor.playing:
			_motor.play()
		elif not working and _motor.playing:
			_motor.stop()
	_prev_progress = progress
	if repaired and not _was_repaired:
		Sfx.play_at("generator_on", global_position, 0.0 if kind == "generator" else -8.0)
	_was_repaired = repaired
	if repaired:
		status_light.color = DONE_COLOR
		status_light.energy = 0.8
	else:
		# Parpadeo lento para que se encuentre a oscuras.
		status_light.color = PENDING_COLOR
		status_light.energy = 0.8 if int(Time.get_ticks_msec() / 600) % 2 == 0 else 0.15


func needs_work() -> bool:
	return not repaired


func work_ratio() -> float:
	return progress / hold_time()


## Solo en el anfitrión.
func add_work(delta: float) -> void:
	if repaired:
		return
	progress = minf(progress + delta, hold_time())
	if progress >= hold_time():
		repaired = true
