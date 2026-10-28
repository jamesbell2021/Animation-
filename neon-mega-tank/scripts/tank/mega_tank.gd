class_name MegaTank
extends CharacterBody3D
## The crew's mega tank. Its open deck has four stations (DRIVE, CANNON, MG, REPAIR) that crew
## members walk between and board, Lovers-in-a-Dangerous-Spacetime style. Hits punch breaches
## into the deck that drain the hull and jam nearby stations until someone patches them.
##
## REPAIR is a timing game: a needle sweeps across a gauge and tapping ACTION while it is inside
## the green zone welds the hull (PERFECT in the bright middle heals most and builds a combo).
## Holding ACTION raises an energy shield around the whole tank until its charge runs out.

signal destroyed

const DECK_Y := 1.4
const DECK_HALF := Vector2(2.25, 3.7)
const MAX_HP := 200.0
const MAX_SPEED := 7.5
const ACCEL := 9.0
const TURN_RATE := 1.5
const TURRET_CENTER := Vector2(0.0, 0.5)
const MG_CENTER := Vector2(1.85, 3.25)
const REACTOR_CENTER := Vector2(-1.85, 3.25)
const CANNON_RELOAD := 1.0
const SHELL_SPEED := 42.0
const SHELL_RANGE := 46.0
## Turret slew: proportional to the error, capped, so big flicks are fast and small ones settle.
const TURRET_GAIN := 16.0
const TURRET_MAX_RATE := 11.0
## A press while the turret is still swinging fires as soon as it lines up (within this time).
const FIRE_BUFFER := 0.35
const FIRE_ALIGN := 0.1
## Stick input below this (after the controller deadzone) leaves the aim alone.
const AIM_THRESHOLD := 0.12
const MG_INTERVAL := 0.075
const MG_HEAT_PER_SHOT := 5.5
const BREACH_DRAIN := 1.0
const MAX_BREACHES := 5
const JAM_RADIUS := 1.3

## Repair gauge: the needle runs 0..1 and back; the zone is centre +- half width.
const NEEDLE_SPEED := 1.6
const NEEDLE_SPEED_PER_COMBO := 0.1
const ZONE_HALF := 0.14
const ZONE_HALF_MIN := 0.075
const PERFECT_FRACTION := 0.38
const HEAL_PERFECT := 12.0
const HEAL_GOOD := 6.0
const MISS_STUN := 0.45
## Energy shield: hold ACTION on REPAIR. Drains while up, recharges while down.
const SHIELD_MAX := 100.0
const SHIELD_DRAIN := 22.0
const SHIELD_REGEN := 3.5
const SHIELD_MIN := 15.0
const SHIELD_HOLD := 0.22
const SHIELD_BREAK_LOCK := 2.5
const SHIELD_RX := 5.0
const SHIELD_RZ := 6.2


class Station:
	var id := ""
	var title := ""
	var pos := Vector2.ZERO
	var look := Vector2.ZERO
	var occupant: Crew = null
	var jammed := false
	var pad: MeshInstance3D
	var label: Label3D


var hp := MAX_HP
var dead := false
## Demo over: nothing can hurt the tank any more.
var invulnerable := false
## LAN client: the tank only mirrors the host's snapshots.
var puppet := false
var _net := []
var _breach_ids := {}
var speed := 0.0
var stations := {}
var breaches: Array[Breach] = []
var meshes: Array[MeshInstance3D] = []
var crew_members: Array[Crew] = []

var turret: Node3D
var barrels: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var cannon_laser: MeshInstance3D
var cannon_cd := 0.0
var cannon_side := 0
var turret_yaw := 0.0
## Enemy the cannon's aim assist is tracking (host), shown with a lock ring on every screen.
var aim_target: Enemy
var _aim_target_id := 0
var _lock_t := 0.0
var _fire_wanted := 0.0
var _reticle: Node3D
var _reticle_parts: Array[MeshInstance3D] = []
var _lock_ring: Node3D
var _lock_parts: Array[MeshInstance3D] = []

var mg_pivot: Node3D
var mg_muzzle: Node3D
var mg_laser: MeshInstance3D
var mg_yaw := 0.0
var mg_cd := 0.0
var mg_heat := 0.0
var mg_overheated := false

var reactor: MeshInstance3D
## Someone is working the REPAIR station (drives the reactor glow).
var repairing := false
var needle_phase := 0.0
var zone_center := 0.5
var zone_half := ZONE_HALF
var combo := 0
var rep_stun := 0.0
## Last judged tap, for the HUD: "perfect" / "good" / "miss", counted so phones see each one.
var last_grade := ""
var grade_seq := 0
var last_heal := 0.0
var shield := SHIELD_MAX * 0.5
var shield_up := false
var shield_lock := 0.0
var _hold_t := 0.0
## After the shield breaks, ACTION has to be let go before it can be raised again.
var _need_release := false
var _pending_miss := 0.0
var _miss_combo := 0
var _shield_mesh: MeshInstance3D
var _shield_mat: ShaderMaterial
var _shield_vis := 0.0
var _shield_hit_t := 9.0

var _lugs: Array[MeshInstance3D] = []
var _tread_phase := 0.0
var _hit_flash_cd := 0.0
var _time := 0.0
## Deck obstacles crew walk around: [centre, radius].
var obstacles := [[TURRET_CENTER, 1.35], [MG_CENTER, 0.45], [REACTOR_CENTER, 0.6]]


func _ready() -> void:
	collision_layer = G.LAYER_PLAYER
	collision_mask = G.LAYER_TERRAIN | G.LAYER_ENEMY
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	cs.shape = G.box_shape(Vector3(6.6, 2.0, 8.8))
	cs.position.y = 1.0
	add_child(cs)
	_build_hull()
	_build_turret()
	_build_mg()
	_build_shield()
	_new_zone()
	_add_station("drive", "DRIVE", Vector2(0.0, -2.9), Vector2(0.0, -6.0))
	_add_station("cannon", "CANNON", Vector2(-1.65, 0.5), TURRET_CENTER)
	_add_station("mg", "MG", Vector2(1.45, 2.55), MG_CENTER)
	_add_station("repair", "REPAIR", Vector2(-1.45, 2.55), REACTOR_CENTER)
	turret_yaw = global_rotation.y
	mg_yaw = global_rotation.y


func _part(size: Vector3, pos: Vector3, color := Color(0.4, 0.95, 1.0), energy := 2.4,
		parent: Node = null) -> MeshInstance3D:
	# Tank parts overlap a lot, so they glow less than terrain to avoid blooming into a blob.
	var m := G.neon_box(parent if parent else self, size, pos, color, energy * 0.6)
	meshes.append(m)
	return m


func _build_hull() -> void:
	var dim := G.TANK_COLOR.darkened(0.25)
	_part(Vector3(5.0, 1.0, 8.0), Vector3(0, 0.9, 0))
	var glacis := _part(Vector3(5.0, 0.7, 1.0), Vector3(0, 0.75, -4.25))
	glacis.rotation_degrees.x = 35.0
	_part(Vector3(4.6, 0.6, 0.6), Vector3(0, 1.0, 4.25), dim)
	for side in [-1.0, 1.0]:
		_part(Vector3(1.2, 1.1, 8.8), Vector3(side * 3.0, 0.55, 0), G.TANK_COLOR, 2.0)
		_part(Vector3(1.4, 0.15, 9.0), Vector3(side * 3.0, 1.2, 0), dim, 1.6)
		for i in 10:
			var lug := _part(Vector3(1.25, 0.1, 0.3), Vector3(side * 3.0, 1.12, 0), dim, 2.6)
			_lugs.append(lug)
		_part(Vector3(0.12, 0.25, 7.6), Vector3(side * 2.45, DECK_Y + 0.12, 0), G.TANK_COLOR, 1.8)
		_part(Vector3(0.5, 0.9, 0.5), Vector3(side * 1.4, 1.6, 4.4), dim)
	_part(Vector3(4.9, 0.25, 0.12), Vector3(0, DECK_Y + 0.12, -3.95), G.TANK_COLOR, 1.8)
	_part(Vector3(4.9, 0.25, 0.12), Vector3(0, DECK_Y + 0.12, 3.95), G.TANK_COLOR, 1.8)
	_part(Vector3(3.0, 0.35, 0.15), Vector3(0, DECK_Y + 0.2, -3.75), Color(0.8, 1.0, 1.0), 3.5)


func _build_turret() -> void:
	turret = Node3D.new()
	turret.position = Vector3(TURRET_CENTER.x, DECK_Y, TURRET_CENTER.y)
	add_child(turret)
	_part(Vector3(2.4, 1.3, 2.7), Vector3(0, 0.65, 0), G.TANK_COLOR, 2.6, turret)
	_part(Vector3(1.0, 0.4, 1.0), Vector3(0.4, 1.5, 0.5), G.TANK_COLOR, 2.0, turret)
	_part(Vector3(1.6, 0.5, 0.8), Vector3(0, 0.9, 1.55), G.TANK_COLOR.darkened(0.2), 2.0, turret)
	for side in [-1.0, 1.0]:
		var barrel := Node3D.new()
		barrel.position = Vector3(side * 0.42, 1.25, 0)
		turret.add_child(barrel)
		_part(Vector3(0.34, 0.34, 4.4), Vector3(0, 0, -3.3), G.TANK_COLOR, 2.8, barrel)
		_part(Vector3(0.55, 0.55, 0.7), Vector3(0, 0, -5.4), Color(0.9, 1.0, 1.0), 3.2, barrel)
		var muzzle := Node3D.new()
		muzzle.position = Vector3(0, 0, -5.9)
		barrel.add_child(muzzle)
		barrels.append(barrel)
		muzzles.append(muzzle)
	# Unit-length laser, stretched every frame to wherever the shell would land.
	cannon_laser = G.neon_box(turret, Vector3(0.05, 0.05, 1.0), Vector3(0, 1.25, -21.0), Color.WHITE, 1.2)
	cannon_laser.visible = false
	# Landing reticle on the ground at the end of the laser.
	_reticle = Node3D.new()
	_reticle.top_level = true
	add_child(_reticle)
	for a in [0.0, 90.0]:
		var bar := G.neon_box(_reticle, Vector3(1.6, 0.05, 0.12), Vector3(0, 0.08, 0), Color.WHITE, 3.0, false, true)
		bar.rotation_degrees.y = a
		_reticle_parts.append(bar)
	for i in 4:
		var side := G.neon_box(_reticle, Vector3(0.9, 0.05, 0.1), Vector3.ZERO, Color.WHITE, 2.4, false, true)
		var ang := i * PI * 0.5
		side.position = Vector3(sin(ang), 0.08, cos(ang)) * 0.9
		side.rotation.y = ang
		_reticle_parts.append(side)
	_reticle.visible = false
	# Lock ring under the enemy the aim assist is tracking.
	_lock_ring = Node3D.new()
	_lock_ring.top_level = true
	add_child(_lock_ring)
	for i in 4:
		var ang := i * PI * 0.5 + PI * 0.25
		var corner := G.neon_box(_lock_ring, Vector3(0.9, 0.05, 0.14), Vector3(sin(ang), 0.1, cos(ang)) * 1.9,
				Color.WHITE, 3.5, false, true)
		corner.rotation.y = ang + PI * 0.5
		_lock_parts.append(corner)
	_lock_ring.visible = false


func _build_mg() -> void:
	var base := Node3D.new()
	base.position = Vector3(MG_CENTER.x, DECK_Y, MG_CENTER.y)
	add_child(base)
	_part(Vector3(0.35, 0.8, 0.35), Vector3(0, 0.4, 0), G.TANK_COLOR, 2.0, base)
	mg_pivot = Node3D.new()
	mg_pivot.position = Vector3(0, 0.9, 0)
	base.add_child(mg_pivot)
	_part(Vector3(0.45, 0.35, 0.7), Vector3(0, 0, 0), G.TANK_COLOR, 2.6, mg_pivot)
	_part(Vector3(0.14, 0.14, 1.5), Vector3(-0.08, 0.02, -1.0), G.TANK_COLOR, 3.0, mg_pivot)
	_part(Vector3(0.14, 0.14, 1.5), Vector3(0.08, 0.02, -1.0), G.TANK_COLOR, 3.0, mg_pivot)
	mg_muzzle = Node3D.new()
	mg_muzzle.position = Vector3(0, 0, -1.8)
	mg_pivot.add_child(mg_muzzle)
	mg_laser = G.neon_box(mg_pivot, Vector3(0.04, 0.04, 18.0), Vector3(0, 0, -10.8), Color.WHITE, 1.0)
	mg_laser.visible = false
	reactor = _part(Vector3(0.8, 1.0, 0.8), Vector3(REACTOR_CENTER.x, DECK_Y + 0.5, REACTOR_CENTER.y),
			Color(0.3, 1.0, 0.5), 2.0)
	reactor.set_instance_shader_parameter("windows", 1.0)


## The energy bubble: a squashed sphere around the whole tank, drawn by shaders/shield.gdshader.
func _build_shield() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 40
	sphere.rings = 20
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.mesh = sphere
	_shield_mat = ShaderMaterial.new()
	_shield_mat.shader = load("res://shaders/shield.gdshader")
	_shield_mesh.material_override = _shield_mat
	_shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_mesh.scale = Vector3(SHIELD_RX, 3.0, SHIELD_RZ)
	_shield_mesh.position.y = 0.6
	_shield_mesh.visible = false
	add_child(_shield_mesh)


func _add_station(id: String, title: String, pos: Vector2, look: Vector2) -> void:
	var st := Station.new()
	st.id = id
	st.title = title
	st.pos = pos
	st.look = look
	st.pad = G.neon_box(self, Vector3(1.0, 0.05, 1.0), Vector3(pos.x, DECK_Y + 0.03, pos.y), Color.WHITE, 1.2)
	st.label = Label3D.new()
	st.label.text = G.t(title)
	st.label.font = G.ui_font
	st.label.font_size = 36
	st.label.outline_size = 10
	st.label.pixel_size = 0.009
	st.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	st.label.no_depth_test = true
	st.label.render_priority = 5
	st.label.position = Vector3(pos.x, DECK_Y + 0.15, pos.y + 0.55)
	add_child(st.label)
	stations[id] = st


# --- Crew API --------------------------------------------------------------------------------

func add_crew(crew: Crew, slot: int) -> void:
	var spots := [Vector2(0.0, -1.5), Vector2(-1.2, 2.0), Vector2(1.2, 2.0), Vector2(0.0, 3.0)]
	crew.deck_pos = spots[slot % spots.size()]
	crew_members.append(crew)
	add_child(crew)


func nearest_free_station(p: Vector2, max_dist := 1.1, bots_count_as_free := false) -> Station:
	var best: Station = null
	var best_d := max_dist
	for st: Station in stations.values():
		var d := st.pos.distance_to(p)
		var free := st.occupant == null or (bots_count_as_free and st.occupant.is_bot())
		if free and d < best_d:
			best = st
			best_d = d
	return best


func occupy(st: Station, crew: Crew) -> void:
	st.occupant = crew
	crew.station = st
	crew.deck_pos = st.pos
	G.sfx("station", -4.0)


func leave(crew: Crew) -> void:
	if crew.station:
		crew.station.occupant = null
		crew.station = null
		G.sfx("leave", -6.0)


func clamp_deck(p: Vector2) -> Vector2:
	p.x = clampf(p.x, -DECK_HALF.x, DECK_HALF.x)
	p.y = clampf(p.y, -DECK_HALF.y, DECK_HALF.y)
	for o in obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1]
		var off := p - c
		if off.length() < r:
			p = c + (off.normalized() if off.length() > 0.01 else Vector2.RIGHT) * r
	p.x = clampf(p.x, -DECK_HALF.x, DECK_HALF.x)
	p.y = clampf(p.y, -DECK_HALF.y, DECK_HALF.y)
	return p


## Called every frame while a crew member holds ACTION off-station. Returns true if fixing.
func fix_breach_near(p: Vector2, delta: float) -> bool:
	var best: Breach = null
	var best_d := 1.3
	for b in breaches:
		var d := b.deck_pos.distance_to(p)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return false
	best.progress += delta / 1.3
	if best.progress >= 1.0:
		breaches.erase(best)
		G.sparks(best.global_position + Vector3(0, 0.3, 0), Color(0.3, 1.0, 0.5), 12, 4.0)
		G.sfx("fix", -2.0)
		best.queue_free()
	return true


# --- Simulation ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	_hit_flash_cd -= delta
	if dead or puppet:
		return
	_update_jams()
	_drive(delta)
	_machine_gun(delta)
	if not breaches.is_empty() and not invulnerable:
		hp -= BREACH_DRAIN * breaches.size() * delta
		if hp <= 0.0:
			_die()


func _manned(id: String) -> Crew:
	var st: Station = stations[id]
	return st.occupant if not st.jammed else null


func _update_jams() -> void:
	for st: Station in stations.values():
		st.jammed = false
		for b in breaches:
			if b.deck_pos.distance_to(st.pos) < JAM_RADIUS:
				st.jammed = true


func _drive(delta: float) -> void:
	var driver := _manned("drive")
	var target_speed := 0.0
	if driver:
		var want := G.main.stick_to_world(driver.input.move)
		if want.length() > 0.2:
			var dir := want.normalized()
			var fwd := -global_basis.z
			var ang := fwd.signed_angle_to(dir, Vector3.UP)
			var reverse := absf(ang) > deg_to_rad(125.0)
			if reverse:
				ang = (-fwd).signed_angle_to(dir, Vector3.UP)
			rotate_y(clampf(ang, -TURN_RATE * delta, TURN_RATE * delta))
			var align := maxf(0.0, cos(ang))
			target_speed = MAX_SPEED * minf(want.length(), 1.0) * align * align * (-0.6 if reverse else 1.0)
	speed = move_toward(speed, target_speed, ACCEL * delta)
	velocity = -global_basis.z * speed
	move_and_slide()
	global_position.y = 0.0
	_tread_phase += speed * delta
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other is Block:
			var b: Block = other
			if b.crushable:
				b.take_damage(999.0, global_position, G.Team.PLAYER)
				G.sfx("crush", -4.0)
			elif absf(speed) > 1.5:
				b.take_damage(55.0 * delta, global_position, G.Team.PLAYER)
		elif other is Soldier:
			(other as Soldier).crush()
		elif other is MortarTeam:
			(other as MortarTeam).crush()
		elif other is Buggy:
			(other as Buggy).detonate()
		elif other is EnemyTank and absf(speed) > 1.5:
			(other as EnemyTank).take_damage(30.0 * delta, global_position, G.Team.PLAYER)


## Runs every rendered frame (not physics ticks), so a quick tap is never missed and the turret
## answers the stick on the very next frame.
func _cannon(delta: float) -> void:
	cannon_cd = maxf(0.0, cannon_cd - delta)
	_fire_wanted = maxf(0.0, _fire_wanted - delta)
	var gunner := _manned("cannon")
	if gunner:
		var stick := gunner.input.aim
		if stick.length() > AIM_THRESHOLD:
			var dir := G.main.stick_to_world(stick).normalized()
			_lock_t = 3.0
			aim_target = _assist_target(dir, gunner.input.device)
			turret_yaw = _yaw_to(aim_target) if aim_target != null else atan2(-dir.x, -dir.z)
		elif is_instance_valid(aim_target) and not aim_target.dead and _lock_t > 0.0:
			# Stick released after a flick: keep tracking the locked enemy for a few seconds.
			_lock_t -= delta
			turret_yaw = _yaw_to(aim_target)
		else:
			aim_target = null
		if gunner.input.action_pressed or gunner.input.action_held:
			_fire_wanted = FIRE_BUFFER
	else:
		aim_target = null
		_fire_wanted = 0.0
	var diff := _slew_turret(delta)
	if gunner and _fire_wanted > 0.0 and cannon_cd <= 0.0 and absf(diff) < FIRE_ALIGN:
		_fire_wanted = 0.0
		_fire_cannon(gunner.color)
		G.rumble(gunner.input, 0.35, 0.9, 0.16)
	_aim_target_id = aim_target.net_id if is_instance_valid(aim_target) else 0


## Turns the turret toward turret_yaw; returns the remaining error.
func _slew_turret(delta: float) -> float:
	var diff := wrapf(turret_yaw - turret.global_rotation.y, -PI, PI)
	var rate := minf(TURRET_MAX_RATE, maxf(2.0, absf(diff) * TURRET_GAIN))
	turret.rotation.y += clampf(diff, -rate * delta, rate * delta)
	return wrapf(turret_yaw - turret.global_rotation.y, -PI, PI)


## Aim assist: the enemy closest to the aim line, if it is near enough to it. Keyboards can only
## point 8 ways, so they get a wide cone; sticks and touch get a narrow one.
func _assist_target(dir: Vector3, device: int) -> Enemy:
	var origin := turret.global_position
	var keyboard := device == PlayerInput.KEYBOARD_1 or device == PlayerInput.KEYBOARD_2
	var cone := 0.42 if keyboard else 0.16
	var best: Enemy = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		var to := e.global_position - origin
		to.y = 0.0
		var dist := to.length()
		if dist > SHELL_RANGE or dist < 3.0:
			continue
		var ang := absf(dir.signed_angle_to(to, Vector3.UP))
		# Allow about 2 m either side of the line up close, never less than the cone further out.
		var tolerance := maxf(cone, atan2(2.2, dist))
		if ang > tolerance:
			continue
		var score := ang / tolerance + dist / SHELL_RANGE * 0.5
		if score < best_score:
			best = e
			best_score = score
	return best


## World yaw from the turret to an enemy, leading it by the shell's flight time.
func _yaw_to(e: Enemy) -> float:
	var to := e.global_position - turret.global_position
	to += e.velocity * (to.length() / SHELL_SPEED)
	return atan2(-to.x, -to.z)


func _fire_cannon(color: Color) -> void:
	cannon_cd = CANNON_RELOAD
	var muzzle := muzzles[cannon_side]
	var barrel := barrels[cannon_side]
	cannon_side = 1 - cannon_side
	var dir := -muzzle.global_basis.z
	dir.y = 0.0
	G.spawn_projectile(muzzle.global_position, dir.normalized() * SHELL_SPEED, G.Team.PLAYER, "shell",
			color.lerp(Color.WHITE, 0.4))
	G.ring(muzzle.global_position, color, 1.6, 0.25, muzzle.global_position.y)
	G.sparks(muzzle.global_position, Color(1, 0.9, 0.6), 8, 6.0, 0.3, 0.15, 0.0)
	G.add_shake(0.35)
	G.sfx("cannon", 2.0)
	var tw := barrel.create_tween()
	tw.tween_property(barrel, "position:z", 0.6, 0.05)
	tw.tween_property(barrel, "position:z", 0.0, 0.4)


## Stretches the laser to where a shell would stop and puts the reticle there (every screen).
func _update_aim_visuals(gunner: Crew) -> void:
	var show := gunner != null and not dead
	cannon_laser.visible = show
	_reticle.visible = show
	# Untyped on purpose: the target may have been freed this frame.
	var target: Variant = null
	if puppet:
		if _aim_target_id != 0 and G.main:
			target = G.main.puppet_by_id(_aim_target_id)
	elif is_instance_valid(aim_target):
		target = aim_target
	_lock_ring.visible = show and is_instance_valid(target) and not (target as Enemy).dead
	if not show:
		return
	var col := gunner.color
	var dir := -turret.global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	# Cast at the height shells actually fly (Projectile.FLIGHT_HEIGHT), from the muzzles.
	var base := turret.global_position
	var from := Vector3(base.x, Projectile.FLIGHT_HEIGHT, base.z) + dir * 5.9
	var to := from + dir * SHELL_RANGE
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, to, G.LAYER_TERRAIN | G.LAYER_ENEMY))
	var end: Vector3 = hit["position"] if not hit.is_empty() else to
	var length := maxf(from.distance_to(end), 0.5)
	cannon_laser.scale = Vector3(1, 1, length)
	cannon_laser.position = Vector3(0, 1.25, -5.9 - length * 0.5)
	var ready := cannon_cd <= 0.0
	G.set_neon(cannon_laser, col, 1.6 if ready else 0.7)
	_reticle.global_position = Vector3(end.x, 0.0, end.z)
	_reticle.rotation.y = turret.global_rotation.y + (0.0 if ready else _time * 4.0)
	var pulse := (2.5 + sin(_time * 10.0) * 1.2) if ready else 1.0
	_reticle.scale = Vector3.ONE * (1.0 if ready else 0.7)
	for m in _reticle_parts:
		G.set_neon(m, col, pulse)
	if _lock_ring.visible:
		var e: Enemy = target
		_lock_ring.global_position = Vector3(e.global_position.x, 0.0, e.global_position.z)
		_lock_ring.rotation.y = _time * 2.0
		var big := 1.6 if e is EnemyTank or e is BossTank or e is Gunship else 1.0
		_lock_ring.scale = Vector3.ONE * big * (1.0 + 0.12 * sin(_time * 12.0))
		for m in _lock_parts:
			G.set_neon(m, col.lerp(Color.WHITE, 0.3), 4.0)


func _machine_gun(delta: float) -> void:
	mg_cd -= delta
	mg_heat = maxf(0.0, mg_heat - (40.0 if mg_overheated else 28.0) * delta)
	if mg_overheated and mg_heat < 25.0:
		mg_overheated = false
	var gunner := _manned("mg")
	mg_laser.visible = gunner != null and not mg_overheated
	if gunner:
		G.set_neon(mg_laser, gunner.color, 1.0)
		var aim := G.main.stick_to_world(gunner.input.aim)
		if gunner.input.aim.length() > AIM_THRESHOLD:
			mg_yaw = atan2(-aim.x, -aim.z)
		if gunner.input.action_held and not mg_overheated and mg_cd <= 0.0:
			_fire_mg(gunner.color)
			if mg_cd > 0.0 and fmod(_time, 0.15) < 0.02:
				G.rumble(gunner.input, 0.25, 0.0, 0.06)
	var diff := wrapf(mg_yaw - mg_pivot.global_rotation.y, -PI, PI)
	var rate := minf(14.0, maxf(3.0, absf(diff) * 20.0))
	mg_pivot.rotation.y += clampf(diff, -rate * delta, rate * delta)


func _fire_mg(color: Color) -> void:
	mg_cd = MG_INTERVAL
	mg_heat += MG_HEAT_PER_SHOT
	if mg_heat >= 100.0:
		mg_overheated = true
		G.sfx("alarm", -8.0, 1.5)
	var dir := -mg_muzzle.global_basis.z
	dir.y = 0.0
	dir = dir.normalized().rotated(Vector3.UP, randf_range(-0.05, 0.05))
	G.spawn_projectile(mg_muzzle.global_position, dir * 48.0, G.Team.PLAYER, "bullet", color)
	G.sparks(mg_muzzle.global_position, color, 2, 3.0, 0.12, 0.1, 0.0)
	G.sfx("mg", -6.0)


# --- Repair gauge and energy shield ---------------------------------------------------------

## Needle position 0..1 (it sweeps there and back). LAN phones compute the same value locally.
func needle_now() -> float:
	return pingpong(needle_phase, 1.0)


func needle_speed() -> float:
	return NEEDLE_SPEED + minf(combo, 10) * NEEDLE_SPEED_PER_COMBO


## Moves the green zone somewhere the needle isn't, a little narrower as the combo grows.
func _new_zone() -> void:
	zone_half = maxf(ZONE_HALF_MIN, ZONE_HALF - combo * 0.006)
	var lo := zone_half + 0.04
	var hi := 1.0 - zone_half - 0.04
	var c := randf_range(lo, hi)
	for attempt in 6:
		if absf(c - needle_now()) > 0.28:
			break
		c = randf_range(lo, hi)
	zone_center = c


func _repair_game(delta: float) -> void:
	needle_phase += needle_speed() * delta
	rep_stun = maxf(0.0, rep_stun - delta)
	shield_lock = maxf(0.0, shield_lock - delta)
	if _pending_miss > 0.0:
		_pending_miss -= delta
		if _pending_miss <= 0.0:
			_show_grade("miss", 0.0)
	var mech := _manned("repair")
	repairing = mech != null
	if mech:
		if mech.input.action_pressed:
			_repair_tap(mech)
		if mech.input.action_held:
			_hold_t += delta
			if (not shield_up and not _need_release and _hold_t >= SHIELD_HOLD and shield_lock <= 0.0
					and shield >= SHIELD_MIN):
				_raise_shield(mech)
		else:
			_hold_t = 0.0
			_need_release = false
			if shield_up:
				_drop_shield(false)
	else:
		_hold_t = 0.0
		if shield_up:
			_drop_shield(false)
	if shield_up:
		shield -= SHIELD_DRAIN * delta
		if shield <= 0.0:
			_drop_shield(true)
	elif shield_lock <= 0.0:
		shield = minf(SHIELD_MAX, shield + SHIELD_REGEN * delta)


func _repair_tap(mech: Crew) -> void:
	if rep_stun > 0.0:
		return
	var p := mech.input.press_needle if mech.input.press_needle >= 0.0 else needle_now()
	var d := absf(p - zone_center)
	var spot := reactor.global_position + Vector3(0, 0.7, 0)
	if d > zone_half:
		# Judged a miss now, shown a moment later: if this press turns into a shield hold, it
		# was never meant as a tap and the combo is given back.
		_miss_combo = combo
		combo = 0
		rep_stun = MISS_STUN
		_pending_miss = SHIELD_HOLD + 0.03
		return
	var perfect := d <= zone_half * PERFECT_FRACTION
	var heal := (HEAL_PERFECT if perfect else HEAL_GOOD) * (1.0 + minf(combo, 8) * 0.08)
	combo += 1
	var healed := minf(heal, MAX_HP - hp)
	hp += healed
	shield = minf(SHIELD_MAX, shield + (12.0 if perfect else 5.0))
	_show_grade("perfect" if perfect else "good", healed)
	var green := Color(0.3, 1.0, 0.5)
	if perfect:
		G.sparks(spot, Color(0.6, 1.0, 0.7), 18, 7.0, 0.6, 0.14, -8.0)
		G.ring(global_position, green, 3.2, 0.3, DECK_Y + 0.2)
		G.sfx("perfect", -2.0, 1.0 + minf(combo, 12) * 0.045)
		G.rumble(mech.input, 0.5, 0.3, 0.1)
	else:
		G.sparks(spot, green, 8, 4.5, 0.45, 0.12, -6.0)
		G.sfx("weld", -4.0, 1.0 + minf(combo, 12) * 0.03)
		G.rumble(mech.input, 0.3, 0.0, 0.06)
	if combo > 0 and combo % 5 == 0:
		G.popup(spot + Vector3(0, 3.2, 0), ["COMBO x%d", combo], Color(1.0, 0.9, 0.3), 1.1)
	_new_zone()


func _show_grade(grade: String, healed: float) -> void:
	last_grade = grade
	last_heal = healed
	grade_seq += 1
	# Quick taps would stack their words on top of each other: step them sideways in turn.
	var step := (grade_seq % 3) - 1
	var spot := reactor.global_position + Vector3(0, 1.4, 0) + G.main.stick_to_world(Vector2(step * 1.6, 0.0))
	match grade:
		"perfect":
			G.popup(spot, ["PERFECT! +%d", int(round(healed))] if healed >= 1.0 else ["PERFECT! +SHIELD"],
					Color(0.4, 1.0, 0.6), 0.8)
		"good":
			G.popup(spot, ["GOOD +%d", int(round(healed))] if healed >= 1.0 else ["GOOD"], Color(0.6, 0.95, 1.0), 0.65)
		"miss":
			G.popup(spot, "MISS", Color(1.0, 0.3, 0.2), 0.65)
			G.sparks(spot, Color(1.0, 0.3, 0.1), 6, 3.0, 0.3, 0.1)
			G.sfx("fizzle", -6.0)


func _raise_shield(mech: Crew) -> void:
	shield_up = true
	if _pending_miss > 0.0:
		# That press was the start of a hold, not a tap.
		_pending_miss = 0.0
		combo = _miss_combo
		rep_stun = 0.0
	G.sfx("shield_up", -2.0)
	G.ring(global_position, Color(0.4, 0.9, 1.0), 7.0, 0.35, 1.2)
	G.rumble(mech.input, 0.2, 0.5, 0.15)


func _drop_shield(broken: bool) -> void:
	shield_up = false
	_hold_t = 0.0
	if broken:
		shield = 0.0
		shield_lock = SHIELD_BREAK_LOCK
		_need_release = true
		G.sfx("shield_break", 0.0)
		G.sparks(global_position + Vector3(0, 2.0, 0), Color(0.4, 0.9, 1.0), 30, 9.0, 0.7, 0.18, -6.0)
		G.popup(global_position + Vector3(0, 4.5, 0), "SHIELD DOWN", Color(1.0, 0.4, 0.3), 1.0)
	else:
		G.sfx("shield_down", -8.0)


## True if a point is inside the raised shield bubble.
func shield_covers(p: Vector3) -> bool:
	if not shield_up or dead:
		return false
	var local := to_local(p)
	return Vector2(local.x / SHIELD_RX, local.z / SHIELD_RZ).length() <= 1.0


## The shield soaks a hit: costs charge, ripples where it was struck. Host only.
func shield_block(pos: Vector3, amount: float) -> void:
	shield -= 1.0 + amount * 0.6
	shield_hit_fx(pos)
	G.sparks(Vector3(pos.x, maxf(pos.y, 0.8), pos.z), Color(0.5, 0.95, 1.0), 6, 5.0, 0.3, 0.12, 0.0)
	G.sfx("shield_hit", -6.0, randf_range(0.9, 1.2))
	G.add_score(2)
	var mech := _manned("repair")
	if mech:
		G.rumble(mech.input, 0.4, 0.2, 0.08)
	if shield <= 0.0:
		_drop_shield(true)


func shield_hit_fx(pos: Vector3) -> void:
	Net.send_event("shield_hit", [pos])
	_shield_hit_t = 0.0
	var local := to_local(pos)
	local.y = 0.0
	_shield_mat.set_shader_parameter("hit_dir", local.normalized() if local.length() > 0.01 else Vector3.FORWARD)


func take_damage(amount: float, pos: Vector3, team: int) -> void:
	if dead or team == G.Team.PLAYER or invulnerable:
		return
	if shield_up:
		shield_block(pos, amount)
		return
	hp -= amount
	if _hit_flash_cd <= 0.0:
		_hit_flash_cd = 0.1
		G.flash(meshes, 0.5)
	G.add_shake(amount * 0.02)
	if randf() < clampf(amount / 18.0, 0.0, 0.75):
		var local := to_local(pos)
		var p := Vector2(local.x, local.z) * 0.75 + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))
		_add_breach(clamp_deck(p))
	if hp <= 0.0:
		_die()


func _add_breach(p: Vector2) -> void:
	if breaches.size() >= MAX_BREACHES:
		return
	for b in breaches:
		if b.deck_pos.distance_to(p) < 0.8:
			return
	var b := Breach.new()
	b.net_id = G.next_net_id()
	b.deck_pos = p
	b.position = Vector3(p.x, DECK_Y, p.y)
	add_child(b)
	breaches.append(b)
	G.sfx("alarm", -6.0)


func _die() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	speed = 0.0
	for crew in crew_members:
		leave(crew)
	cannon_laser.visible = false
	mg_laser.visible = false
	shield_up = false
	for i in 7:
		var off := Vector3(randf_range(-2.5, 2.5), 1.5, randf_range(-3.5, 3.5))
		get_tree().create_timer(i * 0.2).timeout.connect(_death_blast.bind(off, 3.0 + i * 0.3))
	_show_wreck()
	destroyed.emit()


func _show_wreck() -> void:
	for m in meshes:
		G.set_neon(m, Color(0.7, 0.2, 0.1), 0.9)


func _death_blast(offset: Vector3, radius: float) -> void:
	G.explode(to_global(offset), radius, 0.0, G.Team.PLAYER)


# --- Visual upkeep ---------------------------------------------------------------------------

# --- Replication -----------------------------------------------------------------------------

func net_state() -> Array:
	var b := []
	for br in breaches:
		b.append([br.net_id, br.deck_pos, br.progress])
	return [global_position.x, global_position.z, rotation.y, turret.rotation.y, mg_pivot.rotation.y,
		hp, speed, cannon_cd, mg_heat, mg_overheated, dead, repairing, b,
		[needle_phase, zone_center, zone_half, combo, rep_stun, shield, shield_up, shield_lock,
			last_grade, grade_seq, _aim_target_id]]


func apply_net(s: Array) -> void:
	_net = s
	hp = s[5]
	speed = s[6]
	cannon_cd = s[7]
	mg_heat = s[8]
	mg_overheated = s[9]
	repairing = s[11]
	var r: Array = s[13]
	# The needle runs locally between snapshots; only resync when it drifts.
	if absf(float(r[0]) - needle_phase) > 0.12:
		needle_phase = r[0]
	zone_center = r[1]
	zone_half = r[2]
	combo = r[3]
	rep_stun = r[4]
	shield = r[5]
	if r[6] != shield_up:
		shield_up = r[6]
	shield_lock = r[7]
	last_grade = r[8]
	grade_seq = r[9]
	_aim_target_id = r[10]
	if s[10] and not dead:
		dead = true
		_show_wreck()
	# Breaches appear and disappear as the host reports them.
	var seen := {}
	for entry in s[12]:
		var id: int = entry[0]
		seen[id] = true
		var br: Breach = _breach_ids.get(id)
		if br == null:
			br = Breach.new()
			br.net_id = id
			br.deck_pos = entry[1]
			br.position = Vector3(br.deck_pos.x, DECK_Y, br.deck_pos.y)
			add_child(br)
			breaches.append(br)
			_breach_ids[id] = br
		br.progress = entry[2]
	for id in _breach_ids.keys():
		if not seen.has(id):
			var br: Breach = _breach_ids[id]
			breaches.erase(br)
			br.queue_free()
			_breach_ids.erase(id)


func _puppet_update(delta: float) -> void:
	if _net.is_empty():
		return
	var k := minf(1.0, delta * 12.0)
	var target := Vector3(_net[0], 0.0, _net[1])
	if global_position.distance_to(target) > 8.0:
		global_position = target
	global_position = global_position.lerp(target, k)
	rotation.y = lerp_angle(rotation.y, _net[2], k)
	turret.rotation.y = lerp_angle(turret.rotation.y, _net[3], k)
	mg_pivot.rotation.y = lerp_angle(mg_pivot.rotation.y, _net[4], k)
	velocity = -global_basis.z * speed
	_tread_phase += speed * delta
	_update_jams()
	needle_phase += needle_speed() * delta
	var mg := _manned("mg")
	mg_laser.visible = mg != null and not mg_overheated and not dead
	if mg:
		G.set_neon(mg_laser, mg.color, 1.0)


func _process(delta: float) -> void:
	if puppet:
		_puppet_update(delta)
	elif not dead:
		_cannon(delta)
		_repair_game(delta)
	_update_aim_visuals(_manned("cannon"))
	_update_shield_visual(delta)
	for st: Station in stations.values():
		var c := Color(0.75, 0.85, 1.0)
		var e := 1.0
		if st.jammed:
			c = Color(1.0, 0.15, 0.1)
			e = 3.0 if fmod(_time, 0.4) < 0.2 else 0.6
		elif st.occupant:
			c = st.occupant.color
			e = 3.0
		G.set_neon(st.pad, c, e)
		st.label.modulate = c
		st.label.outline_modulate = Color(c, 0.3)
		st.label.text = G.t("JAMMED") if st.jammed else G.t(st.title)
	if not dead:
		var glow := 2.0 + sin(_time * 3.0) * 0.4
		if repairing:
			glow = 3.0 + 2.0 * maxf(0.0, 1.0 - absf(needle_now() - zone_center) / maxf(zone_half, 0.01))
		G.set_neon(reactor, Color(0.3, 1.0, 0.5) if not shield_up else Color(0.4, 0.9, 1.0), glow)
	var count := _lugs.size() / 2
	for i in _lugs.size():
		var lug := _lugs[i]
		lug.position.z = fposmod(float(i % count) * 0.88 + _tread_phase, 8.8) - 4.4


func _update_shield_visual(delta: float) -> void:
	_shield_vis = move_toward(_shield_vis, 1.0 if shield_up and not dead else 0.0, delta * (7.0 if shield_up else 4.0))
	_shield_hit_t += delta
	_shield_mesh.visible = _shield_vis > 0.01
	if not _shield_mesh.visible:
		return
	var low := shield < 25.0
	var flicker := 0.55 + 0.45 * absf(sin(_time * 30.0)) if low else 1.0
	_shield_mat.set_shader_parameter("strength", _shield_vis * flicker)
	_shield_mat.set_shader_parameter("hit", maxf(0.0, 1.0 - _shield_hit_t * 3.0))
	_shield_mat.set_shader_parameter("charge", shield / SHIELD_MAX)
	var s := 0.85 + 0.15 * _shield_vis
	_shield_mesh.scale = Vector3(SHIELD_RX * s, 3.0 * s, SHIELD_RZ * s)
