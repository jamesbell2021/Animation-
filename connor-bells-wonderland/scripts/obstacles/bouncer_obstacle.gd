class_name BouncerObstacle
extends StaticBody3D
## A springy pad that launches contestants upward when they land on it.
## Optionally adds a fixed horizontal launch velocity (for long jumps).

signal bounced(contestant: Contestant)

@export var radius: float = 1.5
@export var height: float = 0.5
@export var bounce_velocity: float = 14.0
## Horizontal velocity applied on bounce. Zero keeps the contestant's own direction.
@export var launch_direction: Vector3 = Vector3.ZERO
@export var colour: Color = Color(0.9, 0.4, 0.8)
@export var cooldown: float = 0.3

var _last_bounce: Dictionary = {}


## [param pos] is local to [param parent]; y is the floor level under the pad.
static func create(parent: Node, pos: Vector3, p_radius: float, p_bounce_velocity: float, p_colour: Color, p_launch: Vector3 = Vector3.ZERO) -> BouncerObstacle:
	if parent == null:
		push_error("BouncerObstacle.create: parent is null.")
		return null
	var pad := BouncerObstacle.new()
	pad.radius = p_radius
	pad.bounce_velocity = p_bounce_velocity
	pad.colour = p_colour
	pad.launch_direction = p_launch
	pad.position = pos
	parent.add_child(pad)
	return pad


func _ready() -> void:
	if get_child_count() == 0:
		_build_geometry()


func _build_geometry() -> void:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position = Vector3(0.0, height * 0.5, 0.0)
	add_child(shape)

	var rim := CourseBuilder.make_cylinder_mesh(radius + 0.15, height * 0.8, colour.darkened(0.4))
	rim.name = "Rim"
	rim.position = Vector3(0.0, height * 0.4, 0.0)
	add_child(rim)

	var pad := CourseBuilder.make_cylinder_mesh(radius, height, colour)
	pad.name = "Pad"
	pad.position = Vector3(0.0, height * 0.5, 0.0)
	add_child(pad)

	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.9
	sphere.height = 0.5
	sphere.material = CourseBuilder.make_material(colour.lightened(0.3))
	dome.mesh = sphere
	dome.name = "Dome"
	dome.position = Vector3(0.0, height, 0.0)
	add_child(dome)

	var zone := Area3D.new()
	zone.name = "BounceZone"
	zone.collision_mask = Contestant.AREA_MASK
	var zone_shape := CollisionShape3D.new()
	var zone_cyl := CylinderShape3D.new()
	zone_cyl.radius = radius
	zone_cyl.height = 0.8
	zone_shape.shape = zone_cyl
	zone_shape.position = Vector3(0.0, height + 0.4, 0.0)
	zone.add_child(zone_shape)
	add_child(zone)
	zone.body_entered.connect(_on_bounce_zone_entered)


func _on_bounce_zone_entered(body: Node3D) -> void:
	if not (body is Contestant):
		return
	var contestant := body as Contestant
	var now := Time.get_ticks_msec() / 1000.0
	var id := contestant.get_instance_id()
	if now - float(_last_bounce.get(id, -100.0)) < cooldown:
		return
	_last_bounce[id] = now
	contestant.velocity.y = bounce_velocity
	if launch_direction != Vector3.ZERO:
		contestant.velocity.x = launch_direction.x
		contestant.velocity.z = launch_direction.z
	bounced.emit(contestant)
