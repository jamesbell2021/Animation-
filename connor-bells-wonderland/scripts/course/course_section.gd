class_name CourseSection
extends Node3D
## Base class for one course section.
## Sections build along -Z from their own origin: the start edge is at local
## z = 0 and the far edge at z = -section_length. Floor tops are at local y = 0
## unless a section deliberately climbs. Override _build_geometry().

@export var section_length: float = 40.0
@export var section_width: float = 12.0
@export var section_title: String = "Section"
@export var colour_index: int = 0

var checkpoint_manager: CheckpointManager


## Called by the course once this section is inside the scene tree.
func build(manager: CheckpointManager) -> void:
	checkpoint_manager = manager
	if not is_inside_tree():
		push_error("CourseSection '%s': build() called before entering the scene tree." % name)
		return
	_build_geometry()


## Override in each section.
func _build_geometry() -> void:
	pass


## Local position where the next section should start.
func get_end_position() -> Vector3:
	return Vector3(0.0, 0.0, -section_length)


## Floor slab from z_start (nearer 0) to z_end (more negative). Top surface at y = top_y.
func add_floor(z_start: float, z_end: float, width: float, colour: Color, node_name: String = "Floor", top_y: float = 0.0, thickness: float = 1.0, x_centre: float = 0.0) -> StaticBody3D:
	var length := absf(z_start - z_end)
	var size := Vector3(width, thickness, length)
	var pos := Vector3(x_centre, top_y - thickness * 0.5, (z_start + z_end) * 0.5)
	return CourseBuilder.add_box(self, size, pos, CourseBuilder.surface(colour), node_name)


## Low walls on both sides of a floor strip so contestants are not knocked off too easily.
func add_side_rails(z_start: float, z_end: float, width: float, height: float = 0.6, top_y: float = 0.0, x_centre: float = 0.0) -> void:
	var length := absf(z_start - z_end)
	var z_mid := (z_start + z_end) * 0.5
	var half := width * 0.5 - 0.15
	var size := Vector3(0.3, height, length)
	var rail := Color(0.24, 0.25, 0.29)
	var glow := CourseBuilder.accent(colour_index)
	for side: float in [-1.0, 1.0]:
		CourseBuilder.add_box(self, size, Vector3(x_centre + side * half, top_y + height * 0.5, z_mid), rail, "Rail")
		CourseBuilder.add_neon_strip(self, Vector3(0.34, 0.06, length), Vector3(x_centre + side * half, top_y + height + 0.03, z_mid), glow, "RailNeon")


## A thin trigger strip across the course. Respawn is placed at the strip by default.
func add_checkpoint(local_pos: Vector3, local_respawn: Vector3 = Vector3.INF, width: float = -1.0) -> Area3D:
	if checkpoint_manager == null:
		push_warning("CourseSection '%s': no CheckpointManager, checkpoint skipped." % name)
		return null
	var w := width if width > 0.0 else section_width
	var respawn := local_respawn
	if respawn == Vector3.INF:
		respawn = local_pos + Vector3(0.0, 1.0, 0.0)
	return checkpoint_manager.create_checkpoint(self, local_pos + Vector3(0.0, 2.0, 0.0), Vector3(w, 4.0, 1.0), respawn)


## Floating title above the section entrance.
func add_title_sign(height: float = 7.0) -> void:
	CourseBuilder.add_sign(self, section_title, Vector3(0.0, height, -2.0), CourseBuilder.accent(colour_index))


## Two posts and a crossbar, like a fairground gateway.
func add_gateway(z: float, width: float, height: float = 4.5, colour: Color = Color(0.22, 0.23, 0.27)) -> void:
	var half := width * 0.5
	CourseBuilder.add_box(self, Vector3(0.4, height, 0.4), Vector3(-half, height * 0.5, z), colour, "GatePostL")
	CourseBuilder.add_box(self, Vector3(0.4, height, 0.4), Vector3(half, height * 0.5, z), colour, "GatePostR")
	CourseBuilder.add_decor_box(self, Vector3(width + 0.4, 0.6, 0.4), Vector3(0.0, height + 0.3, z), Color(0.2, 0.21, 0.24), "GateBar")
	CourseBuilder.add_neon_strip(self, Vector3(width + 0.4, 0.12, 0.44), Vector3(0.0, height + 0.05, z), CourseBuilder.accent(colour_index), "GateNeon")
	CourseBuilder.add_bunting(self, Vector3(-half, height, z - 0.5), Vector3(half, height, z - 0.5), 10)


## Striped tent-style canopy (decorative) centred at pos.
func add_tent(pos: Vector3, radius: float, height: float, colour: Color) -> void:
	CourseBuilder.add_decor_cylinder(self, radius, 0.3, pos + Vector3(0.0, height, 0.0), Color(0.12, 0.12, 0.14), "TentRim")
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = radius
	mesh.height = height * 0.6
	mesh.material = CourseBuilder.make_material(colour.darkened(0.45))
	cone.mesh = mesh
	cone.position = pos + Vector3(0.0, height + height * 0.3, 0.0)
	cone.name = "TentCone"
	add_child(cone)
	for i in range(4):
		var angle := i * TAU / 4.0 + PI / 4.0
		var pole_pos := pos + Vector3(cos(angle) * radius * 0.9, height * 0.5, sin(angle) * radius * 0.9)
		CourseBuilder.add_decor_cylinder(self, 0.12, height, pole_pos, Color(0.6, 0.4, 0.2), "TentPole%d" % i)
