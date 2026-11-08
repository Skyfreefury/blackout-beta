class_name Lamp
extends PointLight2D
## Luz fija del mapa. El monstruo queda congelado dentro de su radio si la ve.

const SPRITE := preload("res://art/sprites/lamp.png")

@export var radius := 56.0


func _ready() -> void:
	add_to_group("lamps")
	texture = LightTextures.radial(radius)
	shadow_enabled = true
	color = Color(1.0, 0.85, 0.6)
	energy = 0.9
	var fixture := Sprite2D.new()
	fixture.texture = SPRITE
	add_child(fixture)


func is_lighting(point: Vector2) -> bool:
	if not enabled:
		return false
	if global_position.distance_to(point) > radius * 0.9:
		return false
	return LightTextures.has_line_of_sight(get_world_2d(), global_position, point)
