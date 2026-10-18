extends Node3D
## Builds the whole island in code and wires the run together.

const SpawnerScript := preload("res://scenes/systems/spawner.gd")
const HudScript := preload("res://scenes/ui/hud.gd")
const TitleScript := preload("res://scenes/ui/title.gd")
const PauseScript := preload("res://scenes/ui/pause.gd")
const TITLE_ORBIT_SPEED := 0.05
const SPRAY_EVERY := 1.6
# Where each keeper appears when a run starts, around the lighthouse door.
const SPAWNS := [Vector3(2.5, 0.0, 4.0), Vector3(-1.5, 0.0, 4.5), Vector3(1.0, 0.0, 5.6)]

const FENCE_RING := 9.0
const FENCE_SECTIONS := 8
const FENCE_GAP := 1.0
const SCAVENGE_RING := 12.3
const SPAWN_RING := 17.0
const SPAWN_POINTS := 6
const CAMERA_POS := Vector3(0.0, 26.0, 19.0)
const CAMERA_TARGET := Vector3(0.0, 2.0, 4.0)
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
var players: Array[Player] = []
var title: CanvasLayer
var _title_cam: Camera3D
var _title_t := 0.0
var _spray_t := 0.0
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
	lighthouse.position = Vector3(0.0, Terrain.height_at(0.0, 0.0), 0.0)
	add_child(lighthouse)
	_build_homestead()
	_build_fences()
	_build_scavenge()
	_build_camera()
	_enemies = Node3D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_build_spawner()
	hud = HudScript.new()
	hud.lighthouse = lighthouse
	hud.lamp = lighthouse.lamp
	add_child(hud)
	add_child(PauseScript.new())

	Cycle.phase_changed.connect(_on_phase_changed)
	Events.run_ended.connect(_on_run_ended)
	Audio.start_ambience()

	# Tests and CI run headless and start straight away; so does New Run from game over.
	if DisplayServer.get_name() == "headless" or Run.quick_start:
		Run.quick_start = false
		begin_run(true, Players.wanted)
	else:
		_show_title()

func _show_title() -> void:
	Run.active = false
	hud.visible = false
	_apply_lighting(Cycle.Phase.DUSK, 0.0)
	_title_cam = Camera3D.new()
	_title_cam.fov = 50.0
	add_child(_title_cam)
	_title_cam.current = true
	lighthouse.lamp.showcase = true
	lighthouse.lamp._set_state(Lamp.State.BURNING)
	title = TitleScript.new()
	title.start_requested.connect(begin_run)
	add_child(title)

## Start (or continue) a run with n keepers.
func begin_run(continue_save: bool, n: int) -> void:
	if title != null:
		title.queue_free()
		title = null
	if _title_cam != null:
		_title_cam.queue_free()
		_title_cam = null
	camera.current = true
	lighthouse.lamp.showcase = false
	lighthouse.lamp._set_state(Lamp.State.OFF)
	Players.configure(n)
	for i in Players.wanted:
		var p := Player.new()
		p.idx = i
		var at: Vector3 = SPAWNS[i % SPAWNS.size()]
		p.position = at + Vector3(0.0, Terrain.height_at_v(at) + 0.2, 0.0)
		p.camera = camera
		p.lamp = lighthouse.lamp
		Players.nodes.append(p)
		players.append(p)
		add_child(p)
	player = players[0]
	hud.player = player
	hud.players = players
	hud.visible = true
	var d := SaveSys.load_run() if continue_save else {}
	if not d.is_empty():
		Run.start_loaded(d)
	else:
		Run.start_new()
	lighthouse.lamp.fuel = Run.lamp_fuel
	_apply_lighting(Cycle.Phase.DAY, 0.0)
	Cycle.start(Cycle.Phase.DAY)

func _process(delta: float) -> void:
	if _title_cam != null:
		_title_t += delta * TITLE_ORBIT_SPEED
		var a := _title_t * TAU + 0.6
		_title_cam.look_at_from_position(Vector3(sin(a) * 27.0, 10.0, cos(a) * 27.0), Vector3(-4.0, 3.5, 0.0), Vector3.UP)
	_spray_t -= delta
	if _spray_t <= 0.0:
		_spray_t = SPRAY_EVERY * randf_range(0.5, 1.5)
		var a2 := randf() * TAU
		var r := 13.2 + randf() * 0.8
		FX.sea_spray(self, Vector3(sin(a2) * r, Terrain.SEA_LEVEL, cos(a2) * r))
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
	# Crags all round the cliffs, a few boulders on the plateau, and sea stacks in the swell.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var scav_angles: Array[float] = []
	for s in SCAVENGE:
		scav_angles.append(deg_to_rad(float(s[0])))
	for i in 46:
		var a := rng.randf() * TAU
		var clear := true
		for sa in scav_angles:
			if absf(wrapf(a - sa, -PI, PI)) < 0.16:
				clear = false
		if not clear:
			continue
		var r := rng.randf_range(10.6, 14.0)
		var p := Vector3(sin(a) * r, 0.0, cos(a) * r)
		var s := rng.randf_range(0.6, 1.5)
		p.y = Terrain.height_at_v(p) - s * 0.2
		Look.rock(self, 40 + i * 7, Vector3(s * 1.4, s * 1.1, s * 1.2), p, Color(0.34, 0.33, 0.31), 0.45)
	var boulders := [Vector3(-2.5, 0, -7.0), Vector3(7.4, 0, 1.5), Vector3(-8.2, 0, 0.5), Vector3(2.5, 0, -8.0)]
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
		var r := sqrt(rng.randf_range(3.2 * 3.2, 10.6 * 10.6))
		var p := Vector3(sin(a) * r, 0.0, cos(a) * r)
		if not Terrain.is_grassy(p.x, p.z):
			continue
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

func _on_pad(x: float, z: float) -> Vector3:
	return Vector3(x, Terrain.height_at(x, z), z)

func _face_inward(n: Node3D) -> void:
	# Local +Z points away from the lighthouse, so doors on local -Z face it.
	n.rotation.y = atan2(n.position.x, n.position.z)

func _build_homestead() -> void:
	var cottage := Cottage.new()
	cottage.position = _on_pad(Terrain.PADS[0][0], Terrain.PADS[0][1])
	_face_inward(cottage)
	add_child(cottage)
	var garden := Garden.new()
	garden.position = _on_pad(Terrain.PADS[1][0], Terrain.PADS[1][1])
	_face_inward(garden)
	add_child(garden)
	_build_shed(_on_pad(Terrain.PADS[2][0], Terrain.PADS[2][1]))

func _build_shed(at: Vector3) -> void:
	# Oil and tool store: scenery that blocks movement but takes no damage.
	var shed := StaticBody3D.new()
	shed.name = "Shed"
	shed.collision_layer = 4
	shed.collision_mask = 0
	shed.position = at
	_face_inward(shed)
	add_child(shed)
	var stone := Look.flat_mat(Color(0.44, 0.43, 0.40))
	var walls := Geo.box(shed, Vector3(2.4, 1.6, 2.0), Color.WHITE, Vector3(0.0, 0.8, 0.0))
	walls.material_override = stone
	var roof := Geo.box(shed, Vector3(2.7, 0.12, 2.4), Color.WHITE, Vector3(0.0, 1.75, 0.0))
	roof.material_override = Look.flat_mat(Color(0.20, 0.22, 0.25), 0.6)
	roof.rotation.x = deg_to_rad(-12.0)
	Geo.box(shed, Vector3(0.75, 1.25, 0.08), Color(0.30, 0.22, 0.14), Vector3(0.2, 0.62, -1.03))
	var barrel := Geo.cyl(shed, 0.28, 0.8, Color.WHITE, Vector3(-0.85, 0.4, -1.35))
	barrel.material_override = Look.flat_mat(Color(0.18, 0.2, 0.22), 0.5)
	Geo.box_shape(shed, Vector3(2.4, 1.6, 2.0), Vector3(0.0, 0.8, 0.0))

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
