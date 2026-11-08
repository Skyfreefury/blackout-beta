class_name Lamp
extends PointLight2D
## Luz fija del mapa. El monstruo queda congelado dentro de su radio si la ve.
## Las lámparas de zona son luces de emergencia rojas que se encienden al reparar su generador.

const SPRITE := preload("res://art/sprites/lamp.png")
const NORMAL_COLOR := Color(1.0, 0.85, 0.6)
const EMERGENCY_COLOR := Color(1.0, 0.3, 0.25)

@export var radius := 56.0
## Generador que la enciende. Null: siempre encendida.
var generator: Generator


func _ready() -> void:
	add_to_group("lamps")
	texture = LightTextures.radial(radius)
	shadow_enabled = true
	color = NORMAL_COLOR if generator == null else EMERGENCY_COLOR
	energy = 0.9
	var fixture := Sprite2D.new()
	fixture.texture = SPRITE
	add_child(fixture)


func _process(_delta: float) -> void:
	enabled = generator == null or generator.repaired


func is_lighting(point: Vector2) -> bool:
	if not enabled:
		return false
	if global_position.distance_to(point) > radius * 0.9:
		return false
	return LightTextures.has_line_of_sight(get_world_2d(), global_position, point)
