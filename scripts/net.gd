extends Node
## Conexión en red: crear o unirse a una sala, lista de jugadores y arranque de partida.
## El anfitrión (id 1) es la autoridad de la partida. Sin red se usa el modo offline
## de Godot, donde el jugador local también es el id 1.

signal players_changed
signal connection_failed(reason: String)
## Solo en el anfitrión: todos los jugadores han cargado la escena de juego.
signal all_loaded

const PORT := 7777
const MAX_PLAYERS := 4
const NAME_MAX := 16
const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

var player_name := "Jugador"
## id de red -> nombre.
var players := {}
## Rol elegido por el jugador local (índice de Roles.LIST).
var player_role := 0
## id de red -> rol.
var roles := {}
## Mensaje que el menú muestra al volver (desconexión, error).
var last_error := ""
## IP local donde escucha el anfitrión. Vacía escucha en todas las interfaces.
var bind_ip := ""
## Desactiva la validación de movimiento. Solo para pruebas automáticas que teletransportan.
var allow_teleport := false
## Semilla del mapa de la partida en curso. La elige el anfitrión en cada partida.
var map_seed := 0

var _loaded := {}
var _in_game := false


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	if not bind_ip.is_empty():
		peer.set_bind_ip(bind_ip)
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_in_game = false
	players = {1: player_name}
	roles = {1: player_role}
	players_changed.emit()
	return OK


func join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## Cierra la conexión y vuelve al menú mostrando el motivo.
func leave(reason := "") -> void:
	close()
	last_error = reason
	get_tree().change_scene_to_file(MENU_SCENE)


func close() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	roles.clear()
	_loaded.clear()
	_in_game = false


## Solo el anfitrión: carga la escena de juego en todos los equipos.
func start_game() -> void:
	if not multiplayer.is_server():
		return
	_in_game = true
	_loaded.clear()
	_load_game.rpc(randi_range(1, 0x7fffffff))


## Lo llama la escena de juego al terminar de montarse.
func report_loaded() -> void:
	if players.is_empty():
		# Partida lanzada sin pasar por el menú: juego en solitario offline.
		players = {multiplayer.get_unique_id(): player_name}
		roles = {multiplayer.get_unique_id(): player_role}
	if multiplayer.is_server():
		_mark_loaded(1)
	else:
		_client_loaded.rpc_id(1)


## Cambia el rol del jugador local en la sala de espera.
func set_role(role: int) -> void:
	player_role = Roles.clamp_id(role)
	if multiplayer.is_server():
		roles[1] = player_role
		_sync_players.rpc(players, roles)
	else:
		_request_role.rpc_id(1, player_role)


@rpc("any_peer", "reliable")
func _request_role(role: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or _in_game or not players.has(id):
		return
	roles[id] = Roles.clamp_id(role)
	_sync_players.rpc(players, roles)


@rpc("any_peer", "reliable")
func _register(requested_name: String, role := 0) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if _in_game or players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var clean := requested_name.strip_edges().left(NAME_MAX)
	players[id] = clean if not clean.is_empty() else "Jugador %d" % players.size()
	roles[id] = Roles.clamp_id(role)
	_sync_players.rpc(players, roles)


@rpc("authority", "call_local", "reliable")
func _sync_players(list: Dictionary, role_list: Dictionary) -> void:
	players = list
	roles = role_list
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _load_game(seed_value: int) -> void:
	map_seed = seed_value
	get_tree().change_scene_to_file(GAME_SCENE)


@rpc("any_peer", "reliable")
func _client_loaded() -> void:
	if multiplayer.is_server():
		_mark_loaded(multiplayer.get_remote_sender_id())


func _mark_loaded(id: int) -> void:
	_loaded[id] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	if _loaded.is_empty():
		return
	for id: int in players:
		if not _loaded.has(id):
			return
	_loaded.clear()
	all_loaded.emit()


func _on_connected() -> void:
	_register.rpc_id(1, player_name, player_role)


func _on_connection_failed() -> void:
	close()
	connection_failed.emit("No se pudo conectar")


func _on_server_disconnected() -> void:
	leave("El anfitrión se ha desconectado")


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	players.erase(id)
	roles.erase(id)
	_sync_players.rpc(players, roles)
	_check_all_loaded()
