class_name Smotherer
extends Enemy
## The Smotherer: a gaunt, pale drowned thing that wants the light out. It comes up a
## beach and the ledge like the Bloated, then climbs the lighthouse tower and wraps itself
## over the lantern. While it clings there the beam is smothered (dim and short, no use
## for slowing or burning anything) and the lantern glass slowly cracks.
## The light won't burn it: it hunches away from the beam and only slows. So it's a job
## for the boathook, on the ledge (knock it off) or at the tower. No one in the lamp
## room can reach it up there. A keeper at the tower's foot has to strike the tower to
## shake it loose: three blows and it falls, and from the top the fall kills it. Solo,
## that means leaving the lamp; in co-op it's a job for the other keeper.

const CLIMB_SPEED := 1.3
const CLIMB_FROM := 0.4
const SHAKES_TO_FALL := 3
# Each blow at the tower's foot jolts a climber back down a little.
const SHAKE_DROP := 1.2
const SHAKE_REACH := 1.3
const CRACK_DPS := 2.0
const LIGHT_SLOW := 0.6
const STUN_TIME := 1.5
const SKIN := Color(0.62, 0.68, 0.66)
const SKIN_DARK := Color(0.4, 0.46, 0.45)
const WEED := Color(0.12, 0.2, 0.1)
const EYE := Color(0.75, 0.9, 1.0)

var _visual: Node3D
var _skin: StandardMaterial3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _angle := 0.0
var _height := 0.0
var _shakes := 0
var _crack_acc := 0.0
var _lit_t := 0.0
var _fall_from := 0.0
var _smothering := false

func _init() -> void:
	max_hp = 50
	hp = 50
	speed = 1.4
	mass = 1.2
	reach = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("smotherers")

func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if _load_rig("smotherer", _visual):
		rig.mass = 2.0
		rig.thickness = 0.7
		_rig_eye("eye.L", EYE, 0.24, 10.0)
		_rig_eye("eye.R", EYE, 0.24, 10.0)
		Geo.cyl_shape(self, 0.35, 1.9, Vector3(0.0, 0.95, 0.0))
		return
	_skin = Look.flat_mat(SKIN, 0.35)
	var dark := Look.flat_mat(SKIN_DARK, 0.5)
	var weed := Look.flat_mat(WEED, 0.9)
	# Long, narrow, hunched body.
	var body := Geo.box(_visual, Vector3(0.42, 1.0, 0.28), Color.WHITE, Vector3(0.0, 1.15, 0.05))
	body.material_override = _skin
	body.rotation.x = 0.15
	var hips := Geo.box(_visual, Vector3(0.36, 0.25, 0.25), Color.WHITE, Vector3(0.0, 0.62, 0.0))
	hips.material_override = dark
	# A long skull with two pale pinpoints of light deep in its sockets, and a hood of kelp.
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.5
	hm.radial_segments = 7
	hm.rings = 4
	head.mesh = hm
	head.material_override = _skin
	head.position = Vector3(0.0, 1.85, -0.08)
	_visual.add_child(head)
	for side in [-1.0, 1.0]:
		var socket := Geo.sphere(_visual, 0.055, Color.BLACK, Vector3(side * 0.07, 1.9, -0.22))
		socket.material_override = Look.flat_mat(Color(0.03, 0.03, 0.04), 1.0)
		var e := Geo.sphere(_visual, 0.028, EYE, Vector3(side * 0.07, 1.9, -0.26))
		e.material_override = Look.eye_mat(EYE, 10.0)
		Look.glint(_visual, Vector3(side * 0.07, 1.9, -0.3), EYE, 0.26)
	for i in 6:
		var a := float(i) * 1.05
		var strand := Geo.box(_visual, Vector3(0.05, 0.7, 0.02), Color.WHITE, Vector3(sin(a) * 0.17, 1.65, cos(a) * 0.15 + 0.03))
		strand.material_override = weed
		strand.rotation.z = sin(a) * 0.2
	# Arms that reach past its knees, ending in webbed hands.
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.27, 1.55, 0.0)
		_visual.add_child(shoulder)
		var arm := Geo.box(shoulder, Vector3(0.09, 1.15, 0.09), Color.WHITE, Vector3(0.0, -0.55, 0.0))
		arm.material_override = _skin
		var hand := Geo.box(shoulder, Vector3(0.2, 0.22, 0.04), Color.WHITE, Vector3(0.0, -1.18, -0.02))
		hand.material_override = dark
		_arms.append(shoulder)
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.12, 0.6, 0.0)
		_visual.add_child(hip)
		var leg := Geo.box(hip, Vector3(0.1, 0.62, 0.1), Color.WHITE, Vector3(0.0, -0.3, 0.0))
		leg.material_override = dark
		_legs.append(hip)
	Geo.cyl_shape(self, 0.35, 1.9, Vector3(0.0, 0.95, 0.0))

func light_probe_points() -> Array:
	if state == &"Climb" or state == &"Smother" or state == &"Fall":
		return []
	return super.light_probe_points()

func is_on_tower() -> bool:
	return state == &"Climb" or state == &"Smother"

func at_target() -> bool:
	return lighthouse is Structure and lighthouse.surface_distance(global_position) < CLIMB_FROM + 0.4

# ---- walking ----

func _tick_Approach(delta: float) -> void:
	super._tick_Approach(delta)
	if rig != null:
		_animate_walk(delta, 2.4, 0.5, 0.2, 0.55, 0.45)
		return
	var s := sin(state_t * 7.0) * 0.35 * clampf(velocity.length(), 0.0, 1.0)
	_limbs(Vector3(-s * 0.5, 0, 0), Vector3(s * 0.5, 0, 0), Vector3(s, 0, 0), Vector3(-s, 0, 0))

# Arms and legs: on the rig's bones, or the primitive's pivots.
func _limbs(arm_l: Vector3, arm_r: Vector3, leg_l: Vector3, leg_r: Vector3) -> void:
	if rig != null:
		if rig.is_ragdoll():
			return
		rig.pose("upper_arm.L", arm_l)
		rig.pose("upper_arm.R", arm_r)
		rig.pose("thigh.L", leg_l)
		rig.pose("thigh.R", leg_r)
		rig.pose("shin.L", Vector3(maxf(0.0, -leg_l.x) * 1.4, 0, 0))
		rig.pose("shin.R", Vector3(maxf(0.0, -leg_r.x) * 1.4, 0, 0))
		return
	_arms[0].rotation = arm_l
	_arms[1].rotation = arm_r
	_legs[0].rotation = leg_l
	_legs[1].rotation = leg_r

func _enter_Arrived() -> void:
	change_state(&"Climb")

# ---- on the tower ----

func _tower_radius(y: float) -> float:
	# Hugging the tower's taper (Lighthouse.RADIUS at its foot, TOP_RADIUS under the gallery).
	var k := clampf((y - Lighthouse.TOWER_BASE) / (Lighthouse.TOWER_TOP - Lighthouse.TOWER_BASE), 0.0, 1.0)
	return lerpf(Lighthouse.RADIUS, Lighthouse.TOP_RADIUS, k) + 0.3

func _place_on_tower() -> void:
	var base := lighthouse.global_position
	var r := _tower_radius(_height)
	global_position = base + Vector3(sin(_angle) * r, _height, cos(_angle) * r)
	# Face the wall.
	rotation.y = atan2(sin(_angle), cos(_angle))

func _enter_Climb() -> void:
	velocity = Vector3.ZERO
	collision_mask = 0
	collision_layer = 0
	var d := global_position - lighthouse.global_position
	_angle = atan2(d.x, d.z)
	_height = maxf(_height, 0.0)
	Events.message.emit("Something is climbing the lighthouse!")
	Audio.sfx("creak", global_position, -2.0, 0.2)

func _tick_Climb(delta: float) -> void:
	velocity = Vector3.ZERO
	_height += CLIMB_SPEED * delta
	_place_on_tower()
	# Hand over hand.
	var s := sin(state_t * 6.0)
	_limbs(Vector3(-2.6 + s * 0.4, 0, 0), Vector3(-2.6 - s * 0.4, 0, 0), Vector3(-0.6 + s * 0.3, 0, 0), Vector3(-0.6 - s * 0.3, 0, 0))
	if _height >= Lighthouse.TOWER_TOP - 0.2:
		change_state(&"Smother")

func _enter_Smother() -> void:
	_smothering = true
	# Low enough that its body covers the lantern glass.
	_height = Lighthouse.TOWER_TOP - 0.55
	if lighthouse.lamp:
		lighthouse.lamp.smother(true)
	Audio.sfx("whisper", global_position, 2.0, 0.1)

func _tick_Smother(delta: float) -> void:
	velocity = Vector3.ZERO
	# Wrapped round the lantern, arms spread across the glass.
	var base := lighthouse.global_position
	global_position = base + Vector3(sin(_angle) * 1.0, _height, cos(_angle) * 1.0)
	rotation.y = atan2(sin(_angle), cos(_angle))
	# Leaning onto the glass, arms wrapped round the lantern.
	_visual.rotation.x = 0.25
	var breathe := sin(state_t * 2.0) * 0.06
	if rig != null:
		_limbs(Vector3(-1.75 + breathe, -0.75, 0.0), Vector3(-1.75 - breathe, 0.75, 0.0), Vector3(-0.4, 0, 0), Vector3(-0.4, 0, 0))
	else:
		_limbs(Vector3(-1.75 + breathe, 0.75, 0.0), Vector3(-1.75 - breathe, -0.75, 0.0), Vector3(-0.4, 0, 0), Vector3(-0.4, 0, 0))
	_crack_acc += CRACK_DPS * delta
	var dmg := floori(_crack_acc)
	if dmg > 0:
		_crack_acc -= float(dmg)
		lighthouse.take_damage(dmg)

func _exit_Smother() -> void:
	_visual.rotation.x = 0.0
	_let_go_of_lamp()

func _let_go_of_lamp() -> void:
	if _smothering:
		_smothering = false
		if is_instance_valid(lighthouse) and is_instance_valid(lighthouse.lamp):
			lighthouse.lamp.smother(false)

## A boathook blow on the tower's foot: jolts it down; three and it loses its grip.
func shake(_by: Node) -> void:
	if not is_on_tower():
		return
	_shakes += 1
	_height = maxf(0.0, _height - SHAKE_DROP)
	Audio.sfx("hit", global_position, 0.0, 0.1)
	FX.spray(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP, Color(0.6, 0.7, 0.65))
	if _shakes >= SHAKES_TO_FALL:
		_shakes = 0
		Events.message.emit("It loses its grip!")
		if rig != null:
			# Off the tower as a dead weight: the drop does the rest.
			var out := global_position - lighthouse.global_position
			out.y = 0.0
			out = out.normalized()
			_let_go_of_lamp()
			# Clear of the tower's wall first, so the limbs don't start inside the stone.
			global_position = Vector3(lighthouse.global_position.x, global_position.y, lighthouse.global_position.z) + out * (Lighthouse.RADIUS + 0.45)
			_height = 0.0
			knock_down((out.normalized() * 2.0 + Vector3(0.0, 0.5, 0.0)) * rig.mass * 10.0, 1.5)
			_resume_state = &"Approach"
			Audio.sfx("groan", global_position, 0.0, 0.1)
			return
		change_state(&"Fall")
	elif state == &"Smother":
		change_state(&"Climb")

func _enter_Fall() -> void:
	_fall_from = global_position.y
	velocity = Vector3.ZERO
	Audio.sfx("groan", global_position, 0.0, 0.1)

func _tick_Fall(delta: float) -> void:
	velocity = Vector3.ZERO
	# Off the wall and down to the yard.
	var base := lighthouse.global_position
	var r := _tower_radius(0.0) + 0.6
	var target := base + Vector3(sin(_angle) * r, 0.0, cos(_angle) * r)
	global_position.x = lerpf(global_position.x, target.x, minf(1.0, delta * 6.0))
	global_position.z = lerpf(global_position.z, target.z, minf(1.0, delta * 6.0))
	global_position.y -= 12.0 * delta
	_visual.rotation.x = minf(1.4, _visual.rotation.x + delta * 4.0)
	var g := ground_y()
	if global_position.y <= g:
		global_position.y = g
		var drop := _fall_from - g
		_height = 0.0
		collision_layer = 8
		collision_mask = 2 | 4
		FX.spray(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), Vector3.UP, Color(0.33, 0.27, 0.2))
		Audio.sfx("hit", global_position, 0.0, 0.1)
		if drop > FALL_HURT_FROM:
			last_hit = "fall"
			take_damage(int(drop * FALL_DMG_PER_M), Vector3.ZERO, null)
		if is_inside_tree() and not is_queued_for_deletion() and hp > 0:
			change_state(&"Stunned")

func _tick_Stunned(_delta: float) -> void:
	velocity = Vector3.ZERO
	_visual.rotation.x = lerpf(1.4, 0.0, clampf(state_t / STUN_TIME, 0.0, 1.0))
	if state_t >= STUN_TIME:
		_visual.rotation.x = 0.0
		route.clear()
		change_state(&"Approach")

func _on_got_up() -> void:
	collision_mask = 2 | 4
	super._on_got_up()

func on_dawn() -> void:
	_let_go_of_lamp()
	if is_on_tower() or state == &"Fall":
		# Slithers down and away with the dark.
		_height = 0.0
		var base := lighthouse.global_position
		var r := _tower_radius(0.0) + 0.6
		global_position = base + Vector3(sin(_angle) * r, 0.0, cos(_angle) * r)
		global_position.y = ground_y()
		_visual.rotation.x = 0.0
	super.on_dawn()

# ---- damage ----

func in_light(_mode: int, _delta: float) -> void:
	# Either beam: it cowers and slows, but the light doesn't burn it.
	if is_on_tower():
		return
	speed_mult = LIGHT_SLOW
	_lit_t = 0.15

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	# Up the tower it's out of the boathook's reach: shake it down instead.
	if is_on_tower() and source != null:
		return
	super.take_damage(amount, from_dir, source)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_lit_t = maxf(0.0, _lit_t - delta)
	# In the light it glistens and hunches.
	var lit := _lit_t > 0.0
	if rig != null:
		rig.tint(Color(1.12, 1.12, 1.06) if lit else Color.WHITE)
		if state == &"Approach" and not rig.is_ragdoll():
			rig.pose("spine", Vector3(0.45 if lit else 0.27, 0, 0))
		return
	_skin.albedo_color = SKIN.lerp(Color(0.9, 0.92, 0.85), 0.4) if lit else SKIN
	if state == &"Approach":
		_visual.rotation.x = move_toward(_visual.rotation.x, 0.35 if lit else 0.0, delta * 3.0)

func _die() -> void:
	_let_go_of_lamp()
	FX.burst(get_parent(), global_position + Vector3(0.0, 0.9, 0.0))
	super._die()

func _exit_tree() -> void:
	_let_go_of_lamp()
