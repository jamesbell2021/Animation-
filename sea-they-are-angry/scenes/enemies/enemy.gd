class_name Enemy
extends CharacterBody3D
## Base for every sea creature. A tiny string state machine:
## change_state(&"X") calls _exit_<old>() / _enter_X() if they exist,
## and _physics_process calls _tick_X(delta) each frame.

const EMERGE_TIME := 1.6
# Coming ashore they wade, slowed by the surf and the shingle, up the beach to the
# meadow: time for the beam to find them and burn them.
const WADE_MULT := 0.5
const WADE_STATES := [&"Approach", &"Stalk"]
const EMERGE_DEPTH := -0.6
const FENCE_HIT_INTERVAL := 1.0
const FENCE_HIT_DMG := 10
const RETREAT_MULT := 2.0
const DESPAWN_RADIUS := 30.0
const SINK_RATE := 0.6
const WAYPOINT_REACHED := 0.7
const STRUCTURE_REACH := 1.0
const REPATH_EVERY := 0.5
const OFF_ROUTE_HEIGHT := 1.2
const FALL_RATE := 9.0
# A boathook blow pointing out over the ledge's edge shoves a creature off it.
const SHOVE_SPEED := 6.5
const SHOVE_DOT := 0.35
# Falls longer than this hurt, more the further they drop.
const FALL_HURT_FROM := 1.2
const FALL_DMG_PER_M := 14.0
const KNOCKBACK := 3.0
const KNOCKBACK_DECAY := 8.0
const DETOUR_TIME := 0.8
# Heights on the body the lamp tests against its cone: feet, waist, head.
const LIGHT_PROBE_HEIGHTS := [0.3, 1.0, 1.8]

var hp := 10
var max_hp := 10
var speed := 1.0
var mass := 1.0
var reach := 1.0
var speed_mult := 1.0
var target: Node3D
var lighthouse: Node3D
var state: StringName = &""
var state_t := 0.0
var attack_target: Structure
## Waypoints still to walk (from Nav). Filled on landing and again at dawn.
var route: Array[Vector3] = []
## What last hurt it: "beam", "hook", "fall", or "reached" once it gets to the light.
var last_hit := ""
## Set by the lamp each frame its beam is on this creature; cleared after moving.
var lit_this_frame := false
## Seconds left hidden inside a Squid's ink cloud (unless the beam is on it).
var inked := 0.0
# Too heavy to be shoved off the ledge at or above this.
const SHOVE_MAX_MASS := 3.0
var _resume_state: StringName = &""
var _stagger_len := 0.0

## The rigged model from art/characters, for creatures that have one: animated in code,
## knocked flat as a ragdoll by a hard blow or a fall, and back up again.
var rig: CharacterRig
const HIT_IMPULSE := 3.0
const SHOVE_IMPULSE := 5.5
const KNOCKDOWN_TIME := 0.8
const CORPSE_TIME := 5.0
# A blow shows before the body goes limp: the stagger plays this long first.
const REACT_TIME := 0.14
# Hook blows within POISE_TIME of each other wear down its footing: the blow that
# takes it to poise_hits knocks it flat; the others make it stagger back.
const POISE_TIME := 3.0
const HIT_STAGGER_TIME := 0.55
var poise_hits := 2
## How quickly it comes round to face a new way (see face()): heavy bodies turn slower.
var turn_rate := 8.0
var _faced := false
var _poise := 0
var _poise_t := 0.0
var _walk_phase := 0.0
var _walk_amt := 0.0
var _rag_left := 0.0
var _rag_from_y := 0.0
var _rag_fell := false
var _rag_layer := 0

var _knock := Vector3.ZERO
var _detour_t := 0.0
var _groan_t := 0.0
var _in_water := true
var _detour_dir := Vector3.ZERO
var _attack_t := 0.0
var _repath_t := 0.0
var _sink_t := 0.0
var _fall_top := -INF
var _last_wp := Vector3.INF

## LAN: this creature's id, the same on every machine (given by the host).
var net_id := 0
## LAN, on a client: a puppet, going where the host says. It can't be hurt or act.
var puppet := false
var _net: Array = []
var _net_shot := -1

func _ready() -> void:
	if Net.is_host() and Net.playing() and net_id == 0:
		net_id = Net.new_enemy_id()
	add_to_group("enemies")
	collision_layer = 8
	# No ground layer: creatures follow Terrain.height_at instead, so the beach slope never snags them.
	collision_mask = 2 | 4
	hp = max_hp
	Cycle.phase_changed.connect(_on_phase_changed)
	_build()
	change_state(&"Emerge")

# ---- the rigged model ----

## Load this creature's model into `parent`; false when there's no model (use primitives).
func _load_rig(model: String, parent: Node3D) -> bool:
	rig = CharacterRig.create(model)
	if rig == null:
		return false
	parent.add_child(rig)
	rig.got_up.connect(_on_got_up)
	return true

## A glowing eye on the rig's head at its marker (falls back to a guess).
func _rig_eye(key: String, color: Color, size: float = 0.3, energy: float = 9.0) -> void:
	var at: Vector3 = rig.markers.get(key, Vector3.ZERO)
	var e := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.016
	sm.height = 0.032
	sm.radial_segments = 8
	sm.rings = 4
	e.mesh = sm
	e.material_override = Look.eye_mat(color, energy)
	var holder := Node3D.new()
	holder.add_child(e)
	Look.glint(holder, Vector3(0.0, 0.0, -0.02), color, size)
	rig.attach_at("head", holder, at)

## Walk cycle for humanoids: stride (radians of phase per metre), leg and arm swing,
## a forward hunch and arms held out in front.
func _animate_walk(delta: float, stride: float = 2.6, leg: float = 0.55, arm: float = 0.4, hunch: float = 0.0, arms_fwd: float = 0.0) -> void:
	# A model with clips walks by them (locomote, in _physics_process).
	if rig == null or rig.is_ragdoll() or rig.has_clips():
		return
	var v := Vector2(velocity.x, velocity.z).length()
	_walk_amt = move_toward(_walk_amt, clampf(v / maxf(speed, 0.1), 0.0, 1.2), delta * 4.0)
	_walk_phase += delta * v * stride
	var s := sin(_walk_phase) * _walk_amt
	rig.pose("thigh.L", Vector3(-s * leg, 0.0, 0.0))
	rig.pose("thigh.R", Vector3(s * leg, 0.0, 0.0))
	rig.pose("shin.L", Vector3(maxf(0.0, s) * leg * 1.3 + 0.06, 0.0, 0.0))
	rig.pose("shin.R", Vector3(maxf(0.0, -s) * leg * 1.3 + 0.06, 0.0, 0.0))
	rig.pose("upper_arm.L", Vector3(s * arm - arms_fwd, 0.0, -0.05))
	rig.pose("upper_arm.R", Vector3(-s * arm - arms_fwd, 0.0, 0.05))
	rig.pose("forearm.L", Vector3(-0.25 - arms_fwd * 0.5, 0.0, 0.0))
	rig.pose("forearm.R", Vector3(-0.25 - arms_fwd * 0.5, 0.0, 0.0))
	rig.pose("spine", Vector3(hunch * 0.5, s * 0.08, 0.0))
	rig.pose("chest", Vector3(hunch * 0.5, s * 0.08, s * 0.04))
	rig.pose("neck", Vector3(-hunch * 0.5, 0.0, 0.0))
	rig.shift("hips", Vector3(0.0, absf(sin(_walk_phase)) * 0.04 * _walk_amt, 0.0))

const LOOK_RANGE := 8.0

# Its head turns to the nearest keeper close by (they're what it's after).
func _look_at_keeper() -> void:
	var best: Node3D = null
	var best_d := LOOK_RANGE
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and p.visible:
			var d: float = global_position.distance_to(p.global_position)
			if d < best_d:
				best = p
				best_d = d
	rig.look_at_point(best.global_position + Vector3(0.0, 1.3, 0.0) if best != null else Vector3.INF, 0.8)

## Virtual: whether a blow can knock it flat right now.
func can_ragdoll() -> bool:
	return true

## Knocked flat: the blow shows, then a ragdoll for `time` seconds, then it gets up
## and carries on.
func knock_down(impulse: Vector3, time: float = KNOCKDOWN_TIME) -> void:
	if rig == null or hp <= 0:
		return
	if state == &"Ragdoll":
		rig.ragdoll(impulse, "chest")
		_rag_left = maxf(_rag_left, time * 0.5)
		return
	if state in [&"Emerge", &"Retreat", &"GetUp"] or not can_ragdoll():
		return
	if state != &"Stagger":
		_resume_state = state
	_rag_left = time + REACT_TIME
	_rag_from_y = global_position.y
	_rag_fell = false
	change_state(&"Ragdoll")
	_react_shot(impulse)
	rig.ragdoll(impulse, "chest", REACT_TIME if rig.has_clip("stagger_back") else 0.0)

# The stagger clip that fits a blow pushing this way: it reels away from it.
func _react_shot(push: Vector3) -> void:
	if rig == null or not rig.has_clips():
		return
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var flat := Vector3(push.x, 0.0, push.z)
	if flat.length() > 0.01 and fwd.dot(flat) > 0.3 and rig.has_clip("stagger_fwd"):
		rig.shot("stagger_fwd")
	else:
		rig.shot("stagger_back")

## A blow it keeps its feet through: it reels back a step (if it's light enough to
## move), stops what it was doing for a moment, then carries on.
func hit_reaction(from_dir: Vector3) -> void:
	var flat := Vector3(from_dir.x, 0.0, from_dir.z).normalized()
	var light := mass < SHOVE_MAX_MASS
	if rig != null and rig.has_clip("stagger_back"):
		# A light one is turned to the blow; a heavy one (the Crab) only flinches.
		if light and flat != Vector3.ZERO:
			face(-flat, true)
		rig.shot("stagger_back")
	if not light:
		return
	var travel := float(rig.clips.get("stagger_back", {}).get("travel", 0.3)) if rig != null else 0.3
	_knock = flat * sqrt(2.0 * KNOCKBACK_DECAY * travel)
	stagger(HIT_STAGGER_TIME)

func _enter_Ragdoll() -> void:
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	_rag_layer = collision_layer
	collision_layer = 0

func _tick_Ragdoll(delta: float) -> void:
	velocity = Vector3.ZERO
	# The body goes where the ragdoll lies (a ray down: the island has several levels).
	var g := rig.ragdoll_ground()
	if g != Vector3.INF:
		global_position = g
	var c := rig.ragdoll_centre()
	if c.y < Terrain.SEA_LEVEL - 0.6:
		# Off the rocks and into the sea: gone.
		last_hit = "fall"
		hp = 0
		_die()
		return
	_rag_left -= delta
	var settled := rig.ragdoll_speed() < 1.5
	# Landed after a drop: the fall hurts, more the further it fell.
	var on_ground := c.y - global_position.y < 0.5
	if not _rag_fell and state_t > 0.15 and (on_ground or rig.ragdoll_speed() < 1.0 or (settled and _rag_left <= 0.0)):
		var drop := _rag_from_y - global_position.y
		if drop > FALL_HURT_FROM:
			_rag_fell = true
			_landed(drop)
			if not is_inside_tree() or hp <= 0 or state != &"Ragdoll":
				return
	if _rag_left <= 0.0 and settled:
		var far := Geo.flat_dist(c, global_position) > 1.2
		var plan := {} if far else rig.getup_plan()
		change_state(&"GetUp")
		if not plan.is_empty():
			# Up off its back or its front with a get-up clip, from where it lies.
			face(plan["facing"], true)
			var root: Vector3 = plan["root"]
			global_position.x = root.x
			global_position.z = root.z
			rig.get_up(CharacterRig.GET_UP_TIME, plan["clip"])
			return
		face(-rig.ragdoll_facing(), true)
		rig.get_up(0.05 if far else CharacterRig.GET_UP_TIME)

func _tick_GetUp(_delta: float) -> void:
	velocity = Vector3.ZERO

func _on_got_up() -> void:
	if state != &"GetUp":
		return
	collision_layer = _rag_layer if _rag_layer != 0 else 8
	_repath_t = 0.0
	route.clear()
	_last_wp = Vector3.INF
	var back := _resume_state if _resume_state != &"" and _resume_state != &"Ragdoll" else &"Approach"
	change_state(back)
	if back == &"Approach":
		replan()

## Dead: the body goes limp and lies there, then sinks away.
func _ragdoll_corpse(impulse: Vector3 = Vector3.ZERO) -> bool:
	if rig == null:
		return false
	if net_id > 0 and Net.is_host():
		Net.relay_corpse(net_id, impulse)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	_react_shot(impulse)
	rig.ragdoll(impulse, "chest", REACT_TIME * 0.7 if rig.has_clip("stagger_back") else 0.0)
	rig.stay_down()
	var tw := create_tween()
	tw.tween_interval(CORPSE_TIME)
	tw.tween_callback(queue_free)
	return true

# ---- LAN ----

## The host's word on this creature, for the clients (see net_apply).
func net_snap() -> Array:
	var flags := 0
	if rig != null and rig.is_ragdoll():
		flags |= 1
	if visible:
		flags |= 2
	if burning > 0.0:
		flags |= 4
	if on_fire > 0.0:
		flags |= 8
	return [net_id, get_script().resource_path, global_position, rotation.y, velocity, String(state), hp, flags,
		rig.shot_seq if rig != null else 0, rig.last_shot if rig != null else "", _net_extra()]

## Virtual: anything more a puppet needs to look right (the Eel's body).
func _net_extra() -> Variant:
	return null

func net_apply(a: Array) -> void:
	_net = a
	state = StringName(String(a[5]))
	hp = int(a[6])
	var flags := int(a[7])
	visible = flags & 2 != 0
	burning = BURN_HOLD if flags & 4 != 0 else 0.0
	_show_fire(1.0 if flags & 8 != 0 else 0.0)
	if rig != null:
		var seq := int(a[8])
		if _net_shot >= 0 and seq != _net_shot and String(a[9]) != "":
			rig.shot(String(a[9]))
		_net_shot = seq
		var rag := flags & 1 != 0
		if rag and not rig.is_ragdoll():
			rig.ragdoll(Vector3(0.0, 4.0, 0.0) * mass, "chest")
		elif not rag and rig.is_ragdoll() and not rig.is_getting_up():
			rig.get_up(CharacterRig.GET_UP_TIME)
	_net_apply_extra(a[10])

func _net_apply_extra(_extra: Variant) -> void:
	pass

func _puppet_step(delta: float) -> void:
	if _net.is_empty():
		return
	if rig == null or not rig.is_ragdoll():
		var target: Vector3 = _net[2]
		var k := 1.0 - exp(-delta * Net.FOLLOW)
		global_position = target if global_position.distance_to(target) > 5.0 else global_position.lerp(target, k)
		rotation.y = lerp_angle(rotation.y, float(_net[3]), k)
	velocity = _net[4]
	if rig != null and rig.has_clips() and not rig.is_ragdoll():
		rig.locomote(Vector2(velocity.x, velocity.z).length())
		_burn_pose()

# ---- virtuals ----

func _build() -> void:
	pass

func in_light(_mode: int, _delta: float) -> void:
	pass

func pick_target() -> Node3D:
	if camp_raid:
		return Enemy.nearest_camp(global_position)
	return lighthouse

# Points the lamp tests against its cone. Override for odd shapes (the Eel's head).
func light_probe_points() -> Array:
	var out: Array = []
	for h in LIGHT_PROBE_HEIGHTS:
		out.append(global_position + Vector3(0.0, float(h), 0.0))
	return out

const HOME_IDS := ["cottage", "shed", "garden"]

## Came ashore on the holm, for the camp: it makes for the camp's generator and buildings,
## never the light (the holm isn't joined to the main island for them).
var camp_raid := false

## The nearest of the camp's generator and buildings still standing, or null.
static func nearest_camp(from: Vector3) -> Structure:
	var tree := Engine.get_main_loop() as SceneTree
	var camp := tree.get_first_node_in_group("camp_root")
	if camp == null:
		return null
	var best: Structure = null
	var best_d := INF
	for s in camp.targets():
		var d := Geo.flat_dist(from, s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best

## Whether two points are on the same island (the holm, or the main island).
static func same_island(a: Vector3, b: Vector3) -> bool:
	return Terrain.island_of(a.x, a.z) == Terrain.island_of(b.x, b.z)

## The nearest standing building of the homestead, or null if all are wrecked.
static func nearest_home(from: Vector3) -> Structure:
	var best: Structure = null
	var best_d := INF
	var tree := Engine.get_main_loop() as SceneTree
	for s in tree.get_nodes_in_group("structures"):
		if s is Structure and HOME_IDS.has(s.id) and not s.is_destroyed():
			var d := Geo.flat_dist(from, s.global_position)
			if d < best_d:
				best_d = d
				best = s
	return best

func _enter_Arrived() -> void:
	velocity = Vector3.ZERO

func on_dawn() -> void:
	if rig != null and rig.is_ragdoll():
		rig.get_up(0.05)
		collision_layer = 8
	change_state(&"Retreat")

# ---- state machine ----

func change_state(s: StringName) -> void:
	if state != &"":
		var ex := "_exit_" + String(state)
		if has_method(ex):
			call(ex)
	state = s
	state_t = 0.0
	var en := "_enter_" + String(s)
	if has_method(en):
		call(en)

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_step(delta)
		return
	state_t += delta
	_afflictions(delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if is_wading():
		speed_mult *= WADE_MULT
	if burning > 0.0:
		# Held in the focused beam: it can't take a step, only writhe.
		burning = maxf(0.0, burning - delta)
		speed_mult = 0.0
	var tick := "_tick_" + String(state)
	if has_method(tick):
		call(tick, delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if rig != null and rig.has_clips():
		rig.locomote(Vector2(velocity.x, velocity.z).length())
	if rig != null and rig.has_clips():
		_look_at_keeper()
	if _poise_t > 0.0:
		_poise_t -= delta
		if _poise_t <= 0.0:
			_poise = 0
	velocity += _knock
	_knock = _knock.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()
	# Ink hides it, except while the beam is on it.
	if inked > 0.0:
		inked = maxf(0.0, inked - delta)
	visible = inked <= 0.0 or lit_this_frame
	# Reset after use: the lamp re-applies these every physics frame through in_light().
	speed_mult = 1.0
	lit_this_frame = false

# ---- set alight, and poisoned ----

## Seconds left alight (a flamer's stream, a petrol bomb): it burns on, hurting, after.
var on_fire := 0.0
## Seconds left poisoned (rat poison at a trap): it sickens, slows and weakens.
var poisoned := 0.0
const FIRE_DPS := 8.0
const POISON_DPS := 3.5
const POISON_SLOW := 0.7
var _dot := 0.0
var _dot_fx_t := 0.0
## Pixel fire on it while it burns (PixelFire): a few flames together.
var _fire_fx: Array[MeshInstance3D] = []

func set_alight(t: float) -> void:
	on_fire = maxf(on_fire, t)

func poison(t: float) -> void:
	poisoned = maxf(poisoned, t)

## Show it burning (or not): pixel flames licking up it, dying down as the fire does.
func _show_fire(left: float) -> void:
	if left <= 0.0:
		for f in _fire_fx:
			f.visible = false
		return
	if _fire_fx.is_empty():
		var size := fire_size()
		var sd := float(get_instance_id() % 997) * 0.13
		# A big one up the middle, and two smaller licking up its sides.
		_fire_fx.append(PixelFire.sprite(self, Vector3(0.0, size.y * 0.5, 0.0), size, sd))
		for side: float in [-1.0, 1.0]:
			var small := size * Vector2(0.7, 0.72)
			_fire_fx.append(PixelFire.sprite(self, Vector3(side * size.x * 0.28, small.y * 0.42, side * 0.12), small, sd + side * 3.1))
	for f in _fire_fx:
		f.visible = true
		f.set_instance_shader_parameter("fade", clampf(left / 0.8, 0.6, 1.0))

## Virtual: how big its flames are when it burns (wide, tall).
func fire_size() -> Vector2:
	return Vector2(1.5, 2.1)

func _afflictions(delta: float) -> void:
	_show_fire(on_fire if hp > 0 else 0.0)
	if (on_fire <= 0.0 and poisoned <= 0.0) or hp <= 0:
		return
	if state == &"Emerge" or state == &"Retreat" and _in_water:
		# Into the sea: that puts the fire out.
		on_fire = 0.0
	var dps := 0.0
	var how := ""
	if on_fire > 0.0:
		on_fire = maxf(0.0, on_fire - delta)
		dps += FIRE_DPS
		how = "flame"
	if poisoned > 0.0:
		poisoned = maxf(0.0, poisoned - delta)
		dps += POISON_DPS
		speed_mult *= POISON_SLOW
		if how == "":
			how = "poison"
	_dot_fx_t -= delta
	if _dot_fx_t <= 0.0:
		_dot_fx_t = 0.25
		var at := global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.6, 1.4), randf_range(-0.3, 0.3))
		if on_fire > 0.0:
			FX.embers(get_parent(), at)
			if randf() < 0.4:
				Audio.sfx("crackle", at, -6.0, 0.3)
		if poisoned > 0.0 and randf() < 0.6:
			FX.spray(get_parent(), at, Vector3.DOWN, Color(0.45, 0.8, 0.3))
	_dot += dps * delta
	if _dot >= 1.0:
		var n := int(_dot)
		_dot -= float(n)
		last_hit = how
		take_damage(n, Vector3.ZERO, null)

# ---- burning in the focused beam ----

const BURN_HOLD := 0.15
const NO_WRITHE := [&"Emerge", &"Bloat", &"Burst", &"Ragdoll", &"GetUp"]
## Seconds left held burning (renewed every frame the focused beam burns it).
var burning := 0.0
var _sizzle_t := 0.0
var _crackle_t := 0.0
var _cry_t := 0.0

## Called each frame the focused beam burns it: it stops where it stands and writhes,
## and it sizzles, crackles, spits embers and cries out. `at` is where on it the
## burning is (its middle by default).
func burn_tick(delta: float, cry: String = "", cry_db: float = -2.0, at: Vector3 = Vector3.INF) -> void:
	burning = BURN_HOLD
	var p := global_position + Vector3(0.0, 1.0, 0.0) if at == Vector3.INF else at
	_sizzle_t -= delta
	if _sizzle_t <= 0.0:
		_sizzle_t = randf_range(0.5, 0.75)
		Audio.sfx("sizzle", p, 0.0, 0.15)
	_crackle_t -= delta
	if _crackle_t <= 0.0:
		_crackle_t = randf_range(0.07, 0.3)
		var j := Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.4), randf_range(-0.3, 0.3))
		Audio.sfx("crackle", p + j, randf_range(-6.0, 1.0), 0.35)
		if randf() < 0.45:
			FX.embers(get_parent(), p + j)
	if cry != "":
		_cry_t -= delta
		if _cry_t <= 0.0:
			_cry_t = randf_range(0.9, 1.5)
			Audio.sfx(cry, p, cry_db, 0.2)

# Writhing in the beam (its burn clip) while it burns; back to what it was doing after.
func _burn_pose() -> void:
	if not rig.has_clip("burn") or rig.is_ragdoll():
		return
	if burning > 0.0 and not (state in NO_WRITHE):
		if rig.current_activity() != "burn":
			rig.activity("burn")
	elif rig.current_activity() == "burn":
		rig.activity("")

## Still coming up out of the sea: on a beach, below the meadow.
func is_wading() -> bool:
	if not (state in WADE_STATES) or self is Eel:
		return false
	var p := global_position
	return p.y < Terrain.PLATEAU_HEIGHT - 0.25 and Terrain.beach_weight(p.x, p.z) > 0.35

func _on_phase_changed(p: int) -> void:
	if p == Cycle.Phase.DAWN and state != &"Retreat":
		on_dawn()

## Turn toward a direction, at TURN_RATE: a body with clips steps round to it rather than
## snapping. `snap` turns it at once (getting up where the ragdoll lies, reeling from a blow).
func face(dir: Vector3, snap: bool = false) -> void:
	if Vector2(dir.x, dir.z).length() <= 0.001:
		return
	var want := atan2(-dir.x, -dir.z)
	if snap or not _faced or rig == null or not rig.has_clips():
		rotation.y = want
	else:
		rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-get_physics_process_delta_time() * turn_rate))
	_faced = true

# ---- shared states ----

func ground_y() -> float:
	return Terrain.height_at(global_position.x, global_position.z)

func _enter_Emerge() -> void:
	velocity = Vector3.ZERO
	position.y = ground_y() + EMERGE_DEPTH
	var surface := Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z)
	FX.splash(get_parent(), surface, 1.0)
	Audio.sfx("splash", surface, -4.0)
	_groan_t = randf_range(0.5, 4.0)

func _tick_Emerge(_delta: float) -> void:
	velocity = Vector3.ZERO
	var g := ground_y()
	position.y = lerpf(g + EMERGE_DEPTH, g, clampf(state_t / EMERGE_TIME, 0.0, 1.0))
	if state_t >= EMERGE_TIME:
		position.y = g
		_in_water = false
		change_state(&"Approach")

func _enter_Approach() -> void:
	target = pick_target()
	if _last_wp == Vector3.INF:
		# First time ashore: plot the way unless the spawner already did.
		if route.is_empty():
			replan()
		else:
			_last_wp = global_position

## Plot a fresh route from here to the current target.
func replan() -> void:
	if target != null and is_instance_valid(target):
		set_route(Nav.route_to(global_position, target.global_position))
	elif camp_raid:
		# Nothing left standing in the camp: nowhere to go (the holm isn't joined to the light).
		set_route([] as Array[Vector3])
	else:
		set_route(Nav.route_to_light(global_position))

## Virtual: whether it has reached its target. Buildings are measured to their walls.
func at_target() -> bool:
	if target is Structure and target != lighthouse:
		return target.surface_distance(global_position) < STRUCTURE_REACH
	var to := target.global_position - global_position
	return Vector2(to.x, to.z).length() < reach

func set_route(r: Array[Vector3]) -> void:
	route = r
	_last_wp = global_position

## Next point to walk to: the route's head, then the target itself.
func _steer_point() -> Vector3:
	while not route.is_empty() and Geo.flat_dist(global_position, route[0]) < WAYPOINT_REACHED:
		_last_wp = route.pop_front()
	if not route.is_empty():
		return route[0]
	return target.global_position if target != null and is_instance_valid(target) else global_position

# Knocked off the ledge or out of the gully: find a way back on from here.
func _check_route(delta: float) -> void:
	_repath_t -= delta
	if _repath_t > 0.0 or route.is_empty() or _last_wp == Vector3.INF:
		return
	_repath_t = REPATH_EVERY
	var a := _last_wp
	var b := route[0]
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var k := 0.0
	if ab.length_squared() > 0.001:
		k = clampf(Vector2(global_position.x - a.x, global_position.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
	if absf(ground_y() - lerpf(a.y, b.y, k)) > OFF_ROUTE_HEIGHT:
		replan()

func _tick_Approach(delta: float) -> void:
	if target == null or not is_instance_valid(target) or (target is Structure and target != lighthouse and target.is_destroyed()):
		# Its building is already wrecked: on to the next thing.
		target = pick_target()
		replan()
	if target == null:
		velocity = Vector3.ZERO
		return
	if at_target():
		change_state(&"Arrived")
		return
	_check_route(delta)
	var to := _steer_point() - global_position
	to.y = 0.0
	if to.length() < 0.01:
		to = target.global_position - global_position
		to.y = 0.0
	var dir := to.normalized()
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(6.0, 12.0)
		Audio.sfx("groan", global_position, -6.0, 0.15)
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var col := hit.get_collider()
		if col == target or col is CharacterBody3D:
			continue
		if (col is Fence or (col is Structure and col.is_in_group("barricades"))) and not col.is_destroyed():
			attack_target = col
			change_state(&"AttackFence")
			return
		if col is StaticBody3D and _detour_t <= 0.0:
			# Buildings and scenery: step sideways along the wall for a moment.
			var n := hit.get_normal()
			var side := Vector3(n.z, 0.0, -n.x).normalized()
			if side.dot(dir) < 0.0 or (absf(side.dot(dir)) < 0.05 and get_instance_id() % 2 == 0):
				side = -side
			_detour_dir = side
			_detour_t = DETOUR_TIME
	if _detour_t > 0.0:
		_detour_t -= delta
		dir = _detour_dir
	face(dir)
	velocity = dir * speed * speed_mult
	_follow_ground(delta)

# Stick to the ground, but drop rather than teleport when knocked off a ledge.
func _follow_ground(delta: float) -> void:
	var g := ground_y()
	if position.y > g + 0.05:
		if _fall_top == -INF:
			_fall_top = position.y
		position.y = maxf(g, position.y - FALL_RATE * delta)
		if position.y <= g:
			_landed(_fall_top - g)
	else:
		position.y = g
		_fall_top = -INF

func _landed(drop: float) -> void:
	_fall_top = -INF
	if drop < FALL_HURT_FROM or state == &"Retreat":
		return
	FX.spray(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), Vector3.UP, Color(0.33, 0.27, 0.2))
	Audio.sfx("hit", global_position, -2.0, 0.1)
	Audio.sfx("groan", global_position, -4.0, 0.2)
	Events.message.emit("Over the edge!")
	last_hit = "fall"
	take_damage(int(drop * FALL_DMG_PER_M), Vector3.ZERO, null)
	# Find the way back round from down here.
	_repath_t = 0.0

func _enter_AttackFence() -> void:
	_attack_t = 0.0
	velocity = Vector3.ZERO

func _tick_AttackFence(delta: float) -> void:
	velocity = Vector3.ZERO
	_follow_ground(delta)
	var gone := attack_target == null or not is_instance_valid(attack_target) or attack_target.is_destroyed()
	# Shoved away from it (or off the ledge below it): back to walking.
	if not gone and (Geo.flat_dist(global_position, attack_target.global_position) > attack_target.length * 0.5 + 1.5 \
			or absf(global_position.y - attack_target.global_position.y) > 1.0):
		gone = true
	if gone:
		attack_target = null
		change_state(&"Approach")
		return
	face(attack_target.global_position - global_position)
	var before := _attack_t
	_attack_t += delta
	# The blow is swung so it lands as the damage does.
	if rig != null and rig.has_clip("strike"):
		var lead := rig.hit_time("strike")
		var at := FENCE_HIT_INTERVAL - lead
		if before < at and _attack_t >= at:
			rig.shot("strike")
	if _attack_t >= FENCE_HIT_INTERVAL:
		_attack_t -= FENCE_HIT_INTERVAL
		attack_target.take_damage(FENCE_HIT_DMG)

func _enter_Retreat() -> void:
	# Walk through fences and keepers on the way out; nothing should wedge a retreating creature.
	collision_mask = 0
	attack_target = null
	set_route(Nav.route_to_sea(global_position))

func _tick_Retreat(delta: float) -> void:
	# Back down the way they came, to the nearest beach, and under.
	while not route.is_empty() and Geo.flat_dist(global_position, route[0]) < WAYPOINT_REACHED:
		route.pop_front()
	var flat := Vector3(global_position.x, 0.0, global_position.z)
	var dir: Vector3
	if route.is_empty():
		dir = flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT
	else:
		dir = Vector3(route[0].x - global_position.x, 0.0, route[0].z - global_position.z).normalized()
	if route.is_empty() and (_in_water or flat.length() > DESPAWN_RADIUS):
		_sink_t += delta
		if _sink_t > 2.0 or flat.length() > DESPAWN_RADIUS:
			queue_free()
			return
	face(dir)
	velocity = dir * speed * RETREAT_MULT
	var g := ground_y()
	if g < Terrain.SEA_LEVEL - 0.6 and not _in_water:
		_in_water = true
		var surface := Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z)
		FX.splash(get_parent(), surface, 0.7)
		Audio.sfx("splash", surface, -8.0)
	# Walk down the beach and sink once the water closes over them.
	_follow_ground(delta)
	if _in_water:
		position.y = g - _sink_t * SINK_RATE * 2.0 - SINK_RATE

## Reeling for a moment: stops, wobbles, then carries on with what it was doing.
func stagger(duration: float) -> void:
	if state == &"Stagger" or state == &"Emerge" or state == &"Retreat":
		return
	_resume_state = state
	_stagger_len = duration
	change_state(&"Stagger")

func _enter_Stagger() -> void:
	velocity = Vector3.ZERO

func _tick_Stagger(_delta: float) -> void:
	velocity = Vector3.ZERO
	# A model with clips reels in its stagger clip; the primitives wobble.
	if rig == null or not rig.has_clips():
		rotation.z = sin(state_t * 22.0) * 0.12 * (1.0 - state_t / maxf(_stagger_len, 0.01))
	if state_t >= _stagger_len:
		rotation.z = 0.0
		change_state(_resume_state if _resume_state != &"" else &"Approach")

## Virtual: whether hits land at all right now.
func is_vulnerable() -> bool:
	return true

# ---- damage ----

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if puppet or state == &"Emerge" or hp <= 0 or not is_vulnerable():
		return
	if source is Player:
		last_hit = source.hit_kind
	hp -= amount
	var shoved := false
	var out := Vector3(global_position.x, 0.0, global_position.z).normalized()
	# On the ledge, a blow aimed outward sends it over the edge.
	if source != null and hp > 0 and mass < SHOVE_MAX_MASS and Terrain.on_ledge(global_position.x, global_position.z):
		shoved = Vector3(from_dir.x, 0.0, from_dir.z).dot(out) > SHOVE_DOT
	if rig != null and source != null and hp > 0:
		var flat := Vector3(from_dir.x, 0.0, from_dir.z).normalized()
		# Blows wear its footing down: the one that breaks it knocks it flat.
		_poise += 1
		_poise_t = POISE_TIME
		var floored := shoved or (_poise >= poise_hits and can_ragdoll())
		if floored:
			_poise = 0
			var push := (out * SHOVE_IMPULSE + Vector3(0.0, 1.2, 0.0)) if shoved else (flat * HIT_IMPULSE + Vector3(0.0, 1.0, 0.0))
			knock_down(push * rig.mass * 10.0)
		if state != &"Ragdoll" and not rig.is_ragdoll():
			hit_reaction(from_dir)
	else:
		_knock += Vector3(from_dir.x, 0.0, from_dir.z) * (KNOCKBACK / mass)
		if shoved:
			_knock = out * SHOVE_SPEED
	if source != null:
		FX.spray(get_parent(), global_position + Vector3(0.0, 1.1, 0.0), from_dir, Color(0.55, 0.65, 0.45))
		Audio.sfx("hit", global_position)
	_on_hit()
	if hp <= 0:
		hp = 0
		_die()

# Virtual: visual reaction to a hit.
func _on_hit() -> void:
	pass

func _die() -> void:
	Events.enemy_killed.emit(self)
	if not _ragdoll_corpse(Vector3(0.0, 20.0, 0.0)):
		queue_free()
