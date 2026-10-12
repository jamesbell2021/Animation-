class_name Main
extends Node3D
## Game root: builds the neon city, the mega tank and the isometric camera, handles drop-in
## joining, the lobby DEPLOY gate, enemy waves and game over.

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

func _join(input: PlayerInput, announce := true) -> void:
	if players.size() >= MAX_PLAYERS:
		return
	var crew := Crew.new()
	crew.setup(players.size(), input, G.tank)
	G.tank.add_crew(crew, players.size())
	players.append(crew)
	_candidates.erase(input.device)
	if not G.joined_devices.has(input.device):
		G.joined_devices.append(input.device)
	if announce:
		G.sfx("join")
		hud.toast("P%d JOINED THE CREW" % players.size())


func _poll_joins() -> void:
	if players.size() >= MAX_PLAYERS or state == State.GAMEOVER:
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


# --- Loop ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
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
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			hud.crt.visible = not hud.crt.visible
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
	_wave_break = 3.0
	hud.banner("DEPLOYED", "hostiles inbound - keep every station crewed")


func _playing(delta: float) -> void:
	if _wave_break > 0.0:
		_wave_break -= delta
		if _wave_break <= 0.0:
			_start_wave()
		return
	if not spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_next()
	elif get_tree().get_nodes_in_group("enemies").is_empty():
		var bonus := wave * 50
		G.add_score(bonus)
		G.tank.hp = minf(MegaTank.MAX_HP, G.tank.hp + 30.0)
		hud.banner("WAVE %d CLEAR" % wave, "+%d   hull patched +30" % bonus)
		_wave_break = 5.0


func _start_wave() -> void:
	wave += 1
	var crew_scale := 0.75 + 0.25 * maxi(players.size(), 1)
	var rifles := int(round((2.0 + wave * 1.6) * crew_scale))
	var rpgs := int(round((wave - 1) * 0.9 * crew_scale))
	var tanks := int(floor((wave - 1) * 0.5 * crew_scale))
	spawn_queue.clear()
	for i in rifles:
		spawn_queue.append("rifle")
	for i in rpgs:
		spawn_queue.append("rpg")
	for i in tanks:
		spawn_queue.append("tank")
	spawn_queue.shuffle()
	_spawn_angle = randf() * TAU
	_spawn_timer = 0.0
	hud.banner("WAVE %d" % wave, "%d INFANTRY   %d RPG   %d TANKS" % [rifles, rpgs, tanks])
	G.sfx("wave")


func _spawn_next() -> void:
	var kind: String = spawn_queue.back()
	var pos: Variant = _find_spawn_point(3.0 if kind == "tank" else 1.0)
	if pos == null:
		_spawn_timer = 0.3
		return
	spawn_queue.pop_back()
	var e: Enemy
	match kind:
		"tank":
			e = EnemyTank.new()
		"rpg":
			var s := Soldier.new()
			s.rpg = true
			e = s
		_:
			e = Soldier.new()
	e.position = pos
	_enemies_root.add_child(e)
	_spawn_timer = 1.2 if kind == "tank" else 0.45
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
	hud.banner("TANK DESTROYED", "reached wave %d   score %d\n\npress ACTION to redeploy" % [wave, G.score], 999.0)


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
