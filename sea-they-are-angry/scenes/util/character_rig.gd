class_name CharacterRig
extends Node3D
## A rigged character from art/characters (built by art/source/characters/build_characters.py).
## The game poses its bones in code (walk cycles, swings, cowering) and can turn it into
## a ragdoll: on a hard hit or a fall the bones go over to physics, and when it gets
## back up the ragdoll blends back into the animated pose.
##
## Poses are given as rotations about the model's own axes, so a script can say "swing
## the right thigh forward" without knowing how each bone is rolled. Model space: +Y up,
## the character faces +Z here (this node turns it round to face -Z, the game's forward),
## its left is +X.

signal got_up

const DIR := "res://art/characters/%s.glb"
const RAGDOLL_LAYER := 32
const GET_UP_TIME := 0.55
# Per-bone physics for humanoids: capsule radius, cone swing and twist limits (degrees).
const HUMANOID := {
	"hips": [0.13, 0, 0], "spine": [0.12, 25, 10], "chest": [0.14, 25, 10], "neck": [0.06, 30, 20], "head": [0.1, 35, 25],
	"upper_arm": [0.06, 80, 30], "forearm": [0.05, 70, 10], "hand": [0.045, 40, 10],
	"thigh": [0.08, 60, 15], "shin": [0.065, 70, 5], "foot": [0.05, 30, 5],
}

var skeleton: Skeleton3D
var mesh: MeshInstance3D
var material: StandardMaterial3D
var physics := HUMANOID
var mass := 2.5
var _rest := {}
var _rest_global := {}
var _sim: PhysicalBoneSimulator3D
var _bodies := {}
var _getting_up := false
var _ragdoll := false

## Load a character by name; null when the model is missing (callers keep their fallback).
static func create(model: String) -> CharacterRig:
	var path := DIR % model
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	if inst == null or inst.find_children("*", "Skeleton3D", true, false).is_empty():
		if inst:
			inst.free()
		return null
	var rig := CharacterRig.new()
	inst.rotation.y = PI
	rig.add_child(inst)
	rig._setup(inst)
	return rig

func _setup(inst: Node3D) -> void:
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	skeleton = skels[0]
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		mesh = m
		var src: Material = m.get_active_material(0)
		if src is StandardMaterial3D:
			material = src.duplicate()
		else:
			material = StandardMaterial3D.new()
		material.roughness = 0.88
		m.material_override = material
		# A ragdoll carries the mesh well away from its rest bounds: don't let it be culled.
		m.extra_cull_margin = 8.0
	for i in skeleton.get_bone_count():
		var bn := skeleton.get_bone_name(i)
		_rest[bn] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		_rest_global[bn] = skeleton.get_bone_global_rest(i).basis.get_rotation_quaternion()

func has_bone(bone: String) -> bool:
	return _rest.has(bone)

## Rotate a bone from its rest pose by Euler angles about the model's X, Y and Z axes
## (applied X, then Y, then Z). Zero puts it back to rest.
func pose(bone: String, euler: Vector3) -> void:
	if not _rest.has(bone):
		return
	var g: Quaternion = _rest_global[bone]
	var q_model := Quaternion(Vector3.FORWARD, -euler.z) * Quaternion(Vector3.UP, euler.y) * Quaternion(Vector3.RIGHT, euler.x)
	var q_local := g.inverse() * q_model * g
	skeleton.set_bone_pose_rotation(skeleton.find_bone(bone), _rest[bone] * q_local)

## Move a bone from its rest position by an offset in model space (bobbing hips).
func shift(bone: String, offset: Vector3) -> void:
	var i := skeleton.find_bone(bone)
	if i < 0:
		return
	var parent := skeleton.get_bone_parent(i)
	var local := offset
	if parent >= 0:
		local = skeleton.get_bone_global_rest(parent).basis.inverse() * offset
	skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin + local)

func reset_pose() -> void:
	for i in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
		skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin)

## Hold a node in a bone's frame (tools in hands, a lantern, glowing eyes on the head).
func attach(bone: String, node: Node3D) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	ba.add_child(node)
	return ba

## Hold a node at a bone with its axes lined up with this rig's own at rest, so a tool
## built pointing forward (-Z) is held pointing forward. `offset` is in rig space.
func attach_aligned(bone: String, node: Node3D, offset: Vector3 = Vector3.ZERO) -> BoneAttachment3D:
	var i := skeleton.find_bone(bone)
	var ba := attach(bone, Node3D.new())
	var holder: Node3D = ba.get_child(0)
	var to_skel := global_transform.affine_inverse() * skeleton.global_transform
	var bone_rig := to_skel * skeleton.get_bone_global_rest(i)
	holder.transform = bone_rig.affine_inverse() * Transform3D(Basis(), bone_rig.origin + offset)
	holder.add_child(node)
	return ba

## Where a bone is in the world right now (follows the ragdoll too).
func bone_position(bone: String) -> Vector3:
	if _ragdoll and _bodies.has(bone):
		return (_bodies[bone] as Node3D).global_position
	var i := skeleton.find_bone(bone)
	if i < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin

## Multiply the texture by a colour (white = as painted); emission for glows and burns.
func tint(c: Color, glow: Color = Color.BLACK, energy: float = 0.0) -> void:
	if material == null:
		return
	material.albedo_color = c
	material.emission_enabled = energy > 0.0
	material.emission = glow
	material.emission_energy_multiplier = energy

# ---- ragdoll ----

func is_ragdoll() -> bool:
	return _ragdoll

func is_getting_up() -> bool:
	return _getting_up

## Go limp. The impulse (kg·m/s) is applied at `at_bone`, e.g. a blow on the chest.
func ragdoll(impulse: Vector3 = Vector3.ZERO, at_bone: String = "chest") -> void:
	if skeleton == null:
		return
	if _ragdoll and not _getting_up:
		_push(impulse, at_bone)
		return
	_getting_up = false
	if _sim == null:
		_build_bodies()
	_sim.influence = 1.0
	_sim.physical_bones_start_simulation()
	_ragdoll = true
	_push(impulse, at_bone)

func _push(impulse: Vector3, at_bone: String) -> void:
	if impulse == Vector3.ZERO:
		return
	var b: PhysicalBone3D = _bodies.get(at_bone, _bodies.get("hips"))
	if b:
		b.apply_central_impulse(impulse)

## Where the ragdoll's hips have come to rest, in the world.
func ragdoll_centre() -> Vector3:
	return bone_position("hips")

## The ground under the ragdoll's hips (a ray down; the island has several levels), or
## INF over the sea.
func ragdoll_ground() -> Vector3:
	var c := ragdoll_centre()
	var q := PhysicsRayQueryParameters3D.create(c + Vector3(0.0, 0.4, 0.0), c + Vector3(0.0, -4.0, 0.0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if hit else Vector3.INF

## Which way the ragdoll is lying, head from hips, flattened: for facing on getting up.
func ragdoll_facing() -> Vector3:
	var d := bone_position("head") - bone_position("hips")
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD

## Blend from the ragdoll back into the animated pose. Move the owner to
## ragdoll_centre() first: the limp body stays put in the world while it blends.
func get_up(time: float = GET_UP_TIME) -> void:
	if not _ragdoll or _getting_up:
		return
	_getting_up = true
	var tw := create_tween()
	tw.tween_property(_sim, "influence", 0.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_stood)

func _stood() -> void:
	if not _getting_up:
		return
	_getting_up = false
	_ragdoll = false
	_free_bodies()
	got_up.emit()

## Stay down for good (a corpse): physics keeps running until the owner is freed.
func stay_down() -> void:
	_getting_up = false

func _build_bodies() -> void:
	_sim = PhysicalBoneSimulator3D.new()
	skeleton.add_child(_sim)
	for i in skeleton.get_bone_count():
		var bn := skeleton.get_bone_name(i)
		var spec: Array = physics.get(bn.split(".")[0], [])
		if spec.is_empty():
			continue
		var length := 0.14
		for c in skeleton.get_bone_children(i):
			length = skeleton.get_bone_rest(c).origin.length()
			break
		var pb := PhysicalBone3D.new()
		pb.bone_name = bn
		_sim.add_child(pb)
		var root := _parent_body_bone(i) == ""
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE if root else PhysicalBone3D.JOINT_TYPE_CONE
		pb.body_offset = Transform3D(Basis(), Vector3(0.0, length * 0.5, 0.0))
		pb.joint_offset = Transform3D(Basis(), Vector3(0.0, -length * 0.5, 0.0))
		if not root:
			pb.set("joint_constraints/swing_span", float(spec[1]))
			pb.set("joint_constraints/twist_span", float(spec[2]))
			pb.set("joint_constraints/softness", 0.8)
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = float(spec[0])
		cap.height = maxf(length + float(spec[0]) * 0.5, float(spec[0]) * 2.05)
		col.shape = cap
		pb.add_child(col)
		pb.mass = mass * (1.6 if bn in ["hips", "chest", "spine"] else 0.6)
		pb.collision_layer = RAGDOLL_LAYER
		pb.collision_mask = 1 | 4
		pb.friction = 0.9
		pb.linear_damp = 0.2
		pb.angular_damp = 1.5
		_bodies[bn] = pb

# The nearest ancestor that has a body, or "" for the root of the ragdoll.
func _parent_body_bone(i: int) -> String:
	var p := skeleton.get_bone_parent(i)
	while p >= 0:
		if physics.has(skeleton.get_bone_name(p).split(".")[0]):
			return skeleton.get_bone_name(p)
		p = skeleton.get_bone_parent(p)
	return ""

func _free_bodies() -> void:
	if _sim:
		_sim.physical_bones_stop_simulation()
		_sim.queue_free()
		_sim = null
	_bodies.clear()
