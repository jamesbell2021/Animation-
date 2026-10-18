class_name ItemHolder
extends Node
## A contestant's item slot. Child of a Contestant named "ItemHolder".
## On the host it consumes Contestant.use_requested and asks the ItemManager
## to carry the item out; on clients it only shows what the host says is held.
## A small icon of the held item floats above the contestant's head.

signal item_changed(kind: int, uses: int)

var contestant: Contestant
var manager: ItemManager
var kind: int = ItemKinds.Kind.NONE
var uses: int = 0

var _cooldown: float = 0.0
var _icon: Node3D
var _pop: float = 0.0


func _ready() -> void:
	contestant = get_parent() as Contestant
	if contestant == null:
		push_error("ItemHolder must be a child of a Contestant.")


func is_empty() -> bool:
	return kind == ItemKinds.Kind.NONE


func can_use() -> bool:
	return not is_empty() and _cooldown <= 0.0 and contestant != null \
		and contestant.controls_enabled and not contestant.is_stumbling()


## Host: hand over a fresh item.
func give(new_kind: int) -> void:
	set_item(new_kind, ItemKinds.uses_for(new_kind))
	_cooldown = 0.4


func clear() -> void:
	set_item(ItemKinds.Kind.NONE, 0)


## Sets what is held (host, or a client mirroring the host) and rebuilds the icon.
func set_item(new_kind: int, new_uses: int) -> void:
	var changed := new_kind != kind
	if new_uses <= 0:
		new_kind = ItemKinds.Kind.NONE
	kind = new_kind
	uses = new_uses if new_kind != ItemKinds.Kind.NONE else 0
	if changed or is_empty():
		_rebuild_icon()
	else:
		_pop = 1.0
	item_changed.emit(kind, uses)


func _physics_process(delta: float) -> void:
	if contestant == null:
		return
	_cooldown -= delta
	if not contestant.use_requested:
		return
	contestant.use_requested = false
	if not multiplayer.is_server() or manager == null or not can_use():
		return
	var used_kind := kind
	if manager.use_item(contestant, used_kind):
		_cooldown = ItemKinds.cooldown_for(used_kind)
		_pop = 1.0
		set_item(used_kind, uses - 1)


func _process(delta: float) -> void:
	if _icon == null:
		return
	_icon.rotation.y = wrapf(_icon.rotation.y + delta * 2.0, 0.0, TAU)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	var s := 1.0 + _pop * 0.6
	_icon.scale = Vector3(s, s, s)


func _rebuild_icon() -> void:
	if _icon != null:
		_icon.queue_free()
		_icon = null
	if is_empty() or contestant == null:
		return
	_icon = Node3D.new()
	_icon.name = "HeldItem"
	_icon.position = Vector3(0.0, 2.45, 0.0)
	contestant.add_child(_icon)
	var colour := ItemKinds.colour_for(kind)
	match kind:
		ItemKinds.Kind.SWORD:
			CourseBuilder.add_decor_box(_icon, Vector3(0.1, 0.8, 0.06), Vector3(0.0, 0.2, 0.0), colour, "Blade")
			CourseBuilder.add_decor_box(_icon, Vector3(0.35, 0.08, 0.1), Vector3(0.0, -0.2, 0.0), Color(0.3, 0.3, 0.9), "Guard")
		ItemKinds.Kind.ZAPPER:
			CourseBuilder.add_decor_box(_icon, Vector3(0.18, 0.5, 0.18), Vector3.ZERO, colour, "Body")
			_ball(Color(1.0, 1.0, 0.3), 0.12, Vector3(0.0, 0.32, 0.0))
		ItemKinds.Kind.BALLOON:
			_ball(colour, 0.25, Vector3(0.0, 0.15, 0.0))
			CourseBuilder.add_decor_box(_icon, Vector3(0.02, 0.35, 0.02), Vector3(0.0, -0.25, 0.0), Color.WHITE, "String")
		ItemKinds.Kind.PIE:
			CourseBuilder.add_decor_cylinder(_icon, 0.28, 0.1, Vector3.ZERO, Color(0.75, 0.5, 0.25), "Crust")
			CourseBuilder.add_decor_cylinder(_icon, 0.24, 0.04, Vector3(0.0, 0.06, 0.0), colour, "Custard")
		ItemKinds.Kind.CONFETTI:
			_ball(colour, 0.22, Vector3.ZERO)
			CourseBuilder.add_decor_box(_icon, Vector3(0.04, 0.2, 0.04), Vector3(0.0, 0.28, 0.0), Color(0.9, 0.9, 0.9), "Fuse")
		ItemKinds.Kind.ROCKET_BOOTS, ItemKinds.Kind.MAGNET, ItemKinds.Kind.SHIELD:
			_ball(colour, 0.22, Vector3.ZERO)
			CourseBuilder.add_decor_cylinder(_icon, 0.3, 0.05, Vector3.ZERO, Color(1.0, 0.95, 0.5), "Ring")
		_:
			# Traps show as a small gift box in the trap's colour.
			CourseBuilder.add_decor_box(_icon, Vector3(0.4, 0.4, 0.4), Vector3.ZERO, colour, "Gift")
			CourseBuilder.add_decor_box(_icon, Vector3(0.44, 0.44, 0.08), Vector3.ZERO, Color(1.0, 0.95, 0.4), "Ribbon")
	_pop = 1.0


func _ball(colour: Color, radius: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.material = CourseBuilder.make_material(colour)
	mi.mesh = sphere
	mi.position = pos
	_icon.add_child(mi)
