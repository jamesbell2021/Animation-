class_name WebCuller
extends Node
## Browser builds only. WebGL stops drawing the 3D world altogether once about a
## thousand objects are visible, and the race course has nearly two thousand. So
## this keeps the scenery nearest the camera (and what's ahead of it) visible, up to
## BUDGET objects in all, and hides the rest. Re-checked a few times a second.

const BUDGET := 650
const INTERVAL := 0.3
## Things behind the camera count as this much further away.
const BEHIND_WEIGHT := 2.5

var _entries: Array[Dictionary] = []
var _fixed: int = 0
var _timer: float = 0.0


## Should the game use one? Browsers, phones that fall back to OpenGL (older ones
## without Vulkan), or "webcull" on the command line to test.
static func wanted() -> bool:
	if OS.has_feature("web") or "webcull" in OS.get_cmdline_user_args():
		return true
	return OS.has_feature("android") and RenderingServer.get_rendering_device() == null


## [param candidates]: nodes that can be hidden. Item boxes and coins hide their own
## root when taken, so for those the culler hides their children instead.
func setup(game_root: Node, candidates: Array[Node3D]) -> void:
	var total := _cost(game_root)
	var culled := 0
	for node in candidates:
		var cost := _cost(node)
		if cost == 0:
			continue
		var targets: Array[Node3D] = []
		if node is ItemBox or node is CoinPickup:
			for child in node.get_children():
				if child is Node3D and not (child is CollisionShape3D):
					targets.append(child)
		else:
			targets.append(node)
		var box := _bounds(node)
		_entries.append({"targets": targets, "centre": box.get_center(), "radius": box.size.length() * 0.5, "cost": cost})
		culled += cost
	_fixed = total - culled
	print("WebCuller: %d objects, %d can be hidden in %d pieces, budget %d" % [total, culled, _entries.size(), BUDGET])
	_update()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = INTERVAL
		_update()


func _update() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _entries.is_empty():
		return
	var eye := cam.global_position
	var ahead := -cam.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var order: Array = []
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		var to: Vector3 = e["centre"] - eye
		var d := maxf(to.length() - float(e["radius"]), 0.0)
		if to.dot(ahead) < 0.0:
			d *= BEHIND_WEIGHT
		order.append([d, i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var left := BUDGET - _fixed
	for pair in order:
		var e: Dictionary = _entries[pair[1]]
		var show := int(e["cost"]) <= left
		if show:
			left -= int(e["cost"])
		for t in e["targets"]:
			var target := t as Node3D
			if is_instance_valid(target) and target.visible != show:
				target.visible = show


static func _cost(node: Node) -> int:
	var n := 0
	if node is GeometryInstance3D and (node as Node3D).is_visible_in_tree():
		n += 1
	for g in node.find_children("*", "GeometryInstance3D", true, false):
		if (g as Node3D).is_visible_in_tree():
			n += 1
	return n


static func _bounds(node: Node3D) -> AABB:
	var box := AABB(node.global_position, Vector3.ZERO)
	var parts: Array = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		parts.append(node)
	for v in parts:
		var vi := v as VisualInstance3D
		box = box.merge(vi.global_transform * vi.get_aabb())
	return box
