class_name Paintball
extends Node3D
## A flying paintball. On the host it is "live": it ray-casts each step and
## reports the first contestant or wall it hits. On clients it is only for show
## and pops on the course or when it reaches any contestant.

signal hit_contestant(ball: Paintball, victim: Contestant)
signal hit_world(ball: Paintball, pos: Vector3, normal: Vector3)

const GRAVITY := 6.0
const LIFETIME := 2.0
const HIT_RADIUS := 0.75

var owner_name: String = ""
var colour: Color = Color.WHITE
var velocity: Vector3 = Vector3.ZERO
var live: bool = false

var _age: float = 0.0
var _owner_rid: RID

static var _mesh: SphereMesh


static func create(parent: Node, origin: Vector3, vel: Vector3, shooter: Contestant, tint: Color, is_live: bool) -> Paintball:
	if parent == null or not parent.is_inside_tree():
		return null
	var ball := Paintball.new()
	ball.velocity = vel
	ball.colour = tint
	ball.live = is_live
	if shooter != null:
		ball.owner_name = str(shooter.name)
		ball._owner_rid = shooter.get_rid()
	parent.add_child(ball)
	ball.global_position = origin
	return ball


func _ready() -> void:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.13
		_mesh.height = 0.26
		_mesh.radial_segments = 8
		_mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = CourseBuilder.make_neon_material(colour, 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	# Contestants first (a sphere sweep approximated by the closest point on the step).
	for node in get_tree().get_nodes_in_group("contestants"):
		var c := node as Contestant
		if c == null or str(c.name) == owner_name or not c.visible:
			continue
		var centre := c.global_position + Vector3.UP * 0.75
		if _segment_distance(from, to, centre) < HIT_RADIUS:
			if live:
				hit_contestant.emit(self, c)
			queue_free()
			return
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, Contestant.COURSE_LAYER)
	if _owner_rid.is_valid():
		query.exclude = [_owner_rid]
	var hit_info := space.intersect_ray(query)
	if not hit_info.is_empty():
		var pos: Vector3 = hit_info["position"]
		var normal: Vector3 = hit_info["normal"]
		PaintSplat.place(get_parent(), pos, normal, colour)
		FX.burst(self, "paint", pos + normal * 0.1, colour, 0.8)
		hit_world.emit(self, pos, normal)
		queue_free()
		return
	global_position = to


static func _segment_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := 0.0
	var len_sq := ab.length_squared()
	if len_sq > 0.0001:
		t = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * t).distance_to(p)
