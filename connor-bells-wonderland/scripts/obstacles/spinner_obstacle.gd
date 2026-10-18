class_name SpinnerObstacle
extends AnimatableBody3D
## A pole with one or more rotating arms that sweep contestants away.
## Geometry is built in _ready() from the exported settings.

@export var arm_length: float = 6.0
@export var arm_count: int = 1
@export var arm_thickness: float = 0.5
@export var arm_height: float = 0.6
@export var speed_degrees: float = 90.0
@export var pole_height: float = 1.6
@export var colour: Color = Color(1.0, 0.85, 0.1)
@export var start_angle_degrees: float = 0.0


## Factory used by sections. [param pos] is local to [param parent]; y is the floor level.
static func create(parent: Node, pos: Vector3, p_arm_length: float, p_speed_degrees: float, p_arm_count: int = 1, p_colour: Color = Color(1.0, 0.85, 0.1), p_arm_height: float = 0.6) -> SpinnerObstacle:
	if parent == null:
		push_error("SpinnerObstacle.create: parent is null.")
		return null
	var spinner := SpinnerObstacle.new()
	spinner.arm_length = p_arm_length
	spinner.speed_degrees = p_speed_degrees
	spinner.arm_count = p_arm_count
	spinner.colour = p_colour
	spinner.arm_height = p_arm_height
	spinner.position = pos
	parent.add_child(spinner)
	return spinner


func _ready() -> void:
	sync_to_physics = true
	rotation.y = deg_to_rad(start_angle_degrees)
	if get_child_count() == 0:
		_build_geometry()


func _physics_process(delta: float) -> void:
	rotation.y = wrapf(rotation.y + deg_to_rad(speed_degrees) * delta, 0.0, TAU)


func _build_geometry() -> void:
	var pole := CourseBuilder.make_cylinder_mesh(0.25, pole_height, Color(0.3, 0.3, 0.35))
	pole.name = "Pole"
	pole.position = Vector3(0.0, pole_height * 0.5, 0.0)
	add_child(pole)

	var pole_shape := CollisionShape3D.new()
	var pole_cyl := CylinderShape3D.new()
	pole_cyl.radius = 0.25
	pole_cyl.height = pole_height
	pole_shape.shape = pole_cyl
	pole_shape.position = Vector3(0.0, pole_height * 0.5, 0.0)
	add_child(pole_shape)

	var count := maxi(arm_count, 1)
	for i in range(count):
		var angle := i * TAU / float(count)
		var size := Vector3(arm_length, arm_thickness, arm_thickness)
		var offset := Vector3(cos(angle) * arm_length * 0.5, arm_height, sin(angle) * arm_length * 0.5)

		var mesh := CourseBuilder.make_box_mesh(size, colour if i % 2 == 0 else colour.darkened(0.25))
		mesh.name = "Arm%d" % i
		mesh.position = offset
		mesh.rotation.y = -angle
		add_child(mesh)

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = offset
		shape.rotation.y = -angle
		add_child(shape)

	var cap := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	sphere.material = CourseBuilder.make_material(Color(1.0, 0.3, 0.3))
	cap.mesh = sphere
	cap.name = "Cap"
	cap.position = Vector3(0.0, pole_height + 0.3, 0.0)
	add_child(cap)
