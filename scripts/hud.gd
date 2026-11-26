class_name Hud
extends Control
## Interfaz de partida: barras, objetivo, progreso al mantener E, estado del jugador,
## avisos, pausa y pantalla final.

signal leave_requested

const BATTERY_COLOR := Color("e8c547")
const STAMINA_COLOR := Color("c9d1d3")
const WORK_COLOR := Color("6b7d6a")
const HEALTH_COLOR := Color("b33a3a")
const STRUGGLE_SIZE := Vector2(70, 6)
const MONSTER_SHEET := preload("res://art/sprites/monster.png")
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
var _end_title := Label.new()
var _end_text := Label.new()
var _end_hint := Label.new()
var _role_label := Label.new()
var _bag := Label.new()
## Animación de muerte en curso: oculta el texto de estado.
var _killing := false


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

	_bag.position = Vector2(6, size.y - 30)
	_bag.add_theme_color_override("font_color", BATTERY_COLOR)
	add_child(_bag)
	_build_pause()
	_build_end()


func _process(delta: float) -> void:
	_objective_label.text = objective
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	_flash.visible = _flash_timer > 0.0
	_status.text = "" if _end.visible or _killing else _status_text()
	_bag.position.y = size.y - 38
	_bag.text = "" if player == null or player.carried_values.is_empty() \
		else "Mochila %d/%d  %d €" % [player.carried_values.size(), player.max_carry, player.carried_total()]
	var darts := 0 if player == null else Net.upgrade_level(player.get_multiplayer_authority(), "dart")
	if darts > 0:
		_bag.text += ("   " if not _bag.text.is_empty() else "") + "Dardos %d" % darts
	queue_redraw()


func flash_message(text: String) -> void:
	_flash.text = text
	_flash_timer = FLASH_TIME


func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	if player != null:
		_role_label.text = "Rol: %s
%s" % [Roles.role_name(player.role), Roles.effects(player.role)]


func show_end(victory: bool, time: float, survivors: PackedStringArray, is_host: bool, level: int) -> void:
	_pause.visible = false
	var minutes := int(time) / 60
	var seconds := int(time) % 60
	_end_title.text = ("NIVEL %d SUPERADO" % level) if victory else "NADIE HA SALIDO"
	_end_title.add_theme_color_override("font_color", STAMINA_COLOR if victory else ACCENT)
	var lines := PackedStringArray(["Tiempo %d:%02d" % [minutes, seconds]])
	if victory:
		lines.append("Supervivientes: " + ", ".join(survivors))
		lines.append("Banco: %d €" % Net.bank)
	_end_text.text = "\n".join(lines)
	var next := "R: ir a la tienda" if victory else ("R: repetir nivel %d" % level)
	_end_hint.text = (next + "   Esc: menú") if is_host else "Esperando al anfitrión   Esc: menú"
	_end.visible = true


## Animación de muerte del jugador local, unos 2,6 s: el Nonato se abalanza sobre él.
func play_kill(color_index: int, monster_tint: Color) -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	layer.add_child(bg)
	var victim_tex := AtlasTexture.new()
	victim_tex.atlas = load(Player.SHEET_PATH % clampi(color_index, 0, 3))
	victim_tex.region = Rect2(0, 0, 16, 24)
	var victim := _big_sprite(victim_tex, 3)
	victim.position = Vector2(size.x * 0.36 - victim.size.x / 2.0, size.y / 2.0 - victim.size.y / 2.0)
	victim.pivot_offset = victim.size / 2.0
	layer.add_child(victim)
	var killer_tex := AtlasTexture.new()
	killer_tex.atlas = MONSTER_SHEET
	killer_tex.region = Rect2(0, 0, 40, 40)
	var killer := _big_sprite(killer_tex, 3)
	killer.modulate = monster_tint
	killer.position = Vector2(size.x + 10, size.y / 2.0 - killer.size.y / 2.0)
	layer.add_child(killer)
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.7, 0.05, 0.05, 0)
	layer.add_child(flash)
	var title := Label.new()
	title.text = "HAS MUERTO"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(size.x, 20)
	title.position = Vector2(0, size.y * 0.78)
	title.modulate.a = 0.0
	layer.add_child(title)
	Music.sting("death")
	_killing = true
	var tween := layer.create_tween()
	tween.tween_property(bg, "color:a", 0.92, 0.25)
	tween.tween_property(killer, "position:x", size.x * 0.52, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Sfx.play_ui("monster_scream")
		Sfx.play_ui("death"))
	tween.tween_property(flash, "color:a", 0.75, 0.05)
	tween.parallel().tween_property(victim, "rotation_degrees", 90.0, 0.15)
	tween.parallel().tween_property(victim, "modulate", Color(1, 0.3, 0.3), 0.15)
	tween.tween_property(flash, "color:a", 0.0, 0.35)
	tween.parallel().tween_property(killer, "position:x", size.x * 0.46, 0.35)
	tween.tween_property(title, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.1)
	tween.tween_property(layer, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		_killing = false
		layer.queue_free())


func _big_sprite(texture: Texture2D, scale_factor: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size = texture.get_size() * scale_factor
	return rect


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
	if player.grabbed:
		return "¡EL NONATO TE HA AGARRADO!\nPulsa E o ESPACIO rápido"
	if player.blind_time > 0.0:
		return "EL NONATO CHILLA\nTu linterna no responde"
	if player.is_down:
		return "DERRIBADO %d s\nUn compañero puede reanimarte con E" % ceili(player.down_time)
	return ""


func _draw() -> void:
	if player == null:
		return
	var bottom := size.y - 6.0
	_bar(Vector2(6, bottom - 18), player.health / Player.HEALTH_MAX, HEALTH_COLOR)
	_bar(Vector2(6, bottom - 12), player.battery / player.battery_max, BATTERY_COLOR)
	_bar(Vector2(6, bottom - 6), player.stamina / player.stamina_max, STAMINA_COLOR)
	if player.grabbed:
		var spos := Vector2((size.x - STRUGGLE_SIZE.x) / 2.0, size.y / 2.0 + 14)
		draw_rect(Rect2(spos, STRUGGLE_SIZE), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(spos + Vector2.ONE, Vector2((STRUGGLE_SIZE.x - 2) * player.struggle, STRUGGLE_SIZE.y - 2)), BATTERY_COLOR)
		return
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
	_role_label.add_theme_color_override("font_color", BATTERY_COLOR)
	box.add_child(_role_label)
	# Los controles completos están en "Cómo jugar": aquí no caben en 180 px de alto.
	var help := Label.new()
	help.text = "Q linterna  E usar  F o clic izq. dardo
ESPACIO correr"
	help.add_theme_color_override("font_color", Color("8a93a0"))
	box.add_child(help)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	buttons.add_child(_button("Volver", toggle_pause))
	var leave := _button("Salir de la partida", leave_requested.emit)
	leave.add_theme_color_override("font_color", Color.WHITE)
	leave.add_theme_color_override("font_hover_color", Color.WHITE)
	leave.add_theme_stylebox_override("normal", _box(Color("8f2a2a"), Color("c04040")))
	leave.add_theme_stylebox_override("hover", _box(Color("b33636"), Color("e05050")))
	leave.add_theme_stylebox_override("pressed", _box(Color("5a1a1a"), Color("c04040")))
	buttons.add_child(leave)
	_pause.add_child(box)
	_pause.visible = false
	_place_center(_pause)


func _build_end() -> void:
	var box := VBoxContainer.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 16)
	box.add_child(_end_title)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	# Sombra de 1 px para leer el texto sobre suelo iluminado.
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.04, 0.04, 0.06, 0.92), Color("34384a"), 6))
	t.set_stylebox("normal", "Button", _box(Color("1d1f2a")))
	t.set_stylebox("hover", "Button", _box(Color("34384a")))
	t.set_stylebox("pressed", "Button", _box(Color("5a2a2a")))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color("8a93a0")))
	t.set_stylebox("disabled", "Button", _box(Color("121319")))
	t.set_color("font_disabled_color", "Button", Color("4a4f5c"))
	return t


func _box(fill: Color, border := Color(0, 0, 0, 0), margin := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_content_margin_all(margin)
	return s
