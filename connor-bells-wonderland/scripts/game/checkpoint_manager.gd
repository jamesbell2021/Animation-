class_name CheckpointManager
extends Node
## Creates and tracks checkpoints along the course.
## When a contestant passes a checkpoint, its respawn point is moved forward.
## Progress (highest checkpoint index reached) is stored per contestant.

signal checkpoint_reached(contestant: Contestant, index: int)

var _checkpoints: Array[Area3D] = []
var _respawn_points: Array[Vector3] = []
var _progress: Dictionary = {}


## Builds a trigger box at [param local_pos] under [param parent] and registers it.
## [param local_respawn] is the respawn point in the parent's local space.
## The parent must already be inside the scene tree.
func create_checkpoint(parent: Node3D, local_pos: Vector3, size: Vector3, local_respawn: Vector3) -> Area3D:
	if parent == null or not parent.is_inside_tree():
		push_error("CheckpointManager.create_checkpoint: parent is null or not in the scene tree.")
		return null
	var area := Area3D.new()
	area.name = "Checkpoint%d" % _checkpoints.size()
	area.collision_mask = Contestant.AREA_MASK
	area.position = local_pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
	register_checkpoint(area, parent.to_global(local_respawn))
	return area


## Registers an existing Area3D as the next checkpoint. [param global_respawn] is in world space.
func register_checkpoint(area: Area3D, global_respawn: Vector3) -> void:
	if area == null:
		push_error("CheckpointManager.register_checkpoint: area is null.")
		return
	var index := _checkpoints.size()
	_checkpoints.append(area)
	_respawn_points.append(global_respawn)
	area.body_entered.connect(_on_body_entered.bind(index))


func get_checkpoint_count() -> int:
	return _checkpoints.size()


func get_respawn_point(index: int) -> Vector3:
	if index < 0 or index >= _respawn_points.size():
		push_warning("CheckpointManager.get_respawn_point: index %d out of range." % index)
		return Vector3.ZERO
	return _respawn_points[index]


## Highest checkpoint index this contestant has reached, or -1 if none.
func get_progress(contestant: Contestant) -> int:
	if contestant == null:
		return -1
	return _progress.get(contestant.get_instance_id(), -1)


## Clears all progress (for restarting a race). Checkpoints themselves remain.
func reset_progress() -> void:
	_progress.clear()


## Frees all checkpoint areas and forgets them (for rebuilding a course).
func clear_checkpoints() -> void:
	for area in _checkpoints:
		if is_instance_valid(area):
			area.queue_free()
	_checkpoints.clear()
	_respawn_points.clear()
	_progress.clear()


func _on_body_entered(body: Node3D, index: int) -> void:
	if not (body is Contestant):
		return
	var contestant := body as Contestant
	var id := contestant.get_instance_id()
	var current: int = _progress.get(id, -1)
	if index <= current:
		return
	_progress[id] = index
	contestant.set_respawn_point(_respawn_points[index])
	checkpoint_reached.emit(contestant, index)
