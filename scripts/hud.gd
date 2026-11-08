class_name Hud
extends Control
## Barras de batería y resistencia, y mensajes centrados.

const BATTERY_COLOR := Color("e8c547")
const STAMINA_COLOR := Color("c9d1d3")
const BAR_SIZE := Vector2(42, 4)

var player: Player

var _message := Label.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 12)
	_message.add_theme_color_override("font_color", STAMINA_COLOR)
	add_child(_message)


func _process(_delta: float) -> void:
	queue_redraw()


func show_message(text: String) -> void:
	_message.text = text


func _draw() -> void:
	if player == null:
		return
	var bottom := size.y - 6.0
	_bar(Vector2(6, bottom - 12), player.battery / Player.BATTERY_MAX, BATTERY_COLOR)
	_bar(Vector2(6, bottom - 6), player.stamina / Player.STAMINA_MAX, STAMINA_COLOR)


func _bar(pos: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, BAR_SIZE), Color(0, 0, 0, 0.7))
	var fill := Vector2((BAR_SIZE.x - 2) * clampf(ratio, 0.0, 1.0), BAR_SIZE.y - 2)
	draw_rect(Rect2(pos + Vector2.ONE, fill), color)
