class_name SectionHighRides
extends CourseSection
## Section 5: The High Rides. Climb to a high deck, cross three sliding gondolas
## over a drop, then ride a roller-coaster beam down. Ferris wheels flank the route.

@export var top_height: float = 5.0
@export var gondola_period: float = 5.0
@export var beam_width: float = 3.0


func _init() -> void:
	section_length = 80.0
	section_width = 14.0
	section_title = "The High Rides"
	colour_index = 4


func _build_geometry() -> void:
	add_floor(0.0, -6.0, section_width, CourseBuilder.accent(4), "EntryFloor")
	add_side_rails(0.0, -6.0, section_width)
	add_title_sign()
	_add_slope(-6.0, 0.0, -16.0, top_height, section_width, CourseBuilder.accent(5), "UpRamp")
	add_floor(-16.0, -22.0, section_width, CourseBuilder.accent(6), "HighDeckA", top_height)
	add_side_rails(-16.0, -22.0, section_width, 0.6, top_height)
	add_checkpoint(Vector3(0.0, top_height, -20.0))
	_build_gondolas()
	add_floor(-40.0, -46.0, section_width, CourseBuilder.accent(1), "HighDeckB", top_height)
	add_side_rails(-40.0, -46.0, section_width, 0.6, top_height)
	add_checkpoint(Vector3(0.0, top_height, -43.0))
	_build_coaster()
	add_floor(-74.0, -section_length, section_width, CourseBuilder.accent(3), "ExitFloor")
	add_side_rails(-74.0, -section_length, section_width)
	add_checkpoint(Vector3(0.0, 0.0, -78.0))
	_build_ferris_wheel(Vector3(-14.0, 0.0, -30.0))
	_build_ferris_wheel(Vector3(14.0, 0.0, -30.0))


## Sloped slab whose top surface runs from (z0, y0) to (z1, y1).
func _add_slope(z0: float, y0: float, z1: float, y1: float, width: float, colour: Color, node_name: String) -> void:
	var run := absf(z0 - z1)
	var rise := y1 - y0
	var angle := atan2(rise, run)
	var length := sqrt(run * run + rise * rise)
	var normal := Vector3(0.0, cos(angle), sin(angle))
	var surface_centre := Vector3(0.0, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	CourseBuilder.add_ramp(self, Vector3(width, 1.0, length), surface_centre - normal * 0.5, rad_to_deg(angle), CourseBuilder.surface(colour), node_name)


func _build_gondolas() -> void:
	var zs: Array[float] = [-25.0, -31.0, -37.0]
	for i in range(zs.size()):
		var from_left := i % 2 == 0
		var start_x := -4.0 if from_left else 4.0
		var travel := Vector3(8.0, 0.0, 0.0) if from_left else Vector3(-8.0, 0.0, 0.0)
		var gondola := MovingPlatform.create_box(self, Vector3(start_x, top_height - 0.25, zs[i]), Vector3(3.0, 0.5, 3.0), travel, gondola_period + float(i) * 0.7, CourseBuilder.accent(i * 2), float(i) * 1.3)
		if gondola == null:
			continue
		for x: float in [-1.3, 1.3]:
			var pole := CourseBuilder.make_cylinder_mesh(0.08, 2.6, Color(0.35, 0.36, 0.4))
			pole.position = Vector3(x, 1.55, 0.0)
			gondola.add_child(pole)
		var roof := CourseBuilder.make_box_mesh(Vector3(3.2, 0.25, 3.2), CourseBuilder.accent(i * 2 + 1))
		roof.position = Vector3(0.0, 2.95, 0.0)
		gondola.add_child(roof)


func _build_coaster() -> void:
	_add_slope(-46.0, top_height, -54.0, 2.0, beam_width, CourseBuilder.accent(0), "CoasterDrop")
	add_floor(-54.0, -58.0, beam_width, CourseBuilder.accent(2), "CoasterFlat", 2.0)
	_add_slope(-58.0, 2.0, -64.0, 4.0, beam_width, CourseBuilder.accent(4), "CoasterRise")
	_add_slope(-64.0, 4.0, -74.0, 0.0, beam_width, CourseBuilder.accent(6), "CoasterFinalDrop")
	var supports := [[-50.0, 3.5], [-56.0, 2.0], [-61.0, 3.0], [-66.0, 3.2], [-70.0, 1.6]]
	for s: Array in supports:
		var z: float = s[0]
		var surface_y: float = s[1]
		var height := surface_y + 12.0
		for x: float in [-1.2, 1.2]:
			CourseBuilder.add_decor_cylinder(self, 0.15, height, Vector3(x, surface_y - height * 0.5, z), Color(0.3, 0.08, 0.1), "CoasterSupport")
	CourseBuilder.add_sign(self, "MIND THE DROP!", Vector3(0.0, top_height + 3.0, -47.0), Color(1.0, 0.3, 0.3), 64)


func _build_ferris_wheel(centre: Vector3) -> void:
	var radius := 7.0
	var hub := centre + Vector3(0.0, radius + 1.0, 0.0)
	for i in range(16):
		var a := i * TAU / 16.0
		var seg := CourseBuilder.make_box_mesh(Vector3(0.3, 0.3, 2.9), CourseBuilder.accent(i % 2))
		seg.mesh.material = CourseBuilder.make_neon_material(CourseBuilder.accent(i % 2))
		seg.position = hub + Vector3(0.0, sin(a) * radius, cos(a) * radius)
		seg.rotation.x = -a - PI * 0.5
		add_child(seg)
	for i in range(8):
		var a := i * TAU / 8.0
		var spoke := CourseBuilder.make_box_mesh(Vector3(0.18, 0.18, radius), Color(0.3, 0.31, 0.35))
		spoke.position = hub + Vector3(0.0, sin(a) * radius * 0.5, cos(a) * radius * 0.5)
		spoke.rotation.x = -a
		add_child(spoke)
		var car := CourseBuilder.make_box_mesh(Vector3(1.4, 1.1, 1.4), CourseBuilder.accent(i + 3))
		car.position = hub + Vector3(0.0, sin(a) * radius - 0.8, cos(a) * radius)
		add_child(car)
	var axle := CourseBuilder.make_cylinder_mesh(0.35, 2.4, Color(0.3, 0.3, 0.35))
	axle.rotation.z = PI * 0.5
	axle.position = hub
	add_child(axle)
	for z: float in [-3.0, 3.0]:
		var leg := CourseBuilder.make_cylinder_mesh(0.3, hub.y + 0.5, Color(0.3, 0.3, 0.35))
		leg.position = Vector3(centre.x, (hub.y + 0.5) * 0.5 - 0.5, centre.z + z)
		leg.rotation.x = atan2(z, hub.y)
		add_child(leg)
