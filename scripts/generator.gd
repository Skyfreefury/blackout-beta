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

@onready var status_light: PointLight2D = $StatusLight


func _ready() -> void:
	add_to_group("generators")
	status_light.texture = LightTextures.radial(10.0)


func _process(_delta: float) -> void:
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
