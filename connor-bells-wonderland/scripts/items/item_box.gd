class_name ItemBox
extends Area3D
## A floating "?" gift box. A contestant with an empty item slot that touches
## it gets a random Fairground Mayhem item (decided on the host). The box hides
## and comes back after respawn_seconds.

signal picked(box: ItemBox, contestant: Contestant)

@export var respawn_seconds: float = 4.0
@export var size: float = 0.9

var index: int = 0

var _hidden_left: float = 0.0
var _time: float = 0.0
var _origin_y: float = 0.0
var _model: Node3D


static func create(parent: Node, pos: Vector3, p_index: int) -> ItemBox:
	if parent == null:
		push_error("ItemBox.create: parent is null.")
		return null
	var box := ItemBox.new()
	box.index = p_index
	box.name = "ItemBox%d" % p_index
	box.position = pos
	parent.add_child(box)
	return box


func _ready() -> void:
	add_to_group("item_boxes")
	collision_mask = Contestant.AREA_MASK
	_origin_y = position.y
	_time = float(index) * 0.7
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = size
	shape.shape = sphere
	add_child(shape)
	_build_model()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _hidden_left > 0.0:
		_hidden_left -= delta
		if _hidden_left <= 0.0:
			_show()
		return
	_time += delta
	_model.rotation.y = wrapf(_model.rotation.y + delta * 1.6, 0.0, TAU)
	_model.rotation.x = sin(_time * 1.3) * 0.25
	position.y = _origin_y + sin(_time * 2.5) * 0.15


func is_available() -> bool:
	return _hidden_left <= 0.0


## Hide the box (on the host after a pickup, on clients when told).
func take() -> void:
	_hidden_left = respawn_seconds
	visible = false
	set_deferred("monitoring", false)


func reset() -> void:
	_hidden_left = 0.0
	_show()


func _show() -> void:
	_hidden_left = 0.0
	visible = true
	set_deferred("monitoring", true)


func _on_body_entered(body: Node3D) -> void:
	if not is_available() or not (body is Contestant) or not multiplayer.is_server():
		return
	var holder := body.get_node_or_null("ItemHolder") as ItemHolder
	if holder == null or not holder.is_empty():
		return
	take()
	picked.emit(self, body as Contestant)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var colour := CourseBuilder.rainbow(index)
	var cube := CourseBuilder.make_box_mesh(Vector3(size, size, size), colour)
	var mat := cube.mesh.material as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 0.35
	_model.add_child(cube)
	var ribbon := Color(1.0, 0.95, 0.4)
	_model.add_child(_ribbon(Vector3(size + 0.04, size + 0.04, 0.16), ribbon))
	_model.add_child(_ribbon(Vector3(0.16, size + 0.04, size + 0.04), ribbon))
	for x: float in [-0.14, 0.14]:
		var bow := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.14
		sphere.height = 0.2
		sphere.material = CourseBuilder.make_material(ribbon)
		bow.mesh = sphere
		bow.position = Vector3(x, size * 0.5 + 0.08, 0.0)
		_model.add_child(bow)
	var mark := Label3D.new()
	mark.text = "?"
	mark.font_size = 120
	mark.outline_size = 16
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.position = Vector3(0.0, size * 0.9, 0.0)
	add_child(mark)


func _ribbon(box_size: Vector3, colour: Color) -> MeshInstance3D:
	return CourseBuilder.make_box_mesh(box_size, colour)
