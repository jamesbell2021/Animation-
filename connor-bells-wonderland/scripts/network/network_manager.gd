extends Node
## Autoload "NetworkManager". ENet host/join, player registry and shared race
## settings for local Wi-Fi play. The host (peer 1) is authoritative.

signal player_list_changed
signal settings_changed(settings: Dictionary)
signal connected_to_host
signal connection_failed(reason: String)
signal disconnected_from_host(reason: String)
signal game_starting(settings: Dictionary)

const DEFAULT_PORT := 24680
const MAX_PLAYERS := 8
const GAME_SCENE := "res://scenes/main/main.tscn"
const LOBBY_SCENE := "res://scenes/menus/lobby.tscn"
const MENU_SCENE := "res://scenes/menus/main_menu.tscn"

var local_name: String = "Player"
var local_colour: Color = Color(1.0, 0.35, 0.35)
var players: Dictionary = {}
var settings: Dictionary = {"sections": 6, "bots": 3, "difficulty": 1, "countdown": 3, "items": true}
var is_multiplayer_session: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_host() -> bool:
	return is_multiplayer_session and multiplayer.is_server()


func is_client() -> bool:
	return is_multiplayer_session and not multiplayer.is_server()


func host(port: int = DEFAULT_PORT) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		connection_failed.emit("Could not host on port %d (error %d)." % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	is_multiplayer_session = true
	players.clear()
	players[1] = _local_entry()
	player_list_changed.emit()
	return true


func join(address: String, port: int = DEFAULT_PORT) -> bool:
	leave()
	if address.strip_edges().is_empty():
		connection_failed.emit("Enter the host's IP address.")
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), port)
	if err != OK:
		connection_failed.emit("Could not start connection to %s (error %d)." % [address, err])
		return false
	multiplayer.multiplayer_peer = peer
	is_multiplayer_session = true
	players.clear()
	return true


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_multiplayer_session = false
	players.clear()
	player_list_changed.emit()


## Peer ids in a stable order (host first). Used to spawn contestants identically everywhere.
func get_sorted_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for id in players.keys():
		ids.append(int(id))
	ids.sort()
	return ids


func get_player_count() -> int:
	return players.size()


func set_local_ready(is_ready: bool) -> void:
	if not is_multiplayer_session:
		return
	if multiplayer.is_server():
		_set_ready(1, is_ready)
	else:
		_rpc_set_ready.rpc_id(1, is_ready)


func all_ready() -> bool:
	for id in players:
		if int(id) != 1 and not bool(players[id].get("ready", false)):
			return false
	return true


## Host only: updates shared settings and sends them to clients.
func update_settings(new_settings: Dictionary) -> void:
	if not is_host():
		return
	settings = new_settings.duplicate()
	settings_changed.emit(settings)
	_rpc_settings.rpc(settings)


## Host only: tells everyone (including itself) to load the game scene.
func start_game() -> void:
	if not is_host():
		return
	_rpc_start_game.rpc(settings)


func get_local_ip_addresses() -> Array[String]:
	var result: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			result.append(ip)
	return result


func _local_entry() -> Dictionary:
	return {"name": local_name, "colour": local_colour, "ready": false}


func _set_ready(peer_id: int, is_ready: bool) -> void:
	if players.has(peer_id):
		players[peer_id]["ready"] = is_ready
	_broadcast_players()


func _broadcast_players() -> void:
	player_list_changed.emit()
	if is_host():
		_rpc_player_list.rpc(players)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_rpc_settings.rpc_id(id, settings)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		_broadcast_players()


func _on_connected_to_server() -> void:
	connected_to_host.emit()
	_rpc_register_player.rpc_id(1, local_name, local_colour)


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("Could not reach the host. Check the IP address and that both devices are on the same Wi-Fi.")


func _on_server_disconnected() -> void:
	leave()
	disconnected_from_host.emit("The host left the game.")
	if get_tree() != null:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_player(player_name: String, colour: Color) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		push_warning("NetworkManager: lobby full, rejecting peer %d." % id)
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
		return
	players[id] = {"name": player_name, "colour": colour, "ready": false}
	_broadcast_players()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_ready(is_ready: bool) -> void:
	if multiplayer.is_server():
		_set_ready(multiplayer.get_remote_sender_id(), is_ready)


@rpc("authority", "call_remote", "reliable")
func _rpc_player_list(list: Dictionary) -> void:
	players = list
	player_list_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_settings(new_settings: Dictionary) -> void:
	settings = new_settings
	settings_changed.emit(settings)


@rpc("authority", "call_local", "reliable")
func _rpc_start_game(game_settings: Dictionary) -> void:
	settings = game_settings
	game_starting.emit(settings)
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		push_error("NetworkManager: could not load %s (error %d)." % [GAME_SCENE, err])
