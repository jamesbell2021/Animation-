class_name TowerClimbCourse
extends FairgroundCourse
## Tower Climb: an extreme obby spiralling up a 120 m neon tower. Eight stages
## (TowerStage) climb 15 m each round the tower; each starts on a checkpoint
## landing, and falling sends you back to it. Every item is in play. The first
## to reach Connor's Crown on the top wins.

const STAGES := 8
const TOP_Y := TowerStage.RISE * STAGES
const CORE_RADIUS := 5.0
const CROWN_RADIUS := 6.8
## How far below your last checkpoint you can fall before you're sent back.
const FALL_DEPTH := 8.0

var _spawns: Array[Vector3] = []
var _connected: bool = false


func build() -> void:
	if not is_inside_tree():
		push_error("TowerClimbCourse.build: not inside the scene tree.")
		return
	clear()
	_build_environment()
	var holder := Node3D.new()
	holder.name = "SceneryTower"
	add_child(holder)
	_build_plaza(holder)
	_build_core(holder)
	for i in range(STAGES):
		var stage := TowerStage.new()
		stage.name = "Stage%d" % (i + 1)
		stage.stage_index = i
		stage.kind = i
		add_child(stage)
		stage.build(checkpoint_manager)
		sections.append(stage)
	_build_crown(holder)
	_total_length = TOP_Y
	_spawns.clear()
	for i in range(8):
		var a := -0.12 - float(i / 2) * 0.12
		var r := TowerStage.RADIUS + (-1.3 if i % 2 == 0 else 1.3)
		_spawns.append(TowerStage.point(a, 1.0, r))
	if not _connected and checkpoint_manager != null:
		_connected = true
		checkpoint_manager.checkpoint_reached.connect(_on_checkpoint_reached)
	course_built.emit()


func get_spawn_positions(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(count):
		out.append(_spawns[i % _spawns.size()])
	return out


## Every stage's item box spots (world space) for the ItemManager.
func item_box_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for section in sections:
		var stage := section as TowerStage
		if stage != null:
			spots.append_array(stage.box_spots())
	return spots


## All the weapons are in play on the tower.
func item_pool() -> Array[int]:
	var pool: Array[int] = []
	for kind in ItemKinds.RANDOM_POOL:
		pool.append(int(kind))
	return pool


## New race: everyone back to the ground-floor fall limit.
func on_restart(contestants: Array[Contestant]) -> void:
	for c in contestants:
		if is_instance_valid(c):
			c.fall_limit_y = -6.0


## World position of the crown (for the fireworks).
func crown_position() -> Vector3:
	return Vector3(0.0, TOP_Y, 0.0)


## Falling more than FALL_DEPTH below your checkpoint sends you back to it.
func _on_checkpoint_reached(contestant: Contestant, index: int) -> void:
	if contestant != null:
		contestant.fall_limit_y = checkpoint_manager.get_respawn_point(index).y - FALL_DEPTH


## The start pad by the foot of the spiral; everything else under the tower is
## a pit (fall in and you're back at your last landing).
func _build_plaza(parent: Node3D) -> void:
	var start := TowerStage.point(-0.3, 0.0)
	CourseBuilder.add_cylinder(parent, 4.2, 1.0, start - Vector3.UP * 0.5, Color(0.1, 0.1, 0.13), "StartPad")
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.0
	torus.outer_radius = 4.2
	torus.material = CourseBuilder.make_neon_material(CourseBuilder.accent(1), 2.0)
	rim.mesh = torus
	rim.position = start + Vector3.UP * 0.02
	rim.scale = Vector3(1.0, 0.4, 1.0)
	parent.add_child(rim)
	CourseBuilder.add_sign(parent, "TOWER CLIMB", start + Vector3(0.0, 6.0, 0.0) + (start.normalized() * 3.0), CourseBuilder.accent(0), 140)
	# The pit floor, far below.
	CourseBuilder.add_decor_box(parent, Vector3(600.0, 1.0, 600.0), Vector3(0.0, -30.0, 0.0), Color(0.03, 0.035, 0.04), "Ground")
	for r: float in [8.0, 14.0, 20.0]:
		var ring := MeshInstance3D.new()
		var pit := TorusMesh.new()
		pit.inner_radius = r - 0.25
		pit.outer_radius = r
		pit.rings = 64
		pit.material = CourseBuilder.make_neon_material(CourseBuilder.accent(2), 1.5)
		ring.mesh = pit
		ring.position = Vector3(0.0, -29.4, 0.0)
		ring.scale = Vector3(1.0, 0.4, 1.0)
		parent.add_child(ring)


func _build_core(parent: Node3D) -> void:
	var segment := 6.0
	var count := int(ceil(TOP_Y / segment))
	for i in range(count):
		var y := float(i) * segment
		var drum := CourseBuilder.make_cylinder_mesh(CORE_RADIUS, segment, Color(0.13, 0.13, 0.17) if i % 2 == 0 else Color(0.16, 0.15, 0.2))
		drum.position = Vector3(0.0, y + segment * 0.5, 0.0)
		parent.add_child(drum)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = CORE_RADIUS
		torus.outer_radius = CORE_RADIUS + 0.2
		torus.material = CourseBuilder.make_neon_material(CourseBuilder.accent(i % 4), 1.8)
		ring.mesh = torus
		ring.position = Vector3(0.0, y + segment, 0.0)
		parent.add_child(ring)
	# Solid core so nobody falls through the middle.
	var body := StaticBody3D.new()
	body.name = "CoreBody"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = CORE_RADIUS
	cylinder.height = TOP_Y
	shape.shape = cylinder
	body.add_child(shape)
	body.position = Vector3(0.0, TOP_Y * 0.5, 0.0)
	parent.add_child(body)
	# Searchlights sweeping up the tower.
	for i in range(4):
		var a := TAU * float(i) / 4.0 + 0.4
		var light := SpotLight3D.new()
		light.light_color = CourseBuilder.accent(i)
		light.light_energy = 6.0
		light.spot_range = 140.0
		light.spot_angle = 14.0
		parent.add_child(light)
		light.position = Vector3(cos(a) * 30.0, 0.5, sin(a) * 30.0)
		light.look_at(Vector3(0.0, TOP_Y * 0.6, 0.0), Vector3.UP)


func _build_crown(parent: Node3D) -> void:
	# The summit: a round top on the tower with a bridge out to the end of the path.
	CourseBuilder.add_cylinder(parent, CROWN_RADIUS, 0.8, Vector3(0.0, TOP_Y - 0.4, 0.0), CourseBuilder.surface(Color(1.0, 0.75, 0.1)), "Summit")
	var end_theta := float(STAGES) * TowerStage.ARC
	var bridge_mid := TowerStage.point(end_theta, TOP_Y - 0.3, (CROWN_RADIUS + TowerStage.RADIUS + 1.5) * 0.5)
	var bridge := CourseBuilder.add_box(parent, Vector3(3.2, 0.6, TowerStage.RADIUS + 1.5 - CROWN_RADIUS + 1.0), bridge_mid, CourseBuilder.surface(Color(1.0, 0.75, 0.1)), "SummitBridge")
	bridge.rotation.y = PI * 0.5 - end_theta
	var gold := CourseBuilder.make_neon_material(Color(1.0, 0.75, 0.1), 3.0)
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.2
	torus.outer_radius = 2.8
	torus.material = gold
	band.mesh = torus
	band.position = Vector3(0.0, TOP_Y + 2.6, 0.0)
	parent.add_child(band)
	for i in range(6):
		var a := TAU * float(i) / 6.0
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.5
		cone.height = 2.2
		cone.material = gold
		spike.mesh = cone
		spike.position = Vector3(cos(a) * 2.5, TOP_Y + 3.8, sin(a) * 2.5)
		parent.add_child(spike)
		var jewel := MeshInstance3D.new()
		var gem := SphereMesh.new()
		gem.radius = 0.32
		gem.height = 0.64
		gem.material = CourseBuilder.make_neon_material(CourseBuilder.accent(i % 4), 4.0)
		jewel.mesh = gem
		jewel.position = Vector3(cos(a) * 2.5, TOP_Y + 5.0, sin(a) * 2.5)
		parent.add_child(jewel)
	FX.attach(band, "sparkle", Vector3.ZERO, Color(2.5, 2.0, 0.6))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.3)
	glow.light_energy = 4.0
	glow.omni_range = 18.0
	glow.position = Vector3(0.0, TOP_Y + 4.0, 0.0)
	parent.add_child(glow)
	CourseBuilder.add_sign(parent, Branding.CROWN_SIGN, Vector3(0.0, TOP_Y + 8.0, 0.0), CourseBuilder.accent(0), 140)
	_finish_area = CourseBuilder.add_area(parent, Vector3(CROWN_RADIUS * 1.6, 4.0, CROWN_RADIUS * 1.6), Vector3(0.0, TOP_Y + 2.0, 0.0), "FinishLine")
