class_name SceneryDecorator
extends Node3D
## Dresses a built FairgroundCourse with showman's wagons, caravans, light
## strings (one MultiMesh of bulbs) and coin trails. Add as a child of the
## course (it names itself "SceneryDecorator" so FairgroundCourse.clear() removes it).

signal coin_collected(contestant: Contestant, value: int)

## Per section: [x, z, kind] where kind is "wagon", "caravan" or "tent".
const SIDE_ITEMS := [
	[[-12.0, -32.0, "wagon"], [12.0, -32.0, "caravan"]],
	[[-13.0, -24.0, "caravan"], [13.0, -24.0, "wagon"]],
	[[-13.0, -8.0, "wagon"], [13.0, -8.0, "wagon"], [-13.0, -48.0, "caravan"], [13.0, -48.0, "tent"]],
	[[-13.0, -20.0, "caravan"], [13.0, -20.0, "wagon"], [-13.0, -46.0, "tent"], [13.0, -46.0, "tent"]],
	[[-13.0, -10.0, "wagon"], [13.0, -10.0, "caravan"], [-13.0, -58.0, "tent"], [13.0, -58.0, "wagon"], [-13.0, -72.0, "caravan"]],
	[[-13.0, -6.0, "wagon"], [13.0, -6.0, "wagon"]],
]
## High Rides coin heights: [z, y] because the deck climbs.
const HIGH_RIDE_COINS := [[-3.0, 1.0], [-12.0, 4.2], [-19.0, 6.0], [-28.0, 6.0], [-34.0, 6.0], [-43.0, 6.0], [-50.0, 4.5], [-56.0, 3.0], [-61.0, 4.0], [-69.0, 3.0], [-77.0, 1.0]]

@export var bulb_spacing: float = 2.0
@export var pole_spacing: float = 10.0
@export var coin_spacing: float = 6.0

var _bulb_transforms: Array[Transform3D] = []
var _bulb_colours: Array[Color] = []
var _coin_count: int = 0


func decorate(course: FairgroundCourse, with_coins: bool = true) -> void:
	name = "SceneryDecorator"
	if course == null or course.sections.is_empty():
		push_error("SceneryDecorator.decorate: course is null or not built.")
		return
	for i in range(course.sections.size()):
		var section := course.sections[i]
		_decorate_sides(section, i)
		if not (section is SectionFinaleTower):
			_add_light_strings(section)
		if with_coins:
			_add_coins(section, i)
	_commit_bulbs()


func get_coin_count() -> int:
	return _coin_count


func reset_coins() -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		if coin is CoinPickup:
			coin.reset()


func _decorate_sides(section: CourseSection, index: int) -> void:
	if index >= SIDE_ITEMS.size():
		return
	for item: Array in SIDE_ITEMS[index]:
		var x: float = item[0]
		var z: float = item[1]
		var pos: Vector3 = section.position + Vector3(x, 0.0, z)
		var colour := CourseBuilder.rainbow(index * 2 + int(absf(x + z)))
		match String(item[2]):
			"wagon":
				_add_wagon(pos, colour)
			"caravan":
				_add_caravan(pos, colour)
			"tent":
				section.add_tent(Vector3(x, 0.0, z), 3.0, 3.5, colour)


func _add_wagon(pos: Vector3, colour: Color) -> void:
	var w := Node3D.new()
	w.name = "Wagon"
	w.position = pos
	add_child(w)
	CourseBuilder.add_decor_box(w, Vector3(2.6, 2.2, 5.0), Vector3(0.0, 2.1, 0.0), colour, "Body")
	CourseBuilder.add_decor_box(w, Vector3(2.0, 0.4, 4.6), Vector3(0.0, 0.9, 0.0), Color(0.35, 0.25, 0.15), "Chassis")
	var roof := CourseBuilder.make_cylinder_mesh(1.45, 5.2, Color(0.97, 0.97, 0.95))
	roof.rotation.x = PI * 0.5
	roof.position = Vector3(0.0, 3.1, 0.0)
	w.add_child(roof)
	CourseBuilder.add_decor_box(w, Vector3(2.8, 0.12, 5.1), Vector3(0.0, 3.2, 0.0), Color(1.0, 0.8, 0.1), "Trim")
	for x: float in [-1.5, 1.5]:
		for z: float in [-1.6, 1.6]:
			var wheel := CourseBuilder.make_cylinder_mesh(0.55, 0.25, Color(1.0, 0.75, 0.1))
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(x, 0.55, z)
			w.add_child(wheel)
	for x: float in [-1.31, 1.31]:
		for z: float in [-1.2, 1.2]:
			CourseBuilder.add_decor_box(w, Vector3(0.05, 0.7, 0.7), Vector3(x, 2.4, z), Color(0.7, 0.9, 1.0), "Window")
	CourseBuilder.add_decor_box(w, Vector3(1.0, 1.6, 0.06), Vector3(0.0, 1.9, -2.51), Color(0.3, 0.15, 0.1), "Door")
	CourseBuilder.add_decor_box(w, Vector3(0.9, 0.15, 0.5), Vector3(0.0, 0.5, -2.8), Color(0.35, 0.25, 0.15), "Step")
	CourseBuilder.add_decor_cylinder(w, 0.12, 0.8, Vector3(0.8, 3.9, -1.5), Color(0.1, 0.1, 0.1), "Chimney")


func _add_caravan(pos: Vector3, colour: Color) -> void:
	var c := Node3D.new()
	c.name = "Caravan"
	c.position = pos
	add_child(c)
	CourseBuilder.add_decor_box(c, Vector3(2.4, 2.0, 4.4), Vector3(0.0, 1.6, 0.0), Color(0.96, 0.96, 0.94), "Body")
	CourseBuilder.add_decor_box(c, Vector3(2.45, 0.35, 4.45), Vector3(0.0, 1.5, 0.0), colour, "Stripe")
	var roof := CourseBuilder.make_cylinder_mesh(1.25, 4.5, colour.lightened(0.4))
	roof.rotation.x = PI * 0.5
	roof.position = Vector3(0.0, 2.6, 0.0)
	c.add_child(roof)
	CourseBuilder.add_decor_box(c, Vector3(0.15, 0.15, 1.4), Vector3(0.0, 0.7, 2.9), Color(0.2, 0.2, 0.2), "TowBar")
	for x: float in [-1.3, 1.3]:
		var wheel := CourseBuilder.make_cylinder_mesh(0.45, 0.25, Color(0.15, 0.15, 0.15))
		wheel.rotation.z = PI * 0.5
		wheel.position = Vector3(x, 0.45, 0.3)
		c.add_child(wheel)
		CourseBuilder.add_decor_box(c, Vector3(0.05, 0.6, 1.4), Vector3(x * 1.01, 2.1, -0.6), Color(0.7, 0.9, 1.0), "Window")


func _add_light_strings(section: CourseSection) -> void:
	var half := section.section_width * 0.5 + 1.5
	for side: float in [-1.0, 1.0]:
		var x := side * half
		var z := -5.0
		var previous := Vector3.INF
		while z >= -section.section_length + 4.0:
			var top := section.position + Vector3(x, 4.0, z)
			CourseBuilder.add_decor_cylinder(self, 0.1, 4.0, top - Vector3(0.0, 2.0, 0.0), Color(0.3, 0.3, 0.35), "LightPole")
			_bulb_transforms.append(Transform3D(Basis().scaled(Vector3(2.0, 2.0, 2.0)), top))
			_bulb_colours.append(Color(1.0, 0.95, 0.6))
			if previous != Vector3.INF:
				_string_bulbs(previous, top)
			previous = top
			z -= pole_spacing


func _string_bulbs(from: Vector3, to: Vector3) -> void:
	var count := maxi(int(from.distance_to(to) / bulb_spacing), 1)
	for i in range(1, count):
		var t := float(i) / float(count)
		var p := from.lerp(to, t)
		p.y -= sin(t * PI) * 0.5
		_bulb_transforms.append(Transform3D(Basis(), p))
		_bulb_colours.append(CourseBuilder.rainbow(i))


func _commit_bulbs() -> void:
	if _bulb_transforms.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = _bulb_transforms.size()
	for i in range(_bulb_transforms.size()):
		mm.set_instance_transform(i, _bulb_transforms[i])
		mm.set_instance_color(i, _bulb_colours[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Bulbs"
	mmi.multimesh = mm
	add_child(mmi)


func _add_coins(section: CourseSection, _index: int) -> void:
	if section is SectionFinaleTower:
		_add_tower_coins(section as SectionFinaleTower)
		return
	var points: Array = []
	if section is SectionHighRides:
		points = HIGH_RIDE_COINS
	else:
		var z := -coin_spacing
		while z > -section.section_length + 3.0:
			points.append([z, 1.0])
			z -= coin_spacing
	var lanes: Array[float] = [-3.0, 0.0, 3.0]
	for i in range(points.size()):
		var x: float = lanes[i % 3]
		var kind := CoinPickup.Kind.SHAMROCK if i % 5 == 4 else CoinPickup.Kind.COIN
		var point: Array = points[i]
		_place_coin(section.position + Vector3(x, float(point[1]), float(point[0])), kind)


func _add_tower_coins(tower: SectionFinaleTower) -> void:
	var centre := tower.position + Vector3(0.0, 0.0, SectionFinaleTower.TOWER_Z)
	for i in range(0, tower.steps, 2):
		var a := PI * 0.5 + deg_to_rad(tower.step_angle_degrees) * float(i)
		var h := tower.step_height * float(i + 1)
		var kind := CoinPickup.Kind.SHAMROCK if i % 6 == 4 else CoinPickup.Kind.COIN
		_place_coin(centre + Vector3(cos(a) * tower.ledge_radius, h + 1.0, sin(a) * tower.ledge_radius), kind)


func _place_coin(pos: Vector3, kind: CoinPickup.Kind) -> void:
	var coin := CoinPickup.create(self, pos, kind)
	if coin == null:
		return
	coin.collected.connect(func(contestant: Contestant, value: int) -> void: coin_collected.emit(contestant, value))
	_coin_count += 1
