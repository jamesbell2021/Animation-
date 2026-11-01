extends Node
## Autoload "Net": LAN multiplayer.
##
## The host runs the whole simulation. Each phone that joins gets a crew seat, sends its stick and
## buttons to the host, and renders the world from snapshots (20 per second) plus a stream of
## events (destroyed blocks, explosions, projectiles, voices, banners...). The city is generated
## from a seed that the host shares, so only changes ever travel over the network.
## Hosts announce themselves with UDP broadcasts so phones on the same Wi-Fi find them.

signal hosts_changed
signal connect_failed(reason: Variant)
signal host_lost

enum Mode { OFFLINE, HOST, CLIENT }

const PORT := 47470
const DISCOVERY_PORT := 47471
const MAGIC := "NEONMEGATANK3"  # bump when the network messages change
const SNAPSHOT_RATE := 20.0
const INPUT_RATE := 30.0
## Remote players use device ids from here up (device = REMOTE_BASE + peer id).
const REMOTE_BASE := 1000

var mode := Mode.OFFLINE
var seed_value := 0
## Hosts found on the LAN: ip -> {"name", "crew", "seen"}.
var hosts := {}
## Host side: latest input per peer id.
var remote_inputs := {}
## Client side: the round state from the host's welcome message.
var welcome := {}

var _beacon: PacketPeerUDP
var _listener: PacketPeerUDP
var _beacon_t := 0.0
var _snapshot_t := 0.0
var _input_t := 0.0
var _reliable_queue: Array = []
var _fast_queue: Array = []
var _client_buffer: Array = []
var _client_main: Main
var _action_seq := 0
var _interact_seq := 0
var _prev_action := false
var _prev_interact := false
## Where the repair needle was on this phone when ACTION last went down.
var _press_needle := -1.0
var _awaiting_welcome := false
var _welcome_t := 0.0


func is_host() -> bool:
	return mode == Mode.HOST


func is_client() -> bool:
	return mode == Mode.CLIENT


func is_online() -> bool:
	return mode != Mode.OFFLINE


func my_device() -> int:
	return REMOTE_BASE + multiplayer.get_unique_id()


# --- Hosting ---------------------------------------------------------------------------------

func host() -> bool:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 8) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	return true


func _on_peer_connected(id: int) -> void:
	if G.main:
		G.main.remote_joined(REMOTE_BASE + id)


## Client -> host: "send me the round". Repeated until the welcome arrives, because packets sent
## while the connection is still being set up can be lost.
@rpc("any_peer", "call_remote", "reliable")
func _request_welcome() -> void:
	if mode == Mode.HOST and G.main:
		_welcome.rpc_id(multiplayer.get_remote_sender_id(), seed_value, G.main.welcome_state())



func _on_peer_disconnected(id: int) -> void:
	remote_inputs.erase(id)
	if G.main:
		G.main.remote_left(REMOTE_BASE + id)


## Local IPv4 addresses that other phones can reach (shown on the host's lobby screen).
func local_ips() -> Array[String]:
	var out: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append(ip)
	return out


# --- Joining ---------------------------------------------------------------------------------

func start_discovery() -> void:
	hosts.clear()
	_listener = PacketPeerUDP.new()
	_listener.set_broadcast_enabled(true)
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null


func stop_discovery() -> void:
	if _listener:
		_listener.close()
		_listener = null


func join(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip.strip_edges(), PORT) != OK:
		connect_failed.emit(["could not reach %s", ip])
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	_awaiting_welcome = true
	_welcome_t = 0.0
	if not multiplayer.connection_failed.is_connected(_on_connect_failed):
		multiplayer.connection_failed.connect(_on_connect_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_connect_failed() -> void:
	leave()
	connect_failed.emit("connection failed")


func _on_server_disconnected() -> void:
	leave()
	host_lost.emit()


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for sig in [multiplayer.peer_connected, multiplayer.peer_disconnected]:
		for c in sig.get_connections():
			sig.disconnect(c["callable"])
	mode = Mode.OFFLINE
	remote_inputs.clear()
	_client_buffer.clear()
	_client_main = null
	_beacon = null


@rpc("authority", "call_remote", "reliable")
func _welcome(round_seed: int, state: Dictionary) -> void:
	if _client_main != null and round_seed == seed_value:
		return
	_awaiting_welcome = false
	seed_value = round_seed
	welcome = state
	_client_main = null
	_client_buffer.clear()
	G.menu_done = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


@rpc("authority", "call_remote", "reliable")
func _new_round(round_seed: int) -> void:
	seed_value = round_seed
	welcome = {}
	_client_main = null
	_client_buffer.clear()
	get_tree().reload_current_scene()


## Host: tell every phone to rebuild with a fresh city.
func new_round(round_seed: int) -> void:
	seed_value = round_seed
	if is_host():
		_flush()
		_new_round.rpc(round_seed)


## Client: Main is built and can receive the buffered events.
func client_ready(main: Main) -> void:
	_client_main = main
	for batch in _client_buffer:
		main.apply_events(batch)
	_client_buffer.clear()


# --- Replication -----------------------------------------------------------------------------

## Host: queue an event for every phone. Reliable events (blocks, voices, banners) always arrive;
## the rest (sounds, sparks, projectiles) may be dropped under load.
func send_event(kind: String, args: Array, reliable := false) -> void:
	if mode != Mode.HOST or multiplayer.get_peers().is_empty():
		return
	(_reliable_queue if reliable else _fast_queue).append([kind, args])


func _flush() -> void:
	if not _reliable_queue.is_empty():
		_events.rpc(_reliable_queue)
		_reliable_queue = []
	if not _fast_queue.is_empty():
		_fast_events.rpc(_fast_queue)
		_fast_queue = []


@rpc("authority", "call_remote", "reliable")
func _events(batch: Array) -> void:
	_receive(batch)


@rpc("authority", "call_remote", "unreliable_ordered")
func _fast_events(batch: Array) -> void:
	_receive(batch)


func _receive(batch: Array) -> void:
	if _client_main:
		_client_main.apply_events(batch)
	else:
		_client_buffer.append(batch)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(data: Array) -> void:
	if _client_main:
		_client_main.apply_snapshot(data)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _remote_input(move: Vector2, aim: Vector2, action: bool, action_seq: int, interact_seq: int,
		needle: float) -> void:
	if mode != Mode.HOST:
		return
	remote_inputs[multiplayer.get_remote_sender_id()] = {
		"move": move.limit_length(1.0), "aim": aim.limit_length(1.0), "action": action,
		"action_seq": action_seq, "interact_seq": interact_seq, "needle": needle}


func _process(delta: float) -> void:
	_discover()
	match mode:
		Mode.HOST:
			_beacon_t -= delta
			if _beacon_t <= 0.0:
				_beacon_t = 1.0
				_broadcast()
			if G.main and G.main.is_inside_tree() and not multiplayer.get_peers().is_empty():
				_snapshot_t -= delta
				if _snapshot_t <= 0.0:
					_snapshot_t = 1.0 / SNAPSHOT_RATE
					_snapshot.rpc(G.main.make_snapshot())
			_flush()
		Mode.CLIENT:
			if _awaiting_welcome and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				_welcome_t -= delta
				if _welcome_t <= 0.0:
					_welcome_t = 0.5
					_request_welcome.rpc_id(1)
			_send_input(delta)


func _send_input(delta: float) -> void:
	if _client_main == null or _client_main.local_input == null:
		return
	var inp := _client_main.local_input
	inp.poll()
	# Presses are counted so a dropped packet never loses a button press.
	var pressed_now := inp.action_held and not _prev_action
	if pressed_now:
		_action_seq += 1
		# Judge repair taps by the needle this phone was showing, not where it is on the host.
		_press_needle = G.tank.needle_now() if G.tank else -1.0
	if inp.interact_pressed:
		_interact_seq += 1
	_prev_action = inp.action_held
	_input_t -= delta
	if _input_t <= 0.0 or inp.interact_pressed or pressed_now:
		_input_t = 1.0 / INPUT_RATE
		_remote_input.rpc_id(1, inp.move, inp.aim, inp.action_held, _action_seq, _interact_seq, _press_needle)


func _broadcast() -> void:
	if _beacon == null:
		return
	var crew := G.main.human_count() if G.main else 0
	var name := OS.get_model_name()
	if name == "" or name == "GenericDevice":
		name = "%s host" % OS.get_name()
	var msg := ("%s|%s|%d" % [MAGIC, name, crew]).to_utf8_buffer()
	var targets := ["255.255.255.255"]
	for ip in local_ips():
		var parts := ip.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for t in targets:
		_beacon.set_dest_address(t, DISCOVERY_PORT)
		_beacon.put_packet(msg)


func _discover() -> void:
	if _listener == null:
		return
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var pkt := _listener.get_packet().get_string_from_utf8()
		var ip := _listener.get_packet_ip()
		var parts := pkt.split("|")
		if parts.size() >= 3 and parts[0] == MAGIC:
			if not hosts.has(ip):
				changed = true
			hosts[ip] = {"name": parts[1], "crew": int(parts[2]), "seen": Time.get_ticks_msec()}
	for ip in hosts.keys():
		if Time.get_ticks_msec() - int(hosts[ip]["seen"]) > 4000:
			hosts.erase(ip)
			changed = true
	if changed:
		hosts_changed.emit()
