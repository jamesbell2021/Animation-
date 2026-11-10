extends "res://scenes/main.gd"
## Act One: Kirkhaven (docs/STORY.md). The harbour light was put on a clock, the clock
## stuck, and the fog came in with something in it. Three keepers paid off that week
## try to put the town's lights back and keep its seven people alive: they feed the
## generator, switch the street lamps in, work the harbour light on the pier, and keep
## the kirk doors, behind which the seven shelter at night. The town cannot be held.
## On the third night the fog comes over the quay, the Mary Ann's skipper sounds his
## horn, and the seven have to be brought down through the streets to the boat. Then the
## keepers board and she sails for the rock (Act Two, main.gd).
##
## This scene is the rock's (main.gd) with a different world built in _ready: the same
## keepers, creatures, lamp, HUD, weather and fog, on HarbourMap's ground (Terrain hands
## over to it while Terrain.chapter is 2). Local play only: there is no LAN in Kirkhaven.

const MAIN_SCENE := "res://scenes/main.tscn"
## Where the keepers begin: outside The Creel, where they had rooms.
const LANDING_SPOTS := [Vector3(3.2, 0.0, 1.4), Vector3(1.6, 0.0, 2.4), Vector3(4.8, 0.0, 2.6)]
## What the three carried off the rock.
const KIT := {"driftwood": 4, "scrap": 3, "bio": 2, "diesel": 1, "arrows": 18, "bombs": 3}
const GENERATOR_START := 12.0
## The harbour light points flatter than the rock's did: it stands lower.
const LIGHT_TILT := -26.0
## The nights start this far down the rock's table of landings.
const TABLE_SHIFT := 2
## A landing with a lamp burning at its head lets this share of a group through.
const LIT_LANDING := 0.7
## Kirkhaven draws more of them than the rock did: every group is this much bigger, and
## bigger again on the last night.
const SWELL := 1.35
const LAST_SWELL := 1.1
const LIT_LANDING_RANGE := 9.0
## How likely a group is to pick a dark landing over a lit one.
const DARK_WEIGHT := 3.0
## The bell: how long every lit lamp flares.
const BELL_FLARE := 8.0
## The last night: how far the fog comes over the town (FogBank.flood), and how fast.
const LAST_FLOOD := 0.72
const FLOOD_TIME := 70.0
## From this night, one raiding group a night goes for the kirk doors; on the last, half.
const KIRK_FROM_NIGHT := 3
const HARLS := [Color(0.84, 0.82, 0.76), Color(0.74, 0.74, 0.72), Color(0.80, 0.74, 0.64), Color(0.60, 0.60, 0.58)]
## The last night: how far through it the skipper sounds his horn.
const EVAC_AT := 0.34
## Seconds between each of the seven leaving the kirk.
const EVAC_GAP := 2.4
## While they come down, something more comes up a landing this often.
const EVAC_TRICKLE := 9.0
## What comes up each slip as the horn sounds: the way to the pier runs between them.
const EVAC_RUSH := 3
## With the kirk doors down, how often one of those inside is taken.
const BREACH_EVERY := 7.0
## By day the seven make for the kirk when this much of the day is left.
const CALL_IN := 22.0
## Where the Mary Ann lies, and the pier at her plank.
const BOARD_AT := Vector2(4.3, 21.0)
const MOOR_AT := Vector2(7.2, 21.0)

var generator: Generator
var kirk: KirkKeep
var lamps: Array[StreetLamp] = []
var houses: Array[TownHouse] = []
var villagers: Array[Villager] = []
## The last night's flight: 0 not yet, 1 the seven coming down, 2 the keepers to board,
## 3 away.
var _evac := 0
var _trickle_t := 0.0
var _trickles := 0
var _breach_t := 0.0
var _called_in := false
var _lost_tonight: Array = []
## Tonight's raiding groups so far (the latest is the one now coming ashore).
var _raid_groups := 0
var _crabs := 0
var _boats: Array = []
var _bob := 0.0

func _ready() -> void:
	var headless := DisplayServer.get_name() == "headless"
	if not (Run.enter_harbour or Run.quick_start or headless):
		# Nothing sent us here (back to the title from the pause menu): the title is on the rock.
		Run.chapter = 1
		Terrain.chapter = 1
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)
		return
	var cont := Run.enter_harbour and Run.harbour_continue
	Run.enter_harbour = false
	Run.harbour_continue = false
	Run.quick_start = false
	Run.chapter = 2
	Terrain.chapter = 2
	HarbourMap.extra_solids = []
	HarbourMap.reset_nav()
	KeeperNav.reset()
	_build_environment()
	_build_harbour_ground()
	_build_harbour_sea()
	var l := HarbourMap.LIGHT_AT
	lighthouse = Lighthouse.new()
	lighthouse.position = Vector3(l.x, Terrain.height_at(l.x, l.y), l.y)
	add_child(lighthouse)
	lighthouse.lamp.set_tilt(LIGHT_TILT)
	_build_generator()
	_build_town()
	_build_lamps()
	_build_kirk()
	_build_dressing()
	_build_stores()
	_build_camera()
	_enemies = Node3D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_build_harbour_spawner()
	atmosphere = Atmosphere.new()
	atmosphere.env = _env
	atmosphere.sky_mat = _sky_mat
	atmosphere.sea_mat = _sea_mat
	add_child(atmosphere)
	# The fog lies off the town's front: one long "island" whose south shore is the quay.
	atmosphere.fog.isles = [[0.0, -34.0, 70.0, 40.0 + HarbourMap.QUAY_Z - 6.0, 0.0]]
	atmosphere.fog._push_isles()
	# On the last night it comes over the quay and up the terraces.
	atmosphere.fog.add_flood_layers([HarbourMap.QUAY_H + 0.7, HarbourMap.QUAY_H + 1.5, HarbourMap.BACK_H + 0.9, HarbourMap.GREEN_H + 0.9])
	hud = HudScript.new()
	hud.lighthouse = lighthouse
	hud.lamp = lighthouse.lamp
	hud.camp = null
	hud.status_line = _status_line
	add_child(hud)
	add_child(PauseScript.new())
	events = NightEvents.new()
	add_child(events)
	Cycle.phase_changed.connect(_on_phase_changed)
	Events.run_ended.connect(_on_run_ended)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.structure_destroyed.connect(_on_structure_destroyed)
	Events.lore.connect(_on_lore)
	Audio.start_ambience()
	begin_run(cont, Players.wanted)

# ---- the world ----

func _slab(size: Vector3, at: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	(parent if parent != null else self).add_child(mi)
	return mi

func _build_harbour_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	var mesh := Terrain.build_harbour_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Look.terrain_mat()
	ground.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	ground.add_child(cs)
	# The quay's face and the pier's sides: dressed stone down into the water, with a
	# paler coping along the top.
	var wall := Look.stone(Color(0.52, 0.50, 0.47), 1.6)
	var cope := Look.stone(Color(0.72, 0.70, 0.66), 1.1)
	var top := HarbourMap.QUAY_H + 0.04
	var bottom := HarbourMap.BASIN - 0.3
	var h := top - bottom
	var y := (top + bottom) * 0.5
	var qz := HarbourMap.QUAY_Z + 0.24
	var sh := HarbourMap.SLIP_HALF + 0.35
	var ph := HarbourMap.PIER_HALF + 0.2
	var runs := [[HarbourMap.WEST - 8.0, float(HarbourMap.SLIPS[0]) - sh], [float(HarbourMap.SLIPS[0]) + sh, -ph],
		[ph, float(HarbourMap.SLIPS[1]) - sh], [float(HarbourMap.SLIPS[1]) + sh, HarbourMap.STRAND_X + 0.4]]
	for r in runs:
		var run_len := float(r[1]) - float(r[0])
		var cx := (float(r[0]) + float(r[1])) * 0.5
		_slab(Vector3(run_len, h, 0.6), Vector3(cx, y, qz), wall)
		_slab(Vector3(run_len, 0.14, 0.8), Vector3(cx, top + 0.05, qz - 0.1), cope)
	var hf := HarbourMap.PIER_HEAD_FROM - 0.35
	var hh := HarbourMap.PIER_HEAD_HALF + 0.2
	var pe := HarbourMap.PIER_END + 0.2
	for side in [-1.0, 1.0]:
		var stem_len := hf - HarbourMap.QUAY_Z - 0.5
		_slab(Vector3(0.6, h, stem_len), Vector3(side * (ph + 0.05), y, HarbourMap.QUAY_Z + 0.5 + stem_len * 0.5), wall)
		_slab(Vector3(0.8, 0.14, stem_len), Vector3(side * ph, top + 0.05, HarbourMap.QUAY_Z + 0.5 + stem_len * 0.5), cope)
		_slab(Vector3(hh - ph + 0.6, h, 0.6), Vector3(side * (ph + hh) * 0.5, y, hf), wall)
		_slab(Vector3(0.6, h, pe - hf), Vector3(side * (hh + 0.05), y, (pe + hf) * 0.5), wall)
		_slab(Vector3(0.8, 0.14, pe - hf), Vector3(side * hh, top + 0.05, (pe + hf) * 0.5), cope)
	_slab(Vector3(hh * 2.0 + 0.6, h, 0.6), Vector3(0.0, y, pe + 0.05), wall)
	_slab(Vector3(hh * 2.0 + 0.8, 0.14, 0.8), Vector3(0.0, top + 0.05, pe), cope)
	# Setts, flags and the pier's blocks, laid over the terrain (looks only).
	Paving.lay(self)
	_build_harbour_rocks()
	_build_green()

# Rocks along the arms and the strand's edges, and weed-dark boulders at the slips' feet.
func _build_harbour_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in 70:
		var west := rng.randf() < 0.5
		var x := rng.randf_range(HarbourMap.WEST - 9.0, HarbourMap.WEST - 0.5) if west else rng.randf_range(HarbourMap.EAST + 0.5, HarbourMap.EAST + 9.0)
		var z := rng.randf_range(-30.0, 28.0 if west else 22.0)
		var s := rng.randf_range(0.9, 2.6)
		var hgt := Terrain.height_at(x, z)
		if hgt < Terrain.SEA_LEVEL - 1.6:
			continue
		Look.rock(self, 500 + i, Vector3(s * rng.randf_range(0.9, 1.5), s, s * rng.randf_range(0.9, 1.4)), Vector3(x, hgt - s * 0.25, z), Terrain.WHIN.lerp(Terrain.ROCK, rng.randf()), 0.3)
	for i in 14:
		var x := rng.randf_range(HarbourMap.STRAND_X + 2.0, HarbourMap.EAST - 1.0)
		var z := rng.randf_range(8.0, 15.0)
		var s := rng.randf_range(0.3, 0.7)
		if absf(x - HarbourMap.STRAND_C) < 3.5:
			continue
		Look.rock(self, 700 + i, Vector3(s * 1.3, s, s * 1.2), Vector3(x, Terrain.height_at(x, z) - s * 0.3, z), Terrain.WHIN_DARK, 0.2)

# Grass on the kirk green and the hill behind.
func _build_green() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1987
	var xforms: Array[Transform3D] = []
	for i in 9000:
		var x := rng.randf_range(HarbourMap.WEST, HarbourMap.EAST)
		var z := rng.randf_range(HarbourMap.NORTH - 6.0, HarbourMap.RISE_2.y)
		if not Terrain.is_grassy(x, z):
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		xforms.append(Transform3D(b, Vector3(x, Terrain.height_at(x, z), z)))
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

func _build_harbour_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, 150.0)
	plane.subdivide_width = 240
	plane.subdivide_depth = 150
	sea.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sea.gdshader")
	sea.material_override = mat
	# One shore map for the whole front (it goes in the holm's slot); no rock, no islet.
	var rect := Rect2(-58.0, -2.0, 118.0, 44.0)
	mat.set_shader_parameter("shore_radius", -4000.0)
	mat.set_shader_parameter("holm_shore_tex", Terrain._shore_texture(rect, Terrain.height_at))
	mat.set_shader_parameter("holm_shore_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	mat.set_shader_parameter("use_holm_tex", 1.0)
	mat.set_shader_parameter("islet_shore_tex", Terrain._shore_texture(Rect2(9000.0, 9000.0, 2.0, 2.0), Terrain.height_at))
	mat.set_shader_parameter("islet_shore_rect", Vector4(9000.0, 9000.0, 2.0, 2.0))
	_sea_mat = mat
	sea.position = Vector3(0.0, Terrain.SEA_LEVEL, 58.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, Terrain.height_at(x, z), z)

func _build_generator() -> void:
	var g := HarbourMap.GENERATOR_AT
	generator = Generator.new()
	generator.owner_name = "harbour"
	generator.position = _ground(g.x, g.y)
	add_child(generator)
	generator.add_to_group("homes")
	HarbourMap.extra_solids.append(Rect2(g.x - Generator.HOUSE.x * 0.5, g.y - Generator.HOUSE.z * 0.5, Generator.HOUSE.x, Generator.HOUSE.z))

func _build_town() -> void:
	for i in HarbourMap.BUILDINGS.size():
		var b: Array = HarbourMap.BUILDINGS[i]
		var house := TownHouse.new()
		house.size = Vector3(float(b[2]), float(b[3]), float(b[4]))
		house.style = String(b[5])
		house.sign_text = String(b[6])
		house.roof = String(b[7])
		house.harl = HARLS[int(b[8]) % HARLS.size()]
		house.seed_value = 11 + i * 7
		# Nothing built on at the side: the wynds between the houses are the way through.
		house.allow_lean_to = false
		# Stood at the level of its front, so the door meets the street.
		var front := float(b[1]) + float(b[4]) * 0.5
		house.position = Vector3(float(b[0]), Terrain.height_at(float(b[0]), front), float(b[1]))
		add_child(house)
		houses.append(house)

func _build_lamps() -> void:
	for i in HarbourMap.LAMPS.size():
		var row: Array = HarbourMap.LAMPS[i]
		var lamp := StreetLamp.new()
		lamp.index = i
		lamp.label = String(row[2])
		lamp.generator = generator
		lamp.position = _ground(float(row[0]), float(row[1]))
		add_child(lamp)
		lamps.append(lamp)

func _build_kirk() -> void:
	var k := HarbourMap.KIRK_AT
	kirk = KirkKeep.new()
	kirk.position = _ground(k.x, k.y)
	add_child(kirk)
	kirk.add_to_group("homes")
	kirk.add_to_group("kirk")
	kirk.add_to_group("fog_lights")
	kirk.spoke.connect(_on_kirk_spoke)
	kirk.bell_rung.connect(_on_bell)
	kirk.destroyed.connect(_on_kirk_fallen)

func _put(n: Node3D, x: float, z: float, yaw_deg: float = 0.0, lift: float = 0.0) -> Node3D:
	n.position = _ground(x, z) + Vector3(0.0, lift, 0.0)
	n.rotation.y = deg_to_rad(yaw_deg)
	add_child(n)
	return n

# The harbour's furniture: bollards and ladders along the quay, creels and fish boxes
# by the sheds, boats at their moorings and hauled up the strand, the kirkyard.
func _build_dressing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62
	var edge := HarbourMap.QUAY_Z - 0.75
	for x in [-29.0, -23.0, -8.0, -5.0, 5.0, 8.0, 21.5, 24.0]:
		_put(HarbourProps.bollard(), x, edge)
	for z in [10.0, 14.0, 20.0, 27.5]:
		_put(HarbourProps.bollard(), -HarbourMap.PIER_HALF + 0.55 if z < 17.0 else -HarbourMap.PIER_HEAD_HALF + 0.55, z)
		_put(HarbourProps.bollard(), HarbourMap.PIER_HALF - 0.55 if z < 17.0 else HarbourMap.PIER_HEAD_HALF - 0.55, z)
	for x in [-26.0, 6.5, 22.5]:
		var lad := HarbourProps.ladder(HarbourMap.QUAY_H - HarbourMap.BASIN)
		lad.position = Vector3(x, HarbourMap.BASIN, HarbourMap.QUAY_Z + 0.62)
		add_child(lad)
	_put(HarbourProps.creel_stack(7, 3), -20.5, 0.4, 12.0)
	_put(HarbourProps.creel_stack(5, 9), -17.0, 1.2, -30.0)
	_put(HarbourProps.creel_stack(6, 5), 23.0, 1.0, 20.0)
	_put(HarbourProps.creel_stack(4, 14), 4.0, 19.5, 70.0)
	_put(HarbourProps.fish_boxes(8, 2), -24.5, -0.6, 4.0)
	_put(HarbourProps.fish_boxes(5, 6), -19.2, -0.9, -8.0)
	_put(HarbourProps.fish_boxes(6, 8), -3.6, 20.4, 30.0)
	_put(HarbourProps.net_heap(4), -12.5, 2.2, 0.0)
	_put(HarbourProps.net_heap(7), 26.8, -0.8, 40.0)
	_put(HarbourProps.net_heap(1), 3.4, 28.4, 0.0)
	_put(HarbourProps.winch(), float(HarbourMap.SLIPS[0]) + 3.6, 4.2, 180.0)
	_put(HarbourProps.winch(), float(HarbourMap.SLIPS[1]) - 3.6, 4.2, 180.0)
	_put(HarbourProps.anchor(), -6.4, 1.4, 25.0)
	_put(HarbourProps.phone_box(), 8.6, -0.6, 0.0)
	_put(HarbourProps.bench(), 0.6, -0.9, 0.0)
	_put(HarbourProps.bench(), -8.6, 1.0, 90.0)
	_put(HarbourProps.lifebelt_stand(), -2.0, 5.0, 0.0)
	_put(HarbourProps.lifebelt_stand(), 21.0, 5.0, 0.0)
	_put(HarbourProps.lifebelt_stand(), 4.4, 30.0, 0.0)
	for at in [[-27.5, 1.6], [-27.9, 0.8], [12.6, -1.0], [-1.6, -0.8]]:
		_put(HarbourProps.barrel(), float(at[0]), float(at[1]))
	# Boats: two at moorings, two hauled up the strand.
	var boats := [
		[Color(0.55, 0.16, 0.12), "ROSEHEARTY LASS", -9.0, 11.5, 82.0, true],
		[Color(0.14, 0.34, 0.28), "GUIDING STAR", 9.2, 12.5, 96.0, true],
		[Color(0.70, 0.62, 0.30), "BRAW LAD", 29.0, 6.4, 14.0, false],
		[Color(0.20, 0.22, 0.26), "FULMAR", 33.2, 4.4, -22.0, false],
	]
	for i in boats.size():
		var bt: Array = boats[i]
		var craft := HarbourProps.fishing_boat(bt[0], String(bt[1]), 21 + i)
		craft.rotation.y = deg_to_rad(float(bt[4]))
		if bool(bt[5]):
			craft.position = Vector3(float(bt[2]), Terrain.SEA_LEVEL - 0.25, float(bt[3]))
			_boats.append(craft)
		else:
			craft.position = _ground(float(bt[2]), float(bt[3])) + Vector3(0.0, 0.25, 0.0)
			craft.rotation.z = deg_to_rad(9.0 if i % 2 == 1 else -11.0)
		add_child(craft)
	# The Mary Ann herself lies beside the pier head, plank in, till the last night.
	boat = ReliefBoat.new()
	boat.add_to_group("relief_boat")
	add_child(boat)
	boat.lie_at(_ground(BOARD_AT.x, BOARD_AT.y), Vector3(MOOR_AT.x, Terrain.SEA_LEVEL, MOOR_AT.y))
	# The kirkyard: a wall round the green with a gap at the gate, and the stones.
	var gate := HarbourMap.KIRK_GATE
	var yard := HarbourMap.KIRKYARD
	var yard_w := yard.size.x
	var north := yard.position.y
	for side in [-1.0, 1.0]:
		var half := yard_w * 0.5 - HarbourMap.GATE_HALF
		_put(HarbourProps.wall(half, 1.0), gate.x + side * (HarbourMap.GATE_HALF + half * 0.5), gate.y)
		_put(HarbourProps.wall(yard.size.y, 1.0), gate.x + side * yard_w * 0.5, yard.get_center().y, 90.0)
	_put(HarbourProps.wall(yard_w, 1.0), gate.x, north)
	for i in 16:
		var x := gate.x + rng.randf_range(-yard_w * 0.5 + 0.8, yard_w * 0.5 - 0.8)
		var z := rng.randf_range(north + 0.8, gate.y - 0.9)
		if HarbourMap.KIRK_RECT.grow(0.7).has_point(Vector2(x, z)) or absf(x - gate.x) < 1.3:
			continue
		_put(HarbourProps.gravestone(30 + i), x, z, rng.randf_range(-12.0, 12.0))
	# Drains, mooring rings, rope ends, the kirk steps, weeds at the wall feet.
	Paving.dress(self)

# What can be fetched each day: scrap at the chandler's and the fish shed, lamp fuel
# at the chandler's, diesel at the fuel berth, driftwood off the strand, a little
# ammunition.
func _build_stores() -> void:
	var rows := [
		["scrap", 1, -6.4, -0.7], ["bio", 2, -2.6, -0.7], ["scrap", 1, -18.4, -0.6],
		["diesel", 1, -6.2, 4.4], ["driftwood", 2, 28.4, 5.6], ["driftwood", 1, 33.6, 7.4],
		["driftwood", 1, 35.0, 2.0], ["scrap", 1, 27.0, -1.2],
	]
	for r in rows:
		var sp := ScavengePoint.new(String(r[0]), int(r[1]))
		sp.position = _ground(float(r[2]), float(r[3]))
		add_child(sp)
	# Ammunition: cartridges from the harbour master's cabinet and arrows from the net
	# loft's bench, a few each day (five nights would otherwise outlast what was carried).
	var tin := ScavengePoint.new("shells", 3)
	tin.position = _ground(-27.6, -0.9)
	add_child(tin)
	var sheaf := ScavengePoint.new("arrows", 6)
	sheaf.position = _ground(31.6, -1.6)
	add_child(sheaf)

func _build_harbour_spawner() -> void:
	spawner = SpawnerScript.new()
	spawner.name = "Spawner"
	var pts: Array[Vector3] = []
	for i in HarbourMap.LANDINGS.size():
		for side in [-1.0, 1.0]:
			pts.append(HarbourMap.landing_point(i, 0.0, side * float(HarbourMap.LANDING_SPREAD[i])))
	spawner.points = pts
	spawner.enemies_root = _enemies
	spawner.lighthouse = lighthouse
	spawner.table_shift = TABLE_SHIFT
	spawner.raid_from = 1
	spawner.raid_skip = 3
	spawner.pick_point = _pick_landing
	spawner.count_scale = _landing_scale
	spawner.on_spawn = _on_spawn
	add_child(spawner)
	spawner.wave_incoming.connect(_on_wave_incoming)
	spawner.group_warning.connect(_on_group_warning)
	lighthouse.lamp.smothered_changed.connect(_on_smothered)

# ---- the run ----

func begin_run(continue_save: bool, n: int) -> void:
	camera.current = true
	lighthouse.lamp.showcase = false
	lighthouse.lamp._set_state(Lamp.State.OFF)
	Players.configure(n)
	var total := Players.MAX if Players.helpers else Players.wanted
	for i in total:
		var p := Player.new()
		p.idx = i
		p.ai = i >= Players.wanted
		var at: Vector3 = LANDING_SPOTS[i % LANDING_SPOTS.size()]
		p.position = at + Vector3(0.0, Terrain.height_at_v(at) + 0.2, 0.0)
		p.camera = camera
		p.lamp = lighthouse.lamp
		Players.nodes.append(p)
		players.append(p)
		add_child(p)
		if p.ai:
			# The first helper keeps the harbour light; any other walks the lamps.
			var brain := KeeperAI.new(p, "light" if i == Players.wanted else "lamps")
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
	var d := SaveSys.load_run() if continue_save else {}
	if not d.is_empty() and int(d.get("chapter", 1)) == 2:
		Run.start_loaded(d)
	else:
		d = {}
		Run.start_new()
		for k in KIT:
			Stock.set_amount(k, int(KIT[k]))
		Run.camp_fuel = GENERATOR_START
		# Each keeper has a longbow; the first carries the shotgun too.
		for i in Run.arms.size():
			Run.arms[i] = ["bow", "shotgun"] if i == 0 else ["bow"]
	Run.chapter = 2
	# The town is only ever played as the story's first act.
	Run.story = true
	if d.is_empty():
		Run.villagers = Villagers.all_ids()
		Run.lost = []
	_spawn_villagers()
	lighthouse.lamp.fuel = Run.lamp_fuel
	generator.fuel = Run.camp_fuel
	for i in lamps.size():
		lamps[i].on = Run.lamps_on.has(i)
	for p in players:
		p.max_hp = Player.BASE_HP + int(Run.max_hp_bonus[p.idx])
		p.hp = p.max_hp
	Upgrades.apply(get_tree())
	if d.is_empty():
		hud.report("Kirkhaven. First light.", [
			"Seven of the town are left. At dusk they shut themselves in the kirk.",
			"Fill the generator (west end of the quay) and switch the street lamps in: the fog cannot lie in a burning lamp's light.",
			"At dusk they come up the slips and the strand. Work the harbour light ([R] at its door on the pier), and keep them from the kirk doors.",
		], FIRST_DAY_TIP_TIME + 4.0)
	else:
		hud.report("Kirkhaven. Night %d to come." % Run.night, ["%d of %d lamps are switched in." % [_lamps_on(), lamps.size()]], 6.0)
	_apply_lighting(Cycle.Phase.DAY, 0.0)
	atmosphere.apply(Cycle.Phase.DAY, 0.0)
	Cycle.start(Cycle.Phase.DAY)
	_camera_hint.call_deferred()
	jobs = Jobs.new()
	jobs.players = players
	add_child(jobs)
	Audio.music("harbour_day", 4.0)

func _process(delta: float) -> void:
	if lighthouse == null:
		return
	_bob += delta
	for i in _boats.size():
		var b: Node3D = _boats[i]
		b.position.y = Terrain.SEA_LEVEL - 0.25 + sin(_bob * 0.9 + float(i) * 1.7) * 0.07
		b.rotation.z = sin(_bob * 0.7 + float(i) * 2.3) * 0.035
	_rescue_step(delta)
	_cine_step(delta)
	if not Run.active:
		return
	if _evac == 0 and Input.is_action_just_pressed("skip"):
		Cycle.skip()
	_alarms(delta)
	_people_step(delta)

func _unhandled_input(_event: InputEvent) -> void:
	pass

# ---- lamps, landings, the kirk ----

func _lamps_on() -> int:
	var n := 0
	for l in lamps:
		if l.on and l.hp > 0:
			n += 1
	return n

func _lamps_lit() -> int:
	var n := 0
	for l in lamps:
		if l.is_lit():
			n += 1
	return n

## The HUD's line for the town: its lamps and the generator.
func _status_line() -> Array:
	if generator == null or not is_instance_valid(generator):
		return ["", false]
	var broken := 0
	for l in lamps:
		if l.hp <= 0:
			broken += 1
	var parts: Array[String] = ["Lamps: %d of %d switched in" % [_lamps_on(), lamps.size()]]
	if broken > 0:
		parts.append("%d smashed" % broken)
	var gen := "generator wrecked" if generator.is_destroyed() else "generator %d%%" % roundi(generator.fuel)
	parts.append(gen)
	if kirk != null and kirk.is_damaged():
		parts.append("kirk doors %d%%" % roundi(kirk.health_ratio() * 100.0))
	var alarm := generator.is_destroyed() or generator.fuel < Generator.LOW or (kirk != null and kirk.health_ratio() < 0.5)
	return [" · ".join(parts), alarm]

## Whether a landing has a lamp burning at its head.
func landing_lit(i: int) -> bool:
	var top: Vector2 = HarbourMap.LANDINGS[i][2]
	for l in lamps:
		if l.is_lit() and Vector2(l.global_position.x, l.global_position.z).distance_to(top) <= LIT_LANDING_RANGE:
			return true
	return false

# They would sooner come up in the dark: a landing with no lamp at its head is that much
# more likely. "opp" groups keep off the night's first landing.
func _pick_landing(entry: Dictionary) -> int:
	var first: int = spawner._first_point
	var weights: Array[float] = []
	var total := 0.0
	for i in HarbourMap.LANDINGS.size():
		var w := 1.0 if landing_lit(i) else DARK_WEIGHT
		if entry.get("opp", false) and first >= 0 and i == first / 2:
			w = 0.0
		weights.append(w)
		total += w
	if total <= 0.0:
		return -1
	var roll := randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i * 2 + randi() % 2
	return -1

func _landing_scale(at: Vector3) -> float:
	var k := SWELL * (LAST_SWELL if Rescue.is_last_night() else 1.0)
	return k * (LIT_LANDING if landing_lit(HarbourMap.nearest_landing(at.x, at.z)) else 1.0)

# Some of each night's raiders are sent at the kirk doors.
func _on_spawn(e: Enemy, kind: String, raid: bool) -> void:
	if kirk == null or kirk.is_destroyed() or not (kind == "B" or kind == "C"):
		return
	if kind == "C" and Rescue.is_last_night():
		# Every other Crab of the last night.
		_crabs += 1
		if _crabs % 2 == 1:
			e.raid_goal = kirk
	elif kind == "B" and raid and _for_kirk():
		e.raid_goal = kirk

# Whether the raiding group now coming ashore is for the kirk: the night's first from
# the third night, every other one (and every other Crab) on the last.
func _for_kirk() -> bool:
	if Rescue.is_last_night():
		return _raid_groups % 2 == 1
	return Run.night >= KIRK_FROM_NIGHT and _raid_groups == 1

func _on_group_warning(kind: String, points: Array, raid: bool) -> void:
	Audio.horn([1.0] if points.size() == 1 else [1.0, 1.0], -5.0)
	var what: String = SpawnerScript.WARNINGS.get(kind, "Something stirs in the water")
	var where: Array[String] = []
	for p in points:
		var nm := HarbourMap.place_name(p)
		if not where.has(nm):
			where.append(nm)
	var text := "%s — %s." % [what, " and ".join(where)]
	if raid:
		_raid_groups += 1
		text += "  They're making for the %s!" % ("kirk" if _for_kirk() else "lamps")
	hud.warn(text)

func _on_smothered(on: bool) -> void:
	if on and Run.active:
		_count("smother")
		Audio.horn([1.0, 1.0, 1.0, 1.0], -1.0)
		hud.warn("The harbour light is smothered! Throw your boathook at it from the pier!")

func _on_kirk_spoke(text: String) -> void:
	hud.report("At the kirk door", [text], 9.0)

func _on_bell() -> void:
	for l in lamps:
		if l.is_lit():
			l.flare = BELL_FLARE
	_count("bell")
	hud.warn("The kirk bell! Every lamp in Kirkhaven burns white.")

func _on_kirk_fallen() -> void:
	if not Run.active:
		return
	_count("kirk")
	_breach_t = BREACH_EVERY * 0.5
	if _inside().is_empty():
		hud.warn("The kirk doors are down.")
	else:
		hud.warn("The kirk doors are down! They are in among them: mend the doors!")

func _on_structure_destroyed(s: Node) -> void:
	if s is StreetLamp:
		_count("lamp")
	elif s == generator:
		_count("generator")
		hud.warn("The generator is wrecked: every lamp in the town is out! Mend it!")
	elif s is Fence:
		_count("fence")

func _alarms(delta: float) -> void:
	if not Run.active:
		return
	var lamp := lighthouse.lamp
	if lamp.state == Lamp.State.GUTTERING:
		_gutter_horn_t -= delta
		if _gutter_horn_t <= 0.0:
			_gutter_horn_t = HORN_GUTTER_EVERY
			Audio.horn([1.0, 1.0, 1.0], -2.0)
			hud.warn("The harbour light is guttering! Refuel it at its door!")
	else:
		_gutter_horn_t = 0.0
	if lighthouse.health_ratio() < 0.3 and not _warned_low and lighthouse.hp > 0:
		_warned_low = true
		Audio.horn([1.0, 3.0], -2.0)
		hud.warn("The harbour light is failing!")

# ---- the day and the night ----

func _on_phase_changed(p: int) -> void:
	if _evac > 0:
		return
	_apply_lighting(p, LIGHT_TWEEN)
	if p == Cycle.Phase.DAWN:
		_warned_low = false
	if p == Cycle.Phase.DAY:
		_called_in = false
	if p == Cycle.Phase.DUSK and Run.active:
		_tally = {}
		_raid_groups = 0
		_crabs = 0
		_lost_tonight = []
		_call_in()
		kirk.besieged = Rescue.is_last_night()
		if Villagers.dusk_engineer(generator):
			Events.message.emit("Sandy Coull has put what diesel he had in the generator  (%d%%)" % roundi(generator.fuel))
		if Rescue.is_last_night():
			hud.warn("The third night. The fog is coming over the quay: every lamp that burns is a street they cannot have.")
		elif generator.fuel <= 0.0 or generator.is_destroyed():
			hud.warn("Dusk, and the generator is %s: not a lamp will light!" % ("wrecked" if generator.is_destroyed() else "dry"))
		else:
			hud.warn("Dusk. %d of %d lamps are switched in." % [_lamps_on(), lamps.size()])
		_wireless()
	if p == Cycle.Phase.NIGHT and Run.active:
		# Whoever is still out of doors is out of time.
		for v in villagers:
			if v.state == "walking" or v.state == "about":
				v.walk_to(kirk.door_point(), "inside", true)
		Audio.music("finale" if Rescue.is_last_night() else "harbour_night", 4.0)
		if Rescue.is_last_night():
			# The fog comes over the town.
			create_tween().tween_property(atmosphere.fog, "flood", LAST_FLOOD, FLOOD_TIME).set_trans(Tween.TRANS_SINE)
	if p == Cycle.Phase.DAWN and Run.active:
		create_tween().tween_property(atmosphere.fog, "flood", 0.0, 6.0)
		for v in villagers:
			if v.state == "inside":
				v.place(kirk.door_point() + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(0.0, 1.0)), "about")
				v.walk_to(_home_of(v), "about")
		_dawn_report()
		var damaged := 0
		for s in get_tree().get_nodes_in_group("structures"):
			if s is Structure and s.is_damaged():
				damaged += 1
		Run.lamp_fuel = lighthouse.lamp.fuel
		Run.camp_fuel = generator.fuel
		Run.advance_night(damaged)
		Audio.music("harbour_day", 8.0)
	if p == Cycle.Phase.DAY and Run.active:
		Audio.music("harbour_day", 8.0)

const WIRELESS := [
	"\"...Kirkhaven harbour office to any vessel. The harbour light is dark. Repeat, dark. Stand off the pier...\"",
	"\"...coastguard to Mary Ann. The bank is moving against the wind. If you mean to lie at that pier, do not lie there long...\"",
]
const WIRELESS_LAST := "\"...Mary Ann to the keepers. I can give you till the ebb and not a minute past it. Listen for my horn...\""

func _wireless() -> void:
	events.wireless(WIRELESS_LAST if Rescue.is_last_night() else WIRELESS[(Run.night - 1) % WIRELESS.size()])

# The keeper's log for a night in the town.
func _dawn_report() -> void:
	var t := _tally
	var g := func(k: String) -> int: return int(t.get(k, 0))
	var how: Array[String] = []
	for k in [["beam", "burned by the light"], ["hook", "to the boathook"], ["shot", "shot"], ["arrow", "to arrows"], ["bomb", "to petrol bombs"], ["flare", "to flares"], ["flame", "to the flamer"], ["poison", "poisoned"]]:
		if g.call(k[0]) > 0:
			how.append("%d %s" % [g.call(k[0]), k[1]])
	var lines: Array[String] = []
	lines.append("%d came ashore%s" % [g.call("ashore"), (" · " + " · ".join(how)) if not how.is_empty() else ""])
	var broken := 0
	for l in lamps:
		if l.hp <= 0:
			broken += 1
	var cost: Array[String] = ["%d of %d lamps switched in" % [_lamps_on(), lamps.size()]]
	if broken > 0:
		cost.append("%d smashed" % broken)
	cost.append("generator %s" % ("wrecked" if generator.is_destroyed() else "%d%%" % roundi(generator.fuel)))
	cost.append("kirk doors %d/%d" % [kirk.hp, kirk.max_hp])
	cost.append("harbour light %d/%d, fuel %d%%" % [lighthouse.hp, lighthouse.max_hp, roundi(lighthouse.lamp.fuel)])
	lines.append(" · ".join(cost))
	var tip := ""
	if generator.is_destroyed():
		tip = "Mend the generator first (scrap or driftwood): without it not a lamp burns."
	elif generator.fuel < 40.0:
		tip = "The generator is low. There is a can of diesel at the fuel berth by the pier every day."
	elif broken > 0:
		tip = "A smashed lamp takes one scrap to mend: the chandler's door and the fish shed have some every day."
	elif _lamps_on() < lamps.size():
		tip = "There are lamps still dark. Each one switched in is a pool the fog can't lie in, and a landing with a lamp at its head lets fewer through."
	elif kirk.is_damaged():
		tip = "Mend the kirk doors with driftwood off the strand: the seven are behind them every night."
	elif not Run.bell_mended:
		tip = "Splice the kirk bell's rope ([F] at the kirk door, 2 scrap). Rung in the dark, it makes every burning lamp flare white."
	elif lighthouse.lamp.fuel < 30.0:
		tip = "The harbour light is low: the chandler's has lamp fuel. Refuel at its door."
	if tip != "":
		lines.append("")
		lines.append(tip)
	if _lost_tonight.is_empty():
		lines.append("All %s of Kirkhaven's people saw the morning." % ["none", "one", "two", "three", "four", "five", "six", "seven"][clampi(Villagers.count(), 0, 7)] if Villagers.count() > 0 else "There is nobody left in Kirkhaven but ourselves.")
	else:
		lines.append("Lost in the night: %s. %d of the seven are left." % [", ".join(_lost_tonight), Villagers.count()])
	var gifts := Villagers.dawn_gifts()
	if gifts != "":
		lines.append(gifts)
	if Villagers.dawn_nursing(players):
		lines.append("Nurse Buchan has seen to the keepers.")
	var left := Rescue.night() - Run.night
	if left == 1:
		lines.append("One more night. The skipper says the town cannot be held past it: when he sounds his horn, bring them down to the boat.")
	elif left > 1:
		lines.append("%d more nights." % left)
	hud.report("Night %d held." % Run.night, lines)

# ---- the seven ----

func _spawn_villagers() -> void:
	for id in Run.villagers:
		var v := Villager.new(String(id))
		add_child(v)
		v.place(_home_of(v), "about")
		v.taken.connect(_on_villager_taken)
		v.arrived.connect(_on_villager_arrived)
		villagers.append(v)

func _home_of(v: Villager) -> Vector3:
	var h: Vector2 = Villagers.who(v.id).get("home", Vector2.ZERO)
	return _ground(h.x, h.y)

## Those shut in the kirk now.
func _inside() -> Array:
	var out := []
	for v in villagers:
		if v.state == "inside":
			out.append(v)
	return out

# Late in the day they make for the kirk.
func _call_in() -> void:
	if _called_in:
		return
	_called_in = true
	var any := false
	for v in villagers:
		if v.state == "about" or v.state == "walking":
			v.walk_to(kirk.door_point(), "inside", true)
			any = true
	if any and Run.active:
		Events.message.emit("The seven are making for the kirk." if Villagers.count() == 7 else "Kirkhaven's people are making for the kirk.")

func _on_villager_taken(v: Villager) -> void:
	_count("lost")
	_lost_tonight.append(v.display_name())
	hud.warn("They have taken %s." % v.display_name())

func _on_villager_arrived(v: Villager) -> void:
	if v.state == "aboard":
		Events.message.emit("%s is aboard the Mary Ann." % v.display_name())

# The seven by day and night, the kirk when its doors are down, and the last night.
func _people_step(delta: float) -> void:
	if Cycle.phase == Cycle.Phase.DAY and Cycle.time_left < CALL_IN:
		_call_in()
	var dark := Cycle.phase == Cycle.Phase.NIGHT or Cycle.phase == Cycle.Phase.DUSK
	if _evac == 0 and dark and kirk.is_destroyed():
		if Rescue.is_last_night():
			# Nothing to keep them there now: they run for the boat.
			_begin_evacuation()
		else:
			_breach_t += delta
			if _breach_t >= BREACH_EVERY:
				_breach_t = 0.0
				var inside := _inside()
				if not inside.is_empty():
					(inside[randi() % inside.size()] as Villager).take()
	if _evac == 0 and Rescue.is_last_night() and Cycle.phase == Cycle.Phase.NIGHT and Cycle.progress() >= EVAC_AT:
		_begin_evacuation()
	if _evac == 1:
		_trickle_t -= delta
		if _trickle_t <= 0.0:
			_trickle_t = EVAC_TRICKLE
			_trickles += 1
			# Up one slip, then the other, either side of the pier's foot.
			spawner._queue_group({"kind": "B" if _trickles % 3 != 0 else "S", "count": 2, "point": (_trickles % 2) * 2 + randi() % 2, "opp": false})
		var ashore := false
		for v in villagers:
			ashore = ashore or (v.state != "aboard" and v.state != "lost")
		if not ashore:
			_evac = 2
			boat.open_plank()
			Audio.sfx("boat_horn", boat.global_position, 4.0, 0.0)
			if Villagers.count() > 0:
				hud.warn("They are aboard. Now yourselves: down the pier to the Mary Ann!  [E] at her plank.")
			else:
				hud.warn("There is nobody left to bring. Down the pier to the Mary Ann!  [E] at her plank.")

# ---- the last night: down to the boat ----

# The skipper's horn: the kirk doors open and the seven come down through the streets.
func _begin_evacuation() -> void:
	if _evac > 0:
		return
	_evac = 1
	_trickle_t = EVAC_TRICKLE
	# The night holds until she sails.
	Cycle.running = false
	kirk.besieged = false
	Audio.sfx("boat_horn", boat.global_position, 6.0, 0.0)
	get_tree().create_timer(1.9).timeout.connect(func() -> void: Audio.sfx("boat_horn", boat.global_position, 6.0, 0.0))
	var inside := _inside()
	if inside.is_empty() and Villagers.count() == 0:
		return
	hud.report("The Mary Ann's horn!", [
		"Dod Wiseman cannot lie at the pier past the ebb. The kirk doors are open.",
		"Bring them down through the streets to the boat at the pier head. Stay by them, and keep the way lit: anything that gets within reach of one of them takes them.",
		"When they are aboard, go aboard yourselves.",
	], 14.0)
	for slip in 2:
		spawner._queue_group({"kind": "B", "count": EVAC_RUSH, "point": slip * 2, "opp": false})
	var door := kirk.door_point()
	var to := _ground(BOARD_AT.x, BOARD_AT.y)
	for i in inside.size():
		var v: Villager = inside[i]
		get_tree().create_timer(0.6 + float(i) * EVAC_GAP).timeout.connect(func() -> void:
			if is_instance_valid(v) and v.state == "inside":
				v.place(door + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(0.0, 0.6)), "about")
				v.walk_to(to, "aboard", true))

func _sail() -> void:
	_evac = 3
	Audio.music("chapter_end", 3.0)
	boat.depart()
	boat.departed.connect(_after_town)
	_follow_boat()

# Away. What was saved goes with them to the rock (Act Two).
func _after_town() -> void:
	Run.active = false
	Cycle.stop()
	SaveSys.finish_chapter(2)
	SaveSys.clear_run()
	Run.carry = {"stock": Stock.all(), "arms": Run.arms.duplicate(true), "villagers": Run.villagers.duplicate(),
		"lost": Run.lost.duplicate(), "difficulty": Run.difficulty}
	if DisplayServer.get_name() != "headless":
		hud.visible = false
		var book := StoryPages.open(self, StoryText.crossing(Villagers.count(), Villagers.lost_names()), "")
		book.finished.connect(_to_rock)
	else:
		_to_rock()

func _to_rock() -> void:
	Run.chapter = 1
	Terrain.chapter = 1
	get_tree().change_scene_to_file(MAIN_SCENE)

func _to_title() -> void:
	Run.active = false
	Run.chapter = 1
	Terrain.chapter = 1
	get_tree().change_scene_to_file(MAIN_SCENE)
