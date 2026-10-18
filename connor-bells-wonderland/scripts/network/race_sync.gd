class_name RaceSync
extends Node
## Host -> client replication of race events. Lives at the same path on every
## peer (child "RaceSync" of the GameManager). Does nothing harmful offline.

@export var tick_interval: float = 0.25
@export var load_timeout: float = 15.0

var game: GameManager
var race_time: float = 0.0
var ranking_names: Array = []

var _loaded: Dictionary = {}
var _waiting: bool = false
var _wait_timer: float = 0.0
var _tick_timer: float = 0.0
var _acknowledged: bool = true
var _report_timer: float = 0.0
var _client_racing: bool = false


func setup(p_game: GameManager) -> void:
	game = p_game
	if game == null:
		push_error("RaceSync.setup: game is null.")
		return
	if _networked() and multiplayer.is_server():
		_connect_host_signals()


func _networked() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


## Host: start the countdown once every connected client has loaded (or on timeout).
func begin_when_clients_loaded() -> void:
	if not _networked() or multiplayer.get_peers().is_empty():
		game.start_race()
		return
	_waiting = true
	_wait_timer = load_timeout
	if game.hud != null:
		game.hud.show_message("Waiting for players to load...", 9999.0)


## Client: tell the host we are ready (retried until acknowledged).
func report_loaded() -> void:
	_acknowledged = false
	_report_timer = 0.0


func broadcast_restart() -> void:
	if _networked() and multiplayer.is_server():
		_rpc_restart.rpc()


func _process(delta: float) -> void:
	if game == null or not _networked():
		return
	if multiplayer.is_server():
		if _waiting:
			_wait_timer -= delta
			if _all_loaded() or _wait_timer <= 0.0:
				_waiting = false
				if game.hud != null:
					game.hud.clear_message()
				game.start_race()
		if game.race_manager != null and not multiplayer.get_peers().is_empty():
			_tick_timer -= delta
			if _tick_timer <= 0.0:
				_tick_timer = tick_interval
				_rpc_tick.rpc(game.race_manager.race_time, ranking_names)
	else:
		if _client_racing:
			race_time += delta
		if not _acknowledged:
			_report_timer -= delta
			if _report_timer <= 0.0:
				_report_timer = 1.0
				_rpc_client_loaded.rpc_id(1)


func _all_loaded() -> bool:
	for peer in multiplayer.get_peers():
		if not _loaded.has(peer):
			return false
	return true


func _connect_host_signals() -> void:
	var rm := game.race_manager
	if rm == null:
		push_error("RaceSync: host has no RaceManager.")
		return
	rm.countdown_tick.connect(func(s: int) -> void: _rpc_countdown.rpc(s))
	rm.race_started.connect(func() -> void: _rpc_started.rpc())
	rm.contestant_finished.connect(func(c: Contestant, place: int, t: float) -> void: _rpc_finished.rpc(str(c.name), place, t))
	rm.contestant_fell.connect(func(c: Contestant, n: int) -> void: _rpc_fell.rpc(str(c.name), n))
	rm.race_finished.connect(func(results: Array) -> void: _rpc_results.rpc(_plain_results(results)))
	if game.course != null and game.course.checkpoint_manager != null:
		game.course.checkpoint_manager.checkpoint_reached.connect(func(c: Contestant, i: int) -> void: _rpc_checkpoint.rpc(str(c.name), i))
	if game.items != null:
		game.items.net_event.connect(func(event: String, args: Array) -> void: _rpc_item_event.rpc(event, args))
	if game.paintball != null:
		game.paintball.net_event.connect(func(event: String, args: Array) -> void: _rpc_paint_event.rpc(event, args))
	if game.decorator != null:
		var children := game.decorator.get_children()
		for i in range(children.size()):
			var coin := children[i] as CoinPickup
			if coin != null:
				coin.collected.connect(func(c: Contestant, v: int) -> void: _rpc_coin.rpc(i, str(c.name), v))


## Results with names as plain Strings so they survive the trip to clients.
func _plain_results(results: Array) -> Array:
	var out: Array = []
	for entry in results:
		var copy: Dictionary = (entry as Dictionary).duplicate()
		copy["name"] = str(copy.get("name", ""))
		out.append(copy)
	return out


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_loaded() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_loaded[sender] = true
	_rpc_loaded_ack.rpc_id(sender)


@rpc("authority", "call_remote", "reliable")
func _rpc_loaded_ack() -> void:
	_acknowledged = true


@rpc("authority", "call_remote", "reliable")
func _rpc_countdown(seconds_left: int) -> void:
	game.on_countdown_tick(seconds_left)


@rpc("authority", "call_remote", "reliable")
func _rpc_started() -> void:
	_client_racing = true
	race_time = 0.0
	game.on_race_started()


@rpc("authority", "call_remote", "reliable")
func _rpc_finished(contestant_name: String, place: int, time: float) -> void:
	game.on_contestant_finished(game.find_contestant(contestant_name), place, time)


@rpc("authority", "call_remote", "reliable")
func _rpc_fell(contestant_name: String, fall_count: int) -> void:
	game.on_contestant_fell(game.find_contestant(contestant_name), fall_count)


@rpc("authority", "call_remote", "reliable")
func _rpc_checkpoint(contestant_name: String, index: int) -> void:
	game.on_checkpoint_reached(game.find_contestant(contestant_name), index)


@rpc("authority", "call_remote", "reliable")
func _rpc_coin(coin_index: int, contestant_name: String, value: int) -> void:
	game.on_coin_remote(coin_index, game.find_contestant(contestant_name), value)


@rpc("authority", "call_remote", "reliable")
func _rpc_results(results: Array) -> void:
	_client_racing = false
	game.on_race_finished(results)


@rpc("authority", "call_remote", "reliable")
func _rpc_restart() -> void:
	_client_racing = false
	race_time = 0.0
	ranking_names = []
	game.client_restart()


@rpc("authority", "call_remote", "reliable")
func _rpc_item_event(event: String, args: Array) -> void:
	if game.items != null:
		game.items.apply_remote_event(event, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_paint_event(event: String, args: Array) -> void:
	if game.paintball != null:
		game.paintball.apply_remote_event(event, args)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_tick(time: float, names: Array) -> void:
	race_time = time
	ranking_names = names
