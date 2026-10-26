extends Node
## LAN play: up to three keepers on three machines, each with a screen of their own.
##
## The host runs the game: creatures, buildings, the store, the night. Each other machine
## (a client) sends its keeper's controls to the host every frame and shows what the host
## sends back:
## - snapshots 30 times a second: keepers, creatures, the lamp, the searchlights, the clock;
## - the state 4 times a second: the run (as the save has it), the store, buildings'
##   health, the trap cairns, what's washed up;
## - events: sounds, effects, messages, thrown and fired things, creatures dying, menus.
## A client's keepers and creatures are puppets: they go where the host says and play
## the animations it plays, and nothing on a client can hurt anything.
##
## Found on the LAN by a broadcast the host sends each second; or joined by address.
## A game is started from the lobby; nobody can join once it's under way. A client
## that drops out leaves its keeper to the computer; if the host goes, everyone's out.

enum Mode { OFFLINE, HOST, CLIENT }

const PORT := 24686
const DISCOVER_PORT := 24687
const MAGIC := "SEA_THEY_ARE_ANGRY_LAN_1"
const SNAP_HZ := 30.0
const STATE_HZ := 4.0
const DISCOVER_EVERY := 1.0
const HOST_FORGET := 4.0
## The controls a client sends: held, and counted presses (so a lost packet loses no press).
const ACTIONS := ["attack", "interact", "operate", "beam_mode", "sprint", "flare", "use_dirty",
	"weapon_next", "weapon_prev", "weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5"]
## Puppets catch up with the host this fast (per second).
const FOLLOW := 16.0

signal lobby_changed
signal hosts_changed
signal failed(reason: String)
signal left(reason: String)

var mode := Mode.OFFLINE
var my_name := "Keeper"
var my_slot := 0
## Who's in the game: [{"id": peer id, "name": String, "slot": keeper index}].
var lobby: Array = []
## Hosts heard on the LAN: address -> {"name", "players", "t"}.
var found_hosts := {}
var started := false
## Why the last LAN game ended (shown on the title).
var last_error := ""
## Set while replaying something the host sent (a sound, an effect), so it plays here.
var replaying := false
## A client: how many sounds and effects have come from the host (for the test).
var fx_seen := 0
## A client: the last few messages from the host (for the test).
var messages_seen: Array = []

var _peer: ENetMultiplayerPeer
var _udp: PacketPeerUDP
var _listen: PacketPeerUDP
var _discover_t := 0.0
var _main: Node
var _snap_t := 0.0
var _state_t := 0.0
var _fx: Array = []
var _next_id := 1
var _structs: Array = []
var _scav: Dictionary = {}
var _pending_begin: Dictionary = {}
var _last_snap: Dictionary = {}
var _last_state: Dictionary = {}
# Host: each remote keeper's controls, by slot.
var _inputs := {}
# Client: presses counted since the game began.
var _presses := {}
var _menu_open: Node
# A client: the run's over (the host's states stop counting).
var _ended := false
# The scene is being reloaded for a new run: a start waits for the new one.
var _reloading := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)

func is_host() -> bool:
	return mode == Mode.HOST

func is_client() -> bool:
	return mode == Mode.CLIENT

func online() -> bool:
	return mode != Mode.OFFLINE

## Whether a networked game is under way (the snapshots are flowing).
func playing() -> bool:
	return online() and started and _main != null and is_instance_valid(_main)

# ---- hosting, joining, leaving ----

func host(player_name: String) -> String:
	leave()
	my_name = player_name
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(PORT, Players.MAX - 1)
	if err != OK:
		_peer = null
		return "Couldn't open port %d to host (is another game hosting?)" % PORT
	multiplayer.multiplayer_peer = _peer
	mode = Mode.HOST
	my_slot = 0
	lobby = [{"id": 1, "name": my_name, "slot": 0}]
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	lobby_changed.emit()
	return ""

func join(address: String, player_name: String) -> String:
	leave()
	my_name = player_name
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, PORT)
	if err != OK:
		_peer = null
		return "Couldn't reach %s" % address
	multiplayer.multiplayer_peer = _peer
	mode = Mode.CLIENT
	return ""

func leave() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	started = false
	lobby = []
	_main = null
	_unhook()
	_inputs.clear()
	_presses.clear()
	_scav.clear()
	_structs.clear()
	_pending_begin = {}
	if _udp != null:
		_udp.close()
		_udp = null

## Listen for hosts' broadcasts on the LAN (the join screen).
func browse(on: bool) -> void:
	if on and _listen == null:
		_listen = PacketPeerUDP.new()
		if _listen.bind(DISCOVER_PORT) != OK:
			_listen = null
	elif not on and _listen != null:
		_listen.close()
		_listen = null
		found_hosts.clear()

func _on_peer_connected(id: int) -> void:
	if is_client() and id == 1:
		return

func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	var gone: Dictionary = {}
	for e in lobby:
		if int(e["id"]) == id:
			gone = e
	if gone.is_empty():
		return
	lobby.erase(gone)
	if started:
		# Their keeper carries on, run by the computer.
		if _main != null and is_instance_valid(_main):
			_main.keeper_left(int(gone["slot"]))
		_inputs.erase(int(gone["slot"]))
		Events.message.emit("%s has left: the computer keeps their keeper." % gone["name"])
	else:
		_renumber()
	_send_lobby()

func _on_connected() -> void:
	_hello.rpc_id(1, my_name)

func _on_connection_failed() -> void:
	leave()
	failed.emit("Couldn't connect to the host.")

func _on_server_gone() -> void:
	var was := started
	leave()
	var why := "The host has left the game." if was else "The host closed the lobby."
	left.emit(why)
	if was:
		# Back to the title, saying why.
		last_error = why
		Run.active = false
		Cycle.stop()
		get_tree().paused = false
		get_tree().reload_current_scene()

func _renumber() -> void:
	for i in lobby.size():
		lobby[i]["slot"] = i

func _send_lobby() -> void:
	lobby_changed.emit()
	if is_host():
		_lobby.rpc(lobby)

@rpc("any_peer", "reliable")
func _hello(player_name: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if started or lobby.size() >= Players.MAX:
		_peer.disconnect_peer(id)
		return
	lobby.append({"id": id, "name": player_name.left(16), "slot": lobby.size()})
	_send_lobby()

@rpc("authority", "reliable")
func _lobby(list: Array) -> void:
	lobby = list
	for e in lobby:
		if int(e["id"]) == multiplayer.get_unique_id():
			my_slot = int(e["slot"])
	lobby_changed.emit()

# ---- starting ----

## Host: everyone in the lobby starts the run together.
func start_game(continue_save: bool) -> void:
	if not is_host():
		return
	started = true
	_peer.refuse_new_connections = true
	var cfg := {"humans": lobby.size(), "difficulty": Run.next_difficulty, "cont": continue_save, "names": _names()}
	_begin.rpc(cfg)
	_begin_here(cfg)

func _names() -> Array:
	var out := []
	for e in lobby:
		out.append(e["name"])
	return out

@rpc("authority", "reliable")
func _begin(cfg: Dictionary) -> void:
	started = true
	_begin_here(cfg)

func _begin_here(cfg: Dictionary) -> void:
	Run.next_difficulty = int(cfg.get("difficulty", 1))
	var main := get_tree().current_scene
	if _reloading or main == null or not main.has_method("begin_lan") or not main.is_node_ready():
		_pending_begin = cfg
		return
	main.begin_lan(cfg)

## The main scene, ready: begin anything waiting for it.
func scene_ready(main: Node) -> void:
	_reloading = false
	if not _pending_begin.is_empty():
		var cfg := _pending_begin
		_pending_begin = {}
		main.begin_lan(cfg)

## The run has begun on this machine (main.begin_run is done).
func game_started(main: Node) -> void:
	_main = main
	_ended = false
	_structs.clear()
	for s in get_tree().get_nodes_in_group("structures"):
		if not (s is SandbagWall):
			_structs.append(s)
	_scav.clear()
	_next_id = 1
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ScavengePoint:
			register_scav(n)
	if is_host():
		for e in lobby:
			if int(e["slot"]) > 0:
				_inputs[int(e["slot"])] = _blank_input()
		_unhook()
		Events.message.connect(_relay_message)
		Events.run_ended.connect(_relay_ended)
	else:
		Cycle.running = false

func peer_for_slot(slot: int) -> int:
	for e in lobby:
		if int(e["slot"]) == slot:
			return int(e["id"])
	return 0

func slot_name(slot: int) -> String:
	for e in lobby:
		if int(e["slot"]) == slot:
			return String(e["name"])
	return ""

## A washed-up thing's network id (the same on every machine for what the scene builds).
func register_scav(sp: Node) -> void:
	if int(sp.get_meta("net_id", 0)) > 0:
		return
	sp.set_meta("net_id", _next_id)
	_scav[_next_id] = sp
	_next_id += 1

func new_enemy_id() -> int:
	_next_id += 1
	return 100000 + _next_id

# ---- every frame ----

func _process(delta: float) -> void:
	_discovery(delta)

func _physics_process(delta: float) -> void:
	if not playing():
		return
	if is_host():
		_snap_t += delta
		if _snap_t >= 1.0 / SNAP_HZ:
			_snap_t = 0.0
			_snap.rpc(_build_snap())
		_state_t += delta
		if _state_t >= 1.0 / STATE_HZ:
			_state_t = 0.0
			_state.rpc(_build_state())
		if not _fx.is_empty():
			_fx_batch.rpc(_fx)
			_fx = []
	else:
		_send_input()
		_follow(delta)

func _discovery(delta: float) -> void:
	if is_host() and not started and _udp != null:
		_discover_t -= delta
		if _discover_t <= 0.0:
			_discover_t = DISCOVER_EVERY
			_udp.set_dest_address("255.255.255.255", DISCOVER_PORT)
			_udp.put_packet(("%s|%s|%d" % [MAGIC, my_name, lobby.size()]).to_utf8_buffer())
	if _listen != null:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet().get_string_from_utf8()
			var ip := _listen.get_packet_ip()
			var parts := pkt.split("|")
			if parts.size() == 3 and parts[0] == MAGIC:
				changed = changed or not found_hosts.has(ip)
				found_hosts[ip] = {"name": parts[1], "players": int(parts[2]), "t": 0.0}
		for ip in found_hosts.keys():
			found_hosts[ip]["t"] = float(found_hosts[ip]["t"]) + delta
			if float(found_hosts[ip]["t"]) > HOST_FORGET:
				found_hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()

# ---- a client's controls ----

func _blank_input() -> Dictionary:
	return {"move": Vector2.ZERO, "aim": Vector3.FORWARD, "point": Vector3.INF, "held": {}, "presses": {}, "seen": {}, "new": {}}

func _send_input() -> void:
	var me: Player = _main.player if _main != null else null
	if me == null or not is_instance_valid(me):
		return
	var quiet: bool = ChoiceMenu.current != null or get_tree().paused
	var held := {}
	for a in ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a) and not quiet:
			_presses[a] = int(_presses.get(a, 0)) + 1
		held[a] = InputMap.has_action(a) and Input.is_action_pressed(a) and not quiet
	var move := Vector2.ZERO if quiet else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var aim: Vector3 = me.aim_dir()
	var point := Vector3.INF
	var cam := get_viewport().get_camera_3d()
	if InputSetup.pad_active:
		# On a pad: the right stick aims, or the way the keeper walks.
		var stick := InputSetup.pad_stick()
		if stick.length() > 0.35:
			aim = Vector3(stick.x, 0.0, stick.y).normalized()
		elif move.length() > 0.3:
			aim = Vector3(move.x, 0.0, move.y).normalized()
		cam = null
	if cam != null:
		var mp := get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(mp)
		var dir := cam.project_ray_normal(mp)
		if absf(dir.y) > 0.0001:
			var t := (me.global_position.y - from.y) / dir.y
			if t > 0.0:
				var d: Vector3 = from + dir * t - me.global_position
				d.y = 0.0
				if d.length() > 0.05:
					aim = d.normalized()
			point = Player._ground_hit(from, dir)
	me._aim = aim
	_in.rpc_id(1, {"m": move, "a": aim, "p": point, "h": held, "c": _presses})

@rpc("any_peer", "unreliable_ordered")
func _in(d: Dictionary) -> void:
	if not is_host():
		return
	var slot := _slot_of(multiplayer.get_remote_sender_id())
	if slot <= 0 or not _inputs.has(slot):
		return
	var inp: Dictionary = _inputs[slot]
	inp["move"] = d.get("m", Vector2.ZERO)
	inp["aim"] = d.get("a", Vector3.FORWARD)
	inp["point"] = d.get("p", Vector3.INF)
	inp["held"] = d.get("h", {})
	inp["presses"] = d.get("c", {})
	inp["live"] = true

func _slot_of(id: int) -> int:
	for e in lobby:
		if int(e["id"]) == id:
			return int(e["slot"])
	return -1

## Host: a remote keeper's controls this frame. Presses are turned into "pressed this
## frame" once per physics frame (Player calls this first thing).
func input_for(slot: int) -> Dictionary:
	return _inputs.get(slot, {})

func input_frame(slot: int) -> void:
	var inp: Dictionary = _inputs.get(slot, {})
	if inp.is_empty():
		return
	var presses: Dictionary = inp["presses"]
	var seen: Dictionary = inp["seen"]
	var fresh := {}
	for a in presses:
		var n := int(presses[a])
		if n > int(seen.get(a, 0)):
			fresh[a] = true
		seen[a] = n
	inp["new"] = fresh

func just(slot: int, a: String) -> bool:
	return bool(_inputs.get(slot, {}).get("new", {}).get(a, false))

func held(slot: int, a: String) -> bool:
	return bool(_inputs.get(slot, {}).get("held", {}).get(a, false))

# ---- snapshots (host -> clients, unreliable) ----

func _build_snap() -> Dictionary:
	var ps := []
	for p in _main.players:
		ps.append(p.net_snap() if is_instance_valid(p) else [])
	var es := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.net_id > 0:
			es.append(e.net_snap())
	var lamp: Lamp = _main.lighthouse.lamp
	var sls := []
	for sl in _main.camp.searchlights:
		sls.append([sl._aim, sl.mode, sl.is_lit()])
	return {"ph": Cycle.phase, "tl": Cycle.time_left, "p": ps, "e": es,
		"l": [lamp.yaw, lamp.state, lamp.mode, lamp.fuel, lamp._smothered], "s": sls}

@rpc("authority", "unreliable_ordered")
func _snap(d: Dictionary) -> void:
	if not is_client() or _main == null or not is_instance_valid(_main):
		return
	_last_snap = d
	var ph := int(d.get("ph", 0))
	if ph != Cycle.phase:
		Cycle._enter(ph)
	Cycle.time_left = float(d.get("tl", 0.0))
	var ps: Array = d.get("p", [])
	for i in mini(ps.size(), _main.players.size()):
		if not (ps[i] as Array).is_empty() and is_instance_valid(_main.players[i]):
			_main.players[i].net_apply(ps[i])
	_apply_enemies(d.get("e", []))
	var l: Array = d.get("l", [])
	if l.size() >= 5:
		_main.lighthouse.lamp.net_apply(l)
	var sls: Array = d.get("s", [])
	for i in mini(sls.size(), _main.camp.searchlights.size()):
		_main.camp.searchlights[i].net_apply(sls[i])

func _apply_enemies(list: Array) -> void:
	var here := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.net_id > 0:
			here[e.net_id] = e
	var seen := {}
	for row in list:
		var id := int(row[0])
		seen[id] = true
		var e: Node = here.get(id)
		if e == null:
			e = _make_puppet(row)
			if e == null:
				continue
		e.net_apply(row)
	for id in here:
		if not seen.has(id):
			here[id].queue_free()

func _make_puppet(row: Array) -> Node:
	var path := String(row[1])
	if not ResourceLoader.exists(path):
		return null
	var e = load(path).new()
	e.puppet = true
	e.net_id = int(row[0])
	e.lighthouse = _main.lighthouse
	e.position = row[2]
	var extra = row[10] if row.size() > 10 else null
	if extra is Dictionary and extra.has("origin"):
		e.origin = extra["origin"]
	_main.get_node("Enemies").add_child(e)
	return e

func _follow(_delta: float) -> void:
	pass

# ---- the state (host -> clients, reliable, a few times a second) ----

func _build_state() -> Dictionary:
	var st := []
	for s in _structs:
		st.append(s.hp if is_instance_valid(s) else 0)
	var traps := []
	for t in get_tree().get_nodes_in_group("trap_slots"):
		traps.append(t.net_snap())
	var sc := []
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ScavengePoint and not n.is_queued_for_deletion():
			register_scav(n)
			sc.append([int(n.get_meta("net_id")), n.kind, n.amount, n.global_position, n.available, n.once])
	var gen: Generator = _main.camp.generator
	return {"run": SaveSys.snapshot(), "st": st, "tr": traps, "sc": sc,
		"gen": [gen.fuel, gen.running], "stove": _main.camp.stove.burn, "rs": Run.researching}

@rpc("authority", "reliable")
func _state(d: Dictionary) -> void:
	if not is_client() or _main == null or not is_instance_valid(_main) or _ended:
		return
	var before_up: Dictionary = Run.upgrades.duplicate()
	Run.start_loaded(d.get("run", {}))
	if Run.upgrades != before_up:
		Upgrades.apply(get_tree())
	var st: Array = d.get("st", [])
	for i in mini(st.size(), _structs.size()):
		var s: Structure = _structs[i]
		if is_instance_valid(s) and s.hp != int(st[i]):
			s.net_set_hp(int(st[i]))
	var traps: Array = d.get("tr", [])
	var slots := get_tree().get_nodes_in_group("trap_slots")
	for i in mini(traps.size(), slots.size()):
		slots[i].net_apply(traps[i])
	_apply_scav(d.get("sc", []))
	var gen: Array = d.get("gen", [])
	if gen.size() == 2:
		_main.camp.generator.net_apply(float(gen[0]), bool(gen[1]))
	_main.camp.stove.burn = float(d.get("stove", 0.0))
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_method("refresh") and (n is CampPlot or n is GardenPlot):
			n.refresh()

func _apply_scav(list: Array) -> void:
	var seen := {}
	for row in list:
		var id := int(row[0])
		seen[id] = true
		var sp: Node = _scav.get(id)
		if sp == null or not is_instance_valid(sp):
			sp = ScavengePoint.new(String(row[1]), int(row[2]))
			sp.once = bool(row[5])
			sp.position = row[3]
			sp.set_meta("net_id", id)
			_main.add_child(sp)
			_scav[id] = sp
		sp.net_set_available(bool(row[4]))
	for id in _scav.keys():
		if not seen.has(id):
			if is_instance_valid(_scav[id]):
				_scav[id].queue_free()
			_scav.erase(id)

# ---- events: sounds, effects, messages ----

## Host: a sound to play on the clients too (positional ones; the UI's are each machine's own).
func relay_sfx(key: String, at: Vector3, volume_db: float, pitch_jitter: float) -> void:
	if playing() and is_host():
		_fx.append(["s", key, at, volume_db, pitch_jitter])

func relay_horn(pattern: Array, volume_db: float) -> void:
	if playing() and is_host():
		_fx.append(["h", pattern, volume_db])

## Whether a named effect should play here: on the host (and offline) always, sent on to
## the clients as it does; on a client, only when the host sent it.
func fx_gate(name: String, args: Array) -> bool:
	if not playing():
		return true
	if is_host():
		_fx.append(["f", name, args])
		return true
	return replaying

## Whether a sound should play here (see fx_gate): a client plays its own interface sounds.
func sfx_gate(key: String, at: Vector3, volume_db: float, pitch_jitter: float) -> bool:
	if not playing():
		return true
	if is_host():
		if at != Vector3.INF:
			relay_sfx(key, at, volume_db, pitch_jitter)
		return true
	return replaying or at == Vector3.INF

@rpc("authority", "unreliable")
func _fx_batch(batch: Array) -> void:
	if not is_client() or _main == null:
		return
	replaying = true
	fx_seen += batch.size()
	for ev in batch:
		match String(ev[0]):
			"s":
				Audio.sfx(ev[1], ev[2], ev[3], ev[4])
			"h":
				Audio.horn(ev[1], ev[2])
			"f":
				_play_fx(String(ev[1]), ev[2])
	replaying = false

func _play_fx(name: String, a: Array) -> void:
	match name:
		"splash":
			FX.splash(_main, a[0], a[1])
		"burst":
			FX.burst(_main, a[0])
		"spray":
			FX.spray(_main, a[0], a[1], a[2])
		"steam":
			FX.steam(_main, a[0])
		"embers":
			FX.embers(_main, a[0])
		"steam_burst":
			FX.steam_burst(_main, a[0])
		"splinters":
			FX.splinters(_main, a[0])
		"sparks":
			FX.sparks(_main, a[0])
		"sea_spray":
			FX.sea_spray(_main, a[0])
		"breaker":
			FX.breaker(_main, a[0], a[1])

func _relay_message(text: String) -> void:
	if playing() and is_host():
		_event.rpc("msg", [text])

func _relay_ended(reason: String, night: int) -> void:
	if playing() and is_host():
		_event.rpc("ended", [reason, night])

## Host: a HUD warning or report, shown on the clients too.
func relay_warn(text: String) -> void:
	if playing() and is_host():
		_event.rpc("warn", [text])

func relay_report(heading: String, lines: Array, time: float) -> void:
	if playing() and is_host():
		_event.rpc("report", [heading, lines, time])

## Host: something fired or thrown, to show flying on the clients (it can't hurt there).
func relay_shot(kind: String, args: Array) -> void:
	if playing() and is_host():
		_event.rpc("shot", [kind, args])

## Host: the relief boat's coming, going, and the chapter's end, on the clients too.
func relay_rescue(kind: String, args: Array) -> void:
	if playing() and is_host():
		_event.rpc("rescue", [kind, args])

## Host: a creature has died where it stands (it falls as a corpse on the clients).
func relay_corpse(id: int, impulse: Vector3) -> void:
	if playing() and is_host():
		_event.rpc("corpse", [id, impulse])

@rpc("authority", "reliable")
func _event(kind: String, args: Array) -> void:
	if not is_client() or _main == null or not is_instance_valid(_main):
		return
	match kind:
		"msg":
			messages_seen.append(String(args[0]))
			if messages_seen.size() > 20:
				messages_seen.pop_front()
			_main.hud._on_message(args[0])
		"warn":
			_main.hud.warn(args[0])
		"report":
			_main.hud.report(args[0], args[1], args[2])
		"ended":
			_ended = true
			Run.end_run(args[0])
		"corpse":
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Enemy and e.net_id == int(args[0]):
					e._ragdoll_corpse(args[1])
					e.net_id = -1
		"shot":
			_show_shot(String(args[0]), args[1])
		"restart":
			_restart_here()
		"rescue":
			_main.net_rescue(String(args[0]), args[1])

func _show_shot(kind: String, a: Array) -> void:
	match kind:
		"flare":
			var f := Flare.new()
			f.from = a[0]
			f.to = a[1]
			_main.add_child(f)
		"arrow":
			var ar := Arrow.new()
			ar.from = a[0]
			ar.dir = a[1]
			ar.speed = a[2]
			ar.damage = 0
			_main.add_child(ar)
		"bomb":
			var b := PetrolBomb.new()
			b.from = a[0]
			b.to = a[1]
			_main.add_child(b)
		"ink":
			var cloud := InkCloud.new()
			_main.add_child(cloud)
			cloud.global_position = a[0]
		"harpoon":
			# The boathook in flight: for the look of it; the host knocks the climber off.
			var idx := int(a[0])
			if idx < 0 or idx >= _main.players.size():
				return
			var h := Harpoon.new()
			h.keeper = _main.players[idx]
			h.puppet = true
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Enemy and int(a[2]) > 0 and e.net_id == int(a[2]):
					h.target = e
			_main.add_child(h)
			h.global_position = a[1]

# ---- menus for a keeper on another machine ----

## Host: show (or refresh) a menu on the machine whose keeper opened it.
func send_menu(peer: int, title: String, note: String, rows: Array) -> void:
	_menu.rpc_id(peer, title, note, rows)

func shut_menu(peer: int) -> void:
	if peer > 0 and online():
		_menu_shut.rpc_id(peer)

@rpc("authority", "reliable")
func _menu(title: String, note: String, rows: Array) -> void:
	if _main == null or not is_instance_valid(_main):
		return
	if _menu_open != null and is_instance_valid(_menu_open):
		_menu_open.show_rows(title, note, rows)
	else:
		_menu_open = ChoiceMenu.open_display(_main.player, title, note, rows)

@rpc("authority", "reliable")
func _menu_shut() -> void:
	if _menu_open != null and is_instance_valid(_menu_open):
		# The host has closed it: nothing to tell the host back.
		_menu_open.close(false)
	_menu_open = null

## Client: a row picked (1-based, the last is Leave).
func pick(n: int) -> void:
	_menu_pick.rpc_id(1, n)

func menu_left() -> void:
	_menu_open = null
	if is_client():
		_menu_leave.rpc_id(1)

@rpc("any_peer", "reliable")
func _menu_pick(n: int) -> void:
	var m: ChoiceMenu = ChoiceMenu.remote_menus.get(multiplayer.get_remote_sender_id())
	if is_host() and m != null and is_instance_valid(m):
		m.choose(n)

@rpc("any_peer", "reliable")
func _menu_leave() -> void:
	var m: ChoiceMenu = ChoiceMenu.remote_menus.get(multiplayer.get_remote_sender_id())
	if is_host() and m != null and is_instance_valid(m):
		m.close(false)

func _unhook() -> void:
	if Events.message.is_connected(_relay_message):
		Events.message.disconnect(_relay_message)
	if Events.run_ended.is_connected(_relay_ended):
		Events.run_ended.disconnect(_relay_ended)

# ---- after the run ----

## Host: a new run for everyone (from the game-over screen).
func restart(cont: bool = false) -> void:
	if not is_host():
		return
	_event.rpc("restart", [])
	_restart_here(cont)

func _restart_here(cont: bool = false) -> void:
	_main = null
	_reloading = true
	_unhook()
	if is_host():
		_pending_begin = {"humans": lobby.size(), "difficulty": Run.difficulty, "cont": cont, "names": _names()}
		get_tree().reload_current_scene()
		_begin.rpc.call_deferred(_pending_begin)
	else:
		get_tree().reload_current_scene()
