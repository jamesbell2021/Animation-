class_name SectionFinaleTower
extends CourseSection
## Section 6: The Grand Finale Tower. A spiral of neon-edged ledges climbs a
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
	add_floor(0.0, -13.0, section_width, CourseBuilder.accent(5), "BaseFloor")
	add_side_rails(0.0, -13.0, section_width)
	add_title_sign()
	add_gateway(-2.0, section_width - 1.0, 5.0)
	add_checkpoint(Vector3(0.0, 0.0, -8.0))
	var centre := Vector3(0.0, 0.0, TOWER_Z)
	var top_y := step_height * float(steps) + step_height
	CourseBuilder.add_cylinder(self, core_radius, top_y, centre + Vector3(0.0, top_y * 0.5, 0.0), Color(0.19, 0.2, 0.24), "TowerCore")
	for ring in range(1, int(top_y / 3.0) + 1):
		var band := CourseBuilder.make_cylinder_mesh(core_radius + 0.05, 0.12, CourseBuilder.accent(ring))
		band.mesh.material = CourseBuilder.make_neon_material(CourseBuilder.accent(ring % 2))
		band.position = centre + Vector3(0.0, float(ring) * 3.0, 0.0)
		add_child(band)
	_build_ledges(centre)
	_build_top(centre, top_y)
	_build_neon_arch(centre)


func get_finish_area() -> Area3D:
	return _finish_area


func _build_ledges(centre: Vector3) -> void:
	for i in range(steps):
		var angle := PI * 0.5 + deg_to_rad(step_angle_degrees) * float(i)
		var h := step_height * float(i + 1)
		var pos := centre + Vector3(cos(angle) * ledge_radius, h - 0.25, sin(angle) * ledge_radius)
		var ledge := CourseBuilder.add_box(self, Vector3(4.5, 0.5, 3.0), pos, CourseBuilder.surface(CourseBuilder.accent(i)), "Ledge%d" % i)
		if ledge != null:
			ledge.rotation.y = -angle
			CourseBuilder.add_neon_strip(ledge, Vector3(0.12, 0.12, 3.0), Vector3(2.2, 0.28, 0.0), CourseBuilder.accent(i % 2), "Edge")
		if checkpoint_steps.has(i) and checkpoint_manager != null:
			checkpoint_manager.create_checkpoint(self, pos + Vector3(0.0, 2.25, 0.0), Vector3(4.0, 4.0, 4.0), pos + Vector3(0.0, 1.25, 0.0))
		if spinner_steps.has(i):
			var direction := 1.0 if (i / 5) % 2 == 0 else -1.0
			SpinnerObstacle.create(self, centre + Vector3(0.0, h, 0.0), ledge_radius + 2.5, spinner_speed * direction, 1, CourseBuilder.accent(i + 3), 0.35)


func _build_top(centre: Vector3, top_y: float) -> void:
	var platform_radius := core_radius + 1.0
	CourseBuilder.add_cylinder(self, platform_radius, 0.5, centre + Vector3(0.0, top_y - 0.25, 0.0), Color(0.7, 0.5, 0.08), "TopPlatform")
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
		sphere.material = CourseBuilder.make_material(CourseBuilder.accent(i))
		gem.mesh = sphere
		gem.position = crown_base + Vector3(cos(a) * 1.0, 1.75, sin(a) * 1.0)
		add_child(gem)
	_finish_area = CourseBuilder.add_area(self, Vector3(platform_radius * 2.0, 3.0, platform_radius * 2.0), crown_base + Vector3(0.0, 1.5, 0.0), "FinishLine")
	CourseBuilder.add_sign(self, Branding.CROWN_SIGN, crown_base + Vector3(0.0, 4.0, 0.0), CourseBuilder.accent(0), 96)


## A giant two-band neon arch behind the tower, with a pot of gold at each foot.
func _build_neon_arch(centre: Vector3) -> void:
	var arc_centre := centre + Vector3(0.0, 0.0, -4.0)
	var segments := 16
	for band in range(2):
		var radius := 21.0 + float(band) * 1.2
		var mat := CourseBuilder.make_neon_material(CourseBuilder.accent(band), 2.2)
		for i in range(segments):
			var a := (float(i) + 0.5) * PI / float(segments)
			var length := PI * radius / float(segments) * 1.06
			var seg := CourseBuilder.make_box_mesh(Vector3(length, 0.5, 0.3), CourseBuilder.accent(band))
			seg.mesh.material = mat
			seg.position = arc_centre + Vector3(cos(a) * radius, sin(a) * radius, 0.0)
			seg.rotation.z = a + PI * 0.5
			add_child(seg)
	for side: float in [-1.0, 1.0]:
		CourseBuilder.add_decor_cylinder(self, 1.5, 1.0, arc_centre + Vector3(side * 22.0, 0.5, 0.0), Color(1.0, 0.75, 0.1), "PotOfGold")
		CourseBuilder.add_sign(self, "GOLD", arc_centre + Vector3(side * 22.0, 2.0, 0.0), Color(1.0, 0.8, 0.2), 48)
