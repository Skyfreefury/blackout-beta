class_name KeyPickup
extends Sprite2D
## Llave del armario de fármacos tirada en el suelo. El jugador la pide con E y el anfitrión
## se la da (Player.has_key) y la retira en todos los equipos. Brilla un poco para verla a oscuras.


func _ready() -> void:
	add_to_group("keys")
	texture = preload("res://art/sprites/key.png")
	var glint := PointLight2D.new()
	glint.texture = LightTextures.radial(10.0)
	glint.color = Color("e8c547")
	glint.energy = 0.45
	add_child(glint)


@rpc("authority", "call_local", "reliable")
func take() -> void:
	remove_from_group("keys")
	queue_free()
