class_name FairgroundCourse
extends Node3D
## Assembles the six fairground sections end to end along -Z, owns the
## CheckpointManager, and provides spawn points and the finish area.

signal course_built

## Number of sections to build (1-6). Lower it to test early sections quickly.
@export var enabled_sections: int = 6
@export var build_on_ready: bool = false
@export var sun_rotation_degrees: Vector3 = Vector3(-50.0, 30.0, 0.0)

var checkpoint_manager: CheckpointManager
var sections: Array[CourseSection] = []

var _finish_area: Area3D
var _total_length: float = 0.0
var _section_classes: Array = [
	SectionBigTop,
	SectionDodgems,
	SectionDizzyRides,
	SectionBouncyYard,
	SectionHighRides,
	SectionFinaleTower,
]


func _ready() -> void:
	if checkpoint_manager == null:
		checkpoint_manager = CheckpointManager.new()
		checkpoint_manager.name = "CheckpointManager"
		add_child(checkpoint_manager)
	if build_on_ready:
		build()


## Builds (or rebuilds) the whole course. Must be called while in the scene tree.
func build() -> void:
	if not is_inside_tree():
		push_error("FairgroundCourse.build: not inside the scene tree.")
		return
	clear()
	_build_environment()
	var z := 0.0
	var count := clampi(enabled_sections, 1, _section_classes.size())
	for i in range(count):
		var section: CourseSection = _section_classes[i].new()
		section.name = "Section%d" % (i + 1)
		section.position = Vector3(0.0, 0.0, z)
		add_child(section)
		section.build(checkpoint_manager)
		sections.append(section)
		z += section.get_end_position().z
	_total_length = -z
	_resolve_finish_area(z)
	_build_ground()
	course_built.emit()


func clear() -> void:
	for section in sections:
		if is_instance_valid(section):
			section.queue_free()
	sections.clear()
	if checkpoint_manager != null:
		checkpoint_manager.clear_checkpoints()
	for child in get_children():
		if child != checkpoint_manager and str(child.name).begins_with("Scenery"):
			child.queue_free()
	_finish_area = null


func get_finish_area() -> Area3D:
	return _finish_area


func get_total_length() -> float:
	return _total_length


## World-space spawn positions for [param count] contestants.
func get_spawn_positions(count: int) -> Array[Vector3]:
	if sections.size() > 0 and sections[0] is SectionBigTop:
		return (sections[0] as SectionBigTop).get_spawn_positions(count)
	var fallback: Array[Vector3] = []
	for i in range(count):
		fallback.append(global_position + Vector3(float(i) - float(count - 1) * 0.5, 1.0, 2.0))
	return fallback


func _resolve_finish_area(end_z: float) -> void:
	if sections.size() > 0 and sections[-1] is SectionFinaleTower:
		_finish_area = (sections[-1] as SectionFinaleTower).get_finish_area()
	if _finish_area == null:
		var holder := Node3D.new()
		holder.name = "SceneryFinish"
		add_child(holder)
		_finish_area = CourseBuilder.add_area(holder, Vector3(16.0, 4.0, 1.0), Vector3(0.0, 2.0, end_z + 1.5), "FinishLine")
		CourseBuilder.add_box(holder, Vector3(0.4, 4.0, 0.4), Vector3(-7.0, 2.0, end_z + 1.5), Color(0.2, 0.2, 0.24), "FinishPostL")
		CourseBuilder.add_box(holder, Vector3(0.4, 4.0, 0.4), Vector3(7.0, 2.0, end_z + 1.5), Color(0.2, 0.2, 0.24), "FinishPostR")
		CourseBuilder.add_neon_strip(holder, Vector3(14.4, 0.2, 0.2), Vector3(0.0, 4.1, end_z + 1.5), CourseBuilder.accent(0), "FinishNeon")
		CourseBuilder.add_sign(holder, "FINISH", Vector3(0.0, 5.0, end_z + 1.5), CourseBuilder.accent(0), 96)
	if _finish_area == null:
		push_error("FairgroundCourse: failed to create a finish area.")


func _build_environment() -> void:
	var holder := Node3D.new()
	holder.name = "SceneryEnvironment"
	add_child(holder)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = sun_rotation_degrees
	# Floodlight "moon": bright enough to race by, cool white.
	sun.light_color = Color(0.82, 0.86, 1.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	holder.add_child(sun)

	# Dusk-into-night sky with an orange glow on the horizon.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.09)
	sky_mat.sky_horizon_color = Color(0.45, 0.16, 0.12)
	sky_mat.sky_curve = 0.08
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sky_mat.ground_horizon_color = Color(0.2, 0.08, 0.08)
	sky_mat.sun_angle_max = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.45, 0.62)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Bloom so neon trims, lights and pickups glow.
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	holder.add_child(world_env)


## Decorative grass field far below the course (below the fall limit, no collision).
func _build_ground() -> void:
	var holder := Node3D.new()
	holder.name = "SceneryGround"
	add_child(holder)
	var length := _total_length + 120.0
	CourseBuilder.add_decor_box(holder, Vector3(300.0, 1.0, length), Vector3(0.0, -12.5, -_total_length * 0.5 + 10.0), Color(0.05, 0.06, 0.07), "Field")
	for i in range(10):
		var z := -10.0 - float(i) * (_total_length / 10.0)
		for side: float in [-1.0, 1.0]:
			var x := side * (30.0 + float((i * 7) % 20))
			CourseBuilder.add_decor_box(holder, Vector3(4.0, 3.0, 7.0), Vector3(x, -10.5, z), Color(0.12, 0.12, 0.15), "Wagon")
			CourseBuilder.add_neon_strip(holder, Vector3(4.4, 0.25, 7.4), Vector3(x, -8.9, z), CourseBuilder.accent(i), "WagonRoof")
