class_name ConfettiBurst
extends Node3D
## One-shot rainbow confetti explosion (visual only). Frees itself.

@export var amount: int = 140
@export var radius: float = 4.5
@export var lifetime: float = 1.8

var _age: float = 0.0
var _ring: MeshInstance3D


static func create(parent: Node, pos: Vector3, p_radius: float = 4.5, p_amount: int = 140) -> ConfettiBurst:
	if parent == null:
		return null
	var burst := ConfettiBurst.new()
	burst.radius = p_radius
	burst.amount = p_amount
	burst.position = pos
	parent.add_child(burst)
	return burst


func _ready() -> void:
	var particles := CPUParticles3D.new()
	particles.name = "Confetti"
	particles.amount = amount
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = lifetime
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.6
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = radius * 1.2
	particles.initial_velocity_max = radius * 2.2
	particles.gravity = Vector3(0.0, -9.0, 0.0)
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([CourseBuilder.rainbow(0), CourseBuilder.rainbow(1)])
	for i in range(2, 7):
		gradient.add_point(float(i) / 6.0, CourseBuilder.rainbow(i))
	particles.color_initial_ramp = gradient
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	particles.mesh = quad
	add_child(particles)
	particles.emitting = true

	_ring = CourseBuilder.make_cylinder_mesh(0.5, 0.08, Color(1.0, 0.9, 0.4, 0.7))
	var ring_mat := _ring.mesh.material as StandardMaterial3D
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.position = Vector3(0.0, 0.3, 0.0)
	add_child(_ring)


func _process(delta: float) -> void:
	_age += delta
	if _ring != null:
		var t := clampf(_age / 0.35, 0.0, 1.0)
		var r := lerpf(0.2, radius * 2.0, t)
		_ring.scale = Vector3(r, 1.0, r)
		_ring.visible = t < 1.0
	if _age > lifetime + 0.6:
		queue_free()
