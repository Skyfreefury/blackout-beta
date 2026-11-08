class_name Lamp
extends PointLight2D
## Luz fija del mapa. Su luz es una zona prohibida para el monstruo (ver Level.set_lamp_zone).
## Las lámparas de zona son luces de emergencia rojas que se encienden al reparar su generador.

const SPRITE := preload("res://art/sprites/lamp.png")
const NORMAL_COLOR := Color(1.0, 0.85, 0.6)
const EMERGENCY_COLOR := Color(1.0, 0.3, 0.25)

## Radio de la luz blanca fija. Las de emergencia usan uno menor para no cerrar pasos.
@export var radius := 56.0
const EMERGENCY_RADIUS := 40.0
## Generador que la enciende. Null: siempre encendida.
var generator: Task
var level: Level

var _registered := false


func _ready() -> void:
	add_to_group("lamps")
	if generator != null:
		radius = EMERGENCY_RADIUS
	texture = LightTextures.radial(radius)
	shadow_enabled = true
	color = NORMAL_COLOR if generator == null else EMERGENCY_COLOR
	energy = 0.9
	var fixture := Sprite2D.new()
	fixture.texture = SPRITE
	add_child(fixture)


func _process(_delta: float) -> void:
	enabled = generator == null or generator.repaired
	if level != null and enabled != _registered:
		_registered = enabled
		level.set_lamp_zone(get_instance_id(), global_position, radius * 0.9, enabled)
