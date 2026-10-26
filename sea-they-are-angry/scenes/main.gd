extends Node3D
## Builds the whole island in code and wires the run together.

const SpawnerScript := preload("res://scenes/systems/spawner.gd")
const HudScript := preload("res://scenes/ui/hud.gd")
const TitleScript := preload("res://scenes/ui/title.gd")
const PauseScript := preload("res://scenes/ui/pause.gd")
const TITLE_ORBIT_SPEED := 0.05
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
const HOLM_GRASS_TUFTS := 5000
const JETTY_LATERAL := 4.2
# Keepers' ladders down the east-south-east face, from the top to the ledge and the ledge
# to the meadow: above the upper ledge fence, so they land on the defended side of it,
# and clear of the lighthouse door so the lamp and refuel prompts win there.
const LADDER_ANGLE := 66.0

# Scavenge washes up on the beaches: [beach index, t up the beach, lateral offset, kind, amount].
const SCAVENGE := [
	[0, 0.55, 2.0, "driftwood", 2],
	[0, 0.62, -2.0, "scrap", 2],
	[1, 0.55, 2.0, "driftwood", 2],
	[1, 0.62, -2.0, "bio", 1],
	[2, 0.55, -2.0, "driftwood", 2],
	[2, 0.62, 2.0, "bio", 1],
	# Kelp for the garden (mending it, and digging into the beds), by the tideline.
	[2, 0.46, 0.0, "seaweed", 2],
	[0, 0.4, -1.6, "seaweed", 1],
]
# On the holm's beaches: jerrycans of diesel for the camp's generator, and a little more.
# [holm beach index, t up the beach, lateral offset, kind, amount].
const HOLM_SCAVENGE := [
	[0, 0.62, 1.6, "diesel", 1],
	[1, 0.6, -1.4, "diesel", 1],
	[0, 0.5, -1.8, "driftwood", 1],
	[1, 0.52, 1.8, "scrap", 1],
]
# A third keeper finds a little more on the south beach.
const SCAVENGE_CROWD := [1, 0.46, -0.6, "driftwood", 1]
# Trap cairns up the middle of each beach, short of the fence (a Bloated burst there
# can't reach it), then on the ledge and at its foot as defences are upgraded.
const TRAP_BEACH_T := 0.6
# The holm's defence posts: up each of its beaches, outside the camp gate, and where the
# bridge comes onto the holm.
const HOLM_POST_BEACH_T := 0.86
# Where the internees' papers turn up, about the camp (from its centre): a tin under a
# hut's step, in the greenhouse, at a tower's foot, in the long grass by the wire.
const NOTE_SPOTS := [
	Vector2(-1.2, -3.1), Vector2(6.0, 4.0), Vector2(-9.4, 6.9), Vector2(1.5, 7.2),
	Vector2(9.3, -6.8), Vector2(-8.0, -6.6), Vector2(-2.0, 3.6), Vector2(3.4, -1.0),
]
# Papers lying about at once, at most: one more turns up each dawn.
const NOTES_LYING := 2
const TRAP_LEDGE_S := 0.3
# An oil drum washes up at dawn after every third night, from the second on.
const OIL_EVERY := 3
const OIL_FIRST := 2
# The fire pit, out front of the cottage between it and the shed.
const CAMPFIRE_AT := [-22.0, 10.4]

# Per phase: background, ambient colour and energy, sun colour and energy,
# distance fog density, volumetric fog density, fog glow tint.
# How each kind of night shifts dusk and night: ambient and moon energy, fog.
const WEATHER_LIGHT := [
	{"amb": 1.2, "sun": 1.45, "fog": 0.55, "bg": Color(0.05, 0.08, 0.14), "moon": Color(0.78, 0.86, 1.0)},
	{"amb": 1.0, "sun": 1.0, "fog": 1.0, "bg": Color(0.0, 0.0, 0.0)},
	{"amb": 1.1, "sun": 0.95, "fog": 0.9, "bg": Color(0.0, 0.0, 0.0)},
]

var _lighting := [
	{"bg": Color(0.60, 0.67, 0.72), "amb": Color(0.62, 0.68, 0.76), "amb_e": 0.55, "sun": Color(1.0, 0.92, 0.78), "sun_e": 1.3, "fog": 0.0013, "vfog": 0.0035, "tint": Color(0.70, 0.75, 0.80)},
	{"bg": Color(0.34, 0.31, 0.38), "amb": Color(0.52, 0.44, 0.52), "amb_e": 0.38, "sun": Color(1.0, 0.58, 0.36), "sun_e": 0.8, "fog": 0.005, "vfog": 0.019, "tint": Color(0.52, 0.42, 0.44)},
	{"bg": Color(0.04, 0.06, 0.10), "amb": Color(0.30, 0.40, 0.56), "amb_e": 0.95, "sun": Color(0.6, 0.72, 0.98), "sun_e": 1.05, "fog": 0.006, "vfog": 0.018, "tint": Color(0.11, 0.15, 0.21)},
	{"bg": Color(0.52, 0.50, 0.55), "amb": Color(0.60, 0.55, 0.60), "amb_e": 0.42, "sun": Color(1.0, 0.74, 0.58), "sun_e": 0.95, "fog": 0.004, "vfog": 0.013, "tint": Color(0.62, 0.56, 0.58)},
]

var lighthouse: Lighthouse
var camp: Camp
var bridge: RopeBridge
var player: Player
var players: Array[Player] = []
var title: CanvasLayer
var _title_cam: Camera3D
var _title_t := 0.0
var _gutter_horn_t := 0.0
var _warned_low := false
# This night's tally for the dawn report.
var _tally := {}
const HORN_GUTTER_EVERY := 7.0
const FIRST_DAY_TIP_TIME := 14.0
# How long a page of the internees' notes stays up to be read.
const LORE_TIME := 12.0
var camera: Camera3D
## Frames the keepers' islands and splits the screen when they're apart.
var director: CameraDirector
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
	KeeperNav.reset()
	_build_environment()
	_build_ground()
	_build_sea()
	lighthouse = Lighthouse.new()
	lighthouse.position = Vector3(0.0, Terrain.height_at(0.0, 0.0), 0.0)
	add_child(lighthouse)
	_build_homestead()
	_build_holm()
	_build_fences()
	_build_ladders()
	_build_scavenge()
	_build_trap_slots()
	_build_campfire()
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
	hud.camp = camp
	add_child(hud)
	add_child(PauseScript.new())

	Cycle.phase_changed.connect(_on_phase_changed)
	Events.run_ended.connect(_on_run_ended)
	# Bound methods, not lambdas: Events outlives this scene, and only methods disconnect themselves when it's freed.
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.structure_destroyed.connect(_on_structure_destroyed)
	Events.lore.connect(_on_lore)
	Audio.start_ambience()

	# A LAN game starts when the host says (Net.start_game), even headless.
	if Net.online():
		if Net.started:
			Net.scene_ready(self)
		else:
			_show_title()
	# Tests and CI run headless and start straight away; so does New Run from game over.
	elif DisplayServer.get_name() == "headless" or Run.quick_start:
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

## A LAN game, begun on every machine together (Net.start_game): `humans` keepers, one
## per machine in the lobby's order, and helpers make up the rest. The host's run is the
## one that counts; a client's catches up from the host's state.
func begin_lan(cfg: Dictionary) -> void:
	begin_run(bool(cfg.get("cont", false)) and Net.is_host(), int(cfg.get("humans", 1)))
	var names: Array = cfg.get("names", [])
	for i in mini(names.size(), players.size()):
		players[i].net_name = String(names[i])

## LAN: a client has gone; its keeper is the computer's now (the light's or the camp's,
## whichever has nobody).
func keeper_left(slot: int) -> void:
	if slot < 0 or slot >= players.size():
		return
	var p: Player = players[slot]
	if not is_instance_valid(p) or p.ai:
		return
	p.remote = false
	p.ai = true
	p.in_menu = false
	var camp_kept := false
	for k in players:
		if is_instance_valid(k) and k != p and k.ai and k.get_node_or_null("KeeperAI") != null and k.get_node("KeeperAI").role == "camp":
			camp_kept = true
	var brain := KeeperAI.new(p, "light" if camp_kept else "camp")
	brain.name = "KeeperAI"
	p.add_child(brain)

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
	if Net.online():
		# One keeper on each machine, on its own screen: no split screen to set up.
		Players.wanted = clampi(n, 1, Players.MAX)
		Players.devices = [Players.KEYBOARD_MOUSE]
		Players.nodes.clear()
	else:
		Players.configure(n)
	var total := Players.MAX if Players.helpers else Players.wanted
	for i in total:
		var p := Player.new()
		p.idx = i
		p.ai = i >= Players.wanted
		p.remote = Net.is_host() and i > 0 and not p.ai
		p.puppet = Net.is_client()
		var at: Vector3 = SPAWNS[i % SPAWNS.size()]
		# The last helper keeps the camp, and starts there; any other keeps the light.
		var role := "camp" if i == total - 1 else "light"
		if p.ai and role == "camp":
			at = Vector3(Terrain.CAMP_C.x, 0.0, Terrain.CAMP_C.y)
		p.position = at + Vector3(0.0, Terrain.height_at_v(at) + 0.2, 0.0)
		p.camera = camera
		p.lamp = lighthouse.lamp
		Players.nodes.append(p)
		players.append(p)
		add_child(p)
		if p.ai and not p.puppet:
			var brain := KeeperAI.new(p, role)
			brain.name = "KeeperAI"
			p.add_child(brain)
	player = players[clampi(Net.my_slot, 0, players.size() - 1)] if Net.is_client() else players[0]
	if director == null:
		director = CameraDirector.new()
		director.main_camera = camera
		add_child(director)
	# On LAN each machine's screen follows its own keeper only.
	director.players = [player] if Net.online() else players
	hud.player = player
	hud.players = players
	hud.visible = true
	var d := SaveSys.load_run() if continue_save and not Net.is_client() else {}
	if not d.is_empty():
		Run.start_loaded(d)
	else:
		Run.start_new()
	lighthouse.lamp.fuel = Run.lamp_fuel
	for p in players:
		p.max_hp = Player.BASE_HP + int(Run.max_hp_bonus[p.idx])
		p.hp = p.max_hp
		p.hunger = float(Run.hunger[p.idx])
		p.warmth = float(Run.warmth[p.idx])
	Upgrades.apply(get_tree())
	if Players.wanted >= 3:
		_add_scavenge(SCAVENGE_CROWD)
	for i in NOTES_LYING:
		_place_notes()
	if d.is_empty():
		hud.report("The first day.", [
			"Keep the light burning until the relief boat comes for you: %d nights." % Rescue.night(),
			"The jobs on the right show you round: the beaches, the camp over the bridge, the shed.",
			"At dusk they come ashore and climb the ledge. Work the lamp (R at the door); Q focuses",
			"the beam to burn them, and on the ledge a blow aimed outward knocks them over the edge.",
		], FIRST_DAY_TIP_TIME)
	_apply_lighting(Cycle.Phase.DAY, 0.0)
	atmosphere.apply(Cycle.Phase.DAY, 0.0)
	Cycle.start(Cycle.Phase.DAY)
	jobs = Jobs.new()
	jobs.players = players
	add_child(jobs)
	if Net.online():
		Net.game_started(self)

func _process(delta: float) -> void:
	if _title_cam != null:
		_title_t += delta * TITLE_ORBIT_SPEED
		var a := _title_t * TAU + 0.6
		_title_cam.look_at_from_position(Vector3(sin(a) * 38.0, 15.0, cos(a) * 38.0), Vector3(-3.0, 6.0, 0.0), Vector3.UP)
	_rescue_step(delta)
	_cine_step(delta)
	if Run.active and not _rescue and not Net.is_client() and Input.is_action_just_pressed("skip"):
		Cycle.skip()
	_alarms(delta)

static func compass(p: Vector3) -> String:
	# The camera looks north (-Z), so +Z is south and +X is east.
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var a := fposmod(atan2(p.x, -p.z), TAU)
	return names[int(round(a / (TAU / 8.0))) % 8]

# ---- the relief boat: the end of Chapter One (Rescue) ----

const BOAT_BEACH := 0
## The boat waits this long for everyone; then any helper still ashore is taken off.
const BOAT_WAIT := 150.0
var boat: ReliefBoat
var jobs: Jobs
var _rescue := false
var _boat_wait := 0.0
var _total_kills := 0
var _cine: Camera3D

func _begin_rescue() -> void:
	_rescue = true
	# The dawn holds while the boat comes in: no more days, no more nights.
	Cycle.running = false
	var b := ReliefBoat.berth(BOAT_BEACH)
	_boat_in(b[0], b[1])
	Net.relay_rescue("arrive", [b[0], b[1]])
	hud.report("The relief boat!", [
		"The %s is coming in to the %s beach." % [ReliefBoat.NAME.capitalize(), compass(Terrain.beach_point(BOAT_BEACH, 0.5))],
		"Everyone down to the shingle and aboard: [E] at her plank.",
	], 16.0)

func _boat_in(shore: Vector3, mooring: Vector3) -> void:
	boat = ReliefBoat.new()
	boat.add_to_group("relief_boat")
	add_child(boat)
	boat.arrive(shore, mooring)

func _rescue_step(delta: float) -> void:
	if boat == null or not boat.waiting or Net.is_client():
		return
	_boat_wait += delta
	var all := true
	for p in players:
		if is_instance_valid(p) and not p.boarded:
			if _boat_wait > BOAT_WAIT and p.ai:
				boat.take_aboard(p)
			else:
				all = false
	if all:
		_sail()

func _sail() -> void:
	boat.depart()
	boat.departed.connect(_chapter_end)
	Net.relay_rescue("depart", [])
	_follow_boat()

# The camera lets go of the keepers and watches the boat away.
func _follow_boat() -> void:
	director.process_mode = Node.PROCESS_MODE_DISABLED
	director._overlay.visible = false
	_cine = Camera3D.new()
	_cine.fov = 46.0
	add_child(_cine)
	_cine.global_position = boat.global_position + Vector3(-14.0, 9.0, -6.0)
	_cine.current = true

func _cine_step(delta: float) -> void:
	if _cine == null or boat == null:
		return
	var want := boat.global_position + Vector3(-12.0, 7.0, -10.0)
	_cine.global_position = _cine.global_position.lerp(want, 1.0 - exp(-delta * 0.6))
	_cine.look_at(boat.global_position + Vector3(0.0, 1.5, 0.0), Vector3.UP)

func _chapter_end() -> void:
	if not Net.is_client():
		Net.relay_rescue("end", [])
	SaveSys.finish_chapter(1)
	var card := preload("res://scenes/ui/chapter_end.gd").new()
	card.nights = Rescue.night()
	card.kills = _total_kills
	card.sea = Difficulty.name()
	card.host_decides = Net.is_client()
	card.back_to_title.connect(_after_chapter.bind(false))
	card.stay_on.connect(_after_chapter.bind(true))
	add_child(card)
	Run.active = false

func _after_chapter(stay: bool) -> void:
	if stay:
		# The same run, kept on: no boat will come again.
		var d := SaveSys.load_run()
		d["endless"] = true
		var f := FileAccess.open(SaveSys.RUN_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(d))
		if Net.is_host() and Net.started:
			Net.restart(true)
			return
		Run.quick_start = true
		Run.active = false
		get_tree().reload_current_scene()
		return
	SaveSys.clear_run()
	Run.active = false
	Net.leave()
	get_tree().reload_current_scene()

## A LAN client: the host's boat, mirrored here.
func net_rescue(kind: String, args: Array) -> void:
	match kind:
		"arrive":
			_rescue = true
			_boat_in(args[0], args[1])
		"depart":
			if boat != null:
				boat.depart()
				_follow_boat()
		"end":
			_chapter_end()

func _on_enemy_killed(e: Node) -> void:
	_total_kills += 1
	var how = e.get("last_hit")
	_count(String(how) if how else "hook")

func _on_structure_destroyed(s: Node) -> void:
	if s is Structure and s.is_in_group("camp"):
		_count("camp_lost")
		if s.id == "wire":
			hud.warn("The camp's wire is down!")
		else:
			var nm: String = s.display_name()
			hud.warn("%s is wrecked!" % (nm.left(1).to_upper() + nm.substr(1)))
			if camp.fallen():
				hud.warn("The camp has fallen: no power, no warmth, no food from it till it's mended.")
	elif s is Fence:
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

# Something coming up the holm's beaches for the camp. With the alarm bell (research) the
# camp's bell rings and says which beach; without it, only a keeper on the holm notices.
func _on_holm_warning(kind: String, points: Array) -> void:
	_count("camp_raid")
	var beach := compass(points[0] - Vector3(Terrain.HOLM_C.x, 0.0, Terrain.HOLM_C.y))
	if Research.has("bell"):
		Audio.sfx("camp_bell", camp.generator.global_position, 2.0, 0.0)
		hud.warn("The camp's bell! Something's coming up the holm's %s beach, for the camp." % beach)
		return
	for k in players:
		if is_instance_valid(k) and not k.ai and Terrain.holm_side(k.global_position.x, k.global_position.z):
			hud.warn("Out on the holm, something's coming ashore on the %s side." % beach)
			return

# Four short blasts: the light is smothered.
func _on_smothered(on: bool) -> void:
	if on and Run.active:
		_count("smother")
		Audio.horn([1.0, 1.0, 1.0, 1.0], -1.0)
		hud.warn("The light is smothered! Throw your boathook at it from the crag top!")

func _unhandled_input(event: InputEvent) -> void:
	# Debug builds: F9 brings the Eel now.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and Run.active:
		spawner.force_eel()

# Foghorn alarms: a guttering lamp blasts every few seconds; a failing lighthouse warns once a night.
func _alarms(delta: float) -> void:
	if not Run.active or Net.is_client():
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
	mi.material_override = Look.terrain_mat()
	ground.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	ground.add_child(cs)
	# The holm's ground, a second mesh beside the first.
	var holm_mesh := Terrain.build_holm_mesh()
	var hmi := MeshInstance3D.new()
	hmi.name = "HolmGround"
	hmi.mesh = holm_mesh
	hmi.material_override = Look.terrain_mat()
	ground.add_child(hmi)
	var hcs := CollisionShape3D.new()
	hcs.shape = holm_mesh.create_trimesh_shape()
	ground.add_child(hcs)
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
	# The holm's grazing, round the outside of the wire.
	for i in HOLM_GRASS_TUFTS:
		var p := Vector3(Terrain.HOLM_C.x + rng.randf_range(-1.0, 1.0) * Terrain.HOLM_HALF.x, 0.0,
			Terrain.HOLM_C.y + rng.randf_range(-1.0, 1.0) * Terrain.HOLM_HALF.y)
		if not Terrain.is_grassy(p.x, p.z):
			continue
		p.y = Terrain.height_at_v(p)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.2))
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

# The holm: the camp on it, the rope bridge across to it, rocks along its shore.
func _build_holm() -> void:
	camp = Camp.new()
	add_child(camp)
	var ends := Terrain.bridge_ends()
	bridge = RopeBridge.new(ends[0], ends[1])
	add_child(bridge)
	var rng := RandomNumberGenerator.new()
	rng.seed = 312
	var placed := 0
	for i in 200:
		if placed >= 46:
			break
		var a := rng.randf() * TAU
		var dir := Vector2(sin(a), cos(a))
		# March out from the middle to just past the clifftop.
		var p := Terrain.HOLM_C
		for k in 120:
			p = Terrain.HOLM_C + dir * float(k) * 0.25
			if Terrain.holm_edge_dist(p.x, p.y) > rng.randf_range(0.6, 2.4):
				break
		if Terrain.holm_beach_weight(p.x, p.y) > 0.05 or Terrain.bridge_coords(p.x, p.y).y < 2.5 and Terrain.bridge_coords(p.x, p.y).x < 1.1:
			continue
		var s := rng.randf_range(0.6, 1.5)
		var at := Vector3(p.x, Terrain.height_at(p.x, p.y) - s * 0.25, p.y)
		Look.rock(self, 1300 + i * 7, Vector3(s * 1.4, s * 1.1, s * 1.2), at, HOLM_ROCK, 0.3)
		placed += 1
	_build_holm_rocks(rng)
	# Rocks in the gully under the bridge, the sea breaking over them.
	var e0: Vector3 = ends[0]
	var e1: Vector3 = ends[1]
	for i in 5:
		var u := 0.2 + float(i) * 0.15
		var q := e0.lerp(e1, u) + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
		q.y = Terrain.SEA_LEVEL - 0.7
		Look.rock(self, 1700 + i * 13, Vector3(1.8, 1.6, 1.5) * rng.randf_range(0.7, 1.2), q, Color(0.27, 0.27, 0.27), 0.4)

const HOLM_ROCK := Color(0.40, 0.30, 0.25)

# Skerries off the holm, a sea stack off its north-east point, and boulders on its knolls.
func _build_holm_rocks(rng: RandomNumberGenerator) -> void:
	var c := Terrain.HOLM_C
	var placed := 0
	for i in 400:
		if placed >= 9:
			break
		var a := rng.randf() * TAU
		var dir := Vector2(sin(a), cos(a))
		var want := rng.randf_range(5.0, 12.0)
		var p := c
		for k in 160:
			p = c + dir * float(k) * 0.25
			if Terrain.holm_edge_dist(p.x, p.y) > want:
				break
		if _near_landing(p) or Terrain.height_at(p.x, p.y) > Terrain.SEA_LEVEL - 0.6 or p.x < 34.0:
			continue
		for r in rng.randi_range(2, 4):
			var s := rng.randf_range(1.0, 2.4)
			var off := Vector3(rng.randf_range(-1.8, 1.8), 0.0, rng.randf_range(-1.8, 1.8))
			var at := Vector3(p.x, Terrain.SEA_LEVEL - s * 0.45, p.y) + off
			Look.rock(self, 2100 + i * 11 + r, Vector3(s * 1.5, s, s * 1.3), at, HOLM_ROCK.darkened(0.15), 0.15)
		placed += 1
	# The stack: a pillar of the same beds, cut off by the sea.
	var sa := deg_to_rad(215.0)
	var sp := c + Vector2(sin(sa), cos(sa)) * 6.0
	for k in 160:
		sp = c + Vector2(sin(sa), cos(sa)) * float(k) * 0.25
		if Terrain.holm_edge_dist(sp.x, sp.y) > 7.0:
			break
	for t in 3:
		var w := 2.4 - float(t) * 0.45
		Look.rock(self, 2500 + t, Vector3(w, 2.2, w * 0.9), Vector3(sp.x, Terrain.SEA_LEVEL - 0.6 + float(t) * 1.7, sp.y), HOLM_ROCK, 0.12 if t == 2 else 0.0)
	# Boulders where the rock breaks through the turf.
	var b := 0
	for i in 600:
		if b >= 22:
			break
		var p := c + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-18.0, 18.0))
		if Terrain.holm_outcrop(p.x, p.y) < 0.5 or Terrain.holm_edge_dist(p.x, p.y) > -1.0:
			continue
		var s := rng.randf_range(0.35, 0.9)
		Look.rock(self, 2600 + i, Vector3(s * 1.3, s * 0.8, s), Vector3(p.x, Terrain.height_at(p.x, p.y) - s * 0.2, p.y), HOLM_ROCK, 0.4)
		b += 1

# Near where creatures land on the holm, or the bridge's gully: kept clear of rocks.
func _near_landing(p: Vector2) -> bool:
	for i in Terrain.HOLM_BEACHES.size():
		for t in [0.0, 0.3]:
			var q := Terrain.holm_beach_point(i, t)
			if p.distance_to(Vector2(q.x, q.z)) < 6.0:
				return true
	var bc := Terrain.bridge_coords(p.x, p.y)
	return bc.x > -0.2 and bc.x < 1.2 and absf(bc.y) < 5.0

func _build_shed(at: Vector3) -> void:
	var shed := Shed.new()
	shed.position = at
	_face_inward(shed)
	add_child(shed)

func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	# Wide enough for both islands, with open sea all round.
	plane.size = Vector2(230.0, 170.0)
	plane.subdivide_width = 240
	plane.subdivide_depth = 180
	sea.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sea.gdshader")
	sea.material_override = mat
	mat.set_shader_parameter("holm_c", Terrain.HOLM_C)
	mat.set_shader_parameter("holm_half", Terrain.HOLM_HALF)
	mat.set_shader_parameter("holm_round", Terrain.HOLM_ROUND)
	mat.set_shader_parameter("holm_shore_tex", Terrain.holm_shore_texture())
	var r := Terrain.SHORE_RECT
	mat.set_shader_parameter("holm_shore_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	mat.set_shader_parameter("use_holm_tex", 1.0)
	_sea_mat = mat
	sea.position = Vector3(24.0, Terrain.SEA_LEVEL, 0.0)
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
	KeeperNav.add_ladder(upper.top, upper.bottom, Ladder.DOWN_TIME, Ladder.UP_TIME)
	var lower := Ladder.new(Terrain.at_angle(a, outer - 0.4), Terrain.at_angle(a, outer + blend + 0.6),
		_at(a, outer - 0.05, ledge + 0.05), _at(a, outer + blend + 0.1, Terrain.PLATEAU_HEIGHT))
	add_child(lower)
	KeeperNav.add_ladder(lower.top, lower.bottom, Ladder.DOWN_TIME, Ladder.UP_TIME)

func _at(a_deg: float, r: float, y: float) -> Vector3:
	return Vector3(sin(deg_to_rad(a_deg)) * r, y, cos(deg_to_rad(a_deg)) * r)

func _build_scavenge() -> void:
	for s in SCAVENGE:
		_add_scavenge(s)
	for s in HOLM_SCAVENGE:
		var sp := ScavengePoint.new(String(s[3]), int(s[4]))
		sp.position = Terrain.holm_beach_point(int(s[0]), float(s[1]), float(s[2]))
		add_child(sp)

func _add_scavenge(s: Array) -> void:
	var sp := ScavengePoint.new(String(s[3]), int(s[4]))
	sp.position = Terrain.beach_point(int(s[0]), float(s[1]), float(s[2]))
	add_child(sp)

func _build_trap_slots() -> void:
	var spots: Array[Vector3] = []
	for i in Terrain.BEACHES.size():
		spots.append(Terrain.beach_point(i, TRAP_BEACH_T, 0.0))
	spots.append(Terrain.ledge_point(TRAP_LEDGE_S))
	spots.append(Terrain.at_angle(Terrain.LEDGE_START - Nav.ENTRY_BEFORE, Terrain.LEDGE_R0))
	for i in spots.size():
		var slot := TrapSlot.new()
		slot.index = i
		slot.position = spots[i]
		if i < Terrain.BEACHES.size():
			slot.path_dir = _flat_dir(Terrain.beach_point(i, TRAP_BEACH_T + 0.1, 0.0) - spots[i])
		add_child(slot)
	# The holm's own posts, open from the start.
	var e := Terrain.bridge_ends()
	var gate := Terrain.camp_gate()
	var holm_posts: Array = [
		[Terrain.holm_beach_point(0, HOLM_POST_BEACH_T), _flat_dir(Terrain.holm_beach_point(0, HOLM_POST_BEACH_T + 0.1) - Terrain.holm_beach_point(0, HOLM_POST_BEACH_T))],
		[Terrain.holm_beach_point(1, HOLM_POST_BEACH_T), _flat_dir(Terrain.holm_beach_point(1, HOLM_POST_BEACH_T + 0.1) - Terrain.holm_beach_point(1, HOLM_POST_BEACH_T))],
		[Vector3(gate.x - 2.2, 0.0, gate.y), Vector3.ZERO],
		[e[1] + _flat_dir(Vector3(gate.x, 0.0, gate.y) - e[1]) * 2.0, Vector3.ZERO],
	]
	for i in holm_posts.size():
		var slot := TrapSlot.new()
		slot.index = 10 + i
		slot.holm = true
		var at: Vector3 = holm_posts[i][0]
		slot.position = Vector3(at.x, Terrain.height_at(at.x, at.z), at.z)
		slot.path_dir = holm_posts[i][1]
		add_child(slot)

static func _flat_dir(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()

# A tin of the internees' papers, at one of the spots about the camp nothing lies at yet.
func _place_notes() -> void:
	var lying := []
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ScavengePoint and n.kind == "notes" and not n.is_queued_for_deletion():
			lying.append(Vector2(n.global_position.x, n.global_position.z))
	if lying.size() >= NOTES_LYING:
		return
	var free := []
	for o in NOTE_SPOTS:
		var p: Vector2 = Terrain.CAMP_C + o
		var taken := false
		for q in lying:
			if p.distance_to(q) < 1.0:
				taken = true
		if not taken:
			free.append(p)
	if free.is_empty():
		return
	var at: Vector2 = free[(Run.notes_found * 3 + lying.size()) % free.size()]
	var sp := ScavengePoint.new("notes", 1)
	sp.once = true
	sp.position = Vector3(at.x, Terrain.height_at(at.x, at.y), at.y)
	add_child(sp)

func _on_lore(text: String) -> void:
	hud.report("A page of the internees' notes", [text], LORE_TIME)

func _build_campfire() -> void:
	var fire := Campfire.new()
	fire.position = Terrain.at_angle(CAMPFIRE_AT[0], CAMPFIRE_AT[1])
	add_child(fire)

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
	var hp: Array[Vector3] = []
	for i in Terrain.HOLM_BEACHES.size():
		for side in [-1.0, 1.0]:
			hp.append(Terrain.holm_beach_point(i, 0.0, side * LANDING_OFFSET * 0.6))
	spawner.holm_points = hp
	spawner.enemies_root = _enemies
	spawner.lighthouse = lighthouse
	add_child(spawner)
	spawner.wave_incoming.connect(_on_wave_incoming)
	spawner.group_warning.connect(_on_group_warning)
	spawner.holm_warning.connect(_on_holm_warning)
	lighthouse.lamp.smothered_changed.connect(_on_smothered)

# ---- cycle ----

func _apply_lighting(p: int, duration: float) -> void:
	var cfg: Dictionary = _lighting[p].duplicate()
	if Run.active and (p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT):
		var w: Dictionary = WEATHER_LIGHT[Weather.tonight()]
		cfg["amb_e"] = float(cfg["amb_e"]) * float(w["amb"])
		cfg["sun_e"] = float(cfg["sun_e"]) * float(w["sun"])
		cfg["fog"] = float(cfg["fog"]) * float(w["fog"])
		cfg["vfog"] = float(cfg["vfog"]) * float(w["fog"])
		if p == Cycle.Phase.NIGHT and w["bg"] != Color(0.0, 0.0, 0.0):
			cfg["bg"] = w["bg"]
		# A clear night is moonlit: silver light that throws real shadows.
		if p == Cycle.Phase.NIGHT and w.has("moon"):
			cfg["sun"] = w["moon"]
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
		if Run.active and Rescue.is_last_night() and not Net.is_client():
			hud.warn("The last night. The relief boat comes at dawn: hold the light!")
	if p == Cycle.Phase.DAWN and Run.active and not Net.is_client():
		_wash_up_oil()
		_wash_up_shells()
		_researched = Research.finish() if camp.desk.usable() else ""
		_place_notes()
		_dawn_report()
		var damaged := 0
		for s in get_tree().get_nodes_in_group("structures"):
			if s is Structure and s.is_damaged():
				damaged += 1
		Run.lamp_fuel = lighthouse.lamp.fuel
		for k in players:
			if is_instance_valid(k):
				Run.hunger[k.idx] = k.hunger
				Run.warmth[k.idx] = k.warmth
		var held := Run.night
		Run.advance_night(damaged)
		if not Run.endless and held >= Rescue.night():
			_begin_rescue()

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
	if g.call("trap") > 0:
		how.append("%d in traps" % g.call("trap"))
	if g.call("flare") > 0:
		how.append("%d to flares" % g.call("flare"))
	for k in [["shot", "shot"], ["arrow", "to arrows"], ["flame", "burned by the flamer"], ["bomb", "to petrol bombs"], ["poison", "poisoned"]]:
		if g.call(k[0]) > 0:
			how.append("%d %s" % [g.call(k[0]), k[1]])
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
	var camp_line := _camp_report()
	if camp_line != "":
		cost.append(camp_line)
	cost.append("fuel %d%%" % roundi(lighthouse.lamp.fuel))
	lines.append(" · ".join(cost))
	var tip := ""
	if lighthouse.lamp.fuel < 30.0:
		tip = "Fuel is low: gather bio on the beaches and refuel at the lighthouse door."
	elif g.call("reached") > 0:
		tip = "Meet climbers on the ledge: a blow aimed outward knocks them over the edge."
	elif g.call("smother") > 0:
		tip = "When something climbs the tower, burn it on the ledge, or throw your boathook up at it from the crag top. Then go and pick the hook up."
	elif camp.fallen():
		tip = "The camp has fallen. Mend the generator and the huts (driftwood and scrap) to get its light, warmth and food back."
	elif camp.wire_down() > 0:
		tip = "Mend the camp's wire with scrap before dark: whatever comes up the holm's beaches has to tear through it."
	elif g.call("fence") > 0:
		tip = "Mend broken fences with driftwood before dark."
	elif not hurt_home.is_empty():
		tip = "Take the hammer to the homestead: the cottage and shed take driftwood, the garden kelp too."
	elif _hurt_keeper() and Stock.get_amount("food") > 0:
		tip = "Eat at the cottage: a meal heals fully and toughens the keeper."
	elif Stock.get_amount("food") == 0 and Run.night <= 4:
		tip = "Dig kelp into the garden beds by day: potatoes by dawn, a meal at the cottage."
	elif g.call("beam") < g.call("ashore") / 2:
		tip = "The focused beam (Q) burns them on the beaches, long before they climb."
	if tip != "":
		lines.append("")
		lines.append(tip)
	if _oil_tonight:
		lines.append("An oil drum has washed up on the %s beach." % compass(_oil_at))
	if _shells_tonight:
		lines.append("A tin of shotgun cartridges has washed up on the %s beach." % compass(_shells_at))
	if _researched != "":
		lines.append("Worked out overnight at the camp: %s." % Research.title(_researched))
	# The relief boat: how long to hold out (Run.night is still the night just held).
	if not Run.endless:
		var left := Rescue.night() - Run.night
		if left == 1:
			lines.append("One more night: the relief boat comes the dawn after.")
		elif left > 1:
			lines.append("The relief boat is due in %d nights." % left)
	hud.report("Night %d held." % Run.night, lines)

# The camp's state for the dawn report: what's wrecked or hurt, or "" if it's all sound.
func _camp_report() -> String:
	if camp.fallen():
		return "the camp has fallen"
	var bad: Array[String] = []
	var wrecked: Array[String] = []
	for s in [camp.generator] + camp.buildings.values():
		if s.is_destroyed():
			wrecked.append(s.display_name())
		elif s.is_damaged():
			bad.append("%s %d%%" % [s.display_name(), roundi(s.health_ratio() * 100.0)])
	var out: Array[String] = []
	if not wrecked.is_empty():
		out.append("%s wrecked" % " and ".join(wrecked))
	out.append_array(bad)
	if camp.wire_down() > 0:
		out.append("%d run%s of wire down" % [camp.wire_down(), "" if camp.wire_down() == 1 else "s"])
	return "camp: " + ", ".join(out) if not out.is_empty() else ""

func _hurt_keeper() -> bool:
	for p in players:
		if is_instance_valid(p) and p.hp < p.max_hp * 0.6:
			return true
	return false

var _researched := ""
var _oil_tonight := false
var _oil_at := Vector3.ZERO

# After the second night and every third after, a drum of oil comes ashore.
func _wash_up_oil() -> void:
	_oil_tonight = Run.night >= OIL_FIRST and (Run.night - OIL_FIRST) % OIL_EVERY == 0
	if not _oil_tonight:
		return
	var beach := (Run.night / OIL_EVERY) % Terrain.BEACHES.size()
	var sp := ScavengePoint.new("oil", 1)
	sp.once = true
	sp.position = Terrain.beach_point(beach, 0.5, 0.8)
	_oil_at = sp.position
	add_child(sp)

# Every third dawn from the third, a tin of a few cartridges from some wreck: the
# shotgun's only ammunition besides the box in the shed.
const SHELLS_FIRST := 3
const SHELLS_EVERY := 3
const SHELLS_TIN := 3
var _shells_tonight := false
var _shells_at := Vector3.ZERO

func _wash_up_shells() -> void:
	_shells_tonight = Run.night >= SHELLS_FIRST and (Run.night - SHELLS_FIRST) % SHELLS_EVERY == 0
	if not _shells_tonight:
		return
	var beach := (Run.night / SHELLS_EVERY + 1) % Terrain.BEACHES.size()
	var sp := ScavengePoint.new("shells", SHELLS_TIN)
	sp.once = true
	sp.position = Terrain.beach_point(beach, 0.55, -0.9)
	_shells_at = sp.position
	add_child(sp)

func _on_run_ended(_reason: String, _night: int) -> void:
	Cycle.stop()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
