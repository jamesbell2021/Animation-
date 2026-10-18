class_name MovingPlatform
extends AnimatableBody3D
## A platform contestants can ride. It can slide back and forth along [member travel]
## and/or spin around its own Y axis. Geometry is built in _ready().

enum ShapeType { BOX, DISC }

@export var shape_type: ShapeType = ShapeType.BOX
@export var size: Vector3 = Vector3(4.0, 0.5, 4.0)
@export var disc_radius: float = 4.0
## Full offset from the start position to the far end of the slide.
@export var travel: Vector3 = Vector3.ZERO
## Seconds for a complete there-and-back trip.
@export var period: float = 4.0
## Phase offset in seconds so neighbouring platforms are not synchronised.
@export var phase: float = 0.0
@export var spin_degrees: float = 0.0
@export var colour: Color = Color(0.25, 0.6, 1.0)

var _origin: Vector3
var _time: float = 0.0


## Factory for sliding platforms. [param pos] is local to [param parent] and is the platform centre.
static func create_box(parent: Node, pos: Vector3, p_size: Vector3, p_travel: Vector3, p_period: float, p_colour: Color, p_phase: float = 0.0) -> MovingPlatform:
	if parent == null:
		push_error("MovingPlatform.create_box: parent is null.")
		return null
	var platform := MovingPlatform.new()
	platform.shape_type = ShapeType.BOX
	platform.size = p_size
	platform.travel = p_travel
	platform.period = p_period
	platform.colour = p_colour
	platform.phase = p_phase
	platform.position = pos
	parent.add_child(platform)
	return platform


## Factory for spinning discs (carousels). [param pos] is the disc centre.
static func create_disc(parent: Node, pos: Vector3, p_radius: float, p_thickness: float, p_spin_degrees: float, p_colour: Color) -> MovingPlatform:
	if parent == null:
		push_error("MovingPlatform.create_disc: parent is null.")
		return null
	var platform := MovingPlatform.new()
	platform.shape_type = ShapeType.DISC
	platform.disc_radius = p_radius
	platform.size = Vector3(p_radius * 2.0, p_thickness, p_radius * 2.0)
	platform.spin_degrees = p_spin_degrees
	platform.colour = p_colour
	platform.position = pos
	parent.add_child(platform)
	return platform


func _ready() -> void:
	add_to_group("moving_platforms")
	sync_to_physics = true
	_origin = position
	_time = phase
	if get_child_count() == 0:
		_build_geometry()


func _physics_process(delta: float) -> void:
	_time += delta
	if travel != Vector3.ZERO and period > 0.0:
		var t := 0.5 - 0.5 * cos(_time * TAU / period)
		position = _origin + travel * t
	if spin_degrees != 0.0:
		rotation.y = wrapf(rotation.y + deg_to_rad(spin_degrees) * delta, 0.0, TAU)


## World-space centre this platform will have [param seconds] from now (bots use it to time jumps).
func predict_global_position(seconds: float) -> Vector3:
	var local := position
	if travel != Vector3.ZERO and period > 0.0:
		local = _origin + travel * (0.5 - 0.5 * cos((_time + seconds) * TAU / period))
	var parent := get_parent() as Node3D
	return parent.to_global(local) if parent != null else local


## World-space height of the top surface.
func get_top_y() -> float:
	return global_position.y + size.y * 0.5


func _build_geometry() -> void:
	var shape := CollisionShape3D.new()
	if shape_type == ShapeType.DISC:
		var cyl := CylinderShape3D.new()
		cyl.radius = disc_radius
		cyl.height = size.y
		shape.shape = cyl
		add_child(shape)
		var mesh := CourseBuilder.make_cylinder_mesh(disc_radius, size.y, CourseBuilder.surface(colour))
		mesh.name = "DiscMesh"
		add_child(mesh)
		var rim := CourseBuilder.make_cylinder_mesh(disc_radius + 0.06, size.y * 0.4, colour)
		rim.mesh.material = CourseBuilder.make_neon_material(colour)
		rim.name = "DiscRim"
		add_child(rim)
		_add_disc_stripes()
	else:
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		add_child(shape)
		var mesh := CourseBuilder.make_box_mesh(size, CourseBuilder.surface(colour))
		mesh.name = "BoxMesh"
		add_child(mesh)
		for side: float in [-1.0, 1.0]:
			CourseBuilder.add_neon_strip(self, Vector3(size.x + 0.04, 0.08, 0.1), Vector3(0.0, size.y * 0.5, side * size.z * 0.5), colour, "Edge")


## Rainbow wedges painted on top of a disc so the spin is visible.
func _add_disc_stripes() -> void:
	var segments := 6
	for i in range(segments):
		var angle := i * TAU / float(segments)
		var stripe := CourseBuilder.make_box_mesh(Vector3(disc_radius * 0.9, 0.05, 0.25), CourseBuilder.accent(i % 2))
		stripe.mesh.material = CourseBuilder.make_neon_material(CourseBuilder.accent(i % 2), 1.0)
		stripe.name = "Stripe%d" % i
		stripe.position = Vector3(cos(angle) * disc_radius * 0.5, size.y * 0.5 + 0.03, sin(angle) * disc_radius * 0.5)
		stripe.rotation.y = -angle
		add_child(stripe)
