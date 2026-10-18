class_name SectionDodgems
extends CourseSection
## Section 2: Dodgem Disaster. A dark arena floor crossed by dodgem cars that
## knock contestants into the air. Two cars also drive the length of the arena.

const CEILING_HEIGHT: float = 5.5

@export var car_speed: float = 5.0
@export var cross_lanes: int = 9
@export var lane_spacing: float = 4.5


func _init() -> void:
	section_length = 48.0
	section_width = 16.0
	section_title = "Dodgem Disaster"
	colour_index = 1


func _build_geometry() -> void:
	add_floor(0.0, -section_length, section_width, Color(0.18, 0.18, 0.22), "ArenaFloor")
	_build_floor_stripes()
	add_side_rails(0.0, -section_length, section_width, 1.0)
	add_title_sign()
	add_gateway(-1.0, section_width - 1.0, 5.0, CourseBuilder.rainbow(1))
	_build_ceiling()
	_build_cross_cars()
	_build_long_cars()
	_build_booths()
	add_checkpoint(Vector3(0.0, 0.0, -25.0))
	add_checkpoint(Vector3(0.0, 0.0, -46.0))


func _build_floor_stripes() -> void:
	var stripe_width := section_width / 8.0
	for i in range(8):
		var x := -section_width * 0.5 + stripe_width * (float(i) + 0.5)
		var tone := Color(0.25, 0.25, 0.3) if i % 2 == 0 else Color(0.14, 0.14, 0.18)
		CourseBuilder.add_decor_box(self, Vector3(stripe_width, 0.02, section_length), Vector3(x, 0.011, -section_length * 0.5), tone, "Stripe%d" % i)


func _build_ceiling() -> void:
	var half := section_width * 0.5 - 0.15
	var z_mid := -section_length * 0.5
	for x: float in [-6.0, -2.0, 2.0, 6.0]:
		CourseBuilder.add_decor_box(self, Vector3(0.12, 0.12, section_length), Vector3(x, CEILING_HEIGHT, z_mid), Color(0.6, 0.6, 0.65), "CeilingWire")
	var z := -3.0
	while z > -section_length:
		CourseBuilder.add_decor_box(self, Vector3(section_width, 0.12, 0.12), Vector3(0.0, CEILING_HEIGHT, z), Color(0.6, 0.6, 0.65), "CeilingBar")
		z -= 6.0
	z = 0.0
	var i := 0
	while z >= -section_length:
		for side: float in [-1.0, 1.0]:
			CourseBuilder.add_box(self, Vector3(0.3, CEILING_HEIGHT, 0.3), Vector3(side * half, CEILING_HEIGHT * 0.5, z), CourseBuilder.rainbow(i), "Post")
			var lamp := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.3
			sphere.height = 0.6
			sphere.material = CourseBuilder.make_material(CourseBuilder.rainbow(i + 3))
			lamp.mesh = sphere
			lamp.position = Vector3(side * half, CEILING_HEIGHT + 0.3, z)
			add_child(lamp)
		z -= 12.0
		i += 1


func _build_cross_cars() -> void:
	var half := section_width * 0.5 - 1.6
	for i in range(cross_lanes):
		var z := -5.0 - float(i) * lane_spacing
		if z < -section_length + 4.0:
			break
		var from_left := i % 2 == 0
		var start_x := -half if from_left else half
		var travel := Vector3(half * 2.0, 0.0, 0.0) if from_left else Vector3(-half * 2.0, 0.0, 0.0)
		var phase := fmod(float(i) * 0.37, 1.0)
		PusherObstacle.create(self, Vector3(start_x, 0.0, z), travel, car_speed + float(i) * 0.3, CourseBuilder.rainbow(i), phase)


func _build_long_cars() -> void:
	var run := section_length - 8.0
	PusherObstacle.create(self, Vector3(-3.5, 0.0, -4.0), Vector3(0.0, 0.0, -run), car_speed * 1.4, Color(1.0, 1.0, 1.0), 0.5)
	PusherObstacle.create(self, Vector3(3.5, 0.0, -4.0 - run), Vector3(0.0, 0.0, run), car_speed * 1.4, Color(0.1, 0.1, 0.1), 0.0)


func _build_booths() -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * (section_width * 0.5 + 3.0)
		CourseBuilder.add_decor_box(self, Vector3(3.0, 2.6, 2.2), Vector3(x, 1.3, -12.0), CourseBuilder.rainbow(4), "Booth")
		CourseBuilder.add_decor_box(self, Vector3(3.4, 0.4, 2.6), Vector3(x, 2.8, -12.0), Color.WHITE, "BoothRoof")
		CourseBuilder.add_sign(self, "TOKENS", Vector3(x, 3.6, -12.0), Color(1.0, 0.9, 0.2), 64)
		CourseBuilder.add_decor_box(self, Vector3(2.4, 1.4, 2.0), Vector3(x, 0.7, -32.0), CourseBuilder.rainbow(0), "ParkedCar")
		CourseBuilder.add_decor_box(self, Vector3(2.4, 1.4, 2.0), Vector3(x, 0.7, -35.0), CourseBuilder.rainbow(2), "ParkedCar")
