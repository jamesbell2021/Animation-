class_name SectionFinaleTower
extends CourseSection
## Section 6: The Grand Finale Tower. A spiral of rainbow ledges climbs a
## tower core swept by rotating arms. The finish zone surrounds a golden crown.

const TOWER_Z: float = -22.0

@export var steps: int = 16
@export var step_height: float = 0.9
@export var step_angle_degrees: float = 30.0
@export var ledge_radius: float = 6.0
@export var core_radius: float = 4.0
@export var spinner_speed: float = 70.0
@export var checkpoint_steps: Array[int] = [5, 11]
@export var spinner_steps: Array[int] = [4, 9, 14]

var _finish_area: Area3D


func _init() -> void:
	section_length = 36.0
	section_width = 14.0
	section_title = "The Grand Finale Tower"
	colour_index = 5


func _build_geometry() -> void:
	add_floor(0.0, -13.0, section_width, CourseBuilder.rainbow(5), "BaseFloor")
	add_side_rails(0.0, -13.0, section_width)
	add_title_sign()
	add_gateway(-2.0, section_width - 1.0, 5.0, Color(1.0, 0.8, 0.2))
	add_checkpoint(Vector3(0.0, 0.0, -8.0))
	var centre := Vector3(0.0, 0.0, TOWER_Z)
	var top_y := step_height * float(steps) + step_height
	CourseBuilder.add_cylinder(self, core_radius, top_y, centre + Vector3(0.0, top_y * 0.5, 0.0), Color(0.95, 0.9, 0.8), "TowerCore")
	_build_ledges(centre)
	_build_top(centre, top_y)
	_build_rainbow(centre)


func get_finish_area() -> Area3D:
	return _finish_area


func _build_ledges(centre: Vector3) -> void:
	for i in range(steps):
		var angle := PI * 0.5 + deg_to_rad(step_angle_degrees) * float(i)
		var h := step_height * float(i + 1)
		var pos := centre + Vector3(cos(angle) * ledge_radius, h - 0.25, sin(angle) * ledge_radius)
		var ledge := CourseBuilder.add_box(self, Vector3(4.5, 0.5, 3.0), pos, CourseBuilder.rainbow(i), "Ledge%d" % i)
		if ledge != null:
			ledge.rotation.y = -angle
		if checkpoint_steps.has(i) and checkpoint_manager != null:
			checkpoint_manager.create_checkpoint(self, pos + Vector3(0.0, 2.25, 0.0), Vector3(4.0, 4.0, 4.0), pos + Vector3(0.0, 1.25, 0.0))
		if spinner_steps.has(i):
			var direction := 1.0 if (i / 5) % 2 == 0 else -1.0
			SpinnerObstacle.create(self, centre + Vector3(0.0, h, 0.0), ledge_radius + 2.5, spinner_speed * direction, 1, CourseBuilder.rainbow(i + 3), 0.35)


func _build_top(centre: Vector3, top_y: float) -> void:
	var platform_radius := core_radius + 1.0
	CourseBuilder.add_cylinder(self, platform_radius, 0.5, centre + Vector3(0.0, top_y - 0.25, 0.0), Color(1.0, 0.85, 0.2), "TopPlatform")
	var crown_base := centre + Vector3(0.0, top_y, 0.0)
	CourseBuilder.add_decor_cylinder(self, 1.2, 0.8, crown_base + Vector3(0.0, 0.4, 0.0), Color(1.0, 0.78, 0.1), "CrownBand")
	for i in range(6):
		var a := i * TAU / 6.0
		var spike := CourseBuilder.make_box_mesh(Vector3(0.3, 0.9, 0.3), Color(1.0, 0.78, 0.1))
		spike.position = crown_base + Vector3(cos(a) * 1.0, 1.2, sin(a) * 1.0)
		add_child(spike)
		var gem := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.2
		sphere.height = 0.4
		sphere.material = CourseBuilder.make_material(CourseBuilder.rainbow(i))
		gem.mesh = sphere
		gem.position = crown_base + Vector3(cos(a) * 1.0, 1.75, sin(a) * 1.0)
		add_child(gem)
	_finish_area = CourseBuilder.add_area(self, Vector3(platform_radius * 2.0, 3.0, platform_radius * 2.0), crown_base + Vector3(0.0, 1.5, 0.0), "FinishLine")
	CourseBuilder.add_sign(self, Branding.CROWN_SIGN, crown_base + Vector3(0.0, 4.0, 0.0), Color(1.0, 0.9, 0.2), 96)


func _build_rainbow(centre: Vector3) -> void:
	var arc_centre := centre + Vector3(0.0, 0.0, -4.0)
	var segments := 12
	for band in range(7):
		var radius := 20.0 + float(band) * 1.0
		for i in range(segments):
			var a := (float(i) + 0.5) * PI / float(segments)
			var length := PI * radius / float(segments) * 1.06
			var seg := CourseBuilder.make_box_mesh(Vector3(length, 1.0, 0.4), CourseBuilder.rainbow(band))
			seg.position = arc_centre + Vector3(cos(a) * radius, sin(a) * radius, 0.0)
			seg.rotation.z = a + PI * 0.5
			add_child(seg)
	for side: float in [-1.0, 1.0]:
		CourseBuilder.add_decor_cylinder(self, 1.5, 1.0, arc_centre + Vector3(side * 23.0, 0.5, 0.0), Color(1.0, 0.8, 0.1), "PotOfGold")
		CourseBuilder.add_sign(self, "GOLD", arc_centre + Vector3(side * 23.0, 2.0, 0.0), Color(1.0, 0.9, 0.2), 48)
