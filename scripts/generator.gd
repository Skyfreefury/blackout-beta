class_name Generator
extends StaticBody2D
## Generador de zona. Se repara manteniendo E durante 10 s; el progreso no se pierde al soltar.
## El anfitrión suma el progreso y lo sincroniza al resto.

const REPAIR_TIME := 10.0
const INTERACT_RANGE := 22.0
const BROKEN_COLOR := Color(1.0, 0.2, 0.15)
const REPAIRED_COLOR := Color(0.4, 1.0, 0.5)

var zone := 0
var progress := 0.0
var repaired := false

var _motor: AudioStreamPlayer2D
var _prev_progress := 0.0
var _work_timer := 0.0
var _was_repaired := false

@onready var status_light: PointLight2D = $StatusLight


func _ready() -> void:
	add_to_group("generators")
	status_light.texture = LightTextures.radial(10.0)
	_motor = Sfx.make_loop_2d(self, "generator_loop", -4.0)


func _process(delta: float) -> void:
	# El motor suena mientras el progreso sube. El valor llega del anfitrión a saltos,
	# así que se mantiene encendido 0,3 s tras cada subida.
	if progress > _prev_progress:
		_work_timer = 0.3
	_work_timer = maxf(_work_timer - delta, 0.0)
	var working := _work_timer > 0.0 and not repaired
	if working and not _motor.playing:
		_motor.play()
	elif not working and _motor.playing:
		_motor.stop()
	_prev_progress = progress
	if repaired and not _was_repaired:
		Sfx.play_at("generator_on", global_position)
	_was_repaired = repaired
	if repaired:
		status_light.color = REPAIRED_COLOR
		status_light.energy = 0.8
	else:
		# Parpadeo lento para que se encuentre a oscuras.
		status_light.color = BROKEN_COLOR
		status_light.energy = 0.8 if int(Time.get_ticks_msec() / 600) % 2 == 0 else 0.15


func needs_work() -> bool:
	return not repaired


func work_ratio() -> float:
	return progress / REPAIR_TIME


## Solo en el anfitrión.
func add_work(delta: float) -> void:
	if repaired:
		return
	progress = minf(progress + delta, REPAIR_TIME)
	if progress >= REPAIR_TIME:
		repaired = true
