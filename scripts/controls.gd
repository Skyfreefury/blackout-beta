extends Node
## Registra las acciones de teclado al arrancar.
## Usa teclas físicas para que WASD funcione igual en teclado español o inglés.

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"sprint": [KEY_SHIFT],
	"toggle_light": [KEY_F],
	"interact": [KEY_E],
	"restart": [KEY_R],
}


func _ready() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
