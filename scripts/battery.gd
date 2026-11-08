class_name BatteryPickup
extends Sprite2D
## Pila tirada en el suelo. El jugador la recoge con E.

const TEXTURE := preload("res://art/sprites/battery.png")


func _ready() -> void:
	add_to_group("batteries")
	texture = TEXTURE
