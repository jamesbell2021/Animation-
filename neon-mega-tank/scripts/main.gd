class_name Main
extends Node3D
## Game root: builds the neon city, the mega tank and the isometric camera, handles drop-in
## joining, AI crew, the lobby DEPLOY gate, endless escalating waves, survival time and game over.

enum State { LOBBY, PLAYING, GAMEOVER }

const MAX_PLAYERS := 4
const CAM_SIZE := 28.0
const GATE_POS := Vector3(0, 0, -22)

var state := State.LOBBY
var players: Array[Crew] = []
var camera: Camera3D
var hud: Hud
var wave := 0
var spawn_queue: Array[String] = []
var survival_time := 0.0
var new_record := false

var _candidates := {}
var _cam_target := Vector3.ZERO
var _screen_right := Vector3.RIGHT
var _screen_up := Vector3.FORWARD
var _gate: Node3D
var _gate_meshes: Array[MeshInstance3D] = []
var _enemies_root: Node3D
var _spawn_timer := 0.0
var _spawn_angle := 0.0
var _wave_break := 0.0
var _gameover_timer := 0.0
var _time := 0.0
var _leaving := false
var _wave_clock := 0.0
var _bot_t := 0.0


func _ready() -> void:
	G.main = self
	G.reset_round()
	_build_environment()
	G.fx_root = Node3D.new()
	G.fx_root.name = "Fx"
	add_child(G.fx_root)
	var city := City.new()
	city.name = "City"
	add_child(city)
	G.city = city
	city.generate()
	_enemies_root = Node3D.new()
	_enemies_root.name = "Enemies"
	add_child(_enemies_root)
	var tank := MegaTank.new()
	tank.name = "MegaTank"
	add_child(tank)
	G.tank = tank
	tank.destroyed.connect(_on_tank_destroyed)
	_build_camera()
	_build_gate()
	hud = Hud.new()
	add_child(hud)
	for dev in G.joined_devices.duplicate():
		_join(PlayerInput.new(dev), false)
	_fill_bots()
	G.play_music("lobby")


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
	label.text = "DEPLOY"
	label.font = G.ui_font
	label.font_size = 96
	label.outline_size = 16
	label.pixel_size = 0.016
	label.modulate = c
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 7.2, 0)
	_gate.add_child(label)


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
		hud.toast("P%d JOINED THE CREW%s" % [crew.index + 1, " - TOOK OVER FROM AI" if took_over else ""])


func _add_crew(input: PlayerInput) -> Crew:
	var crew := Crew.new()
	crew.setup(players.size(), input, G.tank)
	G.tank.add_crew(crew, players.size())
	players.append(crew)
	return crew


func human_count() -> int:
	var n := 0
	for c in players:
		if not c.is_bot():
			n += 1
	return n


## Keeps the AI crew in sync with the setting: bots fill every empty seat once someone has joined.
func _fill_bots() -> void:
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
	G.ai_crew = not G.ai_crew
	G.save_records()
	_fill_bots()
	hud.toast("AI CREW %s" % ("ON" if G.ai_crew else "OFF"))


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
	if human_count() >= MAX_PLAYERS or state == State.GAMEOVER:
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


## Inverse of stick_to_world, used by the AI crew to "push" the stick toward a world direction.
func world_to_stick(w: Vector3) -> Vector2:
	return Vector2(w.dot(_screen_right), -w.dot(_screen_up))


# --- Loop ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
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
			if state == State.LOBBY:
				get_tree().quit()
			else:
				_restart()


func _lobby() -> void:
	var pulse := 2.0 + sin(_time * 4.0) * 1.2
	for m in _gate_meshes:
		G.set_neon(m, Color(1.0, 0.3, 0.85), pulse)
	if G.tank.global_position.distance_to(GATE_POS) < 4.5:
		start_game()


func start_game() -> void:
	state = State.PLAYING
	G.reset_round()
	G.explode(GATE_POS, 5.0, 0.0, G.Team.PLAYER, Color(1.0, 0.3, 0.85))
	_gate.queue_free()
	wave = 0
	survival_time = 0.0
	_wave_break = 3.0
	hud.banner("出撃！  DEPLOYED", "survive as long as you can - keep every station crewed")
	G.announce("deploy")
	G.play_music("battle")


func _playing(delta: float) -> void:
	survival_time += delta
	_wave_clock += delta
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
		hud.banner("WAVE %d CLEAR" % wave, "+%d   hull patched +40" % bonus)
		G.announce("clear")
		_wave_break = 8.0
	elif _wave_clock > 40.0 + wave * 2.0:
		# Too slow: the next wave rolls in on top of the stragglers.
		_start_wave(true)


func _start_wave(reinforcements := false) -> void:
	wave += 1
	_wave_clock = 0.0
	G.difficulty = minf(3.0, 1.0 + 0.07 * (wave - 1) + survival_time / 900.0)
	# Wave size follows the number of crew (players plus AI), so a full crew faces more.
	var crew_scale := 0.8 + 0.15 * maxi(players.size(), 1)
	var rifles := int(round((2.0 + wave * 1.1) * crew_scale))
	var rpgs := int(round((wave - 1) * 0.7 * crew_scale))
	var tanks := int(floor((wave - 1) * 0.35 * crew_scale))
	var heavies := maxi(0, (wave - 4) / 3)
	for i in rifles:
		spawn_queue.append("rifle")
	for i in rpgs:
		spawn_queue.append("rpg")
	for i in tanks:
		spawn_queue.append("tank")
	for i in heavies:
		spawn_queue.append("heavy")
	spawn_queue.shuffle()
	_spawn_angle = randf() * TAU
	_spawn_timer = 0.0
	var title := ("増援！  REINFORCEMENTS - WAVE %d" if reinforcements else "敵襲来！  WAVE %d") % wave
	var detail := "%d INFANTRY   %d RPG   %d TANKS" % [rifles, rpgs, tanks]
	if heavies > 0:
		detail += "   %d HEAVY" % heavies
	hud.banner(title, detail)
	G.sfx("wave")
	G.announce("reinforce" if reinforcements else "wave")


func _spawn_next() -> void:
	var kind: String = spawn_queue.back()
	var pos: Variant = _find_spawn_point(1.0 if kind == "rifle" or kind == "rpg" else 3.0)
	if pos == null:
		_spawn_timer = 0.3
		return
	spawn_queue.pop_back()
	var e: Enemy
	match kind:
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
		_:
			e = Soldier.new()
	e.position = pos
	_enemies_root.add_child(e)
	_spawn_timer = 0.45 if kind == "rifle" or kind == "rpg" else 1.2
	if randf() < 0.2:
		_spawn_angle += randf_range(-1.5, 1.5)


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


func _on_tank_destroyed() -> void:
	state = State.GAMEOVER
	_gameover_timer = 2.5
	spawn_queue.clear()
	new_record = G.submit_run(survival_time, wave, G.score)
	G.play_music("gameover")
	G.announce("record" if new_record else "gameover")
	var lines := "survived %s   wave %d   score %d" % [G.format_time(survival_time), wave, G.score]
	lines += "\n" + ("★ 新記録！ NEW RECORD! ★" if new_record else "best %s  (wave %d)" % [G.format_time(G.best_time), G.best_wave])
	hud.banner("ゲームオーバー  TANK DESTROYED", lines + "\n\npress ACTION to redeploy", 999.0)


func _gameover(delta: float) -> void:
	_gameover_timer -= delta
	if _gameover_timer > 0.0:
		return
	for crew in players:
		if crew.input.action_pressed:
			_restart()
			return


func _restart() -> void:
	_leaving = true
	get_tree().reload_current_scene()


func _update_camera(delta: float) -> void:
	var tank := G.tank
	var target := tank.global_position + tank.velocity * 0.4
	_cam_target = _cam_target.lerp(target, 1.0 - exp(-delta * 3.0))
	G.shake = maxf(0.0, G.shake - delta * 2.2)
	var b := camera.global_basis
	var jitter := (b.x * randf_range(-1.0, 1.0) + b.y * randf_range(-1.0, 1.0)) * G.shake * 0.5
	camera.global_position = _cam_target + b.z * 120.0 + jitter
