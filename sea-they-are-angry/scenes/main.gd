extends Node3D
## Builds the whole island in code and wires the run together.

const SpawnerScript := preload("res://scenes/systems/spawner.gd")
const HudScript := preload("res://scenes/ui/hud.gd")

const ISLAND_RADIUS := 14.0
const FENCE_RING := 9.0
const FENCE_SECTIONS := 8
const FENCE_GAP := 1.0
const SCAVENGE_RING := 12.0
const SPAWN_RING := 17.0
const SPAWN_POINTS := 6
const PLAYER_START := Vector3(4.0, 0.1, 4.0)
const CAMERA_POS := Vector3(0.0, 22.0, 18.0)
const CAMERA_TARGET := Vector3(0.0, 0.0, 3.8)
const CAMERA_FOV := 47.0
const LIGHT_TWEEN := 2.0
const SEA_COLOR := Color(0.08, 0.14, 0.2)
const ROCK_COLOR := Color(0.42, 0.44, 0.46)

# Scavenge layout: [angle_deg, kind, amount]. Angle 0 points toward the camera (+Z).
const SCAVENGE := [
	[40.0, "driftwood", 2],
	[160.0, "driftwood", 2],
	[280.0, "driftwood", 2],
	[100.0, "scrap", 1],
	[220.0, "bio", 1],
	[330.0, "bio", 1],
]

# Per phase: background colour, ambient energy, sun energy, fog density.
var _lighting := [
	[Color(0.55, 0.62, 0.68), 0.6, 1.0, 0.012],
	[Color(0.3, 0.33, 0.42), 0.35, 0.4, 0.03],
	[Color(0.05, 0.07, 0.12), 0.12, 0.08, 0.045],
	[Color(0.45, 0.5, 0.55), 0.45, 0.6, 0.02],
]

var lighthouse: Lighthouse
var player: Player
var camera: Camera3D
var spawner: Node
var hud: CanvasLayer
var _env: Environment
var _sun: DirectionalLight3D
var _enemies: Node3D
var _tween: Tween

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_sea()
	lighthouse = Lighthouse.new()
	add_child(lighthouse)
	_build_fences()
	_build_scavenge()
	_build_camera()
	player = Player.new()
	player.position = PLAYER_START
	player.camera = camera
	player.lamp = lighthouse.lamp
	add_child(player)
	_enemies = Node3D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_build_spawner()
	hud = HudScript.new()
	hud.player = player
	hud.lighthouse = lighthouse
	hud.lamp = lighthouse.lamp
	add_child(hud)

	Cycle.phase_changed.connect(_on_phase_changed)
	Events.run_ended.connect(_on_run_ended)

	var d := SaveSys.load_run()
	if not d.is_empty():
		Run.start_loaded(d)
	else:
		Run.start_new()
	lighthouse.lamp.fuel = Run.lamp_fuel
	_apply_lighting(Cycle.Phase.DAY, 0.0)
	Cycle.start(Cycle.Phase.DAY)

func _process(_delta: float) -> void:
	if Run.active and Input.is_action_just_pressed("skip"):
		Cycle.skip()

# ---- world ----

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.72, 0.78, 0.88)
	_env.fog_enabled = true
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_sun.shadow_enabled = true
	add_child(_sun)

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	Geo.cyl(ground, ISLAND_RADIUS, 1.0, ROCK_COLOR, Vector3(0.0, -0.5, 0.0))
	Geo.cyl_shape(ground, ISLAND_RADIUS, 1.0, Vector3(0.0, -0.5, 0.0))
	# Decorative rocks along the shore; no collision.
	var rocks := [[15.0, 13.2, 0.9], [75.0, 12.9, 0.6], [130.0, 13.3, 1.1], [190.0, 13.0, 0.7], [250.0, 13.4, 1.0], [305.0, 12.8, 0.8]]
	for r in rocks:
		var a := deg_to_rad(float(r[0]))
		var p := Vector3(sin(a), 0.0, cos(a)) * float(r[1])
		var s := float(r[2])
		var rock := Geo.box(self, Vector3(s * 1.4, s, s * 1.1), ROCK_COLOR.darkened(0.25), p + Vector3(0.0, s * 0.35, 0.0))
		rock.rotation = Vector3(0.2, a * 1.7, 0.15)
		Geo.sphere(self, s * 0.55, ROCK_COLOR.darkened(0.15), p + Vector3(s * 0.6, s * 0.15, s * 0.3))

func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	sea.mesh = plane
	sea.material_override = Geo.mat(SEA_COLOR)
	sea.position = Vector3(0.0, -0.4, 0.0)
	add_child(sea)

func _build_fences() -> void:
	# Eight straight sections on chords of the ring, with keeper-width gaps between them.
	var step := TAU / float(FENCE_SECTIONS)
	var chord := 2.0 * FENCE_RING * sin(step * 0.5)
	var mid_radius := FENCE_RING * cos(step * 0.5)
	for i in FENCE_SECTIONS:
		var a := step * float(i)
		var f := Fence.new(chord - FENCE_GAP)
		f.position = Vector3(sin(a), 0.0, cos(a)) * mid_radius
		# Local +X becomes (cos a, 0, -sin a): the tangent of the ring at this angle.
		f.rotation.y = a
		add_child(f)

func _build_scavenge() -> void:
	for s in SCAVENGE:
		var a := deg_to_rad(float(s[0]))
		var sp := ScavengePoint.new(String(s[1]), int(s[2]))
		sp.position = Vector3(sin(a), 0.0, cos(a)) * SCAVENGE_RING
		add_child(sp)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	add_child(camera)
	camera.position = CAMERA_POS
	camera.look_at(CAMERA_TARGET, Vector3.UP)
	camera.current = true

func _build_spawner() -> void:
	spawner = SpawnerScript.new()
	spawner.name = "Spawner"
	var pts: Array[Vector3] = []
	for i in SPAWN_POINTS:
		var a := TAU * (float(i) + 0.5) / float(SPAWN_POINTS)
		pts.append(Vector3(sin(a), 0.0, cos(a)) * SPAWN_RING)
	spawner.points = pts
	spawner.enemies_root = _enemies
	spawner.lighthouse = lighthouse
	add_child(spawner)

# ---- cycle ----

func _apply_lighting(p: int, duration: float) -> void:
	var cfg: Array = _lighting[p]
	var bg: Color = cfg[0]
	if _tween and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0:
		_env.background_color = bg
		_env.fog_light_color = bg
		_env.ambient_light_energy = cfg[1]
		_sun.light_energy = cfg[2]
		_env.fog_density = cfg[3]
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_env, "background_color", bg, duration)
	_tween.tween_property(_env, "fog_light_color", bg, duration)
	_tween.tween_property(_env, "ambient_light_energy", cfg[1], duration)
	_tween.tween_property(_sun, "light_energy", cfg[2], duration)
	_tween.tween_property(_env, "fog_density", cfg[3], duration)

func _on_phase_changed(p: int) -> void:
	_apply_lighting(p, LIGHT_TWEEN)
	if p == Cycle.Phase.DAWN and Run.active:
		var damaged := 0
		for s in get_tree().get_nodes_in_group("structures"):
			if s is Structure and s.is_damaged():
				damaged += 1
		Run.lamp_fuel = lighthouse.lamp.fuel
		Run.advance_night(damaged)

func _on_run_ended(_reason: String, _night: int) -> void:
	Cycle.stop()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
