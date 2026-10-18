class_name SectionBouncyYard
extends CourseSection
## Section 4: The Bouncy Yard. Three launch pads on pillars fling contestants
## across a drop, then a bouncy castle with a wall that must be bounced over.

@export var launch_bounce: float = 12.0
@export var launch_forward: float = 6.0
@export var castle_bounce: float = 10.0
@export var castle_wall_height: float = 1.6


func _init() -> void:
	section_length = 52.0
	section_width = 14.0
	section_title = "The Bouncy Yard"
	colour_index = 3


func _build_geometry() -> void:
	add_floor(0.0, -6.0, section_width, CourseBuilder.accent(6), "EntryFloor")
	add_side_rails(0.0, -6.0, section_width)
	add_title_sign()
	_build_launch_pads([-10.0, -17.0, -24.0])
	add_floor(-28.0, -34.0, section_width, CourseBuilder.accent(4), "LandingFloor")
	add_side_rails(-28.0, -34.0, section_width)
	add_checkpoint(Vector3(0.0, 0.0, -32.0))
	_build_bouncy_castle(-34.0, -section_length)
	add_checkpoint(Vector3(0.0, 0.0, -50.0))


func _build_launch_pads(zs: Array[float]) -> void:
	for i in range(zs.size()):
		var z: float = zs[i]
		CourseBuilder.add_cylinder(self, 2.2, 4.0, Vector3(0.0, -2.0, z), CourseBuilder.surface(CourseBuilder.accent(i + 1)), "Pillar%d" % i)
		BouncerObstacle.create(self, Vector3(0.0, 0.0, z), 2.0, launch_bounce, CourseBuilder.accent(i + 3), Vector3(0.0, 0.0, -launch_forward))
		CourseBuilder.add_sign(self, "BOUNCE!", Vector3(0.0, 3.5, z), Color.WHITE, 48)
	for side: float in [-1.0, 1.0]:
		for z: float in [-9.0, -17.0, -25.0]:
			CourseBuilder.add_decor_cylinder(self, 0.3, 8.0, Vector3(side * 8.0, 0.0, z), Color(0.3, 0.31, 0.35), "FlagPole")
			CourseBuilder.add_decor_box(self, Vector3(1.2, 0.7, 0.05), Vector3(side * 8.0 + 0.6, 3.6, z), CourseBuilder.accent(int(absf(z))), "Flag")


func _build_bouncy_castle(z_start: float, z_end: float) -> void:
	var castle_colour := Color(0.75, 0.05, 0.12)
	add_floor(z_start, z_end, section_width, castle_colour, "CastleFloor")
	add_side_rails(z_start, z_end, section_width, 1.5)
	for x: float in [-4.0, 0.0, 4.0]:
		BouncerObstacle.create(self, Vector3(x, 0.0, -37.0), 1.4, castle_bounce, CourseBuilder.accent(1))
		BouncerObstacle.create(self, Vector3(x, 0.0, -41.0), 1.5, castle_bounce, CourseBuilder.accent(5))
	for x: float in [-2.0, 2.0]:
		CourseBuilder.add_cylinder(self, 0.7, 2.0, Vector3(x, 1.0, -39.0), CourseBuilder.accent(2), "SoftPillar")
	CourseBuilder.add_box(self, Vector3(section_width - 0.6, castle_wall_height, 0.8), Vector3(0.0, castle_wall_height * 0.5, -43.5), Color(0.2, 0.2, 0.23), "CastleWall")
	CourseBuilder.add_decor_box(self, Vector3(section_width - 0.6, 0.4, 1.0), Vector3(0.0, castle_wall_height + 0.2, -43.5), CourseBuilder.accent(0), "CastleWallTop")
	for x: float in [-3.0, 3.0]:
		BouncerObstacle.create(self, Vector3(x, 0.0, -47.0), 1.3, castle_bounce * 0.7, CourseBuilder.accent(3))
	_build_turrets(z_start, z_end)
	CourseBuilder.add_sign(self, "CRASH PAD", Vector3(0.0, 6.5, z_start - 2.0), CourseBuilder.accent(0), 80)


func _build_turrets(z_start: float, z_end: float) -> void:
	var half := section_width * 0.5 + 0.8
	var i := 0
	for z: float in [z_start - 1.0, z_end + 1.0]:
		for side: float in [-1.0, 1.0]:
			var pos := Vector3(side * half, 0.0, z)
			CourseBuilder.add_decor_cylinder(self, 1.3, 4.5, pos + Vector3(0.0, 2.25, 0.0), Color(0.18, 0.19, 0.22), "Turret%d" % i)
			var cone := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.1
			mesh.bottom_radius = 1.5
			mesh.height = 1.8
			mesh.material = CourseBuilder.make_neon_material(CourseBuilder.accent(i % 2))
			cone.mesh = mesh
			cone.position = pos + Vector3(0.0, 5.4, 0.0)
			add_child(cone)
			i += 1
