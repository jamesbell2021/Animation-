class_name SectionDizzyRides
extends CourseSection
## Section 3: The Dizzy Rides. Cross a turning carousel, a waltzer with a
## double spinner, then hop across three fast teacups.

const DISC_THICKNESS: float = 0.5

@export var carousel_spin: float = 40.0
@export var waltzer_spin: float = -70.0
@export var teacup_spin: float = 120.0
@export var waltzer_arm_speed: float = 90.0


func _init() -> void:
	section_length = 52.0
	section_width = 14.0
	section_title = "The Dizzy Rides"
	colour_index = 2


func _build_geometry() -> void:
	add_floor(0.0, -8.0, section_width, CourseBuilder.rainbow(3), "EntryFloor")
	add_side_rails(0.0, -8.0, section_width)
	add_title_sign()
	_build_carousel(Vector3(0.0, 0.0, -14.0), 5.0)
	_build_waltzer(Vector3(0.0, 0.0, -25.0), 5.0)
	add_floor(-31.0, -36.0, section_width, CourseBuilder.rainbow(5), "MidFloor")
	add_side_rails(-31.0, -36.0, section_width)
	add_checkpoint(Vector3(0.0, 0.0, -33.0))
	_build_teacups(-41.0)
	add_floor(-46.0, -section_length, section_width, CourseBuilder.rainbow(0), "ExitFloor")
	add_side_rails(-46.0, -section_length, section_width)
	add_checkpoint(Vector3(0.0, 0.0, -50.0))


func _build_carousel(centre: Vector3, radius: float) -> void:
	var disc := MovingPlatform.create_disc(self, centre + Vector3(0.0, -DISC_THICKNESS * 0.5, 0.0), radius, DISC_THICKNESS, carousel_spin, CourseBuilder.rainbow(1))
	if disc == null:
		return
	for i in range(6):
		var angle := i * TAU / 6.0
		var pos := Vector3(cos(angle) * radius * 0.65, DISC_THICKNESS * 0.5, sin(angle) * radius * 0.65)
		_add_disc_fixture(disc, pos + Vector3(0.0, 1.5, 0.0), Vector3(0.15, 3.0, 0.15), Color(0.9, 0.8, 0.3), "HorsePole")
		_add_disc_fixture(disc, pos + Vector3(0.0, 1.4, 0.0), Vector3(0.5, 0.6, 1.3), CourseBuilder.rainbow(i), "Horse")
		var head := CourseBuilder.make_box_mesh(Vector3(0.4, 0.5, 0.4), CourseBuilder.rainbow(i).lightened(0.3))
		head.position = pos + Vector3(0.0, 1.9, 0.75)
		disc.add_child(head)
	CourseBuilder.add_cylinder(self, 0.5, 6.0, centre + Vector3(0.0, 3.0, 0.0), Color(0.9, 0.8, 0.3), "CarouselMast")
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = radius + 1.0
	cone.height = 2.5
	cone.material = CourseBuilder.make_material(Color(1.0, 0.95, 0.9))
	roof.mesh = cone
	roof.name = "CarouselRoof"
	roof.position = centre + Vector3(0.0, 6.5, 0.0)
	add_child(roof)
	CourseBuilder.add_decor_cylinder(self, radius + 1.0, 0.3, centre + Vector3(0.0, 5.2, 0.0), CourseBuilder.rainbow(0), "CarouselRim")
	_add_outer_floor(centre, radius)


func _build_waltzer(centre: Vector3, radius: float) -> void:
	var disc := MovingPlatform.create_disc(self, centre + Vector3(0.0, -DISC_THICKNESS * 0.5, 0.0), radius, DISC_THICKNESS, waltzer_spin, CourseBuilder.rainbow(4))
	if disc == null:
		return
	for i in range(3):
		var angle := i * TAU / 3.0
		var pos := Vector3(cos(angle) * radius * 0.7, DISC_THICKNESS * 0.5 + 0.5, sin(angle) * radius * 0.7)
		_add_disc_fixture(disc, pos, Vector3(1.4, 1.0, 1.4), CourseBuilder.rainbow(i + 2), "WaltzerCar")
	SpinnerObstacle.create(self, centre, radius * 0.9, waltzer_arm_speed, 2, CourseBuilder.rainbow(6), 0.7)
	_add_outer_floor(centre, radius)


func _build_teacups(z: float) -> void:
	var xs: Array[float] = [-4.5, 0.0, 4.5]
	for i in range(xs.size()):
		var spin := teacup_spin if i % 2 == 0 else -teacup_spin
		var cup := MovingPlatform.create_disc(self, Vector3(xs[i], -DISC_THICKNESS * 0.5, z), 2.2, DISC_THICKNESS, spin, CourseBuilder.rainbow(i * 2))
		if cup == null:
			continue
		var handle := CourseBuilder.make_box_mesh(Vector3(0.3, 1.0, 0.8), Color.WHITE)
		handle.position = Vector3(2.0, 0.6, 0.0)
		cup.add_child(handle)


## Thin decorative skirt around a ride so the drop is visible but not a wall.
func _add_outer_floor(centre: Vector3, radius: float) -> void:
	CourseBuilder.add_decor_cylinder(self, radius + 1.5, 0.2, centre + Vector3(0.0, -3.0, 0.0), Color(0.3, 0.3, 0.35), "RideBase")
	CourseBuilder.add_decor_cylinder(self, 0.8, 2.5, centre + Vector3(0.0, -1.5, 0.0), Color(0.3, 0.3, 0.35), "RideAxle")


## Adds a collidable box fixed to a moving disc (it rotates with the disc).
func _add_disc_fixture(disc: MovingPlatform, local_pos: Vector3, size: Vector3, colour: Color, node_name: String) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = local_pos
	disc.add_child(shape)
	var mesh := CourseBuilder.make_box_mesh(size, colour)
	mesh.name = node_name
	mesh.position = local_pos
	disc.add_child(mesh)
