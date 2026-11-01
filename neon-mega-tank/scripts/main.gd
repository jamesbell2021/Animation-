class_name Main
extends Node3D
## Game root: builds the neon city, the mega tank and the isometric camera, and runs the game
## flow: title menu, lobby with the DEPLOY gate, endless escalating waves, game over.
## Handles local drop-in players, AI crew and LAN multiplayer. On a LAN client this scene only
## mirrors the host: it applies snapshots and events instead of simulating.

enum State { MENU, LOBBY, PLAYING, GAMEOVER }

const MAX_PLAYERS := 4
const CAM_SIZE := 28.0
const GATE_POS := Vector3(0, 0, -22)
const BOSS_EVERY := 5

var state := State.LOBBY
var players: Array[Crew] = []
var camera: Camera3D
var hud: Hud
var menu: TitleMenu
var wave := 0
var spawn_queue: Array[String] = []
var survival_time := 0.0
var new_record := false
## The boss currently on the field (host) or its puppet (client), for the HUD health bar.
var boss: Enemy
## LAN client: this phone's controls.
var local_input: PlayerInput
## Trailer filming (tools/trailer): when set, called every frame instead of the follow camera.
var cinematic: Callable

var _candidates := {}
var _cam_target := Vector3.ZERO
var _screen_right := Vector3.RIGHT
var _screen_up := Vector3.FORWARD
var _gate: Node3D
var _gate_meshes: Array[MeshInstance3D] = []
var _enemies_root: Node3D
var _puppets := {}
var _spawn_timer := 0.0
var _spawn_angle := 0.0
var _wave_break := 0.0
var _gameover_timer := 0.0
var _time := 0.0
var _leaving := false
var _wave_clock := 0.0
var _bot_t := 0.0
var _gate_msg_t := 0.0
var _demo_over := false


func _ready() -> void:
	G.main = self
	G.reset_round()
	if Net.is_client():
		G.round_seed = Net.seed_value
	elif G.round_seed == 0:
		G.round_seed = randi()
	Net.seed_value = G.round_seed
	_build_environment()
	G.fx_root = Node3D.new()
	G.fx_root.name = "Fx"
	add_child(G.fx_root)
	G.debris_field = DebrisField.new()
	G.debris_field.name = "Debris"
	add_child(G.debris_field)
	var city := City.new()
	city.name = "City"
	add_child(city)
	G.city = city
	city.generate(G.round_seed)
	_enemies_root = Node3D.new()
	_enemies_root.name = "Enemies"
	add_child(_enemies_root)
	var tank := MegaTank.new()
	tank.name = "MegaTank"
	tank.puppet = Net.is_client()
	add_child(tank)
	G.tank = tank
	tank.destroyed.connect(_on_tank_destroyed)
	_build_camera()
	_build_gate()
	hud = Hud.new()
	add_child(hud)
	menu = TitleMenu.new()
	hud.add_child(menu)
	menu.play_local.connect(_on_menu_play)
	menu.host_game.connect(_on_menu_host)
	menu.join_game.connect(_on_menu_join)
	Net.connect_failed.connect(_on_connect_failed)
	Net.host_lost.connect(_on_host_lost)
	if Net.is_client():
		_start_client()
	elif not G.menu_done:
		_set_state(State.MENU)
	else:
		_enter_lobby()


func _exit_tree() -> void:
	if Net.connect_failed.is_connected(_on_connect_failed):
		Net.connect_failed.disconnect(_on_connect_failed)
		Net.host_lost.disconnect(_on_host_lost)


# --- Setup -----------------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.006, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.8
	env.glow_hdr_scale = 2.0
	var levels := [0.0, 1.0, 1.0, 0.8, 0.5, 0.3, 0.0]
	for i in levels.size():
		env.set_glow_level(i, levels[i])
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAM_SIZE
	camera.near = 1.0
	camera.far = 400.0
	camera.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	add_child(camera)
	var b := camera.global_basis
	_screen_right = Vector3(b.x.x, 0.0, b.x.z).normalized()
	_screen_up = Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	_cam_target = G.tank.global_position
	_update_camera(1.0)


func _build_gate() -> void:
	_gate = Node3D.new()
	_gate.position = GATE_POS
	add_child(_gate)
	var c := Color(1.0, 0.3, 0.85)
	for side in [-1.0, 1.0]:
		_gate_meshes.append(G.neon_box(_gate, Vector3(0.7, 5.5, 0.7), Vector3(side * 4.8, 2.75, 0), c, 3.0))
	_gate_meshes.append(G.neon_box(_gate, Vector3(10.3, 0.7, 0.7), Vector3(0, 5.85, 0), c, 3.0))
	_gate_meshes.append(G.neon_box(_gate, Vector3(9.0, 0.05, 3.0), Vector3(0, 0.03, 0), c, 1.5))
	var label := Label3D.new()
	label.text = G.t("DEPLOY")
	label.font = G.ui_font
	label.font_size = 96
	label.outline_size = 16
	label.pixel_size = 0.016
	label.modulate = c
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 7.2, 0)
	_gate.add_child(label)


func _set_state(s: State) -> void:
	state = s
	menu.visible = s == State.MENU
	match s:
		State.MENU, State.LOBBY:
			G.play_music("lobby")
		State.PLAYING:
			G.play_music("battle")
			if is_instance_valid(_gate):
				_gate.queue_free()
		State.GAMEOVER:
			G.play_music("gameover")


# --- Menu ------------------------------------------------------------------------------------

func _on_menu_play() -> void:
	G.menu_done = true
	_enter_lobby()


func _on_menu_host() -> void:
	if not Net.host():
		menu.show_status(["could not open port %d - is another game hosting here?", Net.PORT])
		return
	G.menu_done = true
	_enter_lobby()


func _on_menu_join(ip: String) -> void:
	menu.show_status(["connecting to %s ...", ip])
	Net.join(ip)


func _on_connect_failed(reason: Variant) -> void:
	if state == State.MENU:
		menu.show_status(reason)


func _on_host_lost() -> void:
	G.menu_done = false
	G.menu_message = "the host left the game"
	_restart_local()


func _enter_lobby() -> void:
	_set_state(State.LOBBY)
	if G.is_mobile() and not G.joined_devices.has(TouchInput.TOUCH_DEVICE):
		G.joined_devices.append(TouchInput.TOUCH_DEVICE)
	for dev in G.joined_devices.duplicate():
		_join(PlayerInput.for_device(dev), false)
	_fill_bots()


## Back out of the current game: lobby -> menu, game -> lobby.
func go_back() -> void:
	match state:
		State.MENU:
			get_tree().quit()
		State.LOBBY:
			Net.leave()
			G.menu_done = false
			G.joined_devices.clear()
			G.round_seed = 0
			_restart_local()
		_:
			if Net.is_client():
				Net.leave()
				G.menu_done = false
				_restart_local()
			else:
				_restart()


# --- Players ---------------------------------------------------------------------------------

## A new player takes over the first AI crew member (keeping its station), or gets a new seat.
func _join(input: PlayerInput, announce := true) -> void:
	var crew: Crew = null
	var took_over := false
	for c in players:
		if c.is_bot():
			crew = c
			took_over = true
			break
	if crew:
		crew.set_input(input)
	elif players.size() < MAX_PLAYERS:
		crew = _add_crew(input)
	else:
		return
	_candidates.erase(input.device)
	if not G.joined_devices.has(input.device):
		G.joined_devices.append(input.device)
	if announce:
		G.sfx("join")
		_toast(["P%d JOINED THE CREW%s", crew.index + 1, [" - TOOK OVER FROM AI" if took_over else ""]])


func _add_crew(input: PlayerInput) -> Crew:
	var crew := Crew.new()
	crew.setup(players.size(), input, G.tank)
	crew.puppet = Net.is_client()
	G.tank.add_crew(crew, players.size())
	players.append(crew)
	return crew


func human_count() -> int:
	var n := 0
	for c in players:
		if not c.is_bot():
			n += 1
	return n


## Host: a phone joined over the LAN.
func remote_joined(device: int) -> void:
	if state == State.MENU:
		return
	if human_count() >= MAX_PLAYERS:
		_toast("a phone joined as a spectator - the crew is full")
		return
	_join(NetInput.new(device))


## Host: a phone left; its seat goes back to the AI.
func remote_left(device: int) -> void:
	G.joined_devices.erase(device)
	for c in players:
		if c.input.device == device:
			c.set_input(BotInput.new(c.index))
			_toast(["P%d LEFT - AI TAKES OVER", c.index + 1])
	_fill_bots()


## Keeps the AI crew in sync with the setting: bots fill every empty seat once someone has joined.
func _fill_bots() -> void:
	if Net.is_client() or state == State.MENU:
		return
	if G.ai_crew and human_count() > 0:
		while players.size() < MAX_PLAYERS:
			_add_crew(BotInput.new(players.size()))
	elif not G.ai_crew:
		while not players.is_empty() and players.back().is_bot():
			var c: Crew = players.pop_back()
			G.tank.leave(c)
			G.tank.crew_members.erase(c)
			c.queue_free()


func toggle_ai_crew() -> void:
	if Net.is_client():
		return
	G.ai_crew = not G.ai_crew
	G.save_records()
	_fill_bots()
	_toast(["AI CREW %s", ["ON" if G.ai_crew else "OFF"]])


## Gives every AI crew member a job: drive and cannon first, then breaches, then MG and repair
## (repair first when the hull is low).
## Players always have priority; jammed stations are skipped so bots go patch them instead.
func _assign_bots() -> void:
	var bots: Array[Crew] = []
	for c in players:
		if c.is_bot():
			bots.append(c)
	if bots.is_empty():
		return
	var tank := G.tank
	var tasks: Array[Dictionary] = []
	for id in ["drive", "cannon"]:
		_add_station_task(tasks, id)
	for b in tank.breaches:
		tasks.append({"kind": "fix", "breach": b})
	# A badly damaged hull makes repair more urgent than the machine gun.
	var order := ["repair", "mg"] if tank.hp < MegaTank.MAX_HP * 0.6 else ["mg", "repair"]
	for id in order:
		_add_station_task(tasks, id)
	for task in tasks:
		if bots.is_empty():
			break
		var target: Vector2
		if task["kind"] == "station":
			target = tank.stations[task["id"]].pos
		else:
			target = (task["breach"] as Breach).deck_pos
		var best: Crew = null
		var best_cost := INF
		for b in bots:
			var cost := b.deck_pos.distance_to(target)
			var current: Dictionary = (b.input as BotInput).task
			if task["kind"] == "station" and b.station and b.station.id == task["id"]:
				cost -= 10.0
			elif task["kind"] == "fix" and current.get("breach") == task["breach"]:
				cost -= 5.0
			if cost < best_cost:
				best = b
				best_cost = cost
		(best.input as BotInput).task = task
		bots.erase(best)
	for b in bots:
		(b.input as BotInput).task = {}


func _add_station_task(tasks: Array[Dictionary], id: String) -> void:
	var st: MegaTank.Station = G.tank.stations[id]
	if st.jammed or (st.occupant and not st.occupant.is_bot()):
		return
	if id == "drive" and state != State.PLAYING:
		return
	tasks.append({"kind": "station", "id": id})


func _poll_joins() -> void:
	if human_count() >= MAX_PLAYERS or state == State.GAMEOVER or state == State.MENU:
		return
	var devices: Array[int] = [PlayerInput.KEYBOARD_1, PlayerInput.KEYBOARD_2]
	devices.append_array(Input.get_connected_joypads())
	for dev in devices:
		if G.joined_devices.has(dev):
			continue
		if not _candidates.has(dev):
			_candidates[dev] = PlayerInput.new(dev)
		var input: PlayerInput = _candidates[dev]
		input.poll()
		if input.action_pressed:
			_join(input)


## Converts a stick/WASD vector (screen space, y down) into a flat world direction.
func stick_to_world(v: Vector2) -> Vector3:
	return _screen_right * v.x - _screen_up * v.y


## LAN client: the puppet enemy with this network id (or null).
func puppet_by_id(id: int) -> Enemy:
	var e: Enemy = _puppets.get(id)
	return e if is_instance_valid(e) else null


## Inverse of stick_to_world, used by the AI crew to "push" the stick toward a world direction.
func world_to_stick(w: Vector3) -> Vector2:
	return Vector2(w.dot(_screen_right), -w.dot(_screen_up))


# --- Loop ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if Net.is_client():
		_client_process(delta)
		return
	_fill_bots()
	_bot_t -= delta
	if _bot_t <= 0.0:
		_bot_t = 0.25
		_assign_bots()
	for crew in players:
		crew.input.poll()
	_poll_joins()
	match state:
		State.LOBBY:
			_lobby()
		State.PLAYING:
			_playing(delta)
		State.GAMEOVER:
			_gameover(delta)
	if _leaving:
		return
	_update_camera(delta)
	RenderingServer.global_shader_parameter_set("tank_pos", G.tank.global_position)
	hud.refresh(self, delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed and pad.button_index == JOY_BUTTON_BACK:
		toggle_ai_crew()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			hud.crt.visible = not hud.crt.visible
		KEY_F2:
			toggle_ai_crew()
		KEY_M:
			G.toggle_music()
		KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_ESCAPE:
			go_back()


func _lobby() -> void:
	var used_up := G.demo and G.demo_left <= 0.0
	var pulse := 0.4 if used_up else 2.0 + sin(_time * 4.0) * 1.2
	for m in _gate_meshes:
		G.set_neon(m, Color(1.0, 0.3, 0.85), pulse)
	if G.tank.global_position.distance_to(GATE_POS) < 4.5:
		if used_up:
			if _gate_msg_t <= 0.0:
				_gate_msg_t = 3.0
				_banner("DEMO OVER", [["the demo's 10 minutes of battle are used up"], ["get the full game: %s", G.STORE_URL]], 3.0)
		else:
			start_game()
	_gate_msg_t -= get_process_delta_time()


func start_game() -> void:
	G.reset_round()
	G.explode(GATE_POS, 5.0, 0.0, G.Team.PLAYER, Color(1.0, 0.3, 0.85))
	_set_state(State.PLAYING)
	wave = 0
	survival_time = 0.0
	_wave_break = 3.0
	_banner("出撃！  DEPLOYED", "survive as long as you can - keep every station crewed")
	G.announce("deploy")


func _playing(delta: float) -> void:
	survival_time += delta
	_wave_clock += delta
	if G.demo:
		G.demo_left = maxf(0.0, G.demo_left - delta)
		if G.demo_left <= 0.0:
			_end_demo()
			return
	G.difficulty = minf(3.0, 1.0 + 0.07 * maxf(wave - 1, 0) + survival_time / 900.0)
	if _wave_break > 0.0:
		_wave_break -= delta
		if _wave_break <= 0.0:
			_start_wave()
		return
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if not spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and alive < 40:
			_spawn_next()
	elif alive == 0:
		var bonus := wave * 50
		G.add_score(bonus)
		G.tank.hp = minf(MegaTank.MAX_HP, G.tank.hp + 40.0)
		_banner(["WAVE %d CLEAR", wave], ["+%d   hull patched +40", bonus])
		G.announce("clear")
		_wave_break = 8.0
	elif _wave_clock > 40.0 + wave * 2.0 and not is_instance_valid(boss):
		# Too slow: the next wave rolls in on top of the stragglers (never during a boss fight).
		_start_wave(true)


func _start_wave(reinforcements := false) -> void:
	wave += 1
	_wave_clock = 0.0
	G.difficulty = minf(3.0, 1.0 + 0.07 * (wave - 1) + survival_time / 900.0)
	# Wave size follows the number of crew (players plus AI), so a full crew faces more.
	var counts := wave_counts(wave, players.size())
	var theme: String = counts.get("theme", "")
	counts.erase("theme")
	var boss_wave := wave % BOSS_EVERY == 0
	for kind in counts:
		for i in counts[kind]:
			spawn_queue.append(kind)
	spawn_queue.shuffle()
	if boss_wave:
		spawn_queue.append("boss")  # spawned first (the queue is popped from the back)
	_spawn_angle = randf() * TAU
	_spawn_timer = 0.0
	# Text specs (see G.tx) so every phone shows the banner in its own language.
	var title: Variant = ["増援！  REINFORCEMENTS - WAVE %d" if reinforcements else "敵襲来！  WAVE %d", wave]
	var detail: Variant = _wave_detail(counts)
	match theme:
		"drones":
			title = ["ドローン嵐！  DRONE STORM - WAVE %d", wave]
		"armour":
			title = ["装甲部隊！  ARMOUR COLUMN - WAVE %d", wave]
		"mortars":
			title = ["迫撃砲！  MORTAR BARRAGE - WAVE %d", wave]
	if boss_wave:
		title = ["ボス出現！  BOSS - WAVE %d", wave]
		detail = "鬼戦車 ONI SENSHA - the demon tank approaches"
	_banner(title, detail)
	G.sfx("wave")
	G.announce("boss" if boss_wave else ("reinforce" if reinforcements else "wave"))


## What a wave sends in, by enemy type. Grows with the wave number and with the crew size
## (players plus AI). Every third wave from wave 6 has a theme. "hornets" is a swarm of five.
static func wave_counts(w: int, crew: int) -> Dictionary:
	var crew_scale := 0.8 + 0.15 * maxi(crew, 1)
	var boss_wave := w % BOSS_EVERY == 0
	var rifles := int(round((2.0 + w * 1.1) * crew_scale * (0.5 if boss_wave else 1.0)))
	var rpgs := int(round((w - 1) * 0.7 * crew_scale))
	var tanks := 0 if boss_wave else int(floor((w - 1) * 0.3 * crew_scale))
	var heavies := 0 if boss_wave else maxi(0, (w - 4) / 3)
	var drones := maxi(0, int((w - 2) * 0.5 * crew_scale))
	var buggies := maxi(0, int((w - 3) * 0.45 * crew_scale))
	var swarms := 0 if w < 2 else 1 + int((w - 2) * 0.25 * crew_scale)
	var mortars := 0 if w < 3 else 1 + int((w - 3) * 0.25 * crew_scale)
	var trucks := 0 if boss_wave or w < 4 else 1 + (w - 4) / 5
	var gunships := 0 if boss_wave or w < 6 else 1 + (w - 6) / 4
	if boss_wave:
		mortars /= 2
		swarms = maxi(1, swarms / 2)
	var theme := ""
	if not boss_wave and w >= 6 and w % 3 == 0:
		theme = ["drones", "armour", "mortars"][(w / 3) % 3]
		match theme:
			"drones":
				drones = drones * 2 + 2
				swarms += 2
				rifles /= 2
				tanks = 0
			"armour":
				tanks += 2
				heavies += 1
				trucks += 1
				rifles /= 2
			"mortars":
				mortars += 3
				rpgs += 2
				buggies = 0
	return {"rifle": rifles, "rpg": rpgs, "tank": tanks, "heavy": heavies, "drone": drones,
		"buggy": buggies, "hornets": swarms, "mortar": mortars, "truck": trucks, "gunship": gunships,
		"theme": theme}


## Banner text for a wave's line-up: two lines, only the enemy types that are coming.
func _wave_detail(counts: Dictionary) -> Variant:
	var first: Variant = ["%d INFANTRY   %d RPG   %d TANKS", counts["rifle"], counts["rpg"], counts["tank"] + counts["heavy"]]
	var names := [["drone", "%d DRONES"], ["buggy", "%d BUGGIES"], ["hornets", "%d HORNET SWARMS"],
		["mortar", "%d MORTARS"], ["truck", "%d BARRIER TRUCKS"], ["gunship", "%d GUNSHIPS"]]
	var parts := []
	for n in names:
		if counts[n[0]] > 0:
			parts.append([n[1], counts[n[0]]])
	if parts.is_empty():
		return first
	var fmt := "   ".join(PackedStringArray(_repeat("%s", parts.size())))
	var second: Array = [fmt]
	second.append_array(parts)
	return [first, second]


static func _repeat(text: String, count: int) -> Array:
	var out := []
	for i in count:
		out.append(text)
	return out


## Builds an enemy of the given type (also used for puppets on LAN clients).
func _create_enemy(kind: String) -> Enemy:
	var e: Enemy
	match kind:
		"hornet":
			e = Hornet.new()
		"mortar":
			e = MortarTeam.new()
		"truck":
			e = ShieldTruck.new()
		"gunship":
			e = Gunship.new()
		"tank":
			e = EnemyTank.new()
		"heavy":
			var t := EnemyTank.new()
			t.heavy = true
			e = t
		"rpg":
			var s := Soldier.new()
			s.rpg = true
			e = s
		"drone":
			e = Drone.new()
		"buggy":
			e = Buggy.new()
		"boss":
			e = BossTank.new()
		_:
			e = Soldier.new()
	e.kind = kind
	return e


func _spawn_next() -> void:
	var kind: String = spawn_queue.back()
	var big := kind in ["tank", "heavy", "boss", "truck", "gunship"]
	var pos: Variant = _find_spawn_point(4.5 if kind == "boss" else (3.0 if big else 1.0))
	if pos == null:
		_spawn_timer = 0.3
		return
	spawn_queue.pop_back()
	if kind == "hornets":
		# A swarm: five hornets in a loose cluster.
		for i in 5:
			var off := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
			spawn_quick("hornet", (pos as Vector3) + off)
		G.sfx("wave", -12.0, 2.2)
		_spawn_timer = 0.8
		return
	var e := _create_enemy(kind)
	e.position = pos
	_enemies_root.add_child(e)
	if kind == "boss":
		boss = e
	_spawn_timer = 1.2 if big else 0.45
	if randf() < 0.2:
		_spawn_angle += randf_range(-1.5, 1.5)


## Spawns an enemy right away at a given spot (e.g. drones launched by the boss).
func spawn_quick(kind: String, pos: Vector3) -> void:
	var e := _create_enemy(kind)
	e.position = Vector3(pos.x, 0.0, pos.z)
	_enemies_root.add_child(e)


func _find_spawn_point(radius: float) -> Variant:
	var center := G.tank.global_position
	var lim := City.HALF - 4.0
	for attempt in 12:
		var ang := _spawn_angle + randf_range(-0.7, 0.7)
		var p := center + Vector3(sin(ang), 0.0, cos(ang)) * randf_range(32.0, 42.0)
		# Snap onto the nearest street so enemies arrive along the roads.
		if randf() < 0.5:
			p.x = roundf(p.x / City.PERIOD) * City.PERIOD + randf_range(-2.0, 2.0)
		else:
			p.z = roundf(p.z / City.PERIOD) * City.PERIOD + randf_range(-2.0, 2.0)
		p.x = clampf(p.x, -lim, lim)
		p.z = clampf(p.z, -lim, lim)
		p.y = 0.0
		if p.distance_to(center) > 24.0 and _is_free(p, radius):
			return p
	_spawn_angle = randf() * TAU
	return null


func _is_free(p: Vector3, radius: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	q.shape = s
	q.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
	q.collision_mask = G.LAYER_TERRAIN | G.LAYER_PLAYER | G.LAYER_ENEMY
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Demo build: the 10 minutes of battle are up. The fighting stops and the store link shows.
func _end_demo() -> void:
	if _demo_over:
		return
	_demo_over = true
	_set_state(State.GAMEOVER)
	_gameover_timer = 2.5
	spawn_queue.clear()
	G.tank.invulnerable = true
	for node in get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		G.explode(e.global_position, 2.5, 0.0, G.Team.PLAYER, e.color)
		e.score_value = 0
		e.die()
	new_record = G.submit_run(survival_time, wave, G.score)
	G.announce("clear")
	var lines := [
		["survived %s   wave %d   score %d", G.format_time(survival_time), wave, G.score],
		["the full game is endless - get it on itch.io"],
		[G.STORE_URL],
		[""],
		["press ACTION for the menu"],
	]
	_banner("デモ終了  DEMO OVER - THANKS FOR PLAYING!", lines, 999.0)


func _on_tank_destroyed() -> void:
	if Net.is_client() or _demo_over:
		return
	_set_state(State.GAMEOVER)
	_gameover_timer = 2.5
	spawn_queue.clear()
	new_record = G.submit_run(survival_time, wave, G.score)
	G.announce("record" if new_record else "gameover")
	var lines := [
		["survived %s   wave %d   score %d", G.format_time(survival_time), wave, G.score],
		["★ 新記録！ NEW RECORD! ★"] if new_record else ["best %s  (wave %d)", G.format_time(G.best_time), G.best_wave],
		[""],
		["press ACTION to redeploy"],
	]
	_banner("ゲームオーバー  TANK DESTROYED", lines, 999.0)


func _gameover(delta: float) -> void:
	_gameover_timer -= delta
	if _gameover_timer > 0.0:
		return
	for crew in players:
		if crew.input.action_pressed:
			if _demo_over:
				# Back to the title menu, where the store button is.
				Net.leave()
				G.menu_done = false
				_restart_local()
				return
			_restart()
			return


## Host/local: next round in a fresh city; LAN clients rebuild along with us.
func _restart() -> void:
	G.round_seed = randi()
	Net.new_round(G.round_seed)
	_restart_local()


func _restart_local() -> void:
	_leaving = true
	get_tree().reload_current_scene()


## Title and subtitle are text specs (see G.tx): each phone translates them itself.
func _banner(title: Variant, subtitle: Variant = "", time := 2.5) -> void:
	hud.banner(title, subtitle, time)
	Net.send_event("banner", [title, subtitle, time], true)


func _toast(text: Variant) -> void:
	hud.toast(text)
	Net.send_event("toast", [text], true)


func _update_camera(delta: float) -> void:
	if cinematic.is_valid():
		cinematic.call(delta)
		return
	var tank := G.tank
	var target := tank.global_position + tank.velocity * 0.4
	_cam_target = _cam_target.lerp(target, 1.0 - exp(-delta * 3.0))
	G.shake = maxf(0.0, G.shake - delta * 2.2)
	var b := camera.global_basis
	var jitter := (b.x * randf_range(-1.0, 1.0) + b.y * randf_range(-1.0, 1.0)) * G.shake * 0.5
	camera.global_position = _cam_target + b.z * 120.0 + jitter


# --- LAN replication -------------------------------------------------------------------------

## Host: what a phone needs when it joins mid-round.
func welcome_state() -> Dictionary:
	return {"destroyed": G.city.destroyed_ids, "state": state}


## Host: the world as phones see it, sent 20 times per second.
func make_snapshot() -> Array:
	var crew := []
	for c in players:
		crew.append(c.net_state())
	var enemies := []
	for e in get_tree().get_nodes_in_group("enemies"):
		enemies.append((e as Enemy).net_state())
	return [state, wave, survival_time, G.score, G.tank.net_state(), crew, enemies]


func _start_client() -> void:
	local_input = TouchInput.new()
	G.city.apply_destroyed(Net.welcome.get("destroyed", []))
	_set_state(Net.welcome.get("state", State.LOBBY))
	Net.client_ready(self)


func _client_process(delta: float) -> void:
	if state == State.LOBBY:
		var pulse := 2.0 + sin(_time * 4.0) * 1.2
		for m in _gate_meshes:
			if is_instance_valid(m):
				G.set_neon(m, Color(1.0, 0.3, 0.85), pulse)
	if _leaving:
		return
	_update_camera(delta)
	RenderingServer.global_shader_parameter_set("tank_pos", G.tank.global_position)
	hud.refresh(self, delta)


func apply_snapshot(data: Array) -> void:
	var s: State = data[0]
	if s != state:
		_set_state(s)
	wave = data[1]
	survival_time = data[2]
	G.score = data[3]
	G.tank.apply_net(data[4])
	var crew_states: Array = data[5]
	for i in crew_states.size():
		var cs: Array = crew_states[i]
		var device: int = cs[0]
		if i >= players.size():
			_add_crew(_puppet_input(device, i))
		var c := players[i]
		if c.input.device != device:
			c.set_input(_puppet_input(device, i))
		c.apply_net(cs)
	var seen := {}
	for es in data[6]:
		var id: int = es[0]
		seen[id] = true
		var e: Enemy = _puppets.get(id)
		if e == null:
			e = _create_enemy(es[1])
			e.puppet = true
			e.position = Vector3(es[2], 0.0, es[3])
			_enemies_root.add_child(e)
			e.net_id = id
			_puppets[id] = e
			if e.kind == "boss":
				boss = e
		e.apply_net(es)
	for id in _puppets.keys():
		if not seen.has(id):
			var e: Enemy = _puppets[id]
			_puppets.erase(id)
			if is_instance_valid(e):
				e.remove_from_group("enemies")
				e.queue_free()


func _puppet_input(device: int, slot: int) -> PlayerInput:
	if device <= -100:
		return BotInput.new(slot)
	return PlayerInput.new(device)


func apply_events(batch: Array) -> void:
	for ev in batch:
		var a: Array = ev[1]
		match ev[0]:
			"block":
				G.city.destroy_by_id(a[0], a[1])
			"fall":
				G.city.fall_by_id(a[0], a[1])
			"popup":
				G.popup(a[0], a[1], a[2], a[3])
			"shield_hit":
				G.tank.shield_hit_fx(a[0])
			"dome_hit":
				var truck := puppet_by_id(a[0]) as ShieldTruck
				if truck:
					truck.dome_hit_fx(a[1])
			"mortar":
				var shell := MortarShell.new()
				shell.setup(a[0], a[1], a[2], a[3])
				shell.visual_only = true
				G.fx_root.add_child(shell)
			"rumble":
				G.rumble_remote(a[0], a[1])
			"explode":
				G.explode(a[0], a[1], 0.0, G.Team.PLAYER, a[2])
			"ring":
				G.ring(a[0], a[1], a[2], a[3], a[4])
			"sparks":
				G.sparks(a[0], a[1], a[2], a[3], a[4], a[5], a[6])
			"debris":
				G.debris(a[0], a[1], a[2], a[3], a[4])
			"sfx":
				G.sfx(a[0], a[1], a[2])
			"shout":
				G.shout(a[0], a[1], a[2])
			"announce":
				G.announce(a[0])
			"proj":
				G.spawn_projectile(a[0], a[1], a[2], a[3], a[4], a[5])
			"proj_end":
				var p: Projectile = G.net_projectiles.get(a[0])
				if is_instance_valid(p):
					p.end()
			"banner":
				hud.banner(a[0], a[1], a[2])
			"toast":
				hud.toast(a[0])
