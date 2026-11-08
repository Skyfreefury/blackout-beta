class_name Hud
extends Control
## Interfaz de partida: barras, objetivo, progreso al mantener E, estado del jugador,
## avisos, pausa y pantalla final.

signal leave_requested

const BATTERY_COLOR := Color("e8c547")
const STAMINA_COLOR := Color("c9d1d3")
const WORK_COLOR := Color("6b7d6a")
const ACCENT := Color("8f3a3a")
const BAR_SIZE := Vector2(42, 4)
const FLASH_TIME := 4.0

var player: Player
var objective := ""
## Nombre del jugador observado tras morir o escapar. Vacío si no se observa a nadie.
var spectating := ""

var _status := Label.new()
var _objective_label := Label.new()
var _flash := Label.new()
var _flash_timer := 0.0
var _pause := PanelContainer.new()
var _end := PanelContainer.new()
var _end_text := Label.new()
var _end_hint := Label.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()

	_objective_label.position = Vector2(6, 4)
	add_child(_objective_label)

	# Estado del jugador centrado en la mitad inferior de la pantalla.
	_status.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status.offset_top = 70
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	_flash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_flash.offset_top = 22
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.add_theme_color_override("font_color", ACCENT)
	add_child(_flash)

	_build_pause()
	_build_end()


func _process(delta: float) -> void:
	_objective_label.text = objective
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	_flash.visible = _flash_timer > 0.0
	_status.text = "" if _end.visible else _status_text()
	queue_redraw()


func flash_message(text: String) -> void:
	_flash.text = text
	_flash_timer = FLASH_TIME


func toggle_pause() -> void:
	_pause.visible = not _pause.visible


func show_end(victory: bool, time: float, survivors: PackedStringArray, is_host: bool) -> void:
	_pause.visible = false
	var minutes := int(time) / 60
	var seconds := int(time) % 60
	var lines := PackedStringArray([
		"HABÉIS ESCAPADO" if victory else "NADIE HA SALIDO",
		"Tiempo %d:%02d" % [minutes, seconds],
	])
	if victory:
		lines.append("Supervivientes: " + ", ".join(survivors))
	_end_text.text = "\n".join(lines)
	_end_text.add_theme_color_override("font_color", STAMINA_COLOR if victory else ACCENT)
	_end_hint.text = "R: otra partida   Esc: menú" if is_host else "Esperando al anfitrión   Esc: menú"
	_end.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _end.visible and event.is_action_pressed("ui_cancel"):
		leave_requested.emit()


func _status_text() -> String:
	if player == null:
		return ""
	if not spectating.is_empty():
		return "Observando a " + spectating
	if player.is_dead:
		return "HAS MUERTO"
	if player.escaped:
		return "HAS ESCAPADO"
	if player.is_down:
		return "DERRIBADO %d s\nUn compañero puede reanimarte con E" % ceili(player.down_time)
	return ""


func _draw() -> void:
	if player == null:
		return
	var bottom := size.y - 6.0
	_bar(Vector2(6, bottom - 12), player.battery / Player.BATTERY_MAX, BATTERY_COLOR)
	_bar(Vector2(6, bottom - 6), player.stamina / Player.STAMINA_MAX, STAMINA_COLOR)
	var target := player.hold_target
	if target != null and is_instance_valid(target):
		var pos := Vector2((size.x - BAR_SIZE.x) / 2.0, size.y / 2.0 + 14)
		_bar(pos, target.work_ratio(), WORK_COLOR)
	elif player.is_down:
		var pos := Vector2((size.x - BAR_SIZE.x) / 2.0, size.y / 2.0 + 14)
		_bar(pos, player.work_ratio(), WORK_COLOR)


func _bar(pos: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, BAR_SIZE), Color(0, 0, 0, 0.7))
	var fill := Vector2((BAR_SIZE.x - 2) * clampf(ratio, 0.0, 1.0), BAR_SIZE.y - 2)
	draw_rect(Rect2(pos + Vector2.ONE, fill), color)


func _build_pause() -> void:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := Label.new()
	note.text = "La partida sigue en marcha"
	box.add_child(note)
	box.add_child(_button("Volver", toggle_pause))
	box.add_child(_button("Abandonar", leave_requested.emit))
	_pause.add_child(box)
	_pause.visible = false
	_place_center(_pause)


func _build_end() -> void:
	var box := VBoxContainer.new()
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.add_theme_font_size_override("font_size", 12)
	box.add_child(_end_text)
	_end_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_hint)
	_end.add_child(box)
	_end.visible = false
	_place_center(_end)


func _place_center(panel: PanelContainer) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(panel)


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(Sfx.play_ui.bind("ui_click", -6.0))
	b.pressed.connect(callback)
	return b


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 8
	for type in ["Label", "Button"]:
		t.set_color("font_color", type, STAMINA_COLOR)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.04, 0.04, 0.06, 0.92), Color("34384a"), 6))
	t.set_stylebox("normal", "Button", _box(Color("1d1f2a")))
	t.set_stylebox("hover", "Button", _box(Color("34384a")))
	t.set_stylebox("pressed", "Button", _box(Color("5a2a2a")))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color("8a93a0")))
	return t


func _box(fill: Color, border := Color(0, 0, 0, 0), margin := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_content_margin_all(margin)
	return s
