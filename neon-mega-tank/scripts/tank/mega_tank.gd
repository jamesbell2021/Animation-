class_name MegaTank
extends CharacterBody3D
## The crew's mega tank. Its open deck has four stations (DRIVE, CANNON, MG, REPAIR) that crew
## members walk between and board, Lovers-in-a-Dangerous-Spacetime style. Hits punch breaches
## into the deck that drain the hull and jam nearby stations until someone patches them.

signal destroyed

const DECK_Y := 1.4
const DECK_HALF := Vector2(2.25, 3.7)
const MAX_HP := 160.0
const MAX_SPEED := 7.5
const ACCEL := 9.0
const TURN_RATE := 1.5
const TURRET_CENTER := Vector2(0.0, 0.5)
const MG_CENTER := Vector2(1.85, 3.25)
const REACTOR_CENTER := Vector2(-1.85, 3.25)
const CANNON_RELOAD := 1.0
const MG_INTERVAL := 0.075
const MG_HEAT_PER_SHOT := 5.5
const REPAIR_RATE := 11.0
const BREACH_DRAIN := 1.0
const MAX_BREACHES := 5
const JAM_RADIUS := 1.3


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

var mg_pivot: Node3D
var mg_muzzle: Node3D
var mg_laser: MeshInstance3D
var mg_yaw := 0.0
var mg_cd := 0.0
var mg_heat := 0.0
var mg_overheated := false

var reactor: MeshInstance3D
var repairing := false
var _repair_tick := 0.0

var _lugs: Array[MeshInstance3D] = []
var _tread_phase := 0.0
var _hit_flash_cd := 0.0
var _time := 0.0
var _obstacles := [[TURRET_CENTER, 1.35], [MG_CENTER, 0.45], [REACTOR_CENTER, 0.6]]


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
	cannon_laser = G.neon_box(turret, Vector3(0.05, 0.05, 30.0), Vector3(0, 1.25, -21.0), Color.WHITE, 1.2)
	cannon_laser.visible = false


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


func _add_station(id: String, title: String, pos: Vector2, look: Vector2) -> void:
	var st := Station.new()
	st.id = id
	st.title = title
	st.pos = pos
	st.look = look
	st.pad = G.neon_box(self, Vector3(1.0, 0.05, 1.0), Vector3(pos.x, DECK_Y + 0.03, pos.y), Color.WHITE, 1.2)
	st.label = Label3D.new()
	st.label.text = title
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


func nearest_free_station(p: Vector2, max_dist := 1.1) -> Station:
	var best: Station = null
	var best_d := max_dist
	for st: Station in stations.values():
		var d := st.pos.distance_to(p)
		if st.occupant == null and d < best_d:
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
	for o in _obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1]
		var off := p - c
		if off.length() < r:
			p = c + (off.normalized() if off.length() > 0.01 else Vector2.RIGHT) * r
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
	if dead:
		return
	_update_jams()
	_drive(delta)
	_cannon(delta)
	_machine_gun(delta)
	_repair(delta)
	if not breaches.is_empty():
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
		elif other is EnemyTank and absf(speed) > 1.5:
			(other as EnemyTank).take_damage(30.0 * delta, global_position, G.Team.PLAYER)


func _cannon(delta: float) -> void:
	cannon_cd = maxf(0.0, cannon_cd - delta)
	var gunner := _manned("cannon")
	cannon_laser.visible = gunner != null
	if gunner:
		G.set_neon(cannon_laser, gunner.color, 1.3)
		var aim := G.main.stick_to_world(gunner.input.move)
		if aim.length() > 0.25:
			turret_yaw = atan2(-aim.x, -aim.z)
		if gunner.input.action_held and cannon_cd <= 0.0:
			_fire_cannon(gunner.color)
	var diff := wrapf(turret_yaw - turret.global_rotation.y, -PI, PI)
	turret.rotation.y += clampf(diff, -2.4 * delta, 2.4 * delta)


func _fire_cannon(color: Color) -> void:
	cannon_cd = CANNON_RELOAD
	var muzzle := muzzles[cannon_side]
	var barrel := barrels[cannon_side]
	cannon_side = 1 - cannon_side
	var dir := -muzzle.global_basis.z
	dir.y = 0.0
	G.spawn_projectile(muzzle.global_position, dir.normalized() * 36.0, G.Team.PLAYER, "shell",
			color.lerp(Color.WHITE, 0.4))
	G.ring(muzzle.global_position, color, 1.6, 0.25, muzzle.global_position.y)
	G.sparks(muzzle.global_position, Color(1, 0.9, 0.6), 8, 6.0, 0.3, 0.15, 0.0)
	G.add_shake(0.35)
	G.sfx("cannon", 2.0)
	var tw := barrel.create_tween()
	tw.tween_property(barrel, "position:z", 0.6, 0.05)
	tw.tween_property(barrel, "position:z", 0.0, 0.4)


func _machine_gun(delta: float) -> void:
	mg_cd -= delta
	mg_heat = maxf(0.0, mg_heat - (40.0 if mg_overheated else 28.0) * delta)
	if mg_overheated and mg_heat < 25.0:
		mg_overheated = false
	var gunner := _manned("mg")
	mg_laser.visible = gunner != null and not mg_overheated
	if gunner:
		G.set_neon(mg_laser, gunner.color, 1.0)
		var aim := G.main.stick_to_world(gunner.input.move)
		if aim.length() > 0.25:
			mg_yaw = atan2(-aim.x, -aim.z)
		if gunner.input.action_held and not mg_overheated and mg_cd <= 0.0:
			_fire_mg(gunner.color)
	var diff := wrapf(mg_yaw - mg_pivot.global_rotation.y, -PI, PI)
	mg_pivot.rotation.y += clampf(diff, -7.0 * delta, 7.0 * delta)


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


func _repair(delta: float) -> void:
	var mechanic := _manned("repair")
	repairing = mechanic != null and mechanic.input.action_held and hp < MAX_HP
	if repairing:
		hp = minf(MAX_HP, hp + REPAIR_RATE * delta)
		_repair_tick -= delta
		if _repair_tick <= 0.0:
			_repair_tick = 0.25
			G.sparks(reactor.global_position + Vector3(0, 0.6, 0), Color(0.3, 1.0, 0.5), 4, 3.0, 0.4, 0.1, -4.0)
			G.sfx("repair", -10.0)


func take_damage(amount: float, pos: Vector3, team: int) -> void:
	if dead or team == G.Team.PLAYER:
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
	for i in 7:
		var off := Vector3(randf_range(-2.5, 2.5), 1.5, randf_range(-3.5, 3.5))
		get_tree().create_timer(i * 0.2).timeout.connect(_death_blast.bind(off, 3.0 + i * 0.3))
	for m in meshes:
		G.set_neon(m, Color(0.7, 0.2, 0.1), 0.9)
	destroyed.emit()


func _death_blast(offset: Vector3, radius: float) -> void:
	G.explode(to_global(offset), radius, 0.0, G.Team.PLAYER)


# --- Visual upkeep ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
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
		st.label.text = "JAMMED" if st.jammed else st.title
	if not dead:
		G.set_neon(reactor, Color(0.3, 1.0, 0.5), 4.5 if repairing else 2.0 + sin(_time * 3.0) * 0.4)
	var count := _lugs.size() / 2
	for i in _lugs.size():
		var lug := _lugs[i]
		lug.position.z = fposmod(float(i % count) * 0.88 + _tread_phase, 8.8) - 4.4
