class_name Shop
extends RefCounted
## Mejoras que se compran con el botín entregado (Net.bank) en la pantalla final.
## Cada jugador compra las suyas con el banco común. Duran toda la racha de niveles
## y se pierden al empezar otra vez desde el nivel 1.
## Precio: base x (nivel de la mejora + 1). El botiquín se gasta al usarlo.

const ITEMS := {
	"battery": {"name": "Pila +25%", "price": 120, "max": 2,
		"text": "Pila de litio: +25% de batería máxima por compra."},
	"shoes": {"name": "Zapatillas", "price": 150, "max": 2,
		"text": "Zapatillas: +10% de velocidad y +20% de aguante corriendo por compra."},
	"bag": {"name": "Mochila +1", "price": 200, "max": 2,
		"text": "Mochila grande: un hueco más para botín por compra."},
	"medkit": {"name": "Botiquín", "price": 180, "max": 1,
		"text": "Botiquín: al caer te reanimas solo en 6 s. Se gasta al usarlo."},
	"dart": {"name": "Dardo", "price": 160, "max": 2,
		"text": "Dardo tranquilizante: F o clic izquierdo. Duerme al Nonato 5 s. Cada compra es un dardo."},
}
const BATTERY_STEP := 0.25
const SPEED_STEP := 0.10
const STAMINA_STEP := 0.20
## Segundos que tarda el botiquín en levantar al jugador derribado.
const MEDKIT_TIME := 6.0
## Dardo tranquilizante: alcance, ancho del disparo y segundos que duerme el Nonato.
const DART_RANGE := 160.0
const DART_WIDTH := 16.0
const DART_SLEEP := 5.0


static func price(item: String, owned: int) -> int:
	return ITEMS[item].price * (owned + 1)


static func ids() -> Array:
	return ITEMS.keys()
