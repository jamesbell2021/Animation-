extends "res://scenes/main.gd"
## The Escape (docs/ESCAPE.md, docs/STORY.md): the crossing between the acts. The Mary
## Ann has left Kirkhaven's pier on the third night with whoever reached her, and runs up
## the coast in the fog for the rock, whose light sweeps ahead. Things come up out of the
## sea after her: rocks and great arms in her way to steer round, and the drowned and the
## bloated climbing her sides, to knock back into the water (the boathook, an arrow, the
## shotgun) before they get over the gunwale and go for her people. When she comes in
## under the rock's light they fall back, and the log's last two crossing pages lead on
## to the rock (Act Two, main.gd), with Run.carry as it came off the pier less whoever
## was lost on the way, and whatever was spent.
##
## Built like Kirkhaven (harbour.gd): main.gd's keepers, HUD, pause menu and feel, on
## EscapeMap's ground (Terrain hands over while Terrain.chapter is 3). The boat never
## moves: the world (`world`, the sea's and the fog's patterns) goes past her, so the
## keepers walk a deck that is always still. Local play only.

const MAIN_SCENE := "res://scenes/main.tscn"
const EscapeHudScript := preload("res://scenes/escape/escape_hud.gd")
## What the keepers had about them, for an Escape begun on its own (a test, the
## quick-start argument): Kirkhaven's kit.
const KIT := {"driftwood": 4, "scrap": 3, "bio": 2, "diesel": 1, "arrows": 18, "bombs": 3, "shells": 8}

## Her speed through the water (m/s), how long the crossing is by the sea's mood (m), and
## how many miles the HUD says that is.
const SPEED := 4.5
const DISTANCE := [860.0, 950.0, 1020.0]
const MILES := 3.0
## How far either way of her course she can be put (m), and how quickly.
const CHANNEL := 5.5
const STEER_SPEED := 3.2
const STEER_ACCEL := 5.5
## Her hull, and what each kind of blow takes off it, by the sea's mood.
const HULL := [130, 100, 90]
const ROCK_DMG := [9, 13, 15]
const ARM_DMG := [16, 22, 28]
const ARM_RADIUS := [2.0, 2.25, 2.5]
const ARM_HP := [40, 55, 70]
## How far ahead of where she is an arm aims (s of her sideways way).
const ARM_LEAD := [0.0, 0.35, 0.7]
## After a blow she can't be hurt again for this long (a lurch, not a pile-up).
const INVULN := 1.4
## Something in her way about this often (m), and how many of those are arms.
const HAZARD_EVERY := [64.0, 46.0, 34.0]
const ARM_SHARE := [0.35, 0.45, 0.55]
## How often an arm comes with rocks beyond it, narrowing the way out.
const GATE_SHARE := [0.0, 0.35, 0.6]
## Those coming over the side: a wave this often (s), at most this many at once, how long
## a climb takes, and how many are bloated.
const BOARD_EVERY := [8.0, 4.6, 3.4]
const BOARD_MAX := [3, 6, 8]
const CLIMB_TIME := [5.5, 4.0, 3.4]
const BLOATED_SHARE := [0.2, 0.3, 0.32]
## Three times on the crossing they come up all round her at once (where, 0 to 1), this
## many, spread along both sides.
const SURGES := [0.3, 0.55, 0.78]
const SURGE_SIZE := [3, 5, 6]
## A helper notices something on her side once it is this far up (0 to 1).
const HELPER_NOTICE := 0.3
## Where on the crossing (0 to 1) things start and stop, and where the rock's light
## reaches her and they fall back.
const HAZARDS_FROM := 0.04
const HAZARDS_UNTIL := 0.86
const BOARD_FROM := 0.06
const BOARD_UNTIL := 0.85
const LIGHT_AT := 0.9
const FINALE_AT := 0.55
## Things are put in the water this far ahead of her (m, past the fog's edge).
const SPAWN_AHEAD := 48.0
## The rock, beyond the end of the crossing: ahead and to port.
const ROCK_AHEAD := 24.0
const ROCK_SIDE := -9.0
## Coming in under the light: how long she takes to slow, after the crossing's length.
const ARRIVE_TIME := 5.0
## How far off her the fog bank lies (m): what's in her way comes out of it.
const FOG_GAP := 6.5

## Set by a test to see the end without the pages (always skipped headless).
var skip_pages := false
var world: Node3D
var helm: EscapeHelm
var ehud: CanvasLayer
var villagers: Array[Villager] = []
var arms: Array = []
var rocks: Array = []
var carry := {}
var distance := 950.0
var travelled := 0.0
var lateral := 0.0
var lateral_v := 0.0
var speed := 0.0
var hull := 100
var hull_max := 100
## Who of the seven were lost on the crossing (names), for the log.
var lost_here: Array = []
var arrived := false
var foundered := false
var _invuln := 0.0
var _t := 0.0
var _kick := 0.0
var _board_t := 4.0
var _surge := 0
var _next_hazard := 60.0
var _last_arm_at := -999.0
var _light_told := false
var _first_board := true
var _first_hit := true
var _finale := false
var _arrive_t := -1.0
var _sea: MeshInstance3D
var _fog: FogBank
var _deck: StaticBody3D
var _rock: Node3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _lantern: OmniLight3D
var _flash_light: OmniLight3D
var _cliffs: Array = []
var _next_cliff := -30.0
var _rock_meshes: Array[ArrayMesh] = []
var _autopilot := {}
var _claims := {}

func _ready() -> void:
	var headless := DisplayServer.get_name() == "headless"
	if not (Run.enter_escape or Run.quick_start or headless):
		# Nothing sent us here (back to the title from the pause menu or the game over
		# card): the title is on the rock, and nothing is to be carried there.
		Run.carry = {}
		Run.escape_carry = {}
		Run.chapter = 1
		Terrain.chapter = 1
		set_process(false)
		set_physics_process(false)
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)
		return
	var cont := Run.enter_escape and Run.escape_continue
	Run.enter_escape = false
	Run.escape_continue = false
	Run.quick_start = false
	carry = _find_carry(cont)
	Run.escape_carry = carry.duplicate(true)
	# Off the pier: the rock is not to begin until she gets there.
	Run.carry = {}
	Run.chapter = 3
	Terrain.deck_height = EscapeMap.height_at
	Terrain.deck_walkable = EscapeMap.walkable
	Terrain.chapter = 3
	add_to_group("escape")
	_build_environment()
	_build_escape_sea()
	_build_boat()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	_build_rock()
	_build_fog()
	_build_camera()
	_enemies = Node3D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	hud = HudScript.new()
	hud.lighthouse = null
	hud.lamp = null
	hud.camp = null
	add_child(hud)
	_quiet_hud()
	add_child(PauseScript.new())
	ehud = EscapeHudScript.new()
	ehud.escape = self
	add_child(ehud)
	Events.run_ended.connect(_on_run_ended)
	Events.enemy_killed.connect(_on_enemy_killed)
	Audio.start_ambience()
	begin_run(cont, Players.wanted)

# What came off the pier: the save's (Continue), from Kirkhaven just now, the last try
# (Try again), or, begun on its own, the town's kit and all seven.
func _find_carry(cont: bool) -> Dictionary:
	var saved := SaveSys.load_run()
	var from_save: Dictionary = saved.get("carry", {}) if int(saved.get("chapter", 1)) == 3 and saved.get("carry", {}) is Dictionary else {}
	if cont and not from_save.is_empty():
		return from_save.duplicate(true)
	if not Run.carry.is_empty():
		return Run.carry.duplicate(true)
	if not Run.escape_carry.is_empty():
		return Run.escape_carry.duplicate(true)
	return default_carry()

static func default_carry() -> Dictionary:
	return {"stock": KIT.duplicate(), "arms": [["bow", "shotgun"], ["bow"], ["bow"]], "villagers": Villagers.all_ids(),
		"lost": [], "difficulty": Run.next_difficulty}

# The HUD's top-left card is the light's and the night's: on the crossing the Escape's own
# card (escape_hud.gd) says what matters, so the HUD's is left out (and its game-over
# card is reworded in _on_run_ended).
func _quiet_hud() -> void:
	var card = hud.get("_light_card")
	if card is CanvasItem:
		(card as CanvasItem).modulate = Color(1, 1, 1, 0)

# ---- the world ----

func _build_escape_sea() -> void:
	_sea = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(150.0, 110.0)
	plane.subdivide_width = 150
	plane.subdivide_depth = 110
	_sea.mesh = plane
	_sea_mat = ShaderMaterial.new()
	_sea_mat.shader = load("res://shaders/escape_sea.gdshader")
	_sea_mat.set_shader_parameter("boat_half", Vector2((EscapeMap.BOW_X - EscapeMap.STERN_X) * 0.5, EscapeMap.HALF_BEAM))
	_sea_mat.set_shader_parameter("boat_x", (EscapeMap.BOW_X + EscapeMap.STERN_X) * 0.5)
	_sea.material_override = _sea_mat
	_sea.position = Vector3(12.0, Terrain.SEA_LEVEL, -8.0)
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)

func _build_boat() -> void:
	boat = ReliefBoat.new()
	boat.escape_fit = true
	boat.scale = Vector3.ONE * EscapeMap.SCALE
	boat.position = Vector3(0.0, EscapeMap.ROOT_Y, 0.0)
	add_child(boat)
	# She rides the swell as the Escape says, not as she does at a pier.
	boat.set_process(false)
	# Lamps on her deck, so what comes over the side is seen.
	for at in [Vector3(0.4, EscapeMap.DECK_Y + 2.0, 0.0), Vector3(-4.6, EscapeMap.DECK_Y + 1.8, 0.0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.52)
		l.light_energy = 1.7
		l.omni_range = 8.5
		l.omni_attenuation = 1.2
		l.position = at
		l.shadow_enabled = false
		add_child(l)
	# Her deck to stand on: still, whatever the boat's model does in the swell.
	_deck = StaticBody3D.new()
	_deck.name = "Deck"
	_deck.collision_layer = 1
	_deck.collision_mask = 0
	add_child(_deck)
	var length := EscapeMap.BOW_X - EscapeMap.STERN_X
	var mid := (EscapeMap.BOW_X + EscapeMap.STERN_X) * 0.5
	Geo.box_shape(_deck, Vector3(length, 0.4, EscapeMap.HALF_BEAM * 2.0), Vector3(mid, EscapeMap.DECK_Y - 0.2, 0.0))
	for side in [-1.0, 1.0]:
		Geo.box_shape(_deck, Vector3(length, 1.6, 0.3), Vector3(mid, EscapeMap.DECK_Y + 0.8, side * (EscapeMap.WALK_HALF + 0.5)))
	Geo.box_shape(_deck, Vector3(0.3, 1.6, EscapeMap.HALF_BEAM * 2.0), Vector3(EscapeMap.WALK_STERN - 0.5, EscapeMap.DECK_Y + 0.8, 0.0))
	Geo.box_shape(_deck, Vector3(0.3, 1.6, EscapeMap.HALF_BEAM * 2.0), Vector3(EscapeMap.WALK_BOW + 0.5, EscapeMap.DECK_Y + 0.8, 0.0))
	Geo.box_shape(_deck, Vector3(EscapeMap.HOUSE_FORE - EscapeMap.HOUSE_AFT, 2.3, EscapeMap.HOUSE_HALF * 2.0),
		Vector3((EscapeMap.HOUSE_FORE + EscapeMap.HOUSE_AFT) * 0.5, EscapeMap.DECK_Y + 1.15, 0.0))
	helm = EscapeHelm.new()
	helm.process_physics_priority = 10
	add_child(helm)
	helm.autopilot = _steer_for
	helm.changed.connect(_on_helm_changed)

func _rock_mesh(i: int) -> ArrayMesh:
	if _rock_meshes.is_empty():
		for k in 6:
			_rock_meshes.append(Look.rock_mesh(900 + k * 17, Vector3(1.0, 0.8 + 0.1 * float(k % 3), 1.0), Color(0.44, 0.44, 0.45), 0.0))
	return _rock_meshes[i % _rock_meshes.size()]

func _rock_at(parent: Node3D, i: int, size: Vector3, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _rock_mesh(i)
	mi.material_override = Look._rock_shared()
	mi.scale = size
	mi.position = at
	mi.rotation.y = float(i) * 1.37
	parent.add_child(mi)
	return mi

# The rock itself, past the end of the crossing: its lighthouse, the lamp lit, its beam
# going round in the fog. It comes nearer as she runs up the coast.
func _build_rock() -> void:
	_rock = Node3D.new()
	_rock.name = "TheRock"
	world.add_child(_rock)
	for i in 7:
		var a := float(i) * 0.9
		var s := 3.0 + float(i % 3) * 1.6
		_rock_at(_rock, i, Vector3(s * 1.3, s, s * 1.2), Vector3(cos(a) * 4.5, Terrain.SEA_LEVEL - 0.5 + float(i % 2) * 0.6, sin(a) * 3.5))
	var white := Look.flat_mat(Color(0.86, 0.85, 0.8), 0.7)
	var dark := Look.flat_mat(Color(0.08, 0.08, 0.09), 0.6)
	var tower := Geo.cyl(_rock, 1.3, 11.0, Color.WHITE, Vector3(0.0, 7.0, 0.0), 0.95)
	tower.material_override = white
	var gallery := Geo.cyl(_rock, 1.5, 0.25, Color.WHITE, Vector3(0.0, 12.6, 0.0))
	gallery.material_override = dark
	var glass := Geo.cyl(_rock, 0.9, 1.3, Color.WHITE, Vector3(0.0, 13.4, 0.0))
	glass.material_override = Look.glow_mat(Color(1.0, 0.85, 0.5), 3.0)
	var cap := Geo.cyl(_rock, 1.1, 0.7, Color.WHITE, Vector3(0.0, 14.4, 0.0), 0.2)
	cap.material_override = dark
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(1.0, 0.82, 0.5)
	_lantern.light_energy = 3.0
	_lantern.omni_range = 26.0
	_lantern.position = Vector3(0.0, 13.4, 0.0)
	_rock.add_child(_lantern)
	# The beam: a long soft cone going round.
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 9.0
	cm.height = 80.0
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	_beam.mesh = cm
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = load("res://shaders/beam.gdshader")
	_beam_mat.set_shader_parameter("intensity", 0.25)
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pivot := Node3D.new()
	pivot.name = "BeamPivot"
	pivot.position = Vector3(0.0, 13.4, 0.0)
	_rock.add_child(pivot)
	pivot.add_child(_beam)
	# Lying along the pivot's -Z, tipped a little down to the sea.
	_beam.rotation = Vector3(deg_to_rad(-90.0 + 6.0), 0.0, 0.0)
	_beam.position = Vector3(0.0, -4.0, -40.0)
	# A flash on the water about her as it goes past her.
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.86, 0.6)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 24.0
	_flash_light.position = Vector3(2.0, 7.0, -2.0)
	add_child(_flash_light)

func _build_fog() -> void:
	_fog = FogBank.new()
	# The bank lies all round her, a little way off: her lamps hold it back.
	_fog.isles = [[(EscapeMap.BOW_X + EscapeMap.STERN_X) * 0.5, 0.0, 8.0, 3.0, 0.0]]
	add_child(_fog)
	_fog.apply(Cycle.Phase.NIGHT, 0.0)
	_fog.gap = FOG_GAP
	_fog.density = 0.9

# ---- the run ----

func begin_run(_continue_save: bool, n: int) -> void:
	camera.current = true
	Run.start_new()
	_apply_carry(carry)
	Run.chapter = 3
	Run.story = true
	Run.night = Rescue.HARBOUR_NIGHTS[Difficulty.level()]
	var lvl := Difficulty.level()
	distance = DISTANCE[lvl]
	hull_max = HULL[lvl]
	hull = hull_max
	RenderingServer.global_shader_parameter_set("storm", [0.2, 0.35, 0.55][lvl])
	# The third night, held: the clock doesn't run on the crossing.
	Cycle.running = false
	Cycle.phase = Cycle.Phase.NIGHT
	Cycle.time_left = 0.0
	Players.configure(n)
	var spots := [Vector3(-4.4, 0.0, 1.0), Vector3(1.0, 0.0, 1.25), Vector3(3.9, 0.0, -1.1)]
	var total := Players.MAX if Players.helpers else Players.wanted
	for i in total:
		var p := Player.new()
		p.idx = i
		p.ai = i >= Players.wanted
		var at: Vector3 = spots[i % spots.size()]
		p.position = Vector3(at.x, EscapeMap.DECK_Y + 0.1, at.z)
		p.camera = camera
		p.lamp = null
		Players.nodes.append(p)
		players.append(p)
		add_child(p)
		if p.ai:
			# The first helper takes the wheel from Dod if nobody playing has it; any other
			# keeps the gunwales.
			var brain := KeeperAI.new(p, "helm" if i == Players.wanted else "deck")
			brain.name = "KeeperAI"
			p.add_child(brain)
	player = players[0]
	if director == null:
		director = CameraDirector.new()
		director.main_camera = camera
		add_child(director)
	director.players = players
	hud.markers.director = director
	hud.player = player
	hud.players = players
	hud.run_tally = run_tally
	hud.visible = true
	for p in players:
		p.max_hp = Player.BASE_HP + int(Run.max_hp_bonus[p.idx])
		p.hp = p.max_hp
	_spawn_villagers()
	_save()
	var who := "All seven of Kirkhaven are" if Villagers.count() == 7 else ("%d of Kirkhaven's people are" % Villagers.count() if Villagers.count() > 1 else ("One of Kirkhaven's people is" if Villagers.count() == 1 else "Nobody from Kirkhaven is"))
	hud.report("The Escape", [
		"%s aboard. Dod Wiseman has put her head to the north-east, for the rock's light." % who,
		"Take the wheel ([E] behind the wheelhouse) to steer round the rocks and what rises out of the sea, or leave it to Dod (or a helper).",
		"Anything climbing her side goes back in the water at one blow: the boathook, an arrow, the shotgun. Keep them off the seven.",
	], FIRST_DAY_TIP_TIME)
	_apply_lighting(Cycle.Phase.NIGHT, 0.0)
	_env.fog_density = 0.012
	Audio.music("harbour_night", 3.0)
	Audio.sfx("boat_horn", Vector3(0.0, 3.0, 0.0), 4.0, 0.0)
	_camera_hint.call_deferred()

func _apply_carry(c: Dictionary) -> void:
	Run.difficulty = clampi(int(c.get("difficulty", Run.next_difficulty)), 0, 2)
	var stock: Dictionary = c.get("stock", {})
	for k in Stock.KINDS:
		Stock.set_amount(k, int(stock.get(k, 0)))
	var a: Array = c.get("arms", [])
	for i in mini(a.size(), Run.arms.size()):
		Run.arms[i] = (a[i] as Array).duplicate()
	Run.villagers = (c.get("villagers", []) as Array).duplicate()
	Run.lost = (c.get("lost", []) as Array).duplicate()

## The save while she is at sea: the run, and what came off the pier, so Continue (or
## a try again) begins the crossing again as it was.
func _save() -> void:
	if Net.is_client():
		return
	var d := SaveSys.snapshot()
	d["chapter"] = 3
	d["villagers"] = (carry.get("villagers", []) as Array).duplicate()
	d["lost"] = (carry.get("lost", []) as Array).duplicate()
	d["carry"] = carry
	var f := FileAccess.open(SaveSys.RUN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _spawn_villagers() -> void:
	var ids: Array = Run.villagers.duplicate()
	for i in ids.size():
		var v := Villager.new(String(ids[i]))
		add_child(v)
		var seat: Vector3 = EscapeMap.SEATS[i % EscapeMap.SEATS.size()]
		v.place(Vector3(seat.x, EscapeMap.DECK_Y, seat.z), "about")
		v.global_position.y = EscapeMap.DECK_Y
		# Nothing's prey the way it is in the town's streets: what comes aboard takes them
		# (Boarder), and the Escape keeps the count.
		v.fighting = true
		v.set("_yaw", PI * 0.5 if seat.z <= 0.0 else -PI * 0.5)
		v.taken.connect(_on_villager_taken)
		_sit(v)
		villagers.append(v)

# Huddled on the deck, knees up, arms round them.
func _sit(v: Villager) -> void:
	if v.rig == null:
		return
	v.rig.position.y = -0.42
	v.rig.layer("thigh.L", Vector3(-1.5, 0.0, -0.15))
	v.rig.layer("thigh.R", Vector3(-1.5, 0.0, 0.15))
	v.rig.layer("shin.L", Vector3(1.9, 0.0, 0.0))
	v.rig.layer("shin.R", Vector3(1.9, 0.0, 0.0))
	v.rig.layer("spine", Vector3(0.35, 0.0, 0.0))
	v.rig.layer("upper_arm.L", Vector3(-0.7, 0.0, 0.25))
	v.rig.layer("upper_arm.R", Vector3(-0.7, 0.0, -0.25))
	v.rig.layer("forearm.L", Vector3(-1.3, 0.0, 0.0))
	v.rig.layer("forearm.R", Vector3(-1.3, 0.0, 0.0))

# ---- every frame ----

func _process(delta: float) -> void:
	_t += delta
	# She rides the swell: a slow roll and pitch, heavier on an angrier sea, put over a
	# little as she is steered, and jolted by a blow.
	var sea := 1.0 + 0.35 * float(Difficulty.level())
	_kick = move_toward(_kick, 0.0, delta * 0.25)
	if boat != null and not foundered:
		boat.rotation.x = sin(_t * 0.8) * 0.028 * sea + lateral_v * 0.012 + sin(_t * 9.0) * _kick * 0.6
		boat.rotation.z = sin(_t * 1.05 + 1.3) * 0.032 * sea
		boat.rotation.y = -lateral_v * 0.02
		boat.position.y = EscapeMap.ROOT_Y + sin(_t * 1.1) * 0.07 * sea
	if _sea_mat != null:
		_sea_mat.set_shader_parameter("scroll", Vector2(travelled, lateral))
		_sea_mat.set_shader_parameter("speed", speed)
		_sea_mat.set_shader_parameter("swell", 0.16 + 0.06 * float(Difficulty.level()))
	if _fog != null:
		for c in _fog.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
				var m := (c as MeshInstance3D).material_override as ShaderMaterial
				m.set_shader_parameter("scroll", Vector2(travelled, lateral))
	_light_step(delta)

func _physics_process(delta: float) -> void:
	if world == null:
		return
	if foundered or (not Run.active and not arrived):
		return
	var k := progress()
	# Under way: up to speed off the pier, and slowing as she comes in under the light.
	var want := SPEED
	if _arrive_t >= 0.0:
		want = lerpf(SPEED, 0.6, clampf(_arrive_t / ARRIVE_TIME, 0.0, 1.0))
	speed = move_toward(speed, want, delta * 1.5)
	travelled += speed * delta
	# Steering: across the channel at the wheel's say.
	var steer := helm.steer if helm != null and _arrive_t < 0.0 else 0.0
	lateral_v = move_toward(lateral_v, steer * STEER_SPEED, STEER_ACCEL * delta)
	lateral += lateral_v * delta
	if absf(lateral) > CHANNEL:
		lateral = clampf(lateral, -CHANNEL, CHANNEL)
		lateral_v = 0.0
	world.position = Vector3(-travelled, 0.0, -lateral)
	_invuln = maxf(0.0, _invuln - delta)
	_claims.clear()
	if not Run.active:
		return
	_hazards(k)
	_rocks_step()
	_cliffs_step()
	_boarders(delta, k)
	if k >= LIGHT_AT and not _light_told:
		_light_reaches()
	if k >= FINALE_AT and not _finale:
		_finale = true
		Audio.music("finale", 4.0)
	if travelled >= distance and _arrive_t < 0.0:
		_arrive_t = 0.0
		Audio.sfx("boat_horn", Vector3(0.0, 3.0, 0.0), 4.0, 0.0)
		hud.warn("The rock! She comes in under the light.")
	if _arrive_t >= 0.0:
		_arrive_t += delta
		if _arrive_t >= ARRIVE_TIME:
			_arrive()

## How far through the crossing she is, 0 to 1.
func progress() -> float:
	return clampf(travelled / maxf(distance, 1.0), 0.0, 1.0)

func miles_left() -> float:
	return (1.0 - progress()) * MILES

func helm_name() -> String:
	return helm.who() if helm != null else "Dod Wiseman"

## Kirkhaven's people still aboard (Villager nodes).
func people_aboard() -> Array:
	var out := []
	for v in villagers:
		if is_instance_valid(v) and v.state != "lost":
			out.append(v)
	return out

func people_count() -> int:
	return people_aboard().size()

# ---- in her way ----

func _hazards(k: float) -> void:
	if k < HAZARDS_FROM or k > HAZARDS_UNTIL:
		if k < HAZARDS_FROM:
			_next_hazard = maxf(_next_hazard, travelled + SPAWN_AHEAD)
		return
	var lvl := Difficulty.level()
	while _next_hazard < travelled + SPAWN_AHEAD:
		var at := _next_hazard
		_next_hazard += HAZARD_EVERY[lvl] * randf_range(0.75, 1.25)
		if at / distance > HAZARDS_UNTIL:
			break
		if randf() < ARM_SHARE[lvl] and at - _last_arm_at > SPEED * 5.0:
			_last_arm_at = at
			_spawn_arm(at)
			# Now and then rocks just past it, so there's only so much room to get out from
			# under it.
			if randf() < GATE_SHARE[lvl]:
				var side := 1.0 if randf() < 0.5 else -1.0
				spawn_rock(at + randf_range(4.0, 8.0), clampf(lateral + side * randf_range(4.5, 6.0), -CHANNEL - 1.0, CHANNEL + 1.0), randf_range(1.0, 1.5))
		else:
			_spawn_rocks(at)

## A great arm, lurking ahead at this distance along her course.
func _spawn_arm(at: float) -> SeaArm:
	var lvl := Difficulty.level()
	var arm := SeaArm.new()
	arm.escape = self
	arm.radius = ARM_RADIUS[lvl]
	arm.max_hp = ARM_HP[lvl]
	arm.side = 1.0 if randf() < 0.5 else -1.0
	arm.aim = Vector3(at, Terrain.SEA_LEVEL, lateral)
	world.add_child(arm)
	arm.landed.connect(_on_arm_landed)
	arms.append(arm)
	return arm

## Where an arm lurking ahead means to come down (the world's z): where she is going.
func aim_lateral(_arm: SeaArm) -> float:
	return clampf(lateral + lateral_v * ARM_LEAD[Difficulty.level()], -CHANNEL, CHANNEL)

## Rocks breaking the surface across her course, always with a way through.
func _spawn_rocks(at: float) -> void:
	var gap := randf_range(-CHANNEL + 2.0, CHANNEL - 2.0)
	var n := randi_range(1, 3)
	var placed := 0
	var tries := 0
	# Half the time one lies right in her way.
	var first_z := lateral if randf() < 0.55 else randf_range(-CHANNEL - 1.0, CHANNEL + 1.0)
	while placed < n and tries < 12:
		tries += 1
		var r := randf_range(0.9, 1.7)
		var z := first_z if placed == 0 else randf_range(-CHANNEL - 1.0, CHANNEL + 1.0)
		if absf(z - gap) < EscapeMap.HALF_BEAM + r + 1.0:
			continue
		spawn_rock(at + randf_range(-3.0, 3.0), z, r)
		placed += 1

## One rock (or a knot of them) at a place on her course (world x, z) of radius r.
func spawn_rock(x: float, z: float, r: float) -> Dictionary:
	var node := Node3D.new()
	node.position = Vector3(x, 0.0, z)
	world.add_child(node)
	var i := randi()
	# Wet, pale-topped rock standing well out of the water, so it shows at night.
	_rock_at(node, i, Vector3(r * 1.5, r * 1.9, r * 1.4), Vector3(0.0, Terrain.SEA_LEVEL - r * 0.35, 0.0))
	if r > 1.2:
		_rock_at(node, i + 1, Vector3(r, r * 1.2, r * 0.9), Vector3(r * 0.7, Terrain.SEA_LEVEL - r * 0.35, -r * 0.6))
	# Surf breaking white round it: it shows in the dark before it's reached.
	var foam := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 3.6, r * 3.6)
	foam.mesh = pm
	foam.material_override = _foam_mat()
	foam.position = Vector3(0.0, Terrain.SEA_LEVEL + 0.08, 0.0)
	foam.rotation.y = randf() * TAU
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(foam)
	var rock := {"node": node, "x": x, "z": z, "r": r, "hit": false, "surf": 0.0}
	rocks.append(rock)
	return rock

var _foam: StandardMaterial3D

# A ring of broken white water, soft at both edges, ragged with noise.
func _foam_mat() -> StandardMaterial3D:
	if _foam != null:
		return _foam
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.42, 0.55, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var noise := NoiseTexture2D.new()
	noise.width = 128
	noise.height = 128
	noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.06
	noise.noise = fn
	_foam = StandardMaterial3D.new()
	_foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam.albedo_texture = tex
	_foam.albedo_color = Color(0.82, 0.9, 0.88, 0.9)
	_foam.detail_enabled = true
	_foam.detail_mask = noise
	_foam.detail_albedo = noise
	_foam.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	_foam.render_priority = 10
	return _foam

func _rocks_step() -> void:
	var lvl := Difficulty.level()
	for i in range(rocks.size() - 1, -1, -1):
		var r: Dictionary = rocks[i]
		var node: Node3D = r["node"]
		var at := Vector3(float(r["x"]) - travelled, Terrain.SEA_LEVEL, float(r["z"]) - lateral)
		if at.x < -40.0:
			node.queue_free()
			rocks.remove_at(i)
			continue
		r["surf"] = float(r["surf"]) - get_physics_process_delta_time()
		if float(r["surf"]) <= 0.0 and at.x < 40.0:
			r["surf"] = randf_range(0.6, 1.4)
			FX.splash(node, Vector3(randf_range(-1.0, 1.0) * float(r["r"]), Terrain.SEA_LEVEL, randf_range(-1.0, 1.0) * float(r["r"])), 0.5 + float(r["r"]) * 0.3)
		if not bool(r["hit"]) and EscapeMap.hull_gap(at) < float(r["r"]) * 0.85:
			r["hit"] = true
			hull_hit(ROCK_DMG[lvl], at, "rock")

func _on_arm_landed(arm: SeaArm, at: Vector3) -> void:
	arms.erase(arm)
	if not Run.active:
		return
	if EscapeMap.hull_gap(at) < arm.radius:
		hull_hit(ARM_DMG[Difficulty.level()], at, "arm")
	else:
		# A near thing: the sea it throws up rocks her.
		_kick = maxf(_kick, 0.04)
		Feel.shake(0.18)
		if EscapeMap.hull_gap(at) < arm.radius + 2.5:
			Events.message.emit("That was close!")

## A blow to her hull: from a rock, an arm, or something bursting on her deck.
func hull_hit(dmg: int, at: Vector3, kind: String) -> void:
	if not Run.active or foundered or arrived:
		return
	if _invuln > 0.0 and kind != "burst":
		return
	if kind != "burst":
		_invuln = INVULN
	hull = maxi(0, hull - dmg)
	_count("hull_" + kind)
	run_tally["hull"] = hull_max - hull
	_kick = maxf(_kick, 0.09 if kind == "arm" else 0.06)
	Feel.shake(0.6 if kind == "arm" else 0.45)
	Audio.sfx("wave_crash", at, 4.0, 0.08)
	Audio.sfx("creak", Vector3(at.x, EscapeMap.DECK_Y, at.z), 2.0, 0.15)
	if kind != "burst":
		FX.splash(self, Vector3(clampf(at.x, EscapeMap.STERN_X, EscapeMap.BOW_X), Terrain.SEA_LEVEL, signf(at.z if at.z != 0.0 else 1.0) * EscapeMap.HALF_BEAM), 2.4)
		FX.splinters(self, Vector3(clampf(at.x, EscapeMap.STERN_X, EscapeMap.BOW_X), EscapeMap.DECK_Y + 0.3, signf(at.z if at.z != 0.0 else 1.0) * (EscapeMap.HALF_BEAM - 0.2)))
		# The lurch: those standing are thrown, the arm's blow knocks down any near it.
		for p in players:
			if not is_instance_valid(p) or p.downed or p.in_menu:
				continue
			var away := p.global_position - Vector3(at.x, p.global_position.y, at.z)
			if kind == "arm" and Geo.flat_dist(p.global_position, at) < arm_knock_range():
				p.shove(away.normalized() * 4.0 if away.length() > 0.01 else Vector3(0.0, 0.0, 4.0))
			else:
				p.stagger_from(away)
	if _first_hit:
		_first_hit = false
		hud.warn("She's struck! Steer round them: [E] at the wheel.")
	elif hull > 0 and hull < hull_max * 0.3:
		hud.warn("She's taking water! %d%% of her hull left." % roundi(100.0 * hull / hull_max))
	if hull <= 0:
		_founder()

func arm_knock_range() -> float:
	return 3.5

# ---- over the side ----

func _boarders(delta: float, k: float) -> void:
	if k < BOARD_FROM or k > BOARD_UNTIL:
		return
	var lvl := Difficulty.level()
	if _surge < SURGES.size() and k >= float(SURGES[_surge]):
		_surge += 1
		surge(SURGE_SIZE[lvl] + Players.humans() - 1)
	_board_t -= delta
	if _board_t > 0.0:
		return
	# More of them for more people playing, and more as the crossing goes on.
	var people := float(Players.humans())
	_board_t = BOARD_EVERY[lvl] * lerpf(1.15, 0.8, k) / (1.0 + 0.3 * (people - 1.0)) * randf_range(0.8, 1.2)
	var alive := get_tree().get_nodes_in_group("boarders").size()
	var cap: int = BOARD_MAX[lvl] + int(people) - 1
	var n := 1 + (1 if randf() < 0.25 + 0.2 * float(lvl) else 0) + (1 if lvl > 0 and randf() < 0.15 * float(lvl) else 0)
	for i in n:
		if alive >= cap:
			break
		var slot := _free_slot()
		if slot < 0:
			break
		spawn_boarder("bloated" if randf() < BLOATED_SHARE[lvl] else "drowned", slot)
		alive += 1
	if _first_board:
		_first_board = false
		hud.warn("They're coming up out of the water after us! Knock them off her sides.")

## They come up all round her at once: `n` of them, spread along both sides.
func surge(n: int) -> void:
	var lvl := Difficulty.level()
	var free: Array[int] = []
	for s in EscapeMap.slots():
		free.append(s)
	for b in get_tree().get_nodes_in_group("boarders"):
		free.erase((b as Boarder).slot)
	free.shuffle()
	for i in mini(n, free.size()):
		spawn_boarder("bloated" if randf() < BLOATED_SHARE[lvl] else "drowned", free[i])
	_board_t = maxf(_board_t, BOARD_EVERY[lvl] * 1.5)
	_first_board = false
	hud.warn("They're coming up all round her!")
	Audio.sfx("splash", Vector3(0.0, Terrain.SEA_LEVEL, EscapeMap.HALF_BEAM + 2.0), 4.0, 0.1)
	Audio.sfx("splash", Vector3(-3.0, Terrain.SEA_LEVEL, -EscapeMap.HALF_BEAM - 2.0), 4.0, 0.1)

func _free_slot() -> int:
	var taken := {}
	for b in get_tree().get_nodes_in_group("boarders"):
		if (b as Boarder).clinging():
			taken[(b as Boarder).slot] = true
	var free: Array[int] = []
	for s in EscapeMap.slots():
		if not taken.has(s):
			free.append(s)
	return free[randi() % free.size()] if not free.is_empty() else -1

## One of them, swimming up to a slot on her gunwale.
func spawn_boarder(p_kind: String, slot: int) -> Boarder:
	var b := Boarder.new()
	b.setup(p_kind, slot, CLIMB_TIME[Difficulty.level()] * (1.35 if p_kind == "bloated" else 1.0))
	b.escape = self
	_enemies.add_child(b)
	_count("ashore")
	return b

## A boarder has got over the gunwale.
func boarded(b: Boarder) -> void:
	_count("aboard")
	if b.kind == "bloated":
		hud.warn("A bloated one is over the side! Keep it off them: it will burst.")
	else:
		hud.warn("One's over the side! It's going for them!")

## Knocked back into the sea from her side (or over the rail).
func knocked_off(_b: Boarder, overboard: bool) -> void:
	_count("overboard" if overboard else "knocked")

## One of the seven taken (by a boarder, or a burst).
func take_villager(v: Node, _by: Node = null) -> void:
	if v is Villager and (v as Villager).state != "lost":
		(v as Villager).take()

func _on_villager_taken(v: Villager) -> void:
	_count("lost")
	lost_here.append(Villagers.who(v.id).get("full", v.display_name()))
	hud.warn("They have taken %s over the side!" % v.display_name())

func _on_helm_changed(who: Node) -> void:
	if who == null:
		Events.message.emit("Dod Wiseman has the wheel.")

# ---- the rock's light ----

func _light_step(delta: float) -> void:
	if _rock == null:
		return
	_rock.position = Vector3(distance + ROCK_AHEAD, 0.0, ROCK_SIDE)
	var pivot := _rock.get_node_or_null("BeamPivot") as Node3D
	if pivot != null:
		pivot.rotation.y += delta * 0.55
	var near := _rock.global_position
	var d := Vector2(near.x, near.z).length()
	# Faint and far off at first; brighter as she comes on.
	var k := clampf(1.0 - (d - 30.0) / 260.0, 0.0, 1.0)
	_beam_mat.set_shader_parameter("intensity", 0.08 + 0.32 * k)
	_beam.visible = d < 300.0
	_lantern.light_energy = 1.0 + 4.0 * k
	# As the beam swings past her, the fog round her lights up.
	var to_boat := Vector2(-near.x, -near.z).normalized()
	var beam_dir := Vector2(-sin(pivot.rotation.y), -cos(pivot.rotation.y)) if pivot != null else Vector2.ZERO
	var on := clampf((beam_dir.dot(to_boat) - 0.96) / 0.04, 0.0, 1.0)
	var reach := clampf(1.0 - (d - 30.0) / 400.0, 0.15, 1.0)
	_flash_light.light_energy = on * 2.2 * reach
	if _fog != null:
		for c in _fog.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
				((c as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("brightness", 1.0 + on * 0.7 * reach)
		# Close in, the light holds the fog off her.
		_fog.gap = lerpf(FOG_GAP, 30.0, smoothstep(LIGHT_AT - 0.05, 1.0, progress()))

## The rock's light reaches her: what is in the water and on her sides falls back, and
## what is aboard goes over the side.
func _light_reaches() -> void:
	_light_told = true
	hud.warn("The light! They can't abide it: they're falling back.")
	for b in get_tree().get_nodes_in_group("boarders"):
		(b as Boarder).flee()
	for a in arms:
		if is_instance_valid(a) and (a.state == &"Lurk" or a.state == &"Rise" or a.state == &"Rear"):
			a.change_state(&"Recoil")
	arms.clear()

func _cliffs_step() -> void:
	# The coast to port: dark headlands in the fog.
	while _next_cliff < travelled + 70.0:
		var node := Node3D.new()
		node.position = Vector3(_next_cliff, 0.0, -21.0 - randf() * 4.0)
		world.add_child(node)
		var s := randf_range(4.0, 7.0)
		_rock_at(node, randi(), Vector3(s * 1.8, s * 1.4, s), Vector3(0.0, Terrain.SEA_LEVEL - s * 0.2, 0.0))
		_rock_at(node, randi(), Vector3(s, s * 0.9, s * 0.8), Vector3(s * 0.9, Terrain.SEA_LEVEL - s * 0.3, s * 0.4))
		_cliffs.append(node)
		_next_cliff += randf_range(7.0, 12.0)
	while not _cliffs.is_empty() and (_cliffs[0] as Node3D).position.x - travelled < -50.0:
		(_cliffs.pop_front() as Node3D).queue_free()

# ---- the wheel: Dod's hands, or a helper's ----

## The autopilot's steer for Dod or a helper (EscapeHelm.DOD / HELPER): it picks the
## place across the channel clear of what it can see coming, every so often, a little
## off, and steers for it.
func _steer_for(skill: Dictionary) -> float:
	var key := String(skill.get("name", "helper"))
	var st: Dictionary = _autopilot.get(key, {"t": 0.0, "goal": lateral})
	st["t"] = float(st["t"]) - get_physics_process_delta_time()
	if float(st["t"]) <= 0.0:
		st["t"] = float(skill["react"]) * randf_range(0.8, 1.2)
		st["goal"] = clampf(_safest(float(skill["look"])) + randf_range(-1.0, 1.0) * float(skill["err"]), -CHANNEL, CHANNEL)
	_autopilot[key] = st
	var to := float(st["goal"]) - lateral
	if absf(to) < 0.25:
		return 0.0
	return clampf(to / 1.2, -1.0, 1.0)

## The place across the channel (the world's z) clearest of the rocks and reared arms in
## sight, nearest where she is.
func _safest(look: float) -> float:
	var seen := []
	for r in rocks:
		var x := float(r["x"]) - travelled
		if x > EscapeMap.STERN_X - 2.0 and x < look and not bool(r["hit"]):
			seen.append([x, float(r["z"]), float(r["r"]) * 0.85])
	for a in arms:
		if is_instance_valid(a) and (a as SeaArm).showing():
			var p := (a as SeaArm).impact_point()
			if p.x < look:
				seen.append([p.x, p.z + lateral, (a as SeaArm).radius])
	if seen.is_empty():
		# Nothing ahead: back toward the middle, slowly.
		return lateral * 0.7
	var best := lateral
	var best_cost := INF
	var c := -CHANNEL
	while c <= CHANNEL + 0.01:
		var cost := absf(c - lateral) * 0.35 + absf(c) * 0.05
		for h in seen:
			var clear: float = EscapeMap.HALF_BEAM + float(h[2]) + 0.6
			if absf(float(h[1]) - c) < clear:
				# Nearer things matter more; past what can be reached in time, all the same.
				var ahead := maxf(0.0, float(h[0]) - EscapeMap.BOW_X)
				cost += 40.0 / (1.0 + ahead * 0.1)
		if cost < best_cost:
			best_cost = cost
			best = c
		c += 0.25
	return best

# ---- what the helpers do (KeeperAI asks) ----

## Whether this helper should go and take the wheel: nobody playing has it, and no other
## helper does.
func helm_free_for(k: Player) -> bool:
	return helm != null and helm.helmsman == null and not arrived

## What this helper should go for: the boarder that matters most to it, not one another
## helper has already claimed.
func threat_for(k: Player) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for b in get_tree().get_nodes_in_group("boarders"):
		var bo := b as Boarder
		if bo.hp <= 0 or bo.state == &"Flee" or bo.state == &"Ragdoll":
			continue
		# Still in the water, or only just taken hold of her side: a helper doesn't see it
		# till it is a little way up.
		if bo.state == &"Swim" or (bo.state == &"Climb" and bo.climb_progress() < HELPER_NOTICE):
			continue
		var d := Geo.flat_dist(k.global_position, bo.global_position)
		var score := d
		if bo.clinging():
			score -= bo.climb_progress() * 4.0
			# Its own side of her first.
			if signf(bo.global_position.z) != signf(k.global_position.z):
				score += 1.5
		else:
			score -= 5.0
		if _claims.has(bo) and _claims[bo] != k:
			score += 6.0
		if score < best_score:
			best_score = score
			best = bo
	if best != null:
		_claims[best] = k
	return best

## Where a helper with nothing to do stands: by the seven, at the gunwale.
func post_for(k: Player) -> Vector3:
	var posts := [Vector3(2.2, EscapeMap.DECK_Y, -1.15), Vector3(1.4, EscapeMap.DECK_Y, 1.15), Vector3(-4.4, EscapeMap.DECK_Y, 1.0)]
	return posts[k.idx % posts.size()]

# ---- the end of it ----

func _founder() -> void:
	if foundered:
		return
	foundered = true
	helm.release()
	Run.end_run("The Mary Ann went down in the fog, and everyone aboard her.")
	if boat != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(boat, "position:y", EscapeMap.ROOT_Y - 3.0, 7.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(boat, "rotation:x", 0.4, 7.0)
		tw.tween_property(boat, "rotation:z", 0.25, 7.0)

func _on_run_ended(reason: String, night: int) -> void:
	super._on_run_ended(reason, night)
	if helm != null:
		helm.release()
	# Continue (or try again) begins the crossing again with what came off the pier.
	_save()
	var stats = hud.get("_over_stats")
	if stats is Label:
		(stats as Label).text = "The Escape, on %s · %.1f miles from the rock" % [["a calm sea", "an angry sea", "a raging sea"][Difficulty.level()], miles_left()]
	var tally = hud.get("_over_tally")
	if tally is Label:
		(tally as Label).text = run_summary()

## The crossing in a few lines, for the game-over card.
func run_summary() -> String:
	var t := run_tally
	var g := func(key: String) -> int: return int(t.get(key, 0))
	var lines: Array[String] = []
	lines.append("%d came up out of the water after her; %d got over the side." % [g.call("ashore"), g.call("aboard")])
	var off: int = g.call("knocked") + g.call("overboard")
	if off > 0:
		lines.append("%d knocked back into the sea." % off)
	lines.append("Her hull: %d of %d." % [hull, hull_max])
	if not lost_here.is_empty():
		lines.append("Lost on the crossing: %s." % ", ".join(lost_here))
	return "\n".join(lines)

func _arrive() -> void:
	if arrived:
		return
	arrived = true
	Run.active = false
	helm.release()
	for b in get_tree().get_nodes_in_group("boarders"):
		(b as Boarder).flee()
	SaveSys.clear_run()
	var out := {"stock": Stock.all(), "arms": Run.arms.duplicate(true), "villagers": Run.villagers.duplicate(),
		"lost": Run.lost.duplicate(), "difficulty": Run.difficulty}
	if DisplayServer.get_name() != "headless" and not skip_pages:
		hud.visible = false
		var book := StoryPages.open(self, StoryText.crossing_after(lost_here), "")
		book.finished.connect(_to_rock.bind(out))
	else:
		_to_rock(out)

## On to the rock (Act Two) with what came across.
func _to_rock(out: Dictionary) -> void:
	Run.carry = out
	Run.escape_carry = {}
	Run.chapter = 1
	Terrain.chapter = 1
	get_tree().change_scene_to_file(MAIN_SCENE)

func _to_title() -> void:
	Run.active = false
	Run.carry = {}
	Run.escape_carry = {}
	Run.chapter = 1
	Terrain.chapter = 1
	get_tree().change_scene_to_file(MAIN_SCENE)

func _unhandled_input(_event: InputEvent) -> void:
	pass
