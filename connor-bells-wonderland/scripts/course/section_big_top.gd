class_name SectionBigTop
extends CourseSection
## Section 1: The Big Top Entrance. Start grid for eight contestants, a huge
## striped tent behind the line, a gateway, two hurdles and two slow spinners.

const START_FLOOR_Z: float = 8.0

@export var hurdle_height: float = 0.6
@export var spinner_speed: float = 60.0
@export var spawn_columns: int = 4
@export var spawn_spacing: float = 2.5


func _init() -> void:
	section_length = 40.0
	section_width = 14.0
	section_title = "The Big Top Entrance"
	colour_index = 0


func _build_geometry() -> void:
	add_floor(START_FLOOR_Z, -section_length, section_width, Color(0.95, 0.45, 0.45), "BigTopFloor")
	add_side_rails(START_FLOOR_Z, -section_length, section_width)
	add_title_sign()
	add_gateway(-6.0, section_width - 1.0)
	_build_big_top()
	_build_hurdles()
	SpinnerObstacle.create(self, Vector3(-4.5, 0.0, -28.0), 4.0, spinner_speed, 1, CourseBuilder.rainbow(2))
	SpinnerObstacle.create(self, Vector3(4.5, 0.0, -28.0), 4.0, -spinner_speed, 1, CourseBuilder.rainbow(4))
	add_tent(Vector3(-12.0, 0.0, -20.0), 4.0, 4.0, CourseBuilder.rainbow(1))
	add_tent(Vector3(12.0, 0.0, -20.0), 4.0, 4.0, CourseBuilder.rainbow(5))
	add_checkpoint(Vector3(0.0, 0.0, -38.0))


## World-space spawn points for up to [param count] contestants, in a grid behind the line.
func get_spawn_positions(count: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var columns := maxi(spawn_columns, 1)
	for i in range(count):
		var col := i % columns
		var row := i / columns
		var x := (float(col) - float(columns - 1) * 0.5) * spawn_spacing
		var z := 1.5 + float(row) * spawn_spacing
		var local := Vector3(x, 1.0, z)
		if is_inside_tree():
			result.append(to_global(local))
		else:
			result.append(local)
	return result


func _build_big_top() -> void:
	var centre := Vector3(0.0, 0.0, START_FLOOR_Z + 12.0)
	CourseBuilder.add_decor_cylinder(self, 11.0, 0.3, centre + Vector3(0.0, -0.15, 0.0), Color(0.3, 0.6, 0.3), "BigTopGround")
	for i in range(8):
		var angle := i * TAU / 8.0
		var wall := CourseBuilder.make_box_mesh(Vector3(8.5, 5.0, 0.3), CourseBuilder.rainbow(i))
		wall.name = "BigTopWall%d" % i
		wall.position = centre + Vector3(cos(angle) * 10.0, 2.5, sin(angle) * 10.0)
		wall.rotation.y = -angle + PI * 0.5
		add_child(wall)
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 11.5
	cone.height = 7.0
	cone.material = CourseBuilder.make_material(Color(1.0, 0.95, 0.9))
	roof.mesh = cone
	roof.name = "BigTopRoof"
	roof.position = centre + Vector3(0.0, 8.5, 0.0)
	add_child(roof)
	CourseBuilder.add_decor_cylinder(self, 0.15, 3.0, centre + Vector3(0.0, 13.0, 0.0), Color(0.6, 0.4, 0.2), "BigTopMast")
	CourseBuilder.add_decor_box(self, Vector3(1.5, 0.9, 0.05), centre + Vector3(0.75, 14.0, 0.0), Color(0.2, 0.7, 0.3), "BigTopFlag")
	CourseBuilder.add_sign(self, Branding.BIG_TOP_SIGN, centre + Vector3(0.0, 6.0, -11.0), Color(1.0, 0.9, 0.2), 140)


func _build_hurdles() -> void:
	var colours: Array[Color] = [CourseBuilder.rainbow(3), CourseBuilder.rainbow(5)]
	var zs: Array[float] = [-14.0, -20.0]
	for i in range(zs.size()):
		CourseBuilder.add_box(self, Vector3(section_width - 0.6, hurdle_height, 0.5), Vector3(0.0, hurdle_height * 0.5, zs[i]), colours[i], "Hurdle%d" % i)
		for x: float in [-5.0, 0.0, 5.0]:
			CourseBuilder.add_decor_box(self, Vector3(0.3, hurdle_height + 0.6, 0.3), Vector3(x, (hurdle_height + 0.6) * 0.5, zs[i]), Color.WHITE, "HurdlePost")
