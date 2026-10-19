extends Node3D
## Builds the whole island in code and wires the run together.

const SpawnerScript := preload("res://scenes/systems/spawner.gd")
const HudScript := preload("res://scenes/ui/hud.gd")
const TitleScript := preload("res://scenes/ui/title.gd")
const PauseScript := preload("res://scenes/ui/pause.gd")
const TITLE_ORBIT_SPEED := 0.05
const SPRAY_EVERY := 1.6
# Where each keeper appears when a run starts: the crag top, round the lighthouse door.
const SPAWNS := [Vector3(-1.6, 0.0, 2.7), Vector3(-2.9, 0.0, 0.8), Vector3(0.4, 0.0, 3.2)]

# Fences close the chokepoints: the head of each beach gully, and the ledge path
# at its foot and halfway up. Each leaves a gap a keeper fits through but a Bloated doesn't.
const FENCE_GAP := 0.9
const BEACH_FENCE_T := 0.9
const LEDGE_FENCES := [0.08, 0.58]
# Creatures land offshore of each beach, either side of its centre line.
const LANDING_OFFSET := 1.8
const CAMERA_POS := Vector3(0.0, 41.0, 27.0)
const CAMERA_TARGET := Vector3(0.0, 3.0, 1.0)
const CAMERA_FOV := 45.0
const LIGHT_TWEEN := 2.0
const GRASS_TUFTS := 9500
const JETTY_LATERAL := 4.2
# Keepers' ladders down the east-south-east face, from the top to the ledge and the ledge
# to the meadow: above the upper ledge fence, so they land on the defended side of it,
# and clear of the lighthouse door so the lamp and refuel prompts win there.
const LADDER_ANGLE := 66.0

# Scavenge washes up on the beaches: [beach index, t up the beach, lateral offset, kind, amount].
const SCAVENGE := [
	[0, 0.55, 2.0, "driftwood", 2],
	[0, 0.62, -2.0, "scrap", 1],
	[1, 0.55, 2.0, "driftwood", 2],
	[1, 0.62, -2.0, "bio", 1],
	[2, 0.55, -2.0, "driftwood", 2],
	[2, 0.62, 2.0, "bio", 1],
	# Kelp for mending the garden, low on the west beach by the tideline.
	[2, 0.46, 0.0, "seaweed", 2],
]

# Per phase: background, ambient colour and energy, sun colour and energy,
# distance fog density, volumetric fog density, fog glow tint.
var _lighting := [
	{"bg": Color(0.60, 0.67, 0.72), "amb": Color(0.62, 0.68, 0.76), "amb_e": 0.55, "sun": Color(1.0, 0.92, 0.78), "sun_e": 1.3, "fog": 0.0013, "vfog": 0.0035, "tint": Color(0.70, 0.75, 0.80)},
	{"bg": Color(0.34, 0.31, 0.38), "amb": Color(0.52, 0.44, 0.52), "amb_e": 0.38, "sun": Color(1.0, 0.58, 0.36), "sun_e": 0.8, "fog": 0.005, "vfog": 0.019, "tint": Color(0.52, 0.42, 0.44)},
	{"bg": Color(0.03, 0.05, 0.08), "amb": Color(0.26, 0.36, 0.52), "amb_e": 0.72, "sun": Color(0.55, 0.68, 0.95), "sun_e": 0.85, "fog": 0.0075, "vfog": 0.024, "tint": Color(0.10, 0.14, 0.20)},
	{"bg": Color(0.52, 0.50, 0.55), "amb": Color(0.60, 0.55, 0.60), "amb_e": 0.42, "sun": Color(1.0, 0.74, 0.58), "sun_e": 0.95, "fog": 0.004, "vfog": 0.013, "tint": Color(0.62, 0.56, 0.58)},
]

var lighthouse: Lighthouse
var player: Player
var players: Array[Player] = []
var title: CanvasLayer
var _title_cam: Camera3D
var _title_t := 0.0
var _spray_t := 0.0
var _gutter_horn_t := 0.0
var _warned_low := false
# This night's tally for the dawn report.
var _tally := {}
const HORN_GUTTER_EVERY := 7.0
const FIRST_DAY_TIP_TIME := 14.0
var camera: Camera3D
var spawner: Node
var hud: CanvasLayer
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sea_mat: ShaderMaterial
var atmosphere: Atmosphere
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
	_build_ladders()
	_build_scavenge()
	_build_camera()
	_enemies = Node3D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_build_spawner()
	atmosphere = Atmosphere.new()
	atmosphere.env = _env
	atmosphere.sky_mat = _sky_mat
	atmosphere.sea_mat = _sea_mat
	add_child(atmosphere)
	hud = HudScript.new()
	hud.lighthouse = lighthouse
	hud.lamp = lighthouse.lamp
	add_child(hud)
	add_child(PauseScript.new())

	Cycle.phase_changed.connect(_on_phase_changed)
	Events.run_ended.connect(_on_run_ended)
	# Bound methods, not lambdas: Events outlives this scene, and only methods disconnect themselves when it's freed.
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.structure_destroyed.connect(_on_structure_destroyed)
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
	atmosphere.apply(Cycle.Phase.NIGHT, 0.0)
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
	if d.is_empty():
		hud.report("The first day.", [
			"Gather driftwood, scrap and bio on the three beaches. The ladders down the crag are on its east side.",
			"Mend fences with driftwood (E). At dusk the lamp lights: stand by the door and work it (R).",
			"They come ashore on the beaches and climb the ledge. Q focuses the beam to burn them,",
			"and on the ledge a blow aimed outward knocks them over the edge.",
		], FIRST_DAY_TIP_TIME)
	_apply_lighting(Cycle.Phase.DAY, 0.0)
	atmosphere.apply(Cycle.Phase.DAY, 0.0)
	Cycle.start(Cycle.Phase.DAY)

func _process(delta: float) -> void:
	if _title_cam != null:
		_title_t += delta * TITLE_ORBIT_SPEED
		var a := _title_t * TAU + 0.6
		_title_cam.look_at_from_position(Vector3(sin(a) * 38.0, 15.0, cos(a) * 38.0), Vector3(-3.0, 6.0, 0.0), Vector3.UP)
	_spray_t -= delta
	if _spray_t <= 0.0:
		_spray_t = SPRAY_EVERY * randf_range(0.5, 1.5)
		var a2 := randf() * 360.0
		var r := Terrain.coast_radius(a2) + Terrain.CLIFF_WIDTH * 0.8
		FX.sea_spray(self, Vector3(sin(deg_to_rad(a2)) * r, Terrain.SEA_LEVEL, cos(deg_to_rad(a2)) * r))
	if Run.active and Input.is_action_just_pressed("skip"):
		Cycle.skip()
	_alarms(delta)

static func compass(p: Vector3) -> String:
	# The camera looks north (-Z), so +Z is south and +X is east.
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var a := fposmod(atan2(p.x, -p.z), TAU)
	return names[int(round(a / (TAU / 8.0))) % 8]

func _on_enemy_killed(e: Node) -> void:
	var how = e.get("last_hit")
	_count(String(how) if how else "hook")

func _on_structure_destroyed(s: Node) -> void:
	if s is Fence:
		_count("fence")
	elif s is Structure and Enemy.HOME_IDS.has(s.id):
		_count("home")

func _count(key: String, n: int = 1) -> void:
	_tally[key] = int(_tally.get(key, 0)) + n

func _on_wave_incoming(_points: Array, count: int) -> void:
	_count("ashore", count)

# One foghorn blast per landing, and a warning naming what and where.
func _on_group_warning(kind: String, points: Array, raid: bool) -> void:
	Audio.horn([1.0] if points.size() == 1 else [1.0, 1.0], -5.0)
	var what: String = SpawnerScript.WARNINGS.get(kind, "Something stirs in the water")
	var where: Array[String] = []
	for p in points:
		where.append(compass(p))
	var text := "%s — %s." % [what, " and ".join(where)]
	if raid:
		text += "  They're making for the cottage!"
	hud.warn(text)

# Four short blasts: the light is smothered.
func _on_smothered(on: bool) -> void:
	if on and Run.active:
		_count("smother")
		Audio.horn([1.0, 1.0, 1.0, 1.0], -1.0)
		hud.warn("The light is smothered! Strike the tower's foot to shake it loose!")

func _unhandled_input(event: InputEvent) -> void:
	# Debug builds: F9 brings the Eel now.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and Run.active:
		spawner.force_eel()

# Foghorn alarms: a guttering lamp blasts every few seconds; a failing lighthouse warns once a night.
func _alarms(delta: float) -> void:
	if not Run.active:
		return
	var lamp := lighthouse.lamp
	if lamp.state == Lamp.State.GUTTERING:
		_gutter_horn_t -= delta
		if _gutter_horn_t <= 0.0:
			_gutter_horn_t = HORN_GUTTER_EVERY
			Audio.horn([1.0, 1.0, 1.0], -2.0)
			hud.warn("The lamp is guttering! Refuel it!")
	else:
		_gutter_horn_t = 0.0
	if lighthouse.health_ratio() < 0.3 and not _warned_low and lighthouse.hp > 0:
		_warned_low = true
		Audio.horn([1.0, 3.0], -2.0)
		hud.warn("The lighthouse is failing!")

# ---- world ----

func _build_environment() -> void:
	_env = Environment.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sun_angle_max = 20.0
	_sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.ssr_enabled = true
	_env.ssr_max_steps = 48
	_env.ssr_fade_in = 0.2
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
	_env.volumetric_fog_length = 64.0
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.0
	_env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 80.0
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
	Props.flowers(self, 240)
	Props.ledge_rope(self, 0.12, 0.97, 16)
	# The landing: a jetty off the east beach, with pots stacked on the shingle.
	var east := float(Terrain.BEACHES[0])
	Props.jetty(self, _shore_point(0, JETTY_LATERAL), deg_to_rad(east))
	Props.lobster_pot(self, Terrain.beach_point(0, 0.66, JETTY_LATERAL - 0.6) + Vector3(0.0, -0.05, 0.0), 0.4)
	Props.lobster_pot(self, Terrain.beach_point(0, 0.7, JETTY_LATERAL + 0.5) + Vector3(0.0, -0.05, 0.0), 1.3)
	var shed: Vector3 = _on_pad(Terrain.PADS[2][0], Terrain.PADS[2][1])
	Props.crate(self, _on_pad(shed.x + 1.9, shed.z - 0.4), 0.3)
	Props.crate(self, _on_pad(shed.x + 2.3, shed.z + 0.4), 1.1, 0.45)
	Props.barrel(self, _on_pad(shed.x - 1.9, shed.z - 0.5))
	Props.barrel(self, _on_pad(shed.x - 2.3, shed.z + 0.2), Color(0.18, 0.2, 0.22))
	var cottage: Vector3 = _on_pad(Terrain.PADS[0][0], Terrain.PADS[0][1])
	Props.washing_line(self, _on_pad(cottage.x + 3.2, cottage.z + 0.6), _on_pad(cottage.x + 2.4, cottage.z + 2.4))
	for i in 5:
		Props.gull(self, 31 + i * 17)

# Where the sea meets beach i's shingle, offset sideways.
func _shore_point(i: int, lateral: float) -> Vector3:
	var t := 0.0
	while t < 1.0 and Terrain.beach_point(i, t, lateral).y < Terrain.SEA_LEVEL + 0.4:
		t += 0.01
	return Terrain.beach_point(i, t, lateral)

func _build_rocks() -> void:
	# Crags along the foot of the cliffs and round the crag, a few boulders on the meadow, and sea stacks in the swell.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var placed := 0
	for i in 160:
		if placed >= 70:
			break
		var a := rng.randf() * 360.0
		var r := Terrain.coast_radius(a) + rng.randf_range(0.6, 2.6)
		var p := Terrain.at_angle(a, r)
		if Terrain.beach_weight(p.x, p.z) > 0.05:
			continue
		var s := rng.randf_range(0.7, 1.7)
		p.y -= s * 0.25
		Look.rock(self, 40 + i * 7, Vector3(s * 1.4, s * 1.3, s * 1.2), p, Color(0.34, 0.33, 0.31), 0.45)
		placed += 1
	# Fallen rock at the crag's foot, clear of the track.
	for i in 14:
		var a := Terrain.LEDGE_START + Terrain.LEDGE_SWEEP * 0.15 + rng.randf() * Terrain.LEDGE_SWEEP * 0.95
		var s_at := Terrain.ledge_s(sin(deg_to_rad(a)), cos(deg_to_rad(a)))
		if s_at < 0.0:
			s_at = 1.0
		var r := Terrain.ledge_radius(s_at) + Terrain.LEDGE_HALF + Terrain.CRAG_BLEND + rng.randf_range(0.1, 0.5)
		if r > Terrain.RING_R - 1.0:
			continue
		var p := Terrain.at_angle(a, r)
		var s := rng.randf_range(0.5, 1.0)
		Look.rock(self, 700 + i * 11, Vector3(s * 1.2, s, s * 1.1), p - Vector3(0.0, s * 0.2, 0.0), Color(0.36, 0.35, 0.33), 0.6)
	var boulders := [Terrain.at_angle(60.0, 12.6), Terrain.at_angle(140.0, 12.2), Terrain.at_angle(220.0, 12.4), Terrain.at_angle(300.0, 12.8), Terrain.at_angle(325.0, 11.5)]
	for i in boulders.size():
		var p: Vector3 = boulders[i]
		p.y -= 0.1
		Look.rock(self, 500 + i * 13, Vector3(0.9, 0.6, 0.8), p, Look.STONE, 0.8)
	var stacks := [Vector3(-25.0, 0, -13.0), Vector3(24.5, 0, -11.0), Vector3(-10.0, 0, -27.0), Vector3(15.0, 0, -24.0), Vector3(-26.5, 0, 9.0), Vector3(25.0, 0, 12.5), Vector3(-16.0, 0, 22.0)]
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
		var r := sqrt(rng.randf_range(3.6 * 3.6, 15.5 * 15.5))
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
	var shed := Shed.new()
	shed.position = at
	_face_inward(shed)
	add_child(shed)

func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(150.0, 150.0)
	plane.subdivide_width = 160
	plane.subdivide_depth = 160
	sea.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sea.gdshader")
	sea.material_override = mat
	_sea_mat = mat
	sea.position = Vector3(0.0, Terrain.SEA_LEVEL, 0.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

func _build_fences() -> void:
	# Across the head of each beach gully. Local +X becomes (cos a, 0, -sin a): across the beach.
	var neck := Terrain.beach_half_width(BEACH_FENCE_T)
	for i in Terrain.BEACHES.size():
		var f := Fence.new(neck * 2.0 - FENCE_GAP)
		f.position = Terrain.beach_point(i, BEACH_FENCE_T, FENCE_GAP * 0.5)
		f.rotation.y = deg_to_rad(float(Terrain.BEACHES[i]))
		add_child(f)
	# Across the ledge, gap on the inside against the crag wall.
	for s in LEDGE_FENCES:
		var a := deg_to_rad(Terrain.LEDGE_START + float(s) * Terrain.LEDGE_SWEEP)
		var r := Terrain.ledge_radius(float(s)) + FENCE_GAP * 0.5
		var f := Fence.new(Terrain.LEDGE_HALF * 2.0 - FENCE_GAP)
		f.position = Vector3(sin(a) * r, Terrain.ledge_height(float(s)), cos(a) * r)
		# Local +X along the radius.
		f.rotation.y = a - PI * 0.5
		add_child(f)

func _build_ladders() -> void:
	var a := LADDER_ANGLE
	var s := Terrain.ledge_s(sin(deg_to_rad(a)), cos(deg_to_rad(a)))
	var rho := Terrain.ledge_radius(s)
	var ledge := Terrain.ledge_height(s)
	var inner := rho - Terrain.LEDGE_HALF
	var outer := rho + Terrain.LEDGE_HALF
	var blend := Terrain.CRAG_BLEND
	var upper := Ladder.new(Terrain.at_angle(a, inner - blend - 0.5), Terrain.at_angle(a, inner + 0.4),
		_at(a, inner - blend, Terrain.CRAG_TOP + 0.05), _at(a, inner + 0.1, ledge))
	add_child(upper)
	var lower := Ladder.new(Terrain.at_angle(a, outer - 0.4), Terrain.at_angle(a, outer + blend + 0.6),
		_at(a, outer - 0.05, ledge + 0.05), _at(a, outer + blend + 0.1, Terrain.PLATEAU_HEIGHT))
	add_child(lower)

func _at(a_deg: float, r: float, y: float) -> Vector3:
	return Vector3(sin(deg_to_rad(a_deg)) * r, y, cos(deg_to_rad(a_deg)) * r)

func _build_scavenge() -> void:
	for s in SCAVENGE:
		var sp := ScavengePoint.new(String(s[3]), int(s[4]))
		sp.position = Terrain.beach_point(int(s[0]), float(s[1]), float(s[2]))
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
	for i in Terrain.BEACHES.size():
		for side in [-1.0, 1.0]:
			pts.append(Terrain.beach_point(i, 0.0, side * LANDING_OFFSET))
	spawner.points = pts
	spawner.enemies_root = _enemies
	spawner.lighthouse = lighthouse
	add_child(spawner)
	spawner.wave_incoming.connect(_on_wave_incoming)
	spawner.group_warning.connect(_on_group_warning)
	lighthouse.lamp.smothered_changed.connect(_on_smothered)

# ---- cycle ----

func _apply_lighting(p: int, duration: float) -> void:
	var cfg: Dictionary = _lighting[p]
	if _tween and _tween.is_valid():
		_tween.kill()
	var tint: Color = cfg["tint"]
	var bg: Color = cfg["bg"]
	var targets := [
		[_sky_mat, "sky_top_color", bg.darkened(0.35)],
		[_sky_mat, "sky_horizon_color", bg],
		[_sky_mat, "ground_horizon_color", bg.darkened(0.2)],
		[_sky_mat, "ground_bottom_color", bg.darkened(0.7)],
		[_sky_mat, "sun_angle_max", 20.0 if p == Cycle.Phase.DAY else 8.0],
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
	if p == Cycle.Phase.DAWN:
		_warned_low = false
	if p == Cycle.Phase.DUSK:
		_tally = {}
	if p == Cycle.Phase.DAWN and Run.active:
		_dawn_report()
		var damaged := 0
		for s in get_tree().get_nodes_in_group("structures"):
			if s is Structure and s.is_damaged():
				damaged += 1
		Run.lamp_fuel = lighthouse.lamp.fuel
		Run.advance_night(damaged)

# The keeper's log: what came, what stopped it, what it cost, and one thing to try next.
func _dawn_report() -> void:
	var t := _tally
	var g := func(k: String) -> int: return int(t.get(k, 0))
	var how: Array[String] = []
	if g.call("beam") > 0:
		how.append("%d burned" % g.call("beam"))
	if g.call("fall") > 0:
		how.append("%d over the edge" % g.call("fall"))
	if g.call("hook") > 0:
		how.append("%d to the boathook" % g.call("hook"))
	var lines: Array[String] = []
	lines.append("%d came ashore%s" % [g.call("ashore"), (" · " + " · ".join(how)) if not how.is_empty() else ""])
	var cost: Array[String] = []
	if g.call("reached") > 0:
		cost.append("%d reached the light" % g.call("reached"))
	if g.call("fence") > 0:
		cost.append("%d fence%s broken" % [g.call("fence"), "" if g.call("fence") == 1 else "s"])
	var hurt_home: Array[String] = []
	for s in get_tree().get_nodes_in_group("structures"):
		if s is Structure and Enemy.HOME_IDS.has(s.id) and s.is_damaged():
			hurt_home.append(s.id)
	if not hurt_home.is_empty():
		cost.append("%s damaged" % " and ".join(hurt_home))
	cost.append("lighthouse %d/%d" % [lighthouse.hp, lighthouse.max_hp])
	cost.append("fuel %d%%" % roundi(lighthouse.lamp.fuel))
	lines.append(" · ".join(cost))
	var tip := ""
	if lighthouse.lamp.fuel < 30.0:
		tip = "Fuel is low: gather bio on the beaches and refuel at the lighthouse door."
	elif g.call("reached") > 0:
		tip = "Meet climbers on the ledge: a blow aimed outward knocks them over the edge."
	elif g.call("smother") > 0:
		tip = "When something climbs the tower, burn it on the ledge or strike the tower's foot to shake it down."
	elif g.call("fence") > 0:
		tip = "Mend broken fences with driftwood before dark."
	elif not hurt_home.is_empty():
		tip = "Take the hammer to the homestead: the cottage and shed take driftwood, the garden kelp too."
	elif g.call("beam") < g.call("ashore") / 2:
		tip = "The focused beam (Q) burns them on the beaches, long before they climb."
	if tip != "":
		lines.append("")
		lines.append(tip)
	hud.report("Night %d held." % Run.night, lines)

func _on_run_ended(_reason: String, _night: int) -> void:
	Cycle.stop()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
