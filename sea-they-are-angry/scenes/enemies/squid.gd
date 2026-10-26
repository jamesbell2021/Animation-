class_name Squid
extends Enemy
## The Wall-Crawling Squid: low, quick and clinging. It takes no path. It scuttles
## straight at the nearest keeper over anything in the way (beaches, cliffs, the crag's
## walls, fences) in dashes and pauses, lunges, then backs off. Every so often it
## squirts a cloud of ink that hides the other creatures from all but the beam.
## With no keeper outside, it goes for the lighthouse door.

const DASH_SPEED := 4.5
const DASH_TIME := 1.0
const PAUSE_TIME := 0.6
const LUNGE_RANGE := 1.5
# The tell before it strikes: it coils back, arms cocked, and the dots flash.
const LUNGE_TELL := 0.65
const LUNGE_DMG := 10
const BACK_OFF := 3.0
const INK_EVERY := 8.0
const LIGHT_SLOW := 0.4
const BEAM_DPS := 15.0
const CLIMB_TIME := 0.9
const CLIMB_SPEED := 2.0
const BODY := Color(0.25, 0.3, 0.4)
const DOTS := Color(0.3, 0.9, 0.9)
const LIT_TINT := Color(0.75, 0.82, 0.9)
const BURN_TINT := Color(1.0, 0.55, 0.3)

var _visual: Node3D
var _body_mat: StandardMaterial3D
var _dot_mat: StandardMaterial3D
var _tentacles: Array[Node3D] = []
var _squeal: Label3D
var _dashing := true
var _phase_t := 0.0
var _ink_t := 4.0
var _climb_t := 0.0
var _burn_acc := 0.0
var _lit_t := 0.0
var _burn_t := 0.0
var _steam_t := 0.0
var _squeal_t := 0.0
var _back_dir := Vector3.ZERO
var _struck := false
const PHYS := {
	"mantle": [0.2, 0, 0], "arm0": [0.045, 50, 25], "arm1": [0.045, 50, 25], "arm2": [0.045, 50, 25],
	"arm3": [0.045, 50, 25], "arm4": [0.045, 50, 25], "arm5": [0.045, 50, 25],
}

func _init() -> void:
	max_hp = 35
	hp = 35
	speed = 2.2
	mass = 0.8
	turn_rate = 10.0
	reach = LUNGE_RANGE

func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_body_mat = Look.flat_mat(BODY, 0.3)
	_dot_mat = Look.glow_mat(DOTS, 2.0)
	_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _load_rig("squid", _visual):
		rig.physics = PHYS
		rig.mass = 0.8
		rig.thickness = 1.0
		var eye := Color(0.4, 1.0, 0.95)
		_rig_eye("eye.L", eye, 0.3)
		_rig_eye("eye.R", eye, 0.3)
		# Bioluminescent dots down each arm: they flash before it lunges.
		for i in 6:
			for seg in ["b", "c"]:
				var dot := MeshInstance3D.new()
				var dm := SphereMesh.new()
				dm.radius = 0.035
				dm.height = 0.07
				dm.radial_segments = 6
				dm.rings = 3
				dot.mesh = dm
				dot.material_override = _dot_mat
				dot.position = Vector3(0.0, 0.0, 0.03)
				rig.attach("arm%d.%s" % [i, seg], dot)
		_build_squeal()
		Geo.cyl_shape(self, 0.45, 0.6, Vector3(0.0, 0.35, 0.0))
		return
	var body := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 0.5
	m.radial_segments = 8
	m.rings = 4
	body.mesh = m
	body.material_override = _body_mat
	body.position.y = 0.3
	_visual.add_child(body)
	# A ridge of eyes along the mantle, facing forward.
	for side in [-1.0, 1.0]:
		var eye := Geo.sphere(_visual, 0.07, Color.WHITE, Vector3(side * 0.18, 0.48, -0.36))
		eye.material_override = Look.eye_mat(Color(0.4, 1.0, 0.95))
		Look.glint(_visual, Vector3(side * 0.18, 0.5, -0.42), Color(0.4, 1.0, 0.95))
	# Six splayed tentacles, each beaded with cyan dots.
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.5
		var arm := Node3D.new()
		arm.position = Vector3(0.0, 0.18, 0.0)
		arm.rotation.y = a
		_visual.add_child(arm)
		var t := Geo.box(arm, Vector3(0.09, 0.06, 0.95), Color.WHITE, Vector3(0.0, 0.0, -0.6))
		t.material_override = _body_mat
		for k in 3:
			var dot := Geo.sphere(arm, 0.035, Color.WHITE, Vector3(0.0, 0.05, -0.35 - 0.25 * float(k)))
			dot.material_override = _dot_mat
		_tentacles.append(arm)
	_build_squeal()
	Geo.cyl_shape(self, 0.45, 0.6, Vector3(0.0, 0.35, 0.0))

func _build_squeal() -> void:
	_squeal = Label3D.new()
	_squeal.text = "!"
	_squeal.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_squeal.no_depth_test = true
	_squeal.fixed_size = true
	_squeal.pixel_size = 0.002
	_squeal.font_size = 40
	_squeal.outline_size = 8
	_squeal.modulate = Color(1.0, 0.6, 0.3)
	_squeal.position.y = 1.3
	_squeal.visible = false
	add_child(_squeal)

func light_probe_points() -> Array:
	return [global_position + Vector3(0.0, 0.2, 0.0), global_position + Vector3(0.0, 0.5, 0.0)]

func pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Player) or p.downed or p.is_inside() or p.hp <= 0:
			continue
		if not Enemy.same_island(global_position, p.global_position):
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	if best != null:
		return best
	return Enemy.nearest_camp(global_position) if camp_raid else lighthouse

# Distance to strike at: the keeper, or the lighthouse's wall.
func _gap() -> float:
	if target == null or not is_instance_valid(target):
		return INF
	if target is Structure:
		return target.surface_distance(global_position)
	return Geo.flat_dist(global_position, target.global_position)

# ---- states ----

func _enter_Approach() -> void:
	change_state(&"Stalk")

func _enter_Stalk() -> void:
	target = pick_target()
	_dashing = true
	_phase_t = 0.0
	if randf() < 0.5:
		Audio.sfx("squid_click", global_position, -6.0, 0.15)

func _tick_Stalk(delta: float) -> void:
	_phase_t += delta
	if _dashing and _phase_t >= DASH_TIME:
		_dashing = false
		_phase_t = 0.0
	elif not _dashing and _phase_t >= PAUSE_TIME:
		_dashing = true
		_phase_t = 0.0
		target = pick_target()
	if target == null or not is_instance_valid(target):
		velocity = Vector3.ZERO
		return
	if _gap() < LUNGE_RANGE:
		change_state(&"Lunge")
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dir := to.normalized()
	face(dir)
	var spd := DASH_SPEED if _dashing else 0.0
	_climb_over(delta)
	if _climb_t > 0.0:
		spd = CLIMB_SPEED
	velocity = dir * spd * speed_mult
	_crawl(dir)
	_ink(delta)

var _lunge_shot := false

func _enter_Lunge() -> void:
	velocity = Vector3.ZERO
	_struck = false
	_lunge_shot = false

func _tick_Lunge(delta: float) -> void:
	velocity = Vector3.ZERO
	if target == null or not is_instance_valid(target):
		change_state(&"Stalk")
		return
	face(target.global_position - global_position)
	# The tell: it coils, the dots flash, then it strikes.
	var flash := int(state_t / (LUNGE_TELL / 4.0)) % 2 == 0
	_dot_mat.emission_energy_multiplier = 6.0 if flash and state_t < LUNGE_TELL else 2.0
	# The lunge clip coils first and snaps the arms shut as the strike lands.
	if rig != null and rig.has_clips() and not _lunge_shot and state_t >= LUNGE_TELL - rig.hit_time("lunge"):
		_lunge_shot = true
		rig.shot("lunge")
	if state_t >= LUNGE_TELL and not _struck:
		_struck = true
		Audio.sfx("swing", global_position, -4.0, 0.2)
		if _gap() < LUNGE_RANGE + 0.6:
			if target is Player:
				target.take_damage(LUNGE_DMG, global_position)
			elif target is Structure:
				target.take_damage(LUNGE_DMG)
		_crawl(Vector3.ZERO)
	if state_t >= LUNGE_TELL + 0.15:
		_dot_mat.emission_energy_multiplier = 2.0
		change_state(&"BackOff")

func _enter_BackOff() -> void:
	var away := global_position - (target.global_position if target != null and is_instance_valid(target) else Vector3.ZERO)
	away.y = 0.0
	_back_dir = away.normalized() if away.length() > 0.01 else Vector3.RIGHT

func _tick_BackOff(delta: float) -> void:
	face(-_back_dir)
	velocity = _back_dir * DASH_SPEED * speed_mult
	_crawl(_back_dir)
	_ink(delta)
	if state_t >= BACK_OFF / DASH_SPEED:
		change_state(&"Stalk")

# Clings to whatever it's on: no falling, it just crawls down or up the face.
func _crawl(dir: Vector3) -> void:
	position.y = maxf(ground_y(), Terrain.SEA_LEVEL - 0.5) + _climb_lift()
	# Lean into slopes so it reads as clinging to the rock.
	if dir != Vector3.ZERO:
		var ahead := global_position + dir * 0.6
		var rise := Terrain.height_at(ahead.x, ahead.z) - ground_y()
		_visual.rotation.x = clampf(atan2(rise, 0.6), -1.2, 1.2)

func _climb_lift() -> float:
	return sin(clampf(_climb_t / CLIMB_TIME, 0.0, 1.0) * PI) * 1.4 if _climb_t > 0.0 else 0.0

# Over fences and buildings: it goes up and over them instead of battering them.
func _climb_over(delta: float) -> void:
	if _climb_t > 0.0:
		_climb_t -= delta
		if _climb_t <= 0.0:
			collision_mask = 2 | 4
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col is Structure and col != target:
			_climb_t = CLIMB_TIME
			collision_mask = 2
			return

func _ink(delta: float) -> void:
	_ink_t -= delta
	if _ink_t <= 0.0:
		_ink_t = INK_EVERY
		var cloud := InkCloud.new()
		get_parent().add_child(cloud)
		cloud.global_position = global_position
		Net.relay_shot("ink", [global_position])
		Audio.sfx("squid_ink", global_position, -2.0, 0.1)

func in_light(mode: int, delta: float) -> void:
	speed_mult = LIGHT_SLOW
	_lit_t = 0.15
	if mode == Lamp.Mode.FOCUSED and state != &"Emerge":
		_burn_t = 0.15
		_burn_acc += BEAM_DPS * Lamp.dps_mult * delta
		var dmg := floori(_burn_acc)
		if dmg > 0:
			_burn_acc -= float(dmg)
			last_hit = "beam"
			take_damage(dmg, Vector3.ZERO, null)
		# Seared where it stands: it writhes, fries and crackles, and shrieks.
		burn_tick(delta, "squid_squeal", -2.0, global_position + Vector3(0.0, 0.5, 0.0))
		_steam_t -= delta
		if _steam_t <= 0.0:
			_steam_t = 0.16
			FX.steam(get_parent(), global_position + Vector3(randf_range(-0.3, 0.3), 0.6, randf_range(-0.3, 0.3)))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_inside_tree():
		return
	_lit_t = maxf(0.0, _lit_t - delta)
	_burn_t = maxf(0.0, _burn_t - delta)
	var c := BODY
	if _lit_t > 0.0:
		c = c.lerp(LIT_TINT, 0.5)
	if _burn_t > 0.0:
		c = c.lerp(BURN_TINT, 0.6 + 0.3 * sin(state_t * 40.0))
	_squeal.visible = _burn_t > 0.0 and visible
	# Tentacles ripple, faster when dashing.
	var rate := 14.0 if velocity.length() > 1.0 else 4.0
	if rig != null:
		rig.tint(Color(c.r / BODY.r, c.g / BODY.g, c.b / BODY.b).lerp(Color.WHITE, 0.4))
		if not rig.is_ragdoll() and not rig.has_clips():
			for i in 6:
				for k in 3:
					var w := sin(state_t * rate + float(i) * 1.1 + float(k) * 0.9) * (0.22 + 0.08 * float(k))
					rig.pose("arm%d.%s" % [i, ["a", "b", "c"][k]], Vector3(w * 0.4, w, 0.0))
		return
	_body_mat.albedo_color = c
	for i in _tentacles.size():
		_tentacles[i].rotation.x = sin(state_t * rate + float(i) * 1.1) * 0.25

func on_dawn() -> void:
	_visual.rotation.x = 0.0
	collision_mask = 2 | 4
	super.on_dawn()

func _die() -> void:
	if last_hit == "beam":
		# Burnt up: a hiss of steam and a wet pop.
		Audio.sfx("burn_hiss", global_position + Vector3(0.0, 0.5, 0.0), 2.0, 0.05)
		Audio.sfx("pop", global_position + Vector3(0.0, 0.5, 0.0), 4.0, 0.1)
		FX.steam_burst(get_parent(), global_position + Vector3(0.0, 0.5, 0.0))
	FX.burst(get_parent(), global_position + Vector3(0.0, 0.4, 0.0))
	Audio.sfx("splash", global_position, -2.0, 0.2)
	super._die()
