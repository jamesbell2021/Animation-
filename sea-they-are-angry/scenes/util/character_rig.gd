class_name CharacterRig
extends Node3D
## A rigged character from art/characters (built by art/source/characters/build_characters.py).
## It plays the clips baked into its GLB (art/source/characters/animate.py): the owner says
## how fast it is moving (locomote), what it is busy with (activity: hammering, climbing)
## and fires one-off actions (shot: a swing, a flinch, getting up). Small code layers go
## on top (layer: a claw raised for a slam). It can turn into a ragdoll: on a hard hit or
## a fall the bones go over to physics, and it gets back up with a get-up clip that
## starts from where the body lies.
##
## Poses are given as rotations about the model's own axes, so a script can say "swing
## the right thigh forward" without knowing how each bone is rolled. Model space: +Y up,
## the character faces +Z here (this node turns it round to face -Z, the game's forward),
## its left is +X.

signal got_up

const DIR := "res://art/characters/%s.glb"
const RAGDOLL_LAYER := 32
const GET_UP_TIME := 0.55
## How long the limp body takes to blend into the first frames of a get-up clip.
const RAG_TO_CLIP := 0.3
const LOCO := ["walk", "run", "sprint"]
const UPPER_SHOTS := ["swing", "flare", "hit", "strike"]
const FULL_SHOTS := ["getup_back", "getup_front", "lunge"]
const NOT_ACTIVITIES := ["idle", "walk", "run", "sprint"]
const UPPER_BONES := ["spine", "chest", "neck", "head", "upper_arm", "forearm", "hand"]
# Bodies that start against rock get shoved out hard: never let a limb fly.
const MAX_SPEED := 7.0
const MAX_SPIN := 14.0
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
## Scales the capsules for bigger or smaller bodies than a keeper.
var thickness := 1.0
var _rest := {}
var _rest_global := {}
var _sim: PhysicalBoneSimulator3D
var _bodies := {}
var _getting_up := false
var _ragdoll := false
## Named points from the model's build (eyes, mouth), in this rig's space.
var markers := {}
## The clips in the model and what animate.py says about them (loop, length, period, speed).
var clips := {}
var tree: AnimationTree
var _loco: Array[String] = []
var _activities: Array[String] = []
var _speed := 0.0
var _blend := 0.0
var _move := 0.0
var _busy := 0.0
var _busy_want := 0.0
var _activity := ""
var _act_speed := 1.0
var _layers := {}

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
	var apath := path.get_basename() + ".anims.json"
	if FileAccess.file_exists(apath):
		var meta = JSON.parse_string(FileAccess.get_file_as_string(apath))
		if meta is Dictionary and meta.get("clips") is Dictionary:
			rig._setup_clips(inst, meta["clips"])
	var mpath := path.get_basename() + ".json"
	if FileAccess.file_exists(mpath):
		var data = JSON.parse_string(FileAccess.get_file_as_string(mpath))
		if data is Dictionary:
			for k in data:
				var a: Array = data[k]
				rig.markers[k] = Vector3(a[0], a[1], a[2])
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

# ---- clips ----

func _setup_clips(inst: Node3D, info: Dictionary) -> void:
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player: AnimationPlayer = players[0]
	if not player.has_animation_library(""):
		return
	var lib := player.get_animation_library("")
	player.active = false
	for n in info:
		if lib.has_animation(n):
			clips[n] = info[n]
			var a := lib.get_animation(n)
			a.loop_mode = Animation.LOOP_LINEAR if info[n].get("loop", false) else Animation.LOOP_NONE
	if clips.is_empty():
		return
	for n in LOCO:
		if clips.has(n):
			_loco.append(n)
	for n in clips:
		if n not in NOT_ACTIVITIES and n not in UPPER_SHOTS and n not in FULL_SHOTS:
			_activities.append(n)
	tree = AnimationTree.new()
	tree.name = "Clips"
	inst.add_child(tree)
	tree.add_animation_library("", lib)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.tree_root = _build_tree(lib)
	tree.active = true

func _anim(n: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = StringName(n)
	return a

func _picker(names: Array, xfade: float) -> AnimationNodeTransition:
	var t := AnimationNodeTransition.new()
	t.xfade_time = xfade
	t.allow_transition_to_self = true
	for n in names:
		t.add_input(n)
	return t

func _build_tree(lib: AnimationLibrary) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var still := "idle" if clips.has("idle") else (_loco[0] if not _loco.is_empty() else String(clips.keys()[0]))
	bt.add_node(&"idle", _anim(still))
	var top := &"idle"
	if not _loco.is_empty():
		# Walk, run and sprint are one-second cycles in step, blended by speed and played
		# at the rate that keeps the feet planted.
		var bs := AnimationNodeBlendSpace1D.new()
		bs.sync = true
		bs.min_space = 0.0
		bs.max_space = maxf(1.0, float(_loco.size() - 1))
		for i in _loco.size():
			bs.add_blend_point(_anim(_loco[i]), float(i))
		bt.add_node(&"loco", bs)
		bt.add_node(&"loco_ts", AnimationNodeTimeScale.new())
		bt.connect_node(&"loco_ts", 0, &"loco")
		var mv := AnimationNodeBlend2.new()
		mv.sync = true
		bt.add_node(&"move", mv)
		bt.connect_node(&"move", 0, &"idle")
		bt.connect_node(&"move", 1, &"loco_ts")
		top = &"move"
	if not _activities.is_empty():
		var act := _picker(_activities, 0.15)
		for i in _activities.size():
			bt.add_node(StringName("a_" + _activities[i]), _anim(_activities[i]))
		bt.add_node(&"act", act)
		for i in _activities.size():
			bt.connect_node(&"act", i, StringName("a_" + _activities[i]))
		bt.add_node(&"act_ts", AnimationNodeTimeScale.new())
		bt.connect_node(&"act_ts", 0, &"act")
		bt.add_node(&"busy", AnimationNodeBlend2.new())
		bt.connect_node(&"busy", 0, top)
		bt.connect_node(&"busy", 1, &"act_ts")
		top = &"busy"
	var upper := UPPER_SHOTS.filter(func(n): return clips.has(n))
	if not upper.is_empty():
		var os := AnimationNodeOneShot.new()
		os.fadein_time = 0.06
		os.fadeout_time = 0.18
		os.filter_enabled = true
		var probe := lib.get_animation(StringName(upper[0]))
		for i in probe.get_track_count():
			var path := probe.track_get_path(i)
			var bone := String(path.get_concatenated_subnames()).split(".")[0]
			if bone in UPPER_BONES:
				os.set_filter_path(path, true)
		bt.add_node(&"upper", os)
		bt.add_node(&"upper_pick", _picker(upper, 0.0))
		for i in upper.size():
			bt.add_node(StringName("u_" + upper[i]), _anim(upper[i]))
			bt.connect_node(&"upper_pick", i, StringName("u_" + upper[i]))
		bt.connect_node(&"upper", 0, top)
		bt.connect_node(&"upper", 1, &"upper_pick")
		top = &"upper"
	var full := FULL_SHOTS.filter(func(n): return clips.has(n))
	if not full.is_empty():
		var os := AnimationNodeOneShot.new()
		os.fadein_time = 0.0
		os.fadeout_time = 0.25
		bt.add_node(&"full", os)
		bt.add_node(&"full_pick", _picker(full, 0.0))
		for i in full.size():
			bt.add_node(StringName("f_" + full[i]), _anim(full[i]))
			bt.connect_node(&"full_pick", i, StringName("f_" + full[i]))
		bt.connect_node(&"full", 0, top)
		bt.connect_node(&"full", 1, &"full_pick")
		top = &"full"
	bt.connect_node(&"output", 0, top)
	return bt

func has_clips() -> bool:
	return tree != null

func has_clip(n: String) -> bool:
	return clips.has(n)

## Seconds a clip lasts at normal speed.
func clip_length(n: String) -> float:
	return float(clips.get(n, {}).get("length", 0.0))

## How fast the character is moving over the ground (m/s): picks and paces the walk,
## run or sprint so the feet keep their grip.
func locomote(speed: float) -> void:
	_speed = maxf(0.0, speed)

## A held, looping or one-time action that takes over the body (hammering, pouring,
## climbing, a creature swelling to burst). "" goes back to moving about.
func activity(n: String, speed: float = 1.0) -> void:
	_act_speed = speed
	if n == "" or not _activities.has(n):
		_busy_want = 0.0
		_activity = ""
		return
	_busy_want = 1.0
	if n != _activity:
		_activity = n
		tree.set("parameters/act/transition_request", n)

func current_activity() -> String:
	return _activity

## Play a one-off clip over whatever else is going on: arm actions on the upper body,
## get-ups and lunges on the whole body.
func shot(n: String) -> void:
	if tree == null or not clips.has(n):
		return
	var which := "upper" if n in UPPER_SHOTS else "full"
	tree.set("parameters/%s_pick/transition_request" % which, n)
	tree.set("parameters/%s/request" % which, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func shot_playing(which: String = "upper") -> bool:
	return tree != null and bool(tree.get("parameters/%s/active" % which))

## A turn (model axes, like pose()) added on top of whatever the clips put a bone in;
## Vector3.ZERO clears it.
func layer(bone: String, euler: Vector3) -> void:
	if euler == Vector3.ZERO:
		_layers.erase(bone)
	elif _rest.has(bone):
		_layers[bone] = euler

func _model_q(bone: String, euler: Vector3) -> Quaternion:
	var g: Quaternion = _rest_global[bone]
	var q_model := Quaternion(Vector3.FORWARD, -euler.z) * Quaternion(Vector3.UP, euler.y) * Quaternion(Vector3.RIGHT, euler.x)
	return g.inverse() * q_model * g

func _run_clips(delta: float) -> void:
	var s := global_basis.get_scale().x
	var v := _speed / maxf(s, 0.01)
	var want_blend := 0.0
	var rate := 1.0
	var move := 0.0
	if not _loco.is_empty():
		var sp: Array[float] = []
		var per: Array[float] = []
		for n in _loco:
			sp.append(maxf(0.05, float(clips[n].get("speed", 1.0))))
			per.append(maxf(0.1, float(clips[n].get("period", 1.0))))
		move = clampf(v / (sp[0] * 0.5), 0.0, 1.0)
		if v <= sp[0] or _loco.size() == 1:
			want_blend = 0.0
			rate = maxf(v / sp[0], 0.45) / per[0]
		else:
			var i := 0
			while i < _loco.size() - 2 and v > sp[i + 1]:
				i += 1
			var f := clampf((v - sp[i]) / maxf(sp[i + 1] - sp[i], 0.01), 0.0, 1.0)
			if v > sp[sp.size() - 1]:
				i = sp.size() - 2
				f = 1.0
			want_blend = float(i) + f
			var natural := lerpf(sp[i], sp[i + 1], f)
			rate = (v / natural) / lerpf(per[i], per[i + 1], f)
		_blend = move_toward(_blend, want_blend, delta * 3.0)
		_move = move_toward(_move, move, delta * 5.0)
		tree.set("parameters/loco/blend_position", _blend)
		tree.set("parameters/loco_ts/scale", rate)
		tree.set("parameters/move/blend_amount", _move)
	if not _activities.is_empty():
		_busy = move_toward(_busy, _busy_want, delta * 6.0)
		tree.set("parameters/busy/blend_amount", _busy)
		tree.set("parameters/act_ts/scale", _act_speed)
	tree.advance(delta)
	for bone in _layers:
		var i := skeleton.find_bone(bone)
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * _model_q(bone, _layers[bone]))

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

## Hold a node at a point given in this rig's space (a marker), following a bone.
func attach_at(bone: String, node: Node3D, rig_point: Vector3) -> BoneAttachment3D:
	var i := skeleton.find_bone(bone)
	var to_skel := global_transform.affine_inverse() * skeleton.global_transform
	var bone_rig := to_skel * skeleton.get_bone_global_rest(i)
	return attach_aligned(bone, node, rig_point - bone_rig.origin)

## How fast the ragdoll's hips are moving (settled when small).
func ragdoll_speed() -> float:
	var b: PhysicalBone3D = _bodies.get("hips")
	return b.linear_velocity.length() if b else 0.0

func _physics_process(delta: float) -> void:
	if tree != null:
		_run_clips(delta)
	if not _ragdoll:
		return
	for b in _bodies.values():
		var pb := b as PhysicalBone3D
		if pb.linear_velocity.length() > MAX_SPEED:
			pb.linear_velocity = pb.linear_velocity.normalized() * MAX_SPEED
		if pb.angular_velocity.length() > MAX_SPIN:
			pb.angular_velocity = pb.angular_velocity.normalized() * MAX_SPIN

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

## Lying face up (on its back) or face down, from which way the chest faces.
func ragdoll_face_up() -> bool:
	var b: PhysicalBone3D = _bodies.get("chest", _bodies.get("hips"))
	if b == null or not _rest_global.has(String(b.bone_name)):
		return true
	var g: Quaternion = _rest_global[String(b.bone_name)]
	var fwd: Vector3 = b.global_basis.orthonormalized() * (Basis(g).inverse() * Vector3(0.0, 0.0, 1.0))
	return fwd.y > 0.0

## How to get up from where the ragdoll lies, with a get-up clip: which clip (off its
## back or its front), which way to face, and where to stand the owner so the clip's
## first frame lies where the body does. Empty when there's no clip for it.
func getup_plan() -> Dictionary:
	if not _ragdoll:
		return {}
	var up := ragdoll_face_up()
	var clip := "getup_back" if up else "getup_front"
	if not clips.has(clip):
		return {}
	var hips := bone_position("hips")
	var head := bone_position("head")
	# Off its back it ends facing its feet; off its front, where its head was.
	var d := (hips - head) if up else (head - hips)
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var off: Array = clips[clip].get("hips", [0.0, 0.0, 0.0])
	var s := global_basis.get_scale().x
	var right := d.cross(Vector3.UP)
	var root := hips - right * float(off[0]) * s + d * float(off[2]) * s
	return {"clip": clip, "facing": d, "root": Vector3(root.x, hips.y, root.z)}

## Blend from the ragdoll back into the animated pose. Move the owner to
## ragdoll_centre() first: the limp body stays put in the world while it blends.
## With a get-up clip (from getup_plan(); place the owner as it says first) the body
## blends into the clip's first frames and gets up with it.
func get_up(time: float = GET_UP_TIME, clip: String = "") -> void:
	if not _ragdoll or _getting_up:
		return
	_getting_up = true
	var tw := create_tween()
	if clip != "" and clips.has(clip) and tree != null:
		shot(clip)
		tw.tween_property(_sim, "influence", 0.0, RAG_TO_CLIP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.0, clip_length(clip) - RAG_TO_CLIP - 0.2))
	else:
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
		cap.radius = float(spec[0]) * thickness * 0.85
		cap.height = maxf(length + cap.radius * 0.5, cap.radius * 2.05)
		col.shape = cap
		pb.add_child(col)
		pb.mass = mass * (1.6 if bn in ["hips", "chest", "spine"] else 0.6)
		pb.collision_layer = RAGDOLL_LAYER
		pb.collision_mask = 1 | 4
		pb.friction = 0.9
		pb.linear_damp = 0.4
		pb.angular_damp = 2.5
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
