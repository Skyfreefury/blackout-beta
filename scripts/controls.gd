extends Node
## Registra los controles al arrancar. Todo queda al alcance de la mano izquierda sobre WASD:
## Q linterna, E interactuar, Espacio correr. Las teclas antiguas (F, Mayús) siguen valiendo.
## Usa teclas físicas para que WASD funcione igual en teclado español o inglés.

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"sprint": [KEY_SPACE, KEY_SHIFT],
	"toggle_light": [KEY_Q, KEY_F],
	"interact": [KEY_E],
	"restart": [KEY_R],
	"toggle_fullscreen": [KEY_F11],
}
## Botones del ratón por acción.
const MOUSE := {
	"toggle_light": [MOUSE_BUTTON_RIGHT],
}
## Texto de ayuda que muestran la pausa y el README.
const HELP := "WASD mover   RATÓN apuntar\nQ o clic derecho linterna\nE coger pila (mantener: tareas y reanimar)\nESPACIO correr   F11 pantalla completa"


func _ready() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		for button: MouseButton in MOUSE.get(action, []):
			var click := InputEventMouseButton.new()
			click.button_index = button
			InputMap.action_add_event(action, click)
