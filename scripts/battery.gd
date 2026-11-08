class_name BatteryPickup
extends Sprite2D
## Pila tirada en el suelo. El jugador la pide con E y el anfitrión la retira en todos los equipos.

const TEXTURE := preload("res://art/sprites/battery.png")


func _ready() -> void:
	add_to_group("batteries")
	texture = TEXTURE


@rpc("authority", "call_local", "reliable")
func take() -> void:
	remove_from_group("batteries")
	queue_free()
