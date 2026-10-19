class_name Crab
extends Enemy
## The Armoured Crab: slow, heavy, and out to wreck the homestead. It comes up a beach
## and round the track for the nearest of the cottage, shed and garden, smashing fences
## on the way. Once it has wrecked one, it drags itself back to the sea: each crab costs
## a building unless a keeper stops it. With the homestead already down, it goes for the
## lighthouse.
## The claw goes up for a long wind-up before each slam. Its shell turns blows from the
## front; after a slam it's wide open. The beam can't burn it, but a focused beam in its
## eyes during the wind-up staggers it. Too heavy to shove off the ledge.

const BASE_HP := 150
const SLAM_RANGE := 2.2
const SLAM_ARC_DEG := 60.0
const SLAM_STRUCT_DMG := 30
# After smashing at a building it tears at the wreckage a while before the next slam:
# one crab left alone wrecks about one building a night, not the whole homestead.
const RUMMAGE_TIME := 2.5
const SLAM_PLAYER_DMG := 25
const SLAM_SHOVE := 9.0
const WINDUP_TIME := 1.5
const SLAM_TIME := 0.15
const RECOVER_TIME := 1.0
const FRONT_MULT := 0.5
const RECOVER_MULT := 2.0
const STAGGER_TIME := 1.0
const STAGGER_COOLDOWN := 4.0
# Hit three times by the same keeper within a few seconds and it turns on them.
const GRUDGE_HITS := 3
const GRUDGE_WINDOW := 5.0
const GRUDGE_TIME := 8.0
const SHELL := Color(0.5, 0.3, 0.25)
const SHELL_DARK := Color(0.32, 0.18, 0.15)
const SCRAP := Color(0.45, 0.45, 0.47)
const CLAW_HOT := Color(0.85, 0.45, 0.3)

var _visual: Node3D
var _shell_mat: StandardMaterial3D
var _claw_mat: StandardMaterial3D
var _claw: Node3D
var _legs: Array[Node3D] = []
var _slam_target: Node3D
var _stagger_cd := 0.0
var _scuttle_t := 0.0
var _hits := {}
var _grudge: Node3D
var _grudge_t := 0.0
var _hit_t := 0.0

func _init() -> void:
	max_hp = BASE_HP
	hp = BASE_HP
	speed = 1.2
	mass = 5.0
	reach = SLAM_RANGE - 0.4

func _ready() -> void:
	# More keepers, tougher shell.
	max_hp = roundi(BASE_HP * (1.0 + 0.2 * float(Players.count() - 1)))
	super._ready()

func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_shell_mat = Look.flat_mat(SHELL, 0.45)
	var dark := Look.flat_mat(SHELL_DARK, 0.6)
	var body := Geo.box(_visual, Vector3(1.6, 0.5, 1.2), Color.WHITE, Vector3(0.0, 0.5, 0.0))
	body.material_override = _shell_mat
	var lid := Geo.box(_visual, Vector3(1.3, 0.2, 0.95), Color.WHITE, Vector3(0.0, 0.88, 0.05))
	lid.material_override = _shell_mat
	# Scrap grown into the shell.
	var scrap := Look.flat_mat(SCRAP, 0.35)
	for p in [Vector3(-0.35, 1.02, 0.1), Vector3(0.3, 1.0, -0.15), Vector3(0.1, 1.04, 0.3)]:
		var s := Geo.box(_visual, Vector3(0.28, 0.14, 0.2), Color.WHITE, p)
		s.material_override = scrap
		s.rotation.y = p.x * 2.0
	# Eyes on stalks, facing forward (-Z).
	for side in [-1.0, 1.0]:
		var stalk := Geo.box(_visual, Vector3(0.06, 0.3, 0.06), Color.WHITE, Vector3(side * 0.2, 0.95, -0.55))
		stalk.material_override = dark
		var eye := Geo.sphere(_visual, 0.07, Color.WHITE, Vector3(side * 0.2, 1.12, -0.55))
		eye.material_override = Look.glow_mat(Color(0.9, 0.85, 0.4), 1.5)
	# Six jointed legs: up and out from the shell, then down to a point.
	for i in 6:
		var side := -1.0 if i < 3 else 1.0
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.75, 0.55, -0.4 + float(i % 3) * 0.4)
		_visual.add_child(leg)
		var upper := Geo.box(leg, Vector3(0.55, 0.11, 0.11), Color.WHITE, Vector3(side * 0.25, 0.12, 0.0))
		upper.material_override = dark
		upper.rotation.z = side * 0.45
		var lower := Geo.box(leg, Vector3(0.11, 0.7, 0.1), Color.WHITE, Vector3(side * 0.58, -0.12, 0.0))
		lower.material_override = _shell_mat
		lower.rotation.z = side * -0.35
		_legs.append(leg)
	# One oversized claw on the right, one small on the left.
	_claw_mat = Look.flat_mat(SHELL, 0.4)
	_claw = Node3D.new()
	_claw.position = Vector3(0.65, 0.6, -0.55)
	_visual.add_child(_claw)
	var arm := Geo.box(_claw, Vector3(0.22, 0.22, 0.5), Color.WHITE, Vector3(0.0, 0.0, -0.2))
	arm.material_override = _shell_mat
	var pincer := Geo.box(_claw, Vector3(0.7, 0.4, 0.5), Color.WHITE, Vector3(0.1, 0.05, -0.6))
	pincer.material_override = _claw_mat
	var small := Geo.box(_visual, Vector3(0.3, 0.2, 0.35), Color.WHITE, Vector3(-0.6, 0.55, -0.75))
	small.material_override = _shell_mat
	Geo.box_shape(self, Vector3(1.5, 0.9, 1.2), Vector3(0.0, 0.6, 0.0))

func light_probe_points() -> Array:
	return [global_position + Vector3(0.0, 0.4, 0.0), global_position + Vector3(0.0, 1.0, 0.0)]

func pick_target() -> Node3D:
	if _grudge != null and is_instance_valid(_grudge) and _grudge_t > 0.0 and not _grudge.downed and not _grudge.is_inside():
		return _grudge
	var home := Enemy.nearest_home(global_position)
	return home if home != null else lighthouse

func at_target() -> bool:
	if target is Player:
		return Geo.flat_dist(global_position, target.global_position) < reach
	return super.at_target()

# ---- states ----

func _tick_Approach(delta: float) -> void:
	_scuttle(delta)
	if _grudge_t > 0.0 and target != _grudge and pick_target() == _grudge:
		target = _grudge
		replan()
	super._tick_Approach(delta)

func _enter_AttackFence() -> void:
	_slam_target = attack_target
	change_state(&"WindUp")

func _enter_Arrived() -> void:
	_slam_target = target
	change_state(&"WindUp")

func _enter_WindUp() -> void:
	velocity = Vector3.ZERO
	Audio.sfx("crab_windup", global_position, -2.0, 0.05)

func _tick_WindUp(delta: float) -> void:
	velocity = Vector3.ZERO
	_follow_ground(delta)
	if _slam_target != null and is_instance_valid(_slam_target):
		face(_slam_target.global_position - global_position)
	# The tell: the claw rises and reddens.
	var k := clampf(state_t / WINDUP_TIME, 0.0, 1.0)
	_claw.rotation.x = lerpf(0.0, 1.3, k)
	_claw.position.y = 0.6 + 0.4 * k
	_claw_mat.albedo_color = SHELL.lerp(CLAW_HOT, k)
	_claw_mat.emission_enabled = true
	_claw_mat.emission = CLAW_HOT * k * 0.5
	if state_t >= WINDUP_TIME:
		change_state(&"Slam")

func _enter_Slam() -> void:
	velocity = Vector3.ZERO
	_claw.rotation.x = -0.3
	_claw.position.y = 0.45
	_claw_mat.albedo_color = SHELL
	_claw_mat.emission_enabled = false
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var c := global_position
	for s in get_tree().get_nodes_in_group("structures"):
		if not (s is Structure) or s.is_destroyed():
			continue
		var to: Vector3 = s.global_position - c
		to.y = 0.0
		var in_arc := s == _slam_target or (to.length() > 0.01 and rad_to_deg(fwd.angle_to(to.normalized())) <= SLAM_ARC_DEG)
		if in_arc and s.surface_distance(c) <= SLAM_RANGE:
			s.take_damage(SLAM_STRUCT_DMG)
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Player):
			continue
		var tp: Vector3 = p.global_position - c
		tp.y = 0.0
		if tp.length() <= SLAM_RANGE + 0.3 and (tp.length() < 0.6 or rad_to_deg(fwd.angle_to(tp.normalized())) <= SLAM_ARC_DEG):
			p.take_damage(SLAM_PLAYER_DMG)
			p.shove(tp.normalized() * SLAM_SHOVE)
	var at := c + fwd * 1.4
	FX.splinters(get_parent(), at + Vector3(0.0, 0.3, 0.0))
	FX.emitter(get_parent(), at, FX._puff_mesh_ref(), Color(0.45, 0.4, 0.33, 0.5), 10, 1.0, Vector3.UP, 80.0, 1.0, 2.5, 1.0, 0.4, 0.9, true, true)
	Audio.sfx("crab_slam", c, 0.0, 0.05)

func _tick_Slam(_delta: float) -> void:
	velocity = Vector3.ZERO
	if state_t >= SLAM_TIME:
		change_state(&"Recover")

func _tick_Recover(_delta: float) -> void:
	velocity = Vector3.ZERO
	_claw.rotation.x = lerpf(-0.3, 0.0, clampf(state_t / RECOVER_TIME, 0.0, 1.0))
	_claw.position.y = 0.6
	if state_t >= RECOVER_TIME:
		# Keep smashing the same thing while it stands and is in reach; else move on.
		var t := _slam_target
		var standing: bool = t != null and is_instance_valid(t) and not (t is Structure and t.is_destroyed()) and not (t is Player and t.downed)
		if standing and _in_slam_reach(t):
			change_state(&"Rummage" if t is Structure else &"WindUp")
		elif t is Structure and HOME_IDS.has(t.id) and t.is_destroyed():
			# Its work done, back to the sea.
			Events.message.emit("The crab drags itself back to the sea.")
			change_state(&"Retreat")
		else:
			attack_target = null
			target = pick_target()
			replan()
			change_state(&"Approach")

func _tick_Rummage(delta: float) -> void:
	velocity = Vector3.ZERO
	_scuttle(delta)
	_claw.rotation.x = 0.3 + 0.25 * sin(state_t * 9.0)
	if fmod(state_t, 0.8) < delta and _slam_target != null and is_instance_valid(_slam_target):
		FX.splinters(get_parent(), global_position.lerp(_slam_target.global_position, 0.5) + Vector3(0.0, 0.4, 0.0))
	if state_t >= RUMMAGE_TIME:
		_claw.rotation.x = 0.0
		change_state(&"WindUp")

func _in_slam_reach(t: Node3D) -> bool:
	if t is Structure:
		return t.surface_distance(global_position) <= SLAM_RANGE
	return Geo.flat_dist(t.global_position, global_position) <= SLAM_RANGE

func _scuttle(delta: float) -> void:
	_scuttle_t -= delta
	var moving := velocity.length() > 0.2
	for i in _legs.size():
		_legs[i].rotation.y = sin(state_t * 9.0 + float(i) * 1.7) * (0.35 if moving else 0.05)
	if moving and _scuttle_t <= 0.0:
		_scuttle_t = randf_range(0.8, 1.6)
		Audio.sfx("crab_scuttle", global_position, -8.0, 0.15)

# ---- damage ----

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if state == &"Emerge" or hp <= 0:
		return
	var mult := 1.0
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	# from_dir points from the keeper to the crab: a blow from in front comes against its facing.
	if from_dir != Vector3.ZERO and rad_to_deg(fwd.angle_to(-Vector3(from_dir.x, 0.0, from_dir.z).normalized())) <= 60.0:
		mult = FRONT_MULT
		FX.sparks(get_parent(), global_position + Vector3(0.0, 0.8, 0.0) - from_dir * 0.6)
		Audio.sfx("hammer", global_position, -4.0, 0.2)
	if state == &"Recover":
		mult = RECOVER_MULT
	if source is Player:
		_note_hit(source)
	_hit_t = 0.1
	super.take_damage(maxi(1, roundi(float(amount) * mult)), from_dir, source)

func _note_hit(p: Player) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var times: Array = _hits.get(p, [])
	times.append(now)
	times = times.filter(func(t: float) -> bool: return now - t <= GRUDGE_WINDOW)
	_hits[p] = times
	if times.size() >= GRUDGE_HITS:
		_grudge = p
		_grudge_t = GRUDGE_TIME
		_hits[p] = []

func in_light(mode: int, _delta: float) -> void:
	# The shell shrugs off the beam; but in the eyes mid-wind-up, it reels.
	if mode == Lamp.Mode.FOCUSED and state == &"WindUp" and _stagger_cd <= 0.0:
		_stagger_cd = STAGGER_COOLDOWN
		_claw.rotation.x = 0.0
		_claw_mat.emission_enabled = false
		Audio.sfx("hit", global_position, -2.0, 0.1)
		stagger(STAGGER_TIME)

# Out of a stagger it starts the wind-up again rather than slamming straight away.
func _tick_Stagger(delta: float) -> void:
	if _resume_state == &"WindUp" or _resume_state == &"Slam":
		_resume_state = &"Approach"
	super._tick_Stagger(delta)

func _physics_process(delta: float) -> void:
	_stagger_cd = maxf(0.0, _stagger_cd - delta)
	_grudge_t = maxf(0.0, _grudge_t - delta)
	_hit_t = maxf(0.0, _hit_t - delta)
	super._physics_process(delta)
	if is_inside_tree() and _shell_mat:
		_shell_mat.albedo_color = SHELL.lerp(Color(1, 1, 1), _hit_t / 0.1 * 0.6) if state != &"Recover" else SHELL.lerp(Color(0.85, 0.6, 0.45), 0.4)

func _die() -> void:
	FX.splinters(get_parent(), global_position + Vector3(0.0, 0.6, 0.0))
	FX.emitter(get_parent(), global_position + Vector3(0.0, 0.5, 0.0), FX._puff_mesh_ref(), Color(0.5, 0.3, 0.25, 0.7), 12, 1.0, Vector3.UP, 80.0, 1.5, 3.0, 6.0, 0.3, 0.6)
	Audio.sfx("crab_slam", global_position, -4.0, 0.2)
	if last_hit == "hook" or last_hit == "fall":
		# Scrap grown into its shell, there for the taking.
		Stock.add("scrap", 2)
		Events.message.emit("+2 scrap from the crab's shell")
	super._die()
