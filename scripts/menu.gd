extends Control
## Menú principal y sala de espera.
## Argumentos de prueba tras "--": --name=X, --host[=N] (empieza al llegar a N jugadores),
## --join=IP, --bind=IP (IP local del anfitrión), --role=N (índice de Roles.LIST).

const JOIN_TIMEOUT := 5.0
const TEXT_COLOR := Color("c9d1d3")
const ACCENT := Color("8f3a3a")
## Instrucciones: texto ["t", texto] o fila con dibujo ["i", sprite, texto, región, tinte].
## La región recorta un fotograma de una hoja de sprites. Rect2() usa la imagen entera.
const HELP := [
	["t", "CÓMO JUGAR\nBeta en desarrollo: puede haber fallos y cambios."],
	["t", "OBJETIVO\nEscapad del hospital por la salida de urgencias. Se abre al cumplir dos cosas:\n1. Hacer todas las tareas del nivel (lista arriba a la izquierda).\n2. Entregar botín en el carro hasta cubrir la cuota."],
	["t", "TAREAS\nMantén E junto a ellas. El progreso no se pierde al soltar."],
	["i", "res://art/sprites/generator.png", "Generador, 10 s. Enciende las luces de emergencia de su zona: el Nonato no entra en ellas."],
	["i", "res://art/sprites/task_archive.png", "Archivador, 6 s. Recoger los historiales."],
	["i", "res://art/sprites/task_computer.png", "Ordenador, 8 s. Reiniciarlo."],
	["i", "res://art/sprites/task_valve.png", "Válvula, 5 s. Cerrar el vapor."],
	["t", "BOTÍN\nE coge objetos. La mochila lleva 3 y cada uno te frena un 8%. Si caes, la mochila queda en el suelo."],
	["i", "res://art/sprites/loot_samples.png", "Muestras, de 20 a 40 €."],
	["i", "res://art/sprites/loot_tools.png", "Instrumental, de 40 a 70 €."],
	["i", "res://art/sprites/loot_watch.png", "Reloj de oro, de 80 a 120 €."],
	["i", "res://art/sprites/loot_microscope.png", "Microscopio, de 120 a 180 €."],
	["i", "res://art/sprites/cart.png", "Carro de entrega, en urgencias junto a la salida. E entrega toda la mochila."],
	["t", "EL NONATO\nCaza a oscuras. Tu linterna lo aturde y le hace buscar otro camino. Prefiere a quien no le apunta y a quien hace tareas.\nPrimer golpe: derribado. Un compañero te reanima manteniendo E. Segundo golpe, o 30 s sin ayuda: mueres."],
	["i", "res://art/sprites/monster.png", "Nonato normal.", Rect2(0, 0, 40, 40)],
	["i", "res://art/sprites/monster.png", "Nonato mejorado, más rojo y grande. Corre más y chilla para apagar linternas. Sale con 2 y 4 jugadores; con 3 y 4 hay dos Nonatos.", Rect2(0, 0, 40, 40), Color(1.0, 0.7, 0.7)],
	["t", "LINTERNA\nQ o clic derecho. Gasta pila, más aún si alumbras al Nonato. Con poca pila parpadea."],
	["i", "res://art/sprites/battery.png", "Pila. E la coge y recarga la mitad de la linterna."],
	["t", "ROLES\nEn la sala de espera: enfermero/a, corredor/a, técnico/a y vigía. Cada uno tiene una ventaja y una desventaja."],
	["t", "NIVELES\nCada partida genera un hospital nuevo. Cada nivel suma una tarea y 100 € de cuota. Desde el nivel 2 el hospital es mayor y desde el 3 hay un Nonato más (otro cada 2 niveles). Ganar pasa al siguiente."],
	["t", "TIENDA\nAl acabar un nivel, el botín entregado va al banco común. Cada jugador compra sus mejoras con ese banco. Duran mientras ganéis niveles y se pierden al empezar desde el nivel 1.\nPila +25%: más batería. Zapatillas: +10% de velocidad y +20% de aguante. Mochila +1: un hueco más. Botiquín: al caer te levantas solo en 6 s, un uso."],
	["t", "CONTROLES\nWASD mover, ratón apuntar, ESPACIO correr, Q linterna, E usar, ESC pausa, F11 pantalla completa."],
]
## Ancho de la columna de dibujos en las instrucciones.
const HELP_ICON_WIDTH := 44

var _name_edit := LineEdit.new()
var _ip_edit := LineEdit.new()
var _status := Label.new()
var _main_box := VBoxContainer.new()
var _lobby_box := VBoxContainer.new()
var _lobby_title := Label.new()
var _player_list := Label.new()
var _start_button := Button.new()
var _role_button := Button.new()
var _role_info := Label.new()
var _join_timer := Timer.new()
var _auto_start_at := 0
var _options_box := VBoxContainer.new()
var _help_panel := PanelContainer.new()
var _volume_slider := HSlider.new()
var _volume_label := Label.new()
var _fullscreen_check := CheckBox.new()


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
	_name_edit.text = Settings.player_name
	_name_edit.max_length = Net.NAME_MAX
	_main_box.add_child(_name_edit)
	_main_box.add_child(_button("Crear partida", _on_host_pressed))
	var join_row := HBoxContainer.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size.x = 90
	join_row.add_child(_ip_edit)
	join_row.add_child(_button("Unirse", _on_join_pressed))
	_main_box.add_child(join_row)
	_main_box.add_child(_button("Cómo jugar", _show_help.bind(true)))
	_main_box.add_child(_button("Opciones", _show_options.bind(true)))
	_main_box.add_child(_button("Salir", get_tree().quit))

	root.add_child(_options_box)
	_options_box.add_child(_volume_label)
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.step = 5
	_volume_slider.custom_minimum_size.x = 120
	_volume_slider.value = Settings.volume * 100
	_volume_slider.value_changed.connect(_on_volume_changed)
	_options_box.add_child(_volume_slider)
	_fullscreen_check.text = "Pantalla completa (F11)"
	_fullscreen_check.button_pressed = Settings.fullscreen
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_options_box.add_child(_fullscreen_check)
	_options_box.add_child(_button("Volver", _show_options.bind(false)))
	_options_box.visible = false
	_update_volume_label()

	root.add_child(_lobby_box)
	_lobby_box.add_child(_lobby_title)
	_lobby_box.add_child(_player_list)
	_role_button.pressed.connect(Sfx.play_ui.bind("ui_click", -6.0))
	_role_button.pressed.connect(_on_role_pressed)
	_lobby_box.add_child(_role_button)
	_role_info.add_theme_color_override("font_color", Color("8a93a0"))
	_lobby_box.add_child(_role_info)
	_start_button.text = "Empezar"
	_start_button.pressed.connect(Net.start_game)
	_lobby_box.add_child(_start_button)
	_lobby_box.add_child(_button("Salir de la sala", _on_leave_pressed))

	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", ACCENT)
	root.add_child(_status)

	var beta := Label.new()
	beta.text = "BETA\nEN DESARROLLO"
	beta.add_theme_color_override("font_color", ACCENT)
	# Esquina superior izquierda, libre junto al logo.
	beta.position = Vector2(4, 3)
	add_child(beta)
	_build_help()

	_join_timer.one_shot = true
	_join_timer.timeout.connect(_on_join_failed.bind("Tiempo de espera agotado"))
	add_child(_join_timer)


## Instrucciones a pantalla completa con desplazamiento.
func _build_help() -> void:
	_help_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help_panel.add_theme_stylebox_override("panel", _box(Color("0b0b10"), Color("34384a")))
	var box := VBoxContainer.new()
	_help_panel.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for entry: Array in HELP:
		if entry[0] == "t":
			# Primera línea de cada bloque: título en rojo.
			var lines: PackedStringArray = entry[1].split("
", true, 1)
			var title := _help_label(lines[0])
			title.add_theme_color_override("font_color", ACCENT)
			list.add_child(title)
			if lines.size() > 1:
				list.add_child(_help_label(lines[1]))
		else:
			list.add_child(_help_row(entry))
	box.add_child(_button("Volver", _show_help.bind(false)))
	_help_panel.visible = false
	add_child(_help_panel)


func _help_label(text: String) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = text
	return label


## Fila con el dibujo del juego a la izquierda y su explicación a la derecha.
func _help_row(entry: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	var tex: Texture2D = load(entry[1])
	if entry.size() > 3:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = entry[3]
		tex = atlas
	var icon := TextureRect.new()
	icon.texture = tex
	# Los objetos pequeños (pilas, botín, carro) se dibujan al doble para distinguirlos.
	var zoom := 2.0 if tex.get_height() <= 16 else 1.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(HELP_ICON_WIDTH, tex.get_height() * zoom)
	if entry.size() > 4:
		icon.modulate = entry[4]
	row.add_child(icon)
	var label := _help_label(entry[2])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


func _show_help(open: bool) -> void:
	_help_panel.visible = open


func _show_options(open: bool) -> void:
	_options_box.visible = open
	_main_box.visible = not open
	_fullscreen_check.set_pressed_no_signal(Settings.fullscreen)


func _on_volume_changed(value: float) -> void:
	Settings.volume = value / 100.0
	Settings.apply()
	Settings.save()
	_update_volume_label()


func _update_volume_label() -> void:
	_volume_label.text = "Volumen %d%%" % roundi(Settings.volume * 100)


func _on_fullscreen_toggled(on: bool) -> void:
	Settings.fullscreen = on
	Settings.apply()
	Settings.save()


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
	Net.player_role = Roles.clamp_id(Settings.role)
	if Settings.player_name != Net.player_name:
		Settings.player_name = Net.player_name
		Settings.save()


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


## Pasa al siguiente rol. El anfitrión lo reparte a todos.
func _on_role_pressed() -> void:
	Net.set_role((Net.player_role + 1) % Roles.count())
	Settings.role = Net.player_role
	Settings.save()
	_refresh_lobby()


func _show_lobby(in_lobby: bool) -> void:
	_main_box.visible = not in_lobby
	_lobby_box.visible = in_lobby
	_options_box.visible = false
	_refresh_lobby()


func _refresh_lobby() -> void:
	var ids := Net.players.keys()
	ids.sort()
	_lobby_title.text = "Sala (%d/%d)" % [ids.size(), Net.MAX_PLAYERS]
	var lines := PackedStringArray()
	for id: int in ids:
		lines.append("%s%s (%s)" % ["* " if id == 1 else "- ", Net.players[id], Roles.role_name(Net.roles.get(id, 0))])
	_player_list.text = "\n".join(lines) if not lines.is_empty() else "Esperando..."
	_role_button.text = "Rol: %s" % Roles.role_name(Net.player_role)
	_role_info.text = Roles.effects(Net.player_role)
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
	if args.has("help"):
		_show_help(true)
		if args.has("helpscroll"):
			await get_tree().process_frame
			_help_panel.find_children("*", "ScrollContainer", true, false)[0].scroll_vertical = int(args["helpscroll"])
	if args.has("menushot"):
		await get_tree().create_timer(0.3).timeout
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		img.save_png(args["menushot"])
		get_tree().quit()
		return
	if args.has("name"):
		_name_edit.text = args["name"]
	if args.has("role"):
		Settings.role = int(args["role"])
	if args.has("bind"):
		Net.bind_ip = args["bind"]
	if args.has("host"):
		_auto_start_at = maxi(int(args["host"]), 1)
		_on_host_pressed()
	elif args.has("join"):
		_ip_edit.text = args["join"]
		_on_join_pressed()
