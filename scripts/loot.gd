class_name Loot
extends Sprite2D
## Objeto de valor tirado en el suelo. El jugador lo pide con E y el anfitrión lo mete
## en su mochila y lo retira en todos los equipos. Se entrega en el carro para cubrir la cuota.

## Tipos: nombre, sprite, valor mínimo y máximo, y probabilidad de aparecer (suman 100).
const KINDS := [
	{"name": "Muestras", "sprite": "res://art/sprites/loot_samples.png", "min": 20, "max": 40, "weight": 40},
	{"name": "Instrumental", "sprite": "res://art/sprites/loot_tools.png", "min": 40, "max": 70, "weight": 30},
	{"name": "Reloj de oro", "sprite": "res://art/sprites/loot_watch.png", "min": 80, "max": 120, "weight": 20},
	{"name": "Microscopio", "sprite": "res://art/sprites/loot_microscope.png", "min": 120, "max": 180, "weight": 10},
]

var kind := 0
var value := 0


func _ready() -> void:
	add_to_group("loot")
	texture = load(KINDS[kind]["sprite"])


## Tipo y valor al azar con el generador de la partida, igual en todos los equipos.
static func roll(rng: RandomNumberGenerator) -> Array:
	var r := rng.randi_range(0, 99)
	for i in KINDS.size():
		r -= KINDS[i]["weight"]
		if r < 0:
			return [i, rng.randi_range(KINDS[i]["min"], KINDS[i]["max"])]
	return [0, KINDS[0]["min"]]


@rpc("authority", "call_local", "reliable")
func take() -> void:
	remove_from_group("loot")
	queue_free()
