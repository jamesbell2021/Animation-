class_name Player
extends CharacterBody3D

const SPEED := 4.5
const SPRINT := 6.5
const SPRINT_MAX := 3.0
const SPRINT_COOLDOWN := 2.0
const ATTACK_RANGE := 2.5
const ATTACK_DMG := 20
const ATTACK_CD := 0.6
const ATTACK_ARC_DEG := 60.0
const SWING_TIME := 0.2
const INTERACT_RANGE := 2.2
# The boathook and interactions only reach things on roughly the keeper's own level,
# so nothing is struck or repaired through the crag's walls.
const REACH_HEIGHT := 1.5
const OPERATE_RANGE := 3.8
# Working the lamp: the keeper walks up to the door and goes in; leaving, steps back out.
const DOOR_STEP := 2.5
const DOOR_IN := 1.4
const DOOR_OUT := 3.1
const DOOR_WALK_SPEED := 3.2
# Repairs are a few hammer blows; refuelling is a pour from the oil can.
const STRIKE_TIME := 0.34
const STRIKES := 3
const POUR_TIME := 0.9
# Knocked flat (the Eel's surge) and shoved (the Crab's slam).
const PUSH_DECAY := 10.0
const FALL_SPEED := -5.0
const BODY_COLOR := Color(0.85, 0.65, 0.2)
const MODEL_DIR := "res://art/characters/%s.glb"
const BASE_HP := 100
# The flare gun: two shots, reloaded at the cottage.
const FLARES_MAX := 2
const FLARE_RANGE := 14.0
const FLARE_PAD_DIST := 10.0
const REVIVE_RANGE := 1.5
const REVIVE_HP := 0.4
const DAWN_HP := 0.5
const LANTERN_COLOR := Color(1.0, 0.68, 0.32)
const HOOK_PATH := "res://art/props/boat_hook.glb"
# The keeper GLBs are 2.05 m tall; scaled so the keeper stands about 1.75 m.
const MODEL_SCALE := 0.85
const TURN_SPEED := 12.0
const AIM_FACE_TIME := 0.45
const STRIDE := 2.4
const LEG_SWING := 0.65
const ARM_SWING := 0.5
const STEP_EVERY := 0.42
# Rig joints in the GLB's own (Z-up) coordinates. The file's -X side is the keeper's right.
const RIG := {
	"leg_r": [["trouser_leg", "boot", "boot_sole"], Vector3(-0.155, 0.0, 0.74)],
	"leg_l": [["trouser_leg_1", "boot_1", "boot_sole_1"], Vector3(0.155, 0.0, 0.74)],
	"arm_r": [["upper_sleeve", "forearm", "hand"], Vector3(-0.38, 0.0, 1.4)],
	"arm_l": [["upper_sleeve_1", "forearm_1", "hand_1"], Vector3(0.38, 0.0, 1.4)],
}

var idx := 0
var downed := false
var revive_progress := 0.0
var hp := 100
var max_hp := 100
var camera: Camera3D
var lamp: Lamp
var operating := false

var _aim := Vector3(0.0, 0.0, -1.0)
var _attack_cd := 0.0
var _sprint_t := 0.0
var _sprint_cd := 0.0
var _swing_t := 0.0
var _hook_pivot: Node3D
var _target: Node = null
var _model: Node3D
var _joints := {}
var _walk_phase := 0.0
var _move_amount := 0.0
var _aim_face_t := 0.0
var _step_t := 0.0
var _breath := 0.0
var facing := 0.0
var _pose: Node3D
var _lantern_light: OmniLight3D
var _lantern_glass: StandardMaterial3D
var _ring: MeshInstance3D
var _tag: Label3D
var _flicker := 0.0
# Climbing a ladder: carried from one end to the other, no control meanwhile.
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _climb_t := -1.0
var _climb_len := 1.0
# Where the mouse cursor meets the ground or the sea, while working the lamp.
var _lamp_point := Vector3.INF
# Walking in or out of the lighthouse door, or busy with a tool: no control meanwhile.
var _scripted := false
var _inside := false
var _walking_in := false
var _walk_tween: Tween
var _hook_holder: Node3D
var _hammer: Node3D
var _can: Node3D
var _job_tool := ""
var _job_t := 0.0
var _job_len := 0.0
var _job_target: Node
var _job_strikes := 0
var _prone_t := 0.0
var _push := Vector3.ZERO
# What the finished job calls on its target: "interact", or "use_dirty" at the lighthouse.
var _job_action := "interact"
## In a menu (the cottage, a trap slot): stands still, takes no other input.
var in_menu := false

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	# Faceted ground: let the keeper step over small rises. Terrain.walkable keeps them off cliffs.
	floor_max_angle = deg_to_rad(60.0)
	_pose = Node3D.new()
	_pose.name = "Pose"
	add_child(_pose)
	_hook_pivot = Node3D.new()
	_hook_pivot.position = Vector3(0.4, 0.9, 0.0)
	_pose.add_child(_hook_pivot)
	_hook_holder = Node3D.new()
	_hook_pivot.add_child(_hook_holder)
	_build_tools()
	if not _build_model():
		Geo.cyl(_pose, 0.35, 1.2, BODY_COLOR, Vector3(0.0, 0.6, 0.0))
		Geo.cyl(_pose, 0.22, 0.32, Color(0.9, 0.75, 0.62), Vector3(0.0, 1.38, 0.0))
		Geo.cyl(_pose, 0.25, 0.1, Color(0.15, 0.18, 0.3), Vector3(0.0, 1.57, 0.0))
	_build_lantern()
	_build_marker()
	Cycle.phase_changed.connect(_on_phase_changed)
	_set_lantern(Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT)
	if not _build_hook():
		Geo.box(_hook_holder, Vector3(0.06, 0.06, 1.6), Color(0.18, 0.15, 0.12), Vector3(0.0, 0.0, -0.6))
		Geo.box(_hook_holder, Vector3(0.06, 0.25, 0.06), Color(0.3, 0.3, 0.32), Vector3(0.0, -0.1, -1.4))
	Geo.cyl_shape(self, 0.35, 1.6, Vector3(0.0, 0.8, 0.0))

# Loads a Z-up, vertex-coloured GLB from art/ and stands it upright. Returns null if
# the file is missing or not imported yet, so the primitive fallback is used.
static func load_art(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		return null
	var mat := Look.vertex_mat(0.9)
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			n.material_override = mat
		stack.append_array(n.get_children())
	return node

func _build_model() -> bool:
	var m := load_art(MODEL_DIR % Players.MODELS[idx % Players.MODELS.size()])
	if m == null:
		return false
	var holder := Node3D.new()
	holder.name = "Model"
	# Z-up to Y-up, then turn the model's front (-Y in the file) to face -Z, Godot's forward.
	holder.rotation = Vector3(deg_to_rad(-90.0), PI, 0.0)
	holder.scale = Vector3.ONE * MODEL_SCALE
	holder.add_child(m)
	_pose.add_child(holder)
	_model = holder
	_rig(m)
	return true

func _find_part(root: Node, part: String) -> Node3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var nm := String(n.name)
		if nm.ends_with("_" + part) and n is Node3D:
			# "trouser_leg" must not match "trouser_leg_1".
			var stem := nm.substr(0, nm.length() - part.length() - 1)
			if not stem.ends_with("_") and stem.find("_") == -1:
				return n
		stack.append_array(n.get_children())
	return null

# Parent each limb's parts under a pivot at its joint so they can swing.
func _rig(model_root: Node3D) -> void:
	for key in RIG:
		var parts: Array = RIG[key][0]
		var joint: Vector3 = RIG[key][1]
		var pivot := Node3D.new()
		pivot.name = key
		pivot.position = joint
		var found := 0
		for p in parts:
			var node := _find_part(model_root, p)
			if node == null:
				continue
			var parent := node.get_parent()
			if found == 0:
				parent.add_child(pivot)
			var xf := node.transform
			parent.remove_child(node)
			pivot.add_child(node)
			node.transform = Transform3D(xf.basis, xf.origin - joint)
			found += 1
		if found > 0:
			_joints[key] = pivot
		else:
			pivot.queue_free()

func _build_hook() -> bool:
	var h := load_art(HOOK_PATH)
	if h == null:
		return false
	# The hook's shaft runs along +Z in the file; point it forward along -Z.
	h.rotation.y = PI
	h.position = Vector3(0.0, 0.0, 0.45)
	h.scale = Vector3.ONE * 1.25
	_hook_holder.add_child(h)
	return true

# A claw hammer for repairs and an oil can for the lamp, carried in place of the boathook.
func _build_tools() -> void:
	var wood := Look.flat_mat(Color(0.45, 0.33, 0.2), 0.8)
	var iron := Look.flat_mat(Color(0.22, 0.22, 0.24), 0.4)
	# Drawn larger than life so the tool reads from the camera, like the boathook.
	_hammer = Node3D.new()
	_hammer.scale = Vector3.ONE * 1.7
	_hook_pivot.add_child(_hammer)
	var handle := Geo.box(_hammer, Vector3(0.045, 0.045, 0.46), Color.WHITE, Vector3(0.0, 0.0, -0.22))
	handle.material_override = wood
	var head := Geo.box(_hammer, Vector3(0.08, 0.22, 0.08), Color.WHITE, Vector3(0.0, -0.03, -0.44))
	head.material_override = iron
	_hammer.visible = false
	_can = Node3D.new()
	_can.scale = Vector3.ONE * 1.6
	_hook_pivot.add_child(_can)
	var body := Geo.box(_can, Vector3(0.2, 0.26, 0.13), Color.WHITE, Vector3(0.0, -0.08, -0.28))
	body.material_override = Look.flat_mat(Color(0.55, 0.16, 0.12), 0.5)
	var spout := Geo.cyl(_can, 0.02, 0.24, Color.WHITE, Vector3(0.0, 0.08, -0.42))
	spout.material_override = iron
	spout.rotation.x = deg_to_rad(-55.0)
	_can.visible = false

# A paraffin lantern carried in the left hand: lights the keeper's way at night.
func _build_lantern() -> void:
	var holder: Node3D = _joints.get("arm_l")
	var lantern := Node3D.new()
	lantern.name = "Lantern"
	if holder != null:
		# In the GLB's Z-up space, hanging below the left hand.
		holder.add_child(lantern)
		lantern.position = Vector3(0.04, -0.06, -0.86)
		lantern.rotation.x = deg_to_rad(90.0)
		lantern.scale = Vector3.ONE / MODEL_SCALE * 0.85
	else:
		_pose.add_child(lantern)
		lantern.position = Vector3(-0.42, 0.75, -0.1)
	var iron := Look.flat_mat(Color(0.12, 0.12, 0.13), 0.5)
	_lantern_glass = Look.glow_mat(Color(0.25, 0.2, 0.15), 0.0)
	var glass := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.07
	gm.bottom_radius = 0.07
	gm.height = 0.16
	gm.radial_segments = 6
	glass.mesh = gm
	glass.material_override = _lantern_glass
	lantern.add_child(glass)
	var cap := Geo.cyl(lantern, 0.09, 0.05, Color.WHITE, Vector3(0.0, 0.11, 0.0), 0.04)
	cap.material_override = iron
	var base := Geo.cyl(lantern, 0.09, 0.04, Color.WHITE, Vector3(0.0, -0.1, 0.0))
	base.material_override = iron
	var handle := Geo.box(lantern, Vector3(0.02, 0.1, 0.02), Color.WHITE, Vector3(0.0, 0.18, 0.0))
	handle.material_override = iron
	for c in [glass, cap, base, handle]:
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = LANTERN_COLOR
	_lantern_light.omni_range = 6.5
	_lantern_light.omni_attenuation = 1.4
	_lantern_light.light_volumetric_fog_energy = 0.6
	lantern.add_child(_lantern_light)

func _set_lantern(lit: bool) -> void:
	_lantern_light.visible = lit
	_lantern_glass.albedo_color = LANTERN_COLOR if lit else Color(0.25, 0.2, 0.15)
	_lantern_glass.emission = LANTERN_COLOR
	_lantern_glass.emission_energy_multiplier = 2.5 if lit else 0.0

func _on_phase_changed(p: int) -> void:
	_set_lantern(p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT)
	# Morning: the lamp is out, so the keeper comes down and out to start the day.
	if p == Cycle.Phase.DAWN and _inside:
		_toggle_operate()
	if p == Cycle.Phase.DAWN and downed:
		revive(DAWN_HP)

# Coloured ring and name tag, shown when more than one keeper is playing.
func _build_marker() -> void:
	var col: Color = Players.COLORS[idx % Players.COLORS.size()]
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.5
	t.rings = 18
	t.ring_segments = 4
	_ring.mesh = t
	var m := Look.glow_mat(col, 1.2)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = m
	_ring.position.y = 0.06
	_ring.scale = Vector3(1.0, 0.3, 1.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0011
	_tag.font_size = 26
	var tag_font := Fonts.title()
	if tag_font:
		_tag.font = tag_font
	_tag.outline_size = 8
	_tag.modulate = col
	_tag.position.y = 2.25
	add_child(_tag)
	var multi := Players.count() > 1 or Players.wanted > 1
	_ring.visible = multi
	_tag.visible = multi

func keeper_name() -> String:
	return Players.NAMES[idx % Players.NAMES.size()]

func _act(a: String) -> String:
	return Players.action(idx, a)

func aim_yaw() -> float:
	return atan2(-_aim.x, -_aim.z)

func aim_dir() -> Vector3:
	return _aim

func _physics_process(delta: float) -> void:
	if not Run.active:
		return
	_update_tag()
	_flicker += delta
	if _lantern_light.visible:
		_lantern_light.light_energy = 1.5 + 0.12 * sin(_flicker * 11.0) * sin(_flicker * 7.3)
	if downed:
		velocity = Vector3(0.0, 0.0 if is_on_floor() else FALL_SPEED, 0.0)
		move_and_slide()
		return
	if _climb_t >= 0.0:
		_climbing(delta)
		return
	if _prone_t > 0.0:
		_lying(delta)
		return
	if in_menu:
		velocity = Vector3.ZERO
		_animate(delta)
		return
	if _scripted:
		if _job_tool != "":
			_work(delta)
		_animate(delta)
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_aim_face_t = maxf(0.0, _aim_face_t - delta)
	_update_aim()
	_update_swing(delta)
	if Input.is_action_just_pressed(_act("operate")):
		_toggle_operate()
	if _inside:
		# Up in the lamp room: aim and switch the beam; nothing else reaches in here.
		if operating and Input.is_action_just_pressed(_act("beam_mode")) and lamp:
			lamp.toggle_mode()
		return
	if operating:
		velocity.x = 0.0
		velocity.z = 0.0
		if Input.is_action_just_pressed(_act("beam_mode")) and lamp:
			lamp.toggle_mode()
	else:
		_move(delta)
		if Input.is_action_just_pressed(_act("attack")) and _attack_cd <= 0.0:
			_attack()
		if Input.is_action_just_pressed(_act("flare")):
			_fire_flare()
		if Input.is_action_just_pressed(_act("use_dirty")):
			_pour_dirty()
	velocity.y = 0.0 if is_on_floor() else FALL_SPEED
	velocity.x += _push.x
	velocity.z += _push.z
	_push = _push.move_toward(Vector3.ZERO, PUSH_DECAY * delta)
	var before := global_position
	move_and_slide()
	_clamp_to_island(before)
	_update_facing(delta)
	_animate(delta)
	var mate := _downed_mate()
	if mate != null and Input.is_action_pressed(_act("interact")):
		mate.revive_progress += delta / float(Upgrades.pick("garden", Upgrades.REVIVE_TIME))
		if mate.revive_progress >= 1.0:
			mate.revive(REVIVE_HP)
		return
	_target = _find_interactable()
	if Input.is_action_just_pressed(_act("interact")) and _target != null:
		var tool: String = _target.work_kind() if _target.has_method("work_kind") else ""
		if tool != "":
			_start_job(tool, _target)
		else:
			_target.interact(self)

# Face where the keeper walks; face the cursor while swinging or working the lamp.
func _update_facing(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z)
	var want := facing
	if operating or _aim_face_t > 0.0:
		want = aim_yaw()
	elif flat.length() > 0.3:
		want = atan2(-flat.x, -flat.y)
	facing = lerp_angle(facing, want, 1.0 - exp(-delta * TURN_SPEED))
	rotation.y = facing

func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_move_amount = move_toward(_move_amount, clampf(speed / SPEED, 0.0, 1.4), delta * 6.0)
	_walk_phase += delta * speed * STRIDE
	_breath += delta
	var swing := sin(_walk_phase) * _move_amount
	if _joints.has("leg_r"):
		_joints["leg_r"].rotation.x = swing * LEG_SWING
	if _joints.has("leg_l"):
		_joints["leg_l"].rotation.x = -swing * LEG_SWING
	if _joints.has("arm_l"):
		_joints["arm_l"].rotation.x = -swing * ARM_SWING
	if _joints.has("arm_r"):
		var arm := swing * ARM_SWING
		if _swing_t > 0.0:
			# Raise the hook arm and chop down through the swing.
			var k := 1.0 - _swing_t / SWING_TIME
			arm = lerpf(-1.9, 0.4, k)
		if _job_tool == "hammer":
			# Lift slowly, then bring the hammer down hard.
			var ph := fmod(_job_t, STRIKE_TIME) / STRIKE_TIME
			arm = lerpf(0.2, -1.6, ph / 0.65) if ph < 0.65 else lerpf(-1.6, 0.35, (ph - 0.65) / 0.35)
		elif _job_tool == "can":
			arm = -1.0
		_joints["arm_r"].rotation.x = arm
		_hook_pivot.rotation.x = -arm * 0.6
		if _job_tool == "can":
			_hook_pivot.rotation.z = lerpf(0.0, 1.1, smoothstep(0.0, 0.3, _job_t / maxf(_job_len, 0.01)))
		else:
			_hook_pivot.rotation.z = 0.0
	if _model:
		var bob := absf(sin(_walk_phase)) * 0.06 * _move_amount + sin(_breath * 2.0) * 0.008
		_model.position.y = bob
	if speed > 0.5 and is_on_floor():
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = STEP_EVERY * SPEED / maxf(speed, 1.0)
			Audio.sfx("step", global_position)
	else:
		_step_t = 0.0

func _update_aim() -> void:
	if idx > 0 or Players.devices.size() > idx and Players.devices[idx] != Players.KEYBOARD_MOUSE:
		# Gamepad: right stick aims; otherwise aim where the keeper is walking.
		if InputMap.has_action(_act("aim_left")):
			var stick := Input.get_vector(_act("aim_left"), _act("aim_right"), _act("aim_up"), _act("aim_down"))
			if stick.length() > 0.35:
				_aim = Vector3(stick.x, 0.0, stick.y).normalized()
				_aim_face_t = maxf(_aim_face_t, 0.15)
				return
		var flat := Vector2(velocity.x, velocity.z)
		if flat.length() > 0.3:
			_aim = Vector3(flat.x, 0.0, flat.y).normalized()
		return
	_lamp_point = Vector3.INF
	if camera == null:
		return
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return
	if operating:
		_lamp_point = _ground_hit(from, dir)
	var t := (global_position.y - from.y) / dir.y
	if t <= 0.0:
		return
	var d := from + dir * t - global_position
	d.y = 0.0
	if d.length() > 0.05:
		_aim = d.normalized()

## The point the beam should light: under the mouse when one is aiming, otherwise INF.
func lamp_target() -> Vector3:
	return _lamp_point

# March the cursor ray down to the island or the sea. From the crag top the beaches are
# far below the keeper, so a plane at the keeper's height would swing the beam well off.
static func _ground_hit(from: Vector3, dir: Vector3) -> Vector3:
	if dir.y >= 0.0:
		return Vector3.INF
	var t := maxf(0.0, (Terrain.CRAG_TOP + 1.0 - from.y) / dir.y)
	var t_end := (Terrain.SEA_LEVEL - from.y) / dir.y
	var prev := t
	while t <= t_end:
		var p := from + dir * t
		if p.y <= maxf(Terrain.height_at(p.x, p.z), Terrain.SEA_LEVEL):
			# Refine between the last point above ground and this one.
			for i in 6:
				var mid := (prev + t) * 0.5
				var q := from + dir * mid
				if q.y <= maxf(Terrain.height_at(q.x, q.z), Terrain.SEA_LEVEL):
					t = mid
				else:
					prev = mid
			return from + dir * t
		prev = t
		t += 0.5
	return from + dir * t_end

func _move(delta: float) -> void:
	var input := Input.get_vector(_act("move_left"), _act("move_right"), _act("move_up"), _act("move_down"))
	var dir := Vector3(input.x, 0.0, input.y)
	var spd := SPEED
	if _sprint_cd > 0.0:
		_sprint_cd = maxf(0.0, _sprint_cd - delta)
	if Input.is_action_pressed(_act("sprint")) and dir != Vector3.ZERO and _sprint_cd <= 0.0:
		spd = SPRINT
		_sprint_t += delta
		if _sprint_t >= SPRINT_MAX:
			_sprint_t = 0.0
			_sprint_cd = SPRINT_COOLDOWN
	else:
		_sprint_t = maxf(0.0, _sprint_t - delta)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd

# Keepers don't wade into the sea or step off a cliff or the ledge. If a move would,
# keep whichever half of it is safe so they slide along the edge instead of sticking.
func _clamp_to_island(before: Vector3) -> void:
	var p := global_position
	if Terrain.walkable(p.x, p.z) or not Terrain.walkable(before.x, before.z):
		return
	if Terrain.walkable(p.x, before.z):
		global_position.z = before.z
	elif Terrain.walkable(before.x, p.z):
		global_position.x = before.x
	else:
		global_position.x = before.x
		global_position.z = before.z

func _attack() -> void:
	_attack_cd = ATTACK_CD
	_swing_t = SWING_TIME
	_aim_face_t = AIM_FACE_TIME
	facing = aim_yaw()
	rotation.y = facing
	Audio.sfx("swing", global_position)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("take_damage"):
			continue
		var to: Vector3 = e.global_position - global_position
		if absf(to.y) > REACH_HEIGHT:
			continue
		to.y = 0.0
		var d := to.length()
		if d > ATTACK_RANGE:
			continue
		var dir_to := _aim if d < 0.01 else to / d
		if rad_to_deg(_aim.angle_to(dir_to)) > ATTACK_ARC_DEG:
			continue
		e.take_damage(ATTACK_DMG, dir_to, self)
	# At the tower's foot, a blow on the stone shakes anything clinging up there.
	if _at_tower_foot():
		var shook := false
		for s in get_tree().get_nodes_in_group("smotherers"):
			if s.is_on_tower():
				s.shake(self)
				shook = true
		if shook:
			Audio.sfx("hammer", global_position, 0.0, 0.2)

func _at_tower_foot() -> bool:
	if lamp == null or lamp.lighthouse == null:
		return false
	var lh: Structure = lamp.lighthouse
	return absf(lh.global_position.y - global_position.y) < REACH_HEIGHT and lh.surface_distance(global_position) < Smotherer.SHAKE_REACH

func _climber_on_tower() -> bool:
	for s in get_tree().get_nodes_in_group("smotherers"):
		if s.is_on_tower():
			return true
	return false

## Climb from where the keeper stands to `to` over `time` seconds (ladders).
func climb(to: Vector3, time: float) -> void:
	if operating:
		_toggle_operate()
	_climb_from = global_position
	_climb_to = to
	_climb_len = time
	_climb_t = 0.0
	velocity = Vector3.ZERO
	Audio.sfx("creak", global_position, -4.0, 0.1)

func is_climbing() -> bool:
	return _climb_t >= 0.0

func _climbing(delta: float) -> void:
	_climb_t += delta
	var k := clampf(_climb_t / _climb_len, 0.0, 1.0)
	# Up or down the rungs first, then step off.
	var up := _climb_to.y > _climb_from.y
	var kv := smoothstep(0.0, 0.8, k) if up else smoothstep(0.2, 1.0, k)
	var kh := smoothstep(0.6, 1.0, k) if up else smoothstep(0.0, 0.4, k)
	global_position = Vector3(lerpf(_climb_from.x, _climb_to.x, kh), lerpf(_climb_from.y, _climb_to.y, kv), lerpf(_climb_from.z, _climb_to.z, kh))
	_animate(delta)
	if k >= 1.0:
		_climb_t = -1.0

func _update_swing(delta: float) -> void:
	if _swing_t > 0.0:
		_swing_t = maxf(0.0, _swing_t - delta)
		var k := 1.0 - _swing_t / SWING_TIME
		_hook_pivot.rotation.y = lerpf(deg_to_rad(70.0), deg_to_rad(-70.0), k)
	else:
		_hook_pivot.rotation.y = 0.0

func _toggle_operate() -> void:
	if lamp == null:
		return
	if operating:
		_stop_operating()
		if _inside or _walking_in:
			_come_out()
		return
	if Geo.flat_dist(global_position, lamp.lighthouse.global_position) > OPERATE_RANGE:
		Events.message.emit("Get closer to the lighthouse to operate the lamp.")
		return
	if lamp.operator != null and lamp.operator != self and is_instance_valid(lamp.operator):
		Events.message.emit("Someone is already on the lamp.")
		return
	operating = true
	lamp.set_operator(self)
	_go_in()
	if lamp.is_lit():
		Events.message.emit("On the lamp.  Mouse aims, [Q] beam, [R] leave")
	else:
		Events.message.emit("The lamp is lit at dusk.  [R] leave")

func _stop_operating() -> void:
	operating = false
	if lamp and lamp.operator == self:
		lamp.set_operator(null)

## True while the keeper is up in the lamp room: hidden, untouchable.
func is_inside() -> bool:
	return _inside

func _door_point(r: float) -> Vector3:
	var lh := lamp.lighthouse
	# The door faces +Z, toward the camera.
	return Vector3(lh.global_position.x, global_position.y, lh.global_position.z + r)

func _kill_walk() -> void:
	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()

func _walk_along(k: float, a: Vector3, b: Vector3) -> void:
	global_position = a.lerp(b, k)
	var d := b - a
	d.y = 0.0
	velocity = d.normalized() * DOOR_WALK_SPEED if d.length() > 0.01 else Vector3.ZERO
	if d.length() > 0.01:
		facing = atan2(-d.x, -d.z)
		rotation.y = facing

# Up to the door, then through it.
func _go_in() -> void:
	_kill_walk()
	_scripted = true
	_walking_in = true
	collision_layer = 0
	collision_mask = 0
	var step := _door_point(DOOR_STEP)
	var inside := _door_point(DOOR_IN)
	_walk_tween = create_tween()
	var d := Geo.flat_dist(global_position, step)
	if d > 0.05:
		_walk_tween.tween_method(_walk_along.bind(global_position, step), 0.0, 1.0, d / DOOR_WALK_SPEED)
	_walk_tween.tween_method(_walk_along.bind(step, inside), 0.0, 1.0, (DOOR_STEP - DOOR_IN) / DOOR_WALK_SPEED)
	_walk_tween.tween_callback(_set_inside.bind(true))

func _set_inside(v: bool) -> void:
	_inside = v
	_walking_in = false
	visible = not v
	velocity = Vector3.ZERO
	if v:
		_scripted = false
		Audio.sfx("creak", global_position, -6.0, 0.1)

# Out of the door and a few steps clear of it (or, if still on the way in, turn round).
func _come_out() -> void:
	_kill_walk()
	var from := _door_point(DOOR_IN) if _inside else global_position
	if _inside:
		Audio.sfx("creak", from, -6.0, 0.1)
	_set_inside(false)
	_scripted = true
	var out := _door_point(DOOR_OUT)
	global_position = from
	_walk_tween = create_tween()
	_walk_tween.tween_method(_walk_along.bind(from, out), 0.0, 1.0, maxf(0.1, Geo.flat_dist(from, out) / DOOR_WALK_SPEED))
	_walk_tween.tween_callback(_out_of_door)

func _out_of_door() -> void:
	_scripted = false
	velocity = Vector3.ZERO
	collision_layer = 2
	collision_mask = 1 | 4 | 8

# ---- tools: hammer for repairs, oil can for the lamp ----

func _start_job(tool: String, target: Node, action: String = "interact") -> void:
	_scripted = true
	_job_action = action
	_job_tool = tool
	_job_target = target
	_job_t = 0.0
	_job_strikes = 0
	_job_len = STRIKE_TIME * STRIKES if tool == "hammer" else POUR_TIME
	velocity = Vector3.ZERO
	_hook_holder.visible = false
	_hammer.visible = tool == "hammer"
	_can.visible = tool == "can"
	var d: Vector3 = (target as Node3D).global_position - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		facing = atan2(-d.x, -d.z)
		rotation.y = facing
	if tool == "can":
		Audio.sfx("refuel", global_position, -2.0)

func _work(delta: float) -> void:
	_job_t += delta
	if _job_target == null or not is_instance_valid(_job_target):
		_end_job(false)
		return
	if _job_tool == "hammer":
		# Each blow lands at the bottom of the swing.
		var landed := int((_job_t + STRIKE_TIME * 0.35) / STRIKE_TIME)
		if landed > _job_strikes and _job_strikes < STRIKES:
			_job_strikes = landed
			var fwd := Vector3(-sin(facing), 0.0, -cos(facing))
			var at := global_position + fwd * 0.9 + Vector3(0.0, 0.5, 0.0)
			Audio.sfx("hammer", at, -1.0, 0.12)
			FX.splinters(get_parent(), at)
	if _job_t >= _job_len:
		_end_job(true)

func _end_job(done: bool) -> void:
	var target := _job_target
	_job_tool = ""
	_job_target = null
	_hammer.visible = false
	_can.visible = false
	_hook_holder.visible = true
	_hook_pivot.rotation.z = 0.0
	_scripted = false
	# The work is done: now the stock is spent and the repair or the oil goes in.
	if done and target != null and is_instance_valid(target):
		target.call(_job_action, self)

# ---- flare gun and dirty fuel ----

func flares() -> int:
	return int(Run.flares[idx]) if idx < Run.flares.size() else 0

## Where a flare would land: under the mouse, or ahead along the aim on a pad.
func flare_point() -> Vector3:
	var to := Vector3.INF
	if camera != null and idx == 0 and (Players.devices.size() <= idx or Players.devices[idx] == Players.KEYBOARD_MOUSE):
		var mp := get_viewport().get_mouse_position()
		to = _ground_hit(camera.project_ray_origin(mp), camera.project_ray_normal(mp))
	if to == Vector3.INF:
		to = global_position + _aim * FLARE_PAD_DIST
	var d := to - global_position
	d.y = 0.0
	if d.length() > FLARE_RANGE:
		to = global_position + d.normalized() * FLARE_RANGE
	to.y = maxf(Terrain.height_at(to.x, to.z), Terrain.SEA_LEVEL)
	return to

func _fire_flare() -> void:
	if flares() <= 0:
		Events.message.emit("No flares left: load them at the cottage (1 scrap each).")
		return
	var to := flare_point()
	Run.flares[idx] = flares() - 1
	var d := to - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		_aim = Vector3(d.x, 0.0, d.z).normalized()
		facing = aim_yaw()
		rotation.y = facing
	_aim_face_t = AIM_FACE_TIME
	var f := Flare.new()
	f.from = global_position + Vector3(0.0, 1.4, 0.0) + _aim * 0.4
	f.to = to
	get_parent().add_child(f)

func _pour_dirty() -> void:
	if lamp == null or lamp.lighthouse == null:
		return
	var lh: Structure = lamp.lighthouse
	if absf(lh.global_position.y - global_position.y) > REACH_HEIGHT or lh.surface_distance(global_position) > INTERACT_RANGE:
		return
	if Stock.get_amount("dirty_fuel") <= 0:
		Events.message.emit("No dirty fuel: mix oil and driftwood at the cottage.")
		return
	_start_job("can", lh, "use_dirty")

func is_busy() -> bool:
	return _scripted

# ---- knocked about ----

## Knocked flat for t seconds: can't move or act.
func knock_prone(t: float) -> void:
	if _inside or downed or hp <= 0:
		return
	if _job_tool != "":
		_end_job(false)
	_prone_t = t
	_kill_walk()
	_scripted = false
	var tw := create_tween()
	tw.tween_property(_pose, "rotation:x", deg_to_rad(-80.0), 0.2)
	tw.parallel().tween_property(_pose, "position:y", 0.25, 0.2)

func _lying(delta: float) -> void:
	_prone_t -= delta
	velocity = Vector3(_push.x, 0.0 if is_on_floor() else FALL_SPEED, _push.z)
	_push = _push.move_toward(Vector3.ZERO, PUSH_DECAY * delta)
	var before := global_position
	move_and_slide()
	_clamp_to_island(before)
	if _prone_t <= 0.0:
		_prone_t = 0.0
		var tw := create_tween()
		tw.tween_property(_pose, "rotation:x", 0.0, 0.3)
		tw.parallel().tween_property(_pose, "position:y", 0.0, 0.3)

func is_prone() -> bool:
	return _prone_t > 0.0

## A shove along v (m/s), fading quickly: the Crab's slam.
func shove(v: Vector3) -> void:
	if _inside:
		return
	_push = Vector3(v.x, 0.0, v.z)

func _find_interactable() -> Node:
	var best: Node = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D) or not n.has_method("interact_prompt"):
			continue
		if absf(n.global_position.y - global_position.y) > REACH_HEIGHT:
			continue
		var d := 0.0
		if n is Structure:
			d = n.surface_distance(global_position)
		else:
			d = Geo.flat_dist(global_position, n.global_position)
		if d > best_d:
			continue
		if n.interact_prompt() == "":
			continue
		best = n
		best_d = d
	return best

func interact_prompt() -> String:
	var mate := _downed_mate()
	if mate != null:
		return _keys("[E] Hold to revive %s  (%d%%)" % [mate.keeper_name(), roundi(mate.revive_progress * 100.0)])
	if operating:
		if _climber_on_tower():
			return _keys("Something's on the tower!  [R] Leave the lamp and shake it loose")
		return _keys("[R] Leave the lamp   [Q] Switch beam")
	if _at_tower_foot() and _climber_on_tower():
		return _keys("[LMB] Strike the tower to shake it loose!")
	if _job_tool == "hammer":
		return "Hammering..."
	if _job_tool == "can":
		return "Pouring oil..."
	if _target != null and is_instance_valid(_target):
		return _keys(_target.interact_prompt())
	return ""

# Rewrite keyboard hints for keepers on a gamepad or the arrow keys.
func _keys(text: String) -> String:
	var d := Players.devices[idx] if idx < Players.devices.size() else Players.KEYBOARD_MOUSE
	if d == Players.KEYBOARD_MOUSE:
		return text
	if d == Players.KEYBOARD_ARROWS:
		return text.replace("[E]", "[Shift]").replace("[R]", "[/]").replace("[Q]", "[.]").replace("[LMB]", "[Ctrl]").replace("[F]", "[']").replace("[RMB]", "[;]")
	return text.replace("[E]", "(A)").replace("[R]", "(Y)").replace("[Q]", "(B)").replace("[LMB]", "(X)").replace("[F]", "(LB)").replace("[RMB]", "(LT)")

func _downed_mate() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if p != self and p.downed and Geo.flat_dist(global_position, p.global_position) <= REVIVE_RANGE:
			return p
	return null

func _update_tag() -> void:
	if _tag == null or not _tag.visible:
		return
	var text := "P%d %s" % [idx + 1, keeper_name()]
	if downed:
		text += "\nDOWN  %d%%" % roundi(revive_progress * 100.0)
	elif idx > 0:
		var prompt := interact_prompt()
		if prompt != "":
			text += "\n" + prompt
	_tag.text = text

func go_down() -> void:
	downed = true
	revive_progress = 0.0
	_stop_operating()
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(_pose, "rotation:x", deg_to_rad(-80.0), 0.35)
	tw.parallel().tween_property(_pose, "position:y", 0.25, 0.35)
	Events.message.emit("%s is down!  Hold interact beside them to revive." % keeper_name())

func revive(fraction: float) -> void:
	if not downed:
		return
	downed = false
	revive_progress = 0.0
	hp = maxi(1, roundi(max_hp * fraction))
	collision_layer = 2
	var tw := create_tween()
	tw.tween_property(_pose, "rotation:x", 0.0, 0.4)
	tw.parallel().tween_property(_pose, "position:y", 0.0, 0.4)
	Audio.sfx("gather", global_position, 0.0, 0.0)
	Events.message.emit("%s is back on their feet." % keeper_name())

func take_damage(amount: int) -> void:
	if hp <= 0 or downed or not Run.active or _inside:
		return
	hp = maxi(0, hp - amount)
	Audio.sfx("hurt", global_position)
	FX.spray(get_parent(), global_position + Vector3(0.0, 1.1, 0.0), Vector3.UP, Color(0.75, 0.8, 0.82))
	if hp == 0:
		_stop_operating()
		if Players.count() <= 1:
			Run.end_run("The keeper has fallen.")
			return
		go_down()
		if Players.all_down():
			Run.end_run("Every keeper is down.")

func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
