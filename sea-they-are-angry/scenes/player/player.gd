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
const OPERATE_RANGE := 3.8
const FALL_SPEED := -5.0
const ISLAND_RADIUS := 12.9
const BODY_COLOR := Color(0.85, 0.65, 0.2)
const MODEL_PATH := "res://art/characters/callum_keeper.glb"
const HOOK_PATH := "res://art/props/boat_hook.glb"
# The keeper GLBs are 2.05 m tall; scaled so the keeper stands about 1.75 m.
const MODEL_SCALE := 0.85

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

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	_hook_pivot = Node3D.new()
	_hook_pivot.position = Vector3(0.4, 0.9, 0.0)
	add_child(_hook_pivot)
	if not _build_model():
		Geo.cyl(self, 0.35, 1.2, BODY_COLOR, Vector3(0.0, 0.6, 0.0))
		Geo.cyl(self, 0.22, 0.32, Color(0.9, 0.75, 0.62), Vector3(0.0, 1.38, 0.0))
		Geo.cyl(self, 0.25, 0.1, Color(0.15, 0.18, 0.3), Vector3(0.0, 1.57, 0.0))
	if not _build_hook():
		Geo.box(_hook_pivot, Vector3(0.06, 0.06, 1.6), Color(0.18, 0.15, 0.12), Vector3(0.0, 0.0, -0.6))
		Geo.box(_hook_pivot, Vector3(0.06, 0.25, 0.06), Color(0.3, 0.3, 0.32), Vector3(0.0, -0.1, -1.4))
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
	var m := load_art(MODEL_PATH)
	if m == null:
		return false
	var holder := Node3D.new()
	holder.name = "Model"
	# Z-up to Y-up, then turn the model's front (-Y in the file) to face -Z, Godot's forward.
	holder.rotation = Vector3(deg_to_rad(-90.0), PI, 0.0)
	holder.scale = Vector3.ONE * MODEL_SCALE
	holder.add_child(m)
	add_child(holder)
	return true

func _build_hook() -> bool:
	var h := load_art(HOOK_PATH)
	if h == null:
		return false
	# The hook's shaft runs along +Z in the file; point it forward along -Z.
	h.rotation.y = PI
	h.position = Vector3(0.0, 0.0, 0.45)
	h.scale = Vector3.ONE * 1.25
	_hook_pivot.add_child(h)
	return true

func aim_yaw() -> float:
	return atan2(-_aim.x, -_aim.z)

func aim_dir() -> Vector3:
	return _aim

func _physics_process(delta: float) -> void:
	if not Run.active:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_update_aim()
	rotation.y = aim_yaw()
	_update_swing(delta)
	if Input.is_action_just_pressed("operate"):
		_toggle_operate()
	if operating:
		velocity.x = 0.0
		velocity.z = 0.0
		if Input.is_action_just_pressed("beam_mode") and lamp:
			lamp.toggle_mode()
	else:
		_move(delta)
		if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
			_attack()
	velocity.y = 0.0 if is_on_floor() else FALL_SPEED
	move_and_slide()
	_clamp_to_island()
	_target = _find_interactable()
	if Input.is_action_just_pressed("interact") and _target != null:
		_target.interact(self)

func _update_aim() -> void:
	if camera == null:
		return
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return
	var t := (global_position.y - from.y) / dir.y
	if t <= 0.0:
		return
	var d := from + dir * t - global_position
	d.y = 0.0
	if d.length() > 0.05:
		_aim = d.normalized()

func _move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y)
	var spd := SPEED
	if _sprint_cd > 0.0:
		_sprint_cd = maxf(0.0, _sprint_cd - delta)
	if Input.is_action_pressed("sprint") and dir != Vector3.ZERO and _sprint_cd <= 0.0:
		spd = SPRINT
		_sprint_t += delta
		if _sprint_t >= SPRINT_MAX:
			_sprint_t = 0.0
			_sprint_cd = SPRINT_COOLDOWN
	else:
		_sprint_t = maxf(0.0, _sprint_t - delta)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd

func _clamp_to_island() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > ISLAND_RADIUS:
		flat = flat.normalized() * ISLAND_RADIUS
		global_position.x = flat.x
		global_position.z = flat.y

func _attack() -> void:
	_attack_cd = ATTACK_CD
	_swing_t = SWING_TIME
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("take_damage"):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > ATTACK_RANGE:
			continue
		var dir_to := _aim if d < 0.01 else to / d
		if rad_to_deg(_aim.angle_to(dir_to)) > ATTACK_ARC_DEG:
			continue
		e.take_damage(ATTACK_DMG, dir_to, self)

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
		return
	if Geo.flat_dist(global_position, lamp.lighthouse.global_position) > OPERATE_RANGE:
		Events.message.emit("Get closer to the lighthouse to operate the lamp.")
		return
	operating = true
	lamp.set_operator(self)
	if lamp.is_lit():
		Events.message.emit("On the lamp.  Mouse aims, [Q] beam, [R] leave")
	else:
		Events.message.emit("The lamp is lit at dusk.  [R] leave")

func _stop_operating() -> void:
	operating = false
	if lamp and lamp.operator == self:
		lamp.set_operator(null)

func _find_interactable() -> Node:
	var best: Node = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D) or not n.has_method("interact_prompt"):
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
	if operating:
		return "[R] Leave the lamp   [Q] Switch beam"
	if _target != null and is_instance_valid(_target):
		return _target.interact_prompt()
	return ""

func take_damage(amount: int) -> void:
	if hp <= 0 or not Run.active:
		return
	hp = maxi(0, hp - amount)
	if hp == 0:
		_stop_operating()
		Run.end_run("The keeper has fallen.")

func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
