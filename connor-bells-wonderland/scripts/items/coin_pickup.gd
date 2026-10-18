class_name CoinPickup
extends Area3D
## A spinning, bobbing collectible. COIN is worth 1, SHAMROCK is worth 5.
## Collection is decided on the host only; clients hide coins via take_remote().

signal collected(contestant: Contestant, value: int)

enum Kind { COIN, SHAMROCK }

@export var kind: Kind = Kind.COIN
@export var value: int = 0
@export var spin_speed_degrees: float = 140.0
@export var bob_height: float = 0.15

var _origin_y: float = 0.0
var _time: float = 0.0
var _taken: bool = false


## [param pos] is local to [param parent]; it is the coin's centre.
static func create(parent: Node, pos: Vector3, p_kind: Kind = Kind.COIN) -> CoinPickup:
	if parent == null:
		push_error("CoinPickup.create: parent is null.")
		return null
	var coin := CoinPickup.new()
	coin.kind = p_kind
	coin.position = pos
	parent.add_child(coin)
	return coin


func _ready() -> void:
	add_to_group("coins")
	collision_mask = Contestant.AREA_MASK
	name = "Shamrock" if kind == Kind.SHAMROCK else "Coin"
	if value <= 0:
		value = 5 if kind == Kind.SHAMROCK else 1
	_origin_y = position.y
	_time = randf() * TAU
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	add_child(shape)
	if kind == Kind.SHAMROCK:
		_build_shamrock()
	else:
		_build_coin()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	rotation.y = wrapf(rotation.y + deg_to_rad(spin_speed_degrees) * delta, 0.0, TAU)
	position.y = _origin_y + sin(_time * 3.0) * bob_height


func reset() -> void:
	_taken = false
	visible = true
	set_deferred("monitoring", true)


func is_taken() -> bool:
	return _taken


## Hide without emitting; used on clients when the host reports a collection.
func take_remote() -> void:
	_taken = true
	visible = false
	set_deferred("monitoring", false)


func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is Contestant):
		return
	if not multiplayer.is_server():
		return
	_taken = true
	visible = false
	set_deferred("monitoring", false)
	collected.emit(body as Contestant, value)


func _gold() -> StandardMaterial3D:
	var mat := CourseBuilder.make_material(Color(1.0, 0.82, 0.15))
	mat.metallic = 0.7
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.45, 0.05)
	mat.emission_energy_multiplier = 0.6
	return mat


func _build_coin() -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.4
	mesh.height = 0.1
	mesh.material = _gold()
	disc.mesh = mesh
	disc.rotation.x = PI * 0.5
	add_child(disc)
	var inner := MeshInstance3D.new()
	var inner_mesh := CylinderMesh.new()
	inner_mesh.top_radius = 0.28
	inner_mesh.bottom_radius = 0.28
	inner_mesh.height = 0.14
	inner_mesh.material = CourseBuilder.make_material(Color(0.8, 0.6, 0.1))
	inner.mesh = inner_mesh
	inner.rotation.x = PI * 0.5
	add_child(inner)


func _build_shamrock() -> void:
	var green := CourseBuilder.make_material(Color(0.2, 0.8, 0.3))
	green.emission_enabled = true
	green.emission = Color(0.05, 0.3, 0.1)
	for i in range(3):
		var a := i * TAU / 3.0 + PI * 0.5
		var leaf := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.24
		mesh.height = 0.16
		mesh.material = green
		leaf.mesh = mesh
		leaf.position = Vector3(cos(a) * 0.2, sin(a) * 0.2, 0.0)
		leaf.rotation.x = PI * 0.5
		add_child(leaf)
	var stem := CourseBuilder.make_box_mesh(Vector3(0.06, 0.4, 0.05), Color(0.15, 0.55, 0.2))
	stem.position = Vector3(0.0, -0.35, 0.0)
	add_child(stem)
