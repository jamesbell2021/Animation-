extends Node3D
## Builds the whole island in code and wires the run together.

const SpawnerScript := preload("res://scenes/systems/spawner.gd")
const HudScript := preload("res://scenes/ui/hud.gd")

const FENCE_RING := 9.0
const FENCE_SECTIONS := 8
const FENCE_GAP := 1.0
const SCAVENGE_RING := 12.0
const SPAWN_RING := 17.0
const SPAWN_POINTS := 6
const PLAYER_START := Vector3(4.0, 0.0, 4.0)
const CAMERA_POS := Vector3(0.0, 22.0, 18.0)
const CAMERA_TARGET := Vector3(0.0, 0.0, 3.8)
const CAMERA_FOV := 47.0
const LIGHT_TWEEN := 2.0
const GRASS_TUFTS := 4200

# Scavenge layout: [angle_deg, kind, amount]. Angle 0 points toward the camera (+Z).
const SCAVENGE := [
	[40.0, "driftwood", 2],
	[160.0, "driftwood", 2],
	[280.0, "driftwood", 2],
	[100.0, "scrap", 1],
	[220.0, "bio", 1],
	[330.0, "bio", 1],
]

# Per phase: background, ambient colour and energy, sun colour and energy,
# distance fog density, volumetric fog density, fog glow tint.
var _lighting := [
	{"bg": Color(0.60, 0.67, 0.72), "amb": Color(0.62, 0.68, 0.76), "amb_e": 0.55, "sun": Color(1.0, 0.92, 0.78), "sun_e": 1.3, "fog": 0.002, "vfog": 0.005, "tint": Color(0.70, 0.75, 0.80)},
	{"bg": Color(0.34, 0.31, 0.38), "amb": Color(0.52, 0.44, 0.52), "amb_e": 0.38, "sun": Color(1.0, 0.58, 0.36), "sun_e": 0.8, "fog": 0.008, "vfog": 0.03, "tint": Color(0.52, 0.42, 0.44)},
	{"bg": Color(0.03, 0.05, 0.08), "amb": Color(0.26, 0.36, 0.52), "amb_e": 0.42, "sun": Color(0.55, 0.68, 0.95), "sun_e": 0.5, "fog": 0.01, "vfog": 0.03, "tint": Color(0.10, 0.14, 0.20)},
	{"bg": Color(0.52, 0.50, 0.55), "amb": Color(0.60, 0.55, 0.60), "amb_e": 0.42, "sun": Color(1.0, 0.74, 0.58), "sun_e": 0.95, "fog": 0.006, "vfog": 0.02, "tint": Color(0.62, 0.56, 0.58)},
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
	player.position = PLAYER_START + Vector3(0.0, Terrain.height_at_v(PLAYER_START) + 0.2, 0.0)
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
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 0.95
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_bloom = 0.06
	_env.glow_hdr_threshold = 1.0
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.ssao_enabled = true
	_env.ssao_radius = 1.2
	_env.ssao_intensity = 1.8
	_env.fog_enabled = true
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)
	_env.volumetric_fog_emission_energy = 1.0
	_env.volumetric_fog_anisotropy = 0.45
	_env.volumetric_fog_length = 48.0
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.0
	_env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 60.0
	add_child(_sun)

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	var mesh := Terrain.build_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Look.vertex_mat(0.95)
	ground.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	ground.add_child(cs)
	_build_rocks()
	_build_grass()

func _build_rocks() -> void:
	# Boulders along the shore, a few on the plateau, and sea stacks out in the swell.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var shore := [15.0, 75.0, 130.0, 190.0, 250.0, 305.0]
	for k in shore.size():
		var a := deg_to_rad(float(shore[k]))
		for i in 4:
			var r := rng.randf_range(12.4, 14.2)
			var aa := a + rng.randf_range(-0.12, 0.12)
			var p := Vector3(sin(aa) * r, 0.0, cos(aa) * r)
			var s := rng.randf_range(0.4, 1.1) * (1.3 if i == 0 else 0.8)
			p.y = Terrain.height_at_v(p) - s * 0.15
			Look.rock(self, k * 31 + i * 7 + 3, Vector3(s * 1.3, s * 0.9, s * 1.1), p)
	var boulders := [Vector3(-5.5, 0, -6.5), Vector3(6.8, 0, -3.5), Vector3(-9.5, 0, 2.5), Vector3(2.5, 0, -10.0)]
	for i in boulders.size():
		var p: Vector3 = boulders[i]
		p.y = Terrain.height_at_v(p) - 0.1
		Look.rock(self, 500 + i * 13, Vector3(0.9, 0.6, 0.8), p, Look.STONE, 0.8)
	var stacks := [Vector3(-19.0, 0, -11.0), Vector3(20.5, 0, -8.0), Vector3(-8.0, 0, -20.0), Vector3(13.0, 0, -18.0), Vector3(-21.5, 0, 4.0), Vector3(22.0, 0, 6.5)]
	for i in stacks.size():
		var p: Vector3 = stacks[i]
		var h := 2.5 + float(i % 3) * 1.4
		p.y = Terrain.SEA_LEVEL - 0.6
		Look.rock(self, 900 + i * 17, Vector3(2.4, h * 2.0, 2.0), p, Color(0.26, 0.27, 0.27), 0.5)

func _build_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1890
	var xforms: Array[Transform3D] = []
	for i in GRASS_TUFTS:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(3.2 * 3.2, 11.9 * 11.9))
		var p := Vector3(sin(a) * r, 0.0, cos(a) * r)
		p.y = Terrain.height_at_v(p)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.35))
		xforms.append(Transform3D(b, p))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Look.grass_tuft_mesh()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	plane.subdivide_width = 110
	plane.subdivide_depth = 110
	sea.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sea.gdshader")
	sea.material_override = mat
	sea.position = Vector3(0.0, Terrain.SEA_LEVEL, 0.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		f.position.y = Terrain.height_at_v(f.position)
		# Local +X becomes (cos a, 0, -sin a): the tangent of the ring at this angle.
		f.rotation.y = a
		add_child(f)

func _build_scavenge() -> void:
	for s in SCAVENGE:
		var a := deg_to_rad(float(s[0]))
		var sp := ScavengePoint.new(String(s[1]), int(s[2]))
		sp.position = Vector3(sin(a), 0.0, cos(a)) * SCAVENGE_RING
		sp.position.y = Terrain.height_at_v(sp.position)
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
	var cfg: Dictionary = _lighting[p]
	if _tween and _tween.is_valid():
		_tween.kill()
	var tint: Color = cfg["tint"]
	var targets := [
		[_env, "background_color", cfg["bg"]],
		[_env, "fog_light_color", cfg["bg"]],
		[_env, "ambient_light_color", cfg["amb"]],
		[_env, "ambient_light_energy", cfg["amb_e"]],
		[_sun, "light_color", cfg["sun"]],
		[_sun, "light_energy", cfg["sun_e"]],
		[_env, "fog_density", cfg["fog"]],
		[_env, "volumetric_fog_density", cfg["vfog"]],
		[_env, "volumetric_fog_emission", tint * 0.12],
	]
	if duration <= 0.0:
		for t in targets:
			t[0].set(t[1], t[2])
		return
	_tween = create_tween().set_parallel(true)
	for t in targets:
		_tween.tween_property(t[0], t[1], t[2], duration)

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
