extends Control
## Menú principal y sala de espera.
## Argumentos de prueba tras "--": --name=X, --host[=N] (empieza al llegar a N jugadores),
## --join=IP, --bind=IP (IP local del anfitrión).

const JOIN_TIMEOUT := 5.0
const TEXT_COLOR := Color("c9d1d3")
const ACCENT := Color("8f3a3a")

var _name_edit := LineEdit.new()
var _ip_edit := LineEdit.new()
var _status := Label.new()
var _main_box := VBoxContainer.new()
var _lobby_box := VBoxContainer.new()
var _lobby_title := Label.new()
var _player_list := Label.new()
var _start_button := Button.new()
var _join_timer := Timer.new()
var _auto_start_at := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	_build_ui()
	Net.players_changed.connect(_refresh_lobby)
	Net.connection_failed.connect(_on_join_failed)
	multiplayer.connected_to_server.connect(_on_connected)
	_status.text = Net.last_error
	Net.last_error = ""
	_show_lobby(false)
	_apply_debug_args()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0b0b10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	center.add_child(root)

	var title := TextureRect.new()
	title.texture = preload("res://art/sprites/logo.png")
	title.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	root.add_child(title)

	root.add_child(_main_box)
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.text = Net.player_name
	_name_edit.max_length = Net.NAME_MAX
	_main_box.add_child(_name_edit)
	_main_box.add_child(_button("Crear partida", _on_host_pressed))
	var join_row := HBoxContainer.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size.x = 90
	join_row.add_child(_ip_edit)
	join_row.add_child(_button("Unirse", _on_join_pressed))
	_main_box.add_child(join_row)
	_main_box.add_child(_button("Salir", get_tree().quit))

	root.add_child(_lobby_box)
	_lobby_box.add_child(_lobby_title)
	_lobby_box.add_child(_player_list)
	_start_button.text = "Empezar"
	_start_button.pressed.connect(Net.start_game)
	_lobby_box.add_child(_start_button)
	_lobby_box.add_child(_button("Salir de la sala", _on_leave_pressed))

	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", ACCENT)
	root.add_child(_status)

	_join_timer.one_shot = true
	_join_timer.timeout.connect(_on_join_failed.bind("Tiempo de espera agotado"))
	add_child(_join_timer)


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(Sfx.play_ui.bind("ui_click", -6.0))
	b.pressed.connect(callback)
	return b


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 8
	for type in ["Label", "Button", "LineEdit"]:
		t.set_color("font_color", type, TEXT_COLOR)
	var normal := _box(Color("1d1f2a"))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", _box(Color("34384a")))
	t.set_stylebox("pressed", "Button", _box(Color("5a2a2a")))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color("8a93a0")))
	t.set_stylebox("normal", "LineEdit", _box(Color("0b0b10"), Color("34384a")))
	t.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), Color("8a93a0")))
	return t


func _box(fill: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_content_margin_all(3)
	return s


func _read_name() -> void:
	var clean := _name_edit.text.strip_edges().left(Net.NAME_MAX)
	Net.player_name = clean if not clean.is_empty() else "Jugador"


func _on_host_pressed() -> void:
	_read_name()
	if Net.host() != OK:
		_status.text = "No se pudo abrir el puerto %d" % Net.PORT
		return
	_status.text = ""
	_show_lobby(true)


func _on_join_pressed() -> void:
	_read_name()
	if Net.join(_ip_edit.text.strip_edges()) != OK:
		_status.text = "Dirección no válida"
		return
	_status.text = "Conectando..."
	_join_timer.start(JOIN_TIMEOUT)


func _on_connected() -> void:
	_join_timer.stop()
	_status.text = ""
	_show_lobby(true)


func _on_join_failed(reason: String) -> void:
	_join_timer.stop()
	Net.close()
	_status.text = reason
	_show_lobby(false)


func _on_leave_pressed() -> void:
	Net.close()
	_show_lobby(false)


func _show_lobby(in_lobby: bool) -> void:
	_main_box.visible = not in_lobby
	_lobby_box.visible = in_lobby
	_refresh_lobby()


func _refresh_lobby() -> void:
	var ids := Net.players.keys()
	ids.sort()
	_lobby_title.text = "Sala (%d/%d)" % [ids.size(), Net.MAX_PLAYERS]
	var lines := PackedStringArray()
	for id: int in ids:
		lines.append(("* " if id == 1 else "- ") + str(Net.players[id]))
	_player_list.text = "\n".join(lines) if not lines.is_empty() else "Esperando..."
	var is_host := multiplayer.is_server() and Net.is_online()
	_start_button.visible = is_host
	if _lobby_box.visible and not is_host:
		_status.text = "Esperando al anfitrión"
	if is_host and _auto_start_at > 0 and ids.size() >= _auto_start_at:
		Net.start_game()


func _apply_debug_args() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	# Una prueba automática que vuelve al menú ha terminado: se cierra en vez de quedarse esperando.
	if not args.is_empty() and not _status.text.is_empty():
		print("RESULT vuelta_al_menu motivo=%s" % _status.text)
		get_tree().quit()
		return
	if args.has("menushot"):
		await get_tree().create_timer(0.3).timeout
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		img.save_png(args["menushot"])
		get_tree().quit()
		return
	if args.has("name"):
		_name_edit.text = args["name"]
	if args.has("bind"):
		Net.bind_ip = args["bind"]
	if args.has("host"):
		_auto_start_at = maxi(int(args["host"]), 1)
		_on_host_pressed()
	elif args.has("join"):
		_ip_edit.text = args["join"]
		_on_join_pressed()
