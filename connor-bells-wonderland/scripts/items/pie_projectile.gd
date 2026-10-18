class_name PieProjectile
extends Node3D
## A lobbed custard pie. On the host (authoritative) it splats contestants near
## where it lands; on clients the same flight is shown for looks only.

signal splatted(pie: PieProjectile, pos: Vector3, victims: Array)

const GRAVITY := 20.0
const MAX_AGE := 4.0

var velocity: Vector3 = Vector3.ZERO
var owner_name: String = ""
var authoritative: bool = false
var splat_radius: float = 1.6
var knock: float = 9.0
var launch_up: float = 5.0
var stumble: float = 1.3

var _age: float = 0.0
var _done: bool = false
var _splat_age: float = -1.0
var _model: Node3D
var _splat: MeshInstance3D


static func create(parent: Node, pos: Vector3, p_velocity: Vector3, p_owner: String, p_authoritative: bool) -> PieProjectile:
	if parent == null:
		return null
	var pie := PieProjectile.new()
	pie.name = "Pie"
	pie.velocity = p_velocity
	pie.owner_name = p_owner
	pie.authoritative = p_authoritative
	pie.position = pos
	var def := ItemKinds.get_def(ItemKinds.Kind.PIE)
	pie.splat_radius = float(def.get("radius", 1.6))
	pie.knock = float(def.get("knock", 9.0))
	pie.launch_up = float(def.get("launch_up", 5.0))
	pie.stumble = float(def.get("stumble", 1.3))
	parent.add_child(pie)
	return pie


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	CourseBuilder.add_decor_cylinder(_model, 0.32, 0.12, Vector3.ZERO, Color(0.75, 0.5, 0.25), "Crust")
	CourseBuilder.add_decor_cylinder(_model, 0.28, 0.05, Vector3(0.0, 0.07, 0.0), Color(1.0, 0.9, 0.45), "Custard")
	var cream := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.16
	sphere.material = CourseBuilder.make_material(Color.WHITE)
	cream.mesh = sphere
	cream.position = Vector3(0.0, 0.12, 0.0)
	_model.add_child(cream)


func _physics_process(delta: float) -> void:
	if _done:
		_splat_age += delta
		if _splat != null:
			_splat.scale = Vector3.ONE * clampf(_splat_age / 0.12, 0.05, 1.0)
		if _splat_age > 2.5:
			queue_free()
		return
	_age += delta
	var from := global_position
	velocity.y -= GRAVITY * delta
	var to := from + velocity * delta
	_model.rotation.x += delta * 8.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, Contestant.COURSE_LAYER | Contestant.CONTESTANT_LAYER)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if not (collider is Contestant and str((collider as Contestant).name) == owner_name):
			_land(hit["position"])
			return
	global_position = to
	if _age > MAX_AGE or to.y < -12.0:
		queue_free()


func _land(pos: Vector3) -> void:
	_done = true
	_splat_age = 0.0
	global_position = pos
	_model.visible = false
	_splat = CourseBuilder.make_cylinder_mesh(splat_radius * 0.8, 0.05, Color(1.0, 0.92, 0.5))
	_splat.position = Vector3(0.0, 0.03, 0.0)
	add_child(_splat)
	var victims: Array = []
	if authoritative:
		for node in get_tree().get_nodes_in_group("contestants"):
			var c := node as Contestant
			if c == null or str(c.name) == owner_name:
				continue
			var offset := c.global_position + Vector3.UP * 0.7 - pos
			if offset.length() > splat_radius + 0.6:
				continue
			offset.y = 0.0
			var dir := offset.normalized() if offset.length() > 0.05 else -velocity.normalized()
			dir.y = 0.0
			if StatusEffects.try_knock(c, dir.normalized() * knock + Vector3.UP * launch_up, stumble):
				victims.append(str(c.name))
	splatted.emit(self, pos, victims)
