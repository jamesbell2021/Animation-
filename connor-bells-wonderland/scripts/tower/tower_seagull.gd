class_name TowerSeagull
extends Node3D
## Tower Climb hazard: a giant seagull from Belfast harbour. It flies in from the
## harbour, circles the tower just above the climbers, and every so often picks
## someone (usually whoever's highest), screeches, and dives at them: a hit
## knocks them flying and it nicks whatever item they were holding. In between
## it drops poo bombs. A Shield Bubble bats it away.
## The host flies it and sends its position; clients just show it.

signal net_event(event: String, args: Array)
## For the HUD: "warn", "hit", "miss", "blocked", "poo", "arrive".
signal gull_event(event: String, target_name: String, detail: String)

enum Mode { ARRIVE, CIRCLE, WARN, DIVE, ESCAPE }

const ORBIT_RADIUS := 21.0
const CIRCLE_SPEED := 11.0
const DIVE_SPEED := 24.0
const WARN_TIME := 1.3
const FIRST_ATTACK := 22.0
const ATTACK_GAP := Vector2(11.0, 17.0)
const POO_GAP := Vector2(6.0, 10.0)
const HIT_DISTANCE := 2.2
## How fast the dive can follow a target that moves after the warning (m/s):
## keep running and it misses.
const DIVE_TRACKING := 5.0
const SCALE := 2.4

var game: GameManager
var active: bool = false

var _mode: Mode = Mode.ARRIVE
var _time: float = 0.0
var _mode_time: float = 0.0
var _attack_timer: float = FIRST_ATTACK
var _poo_timer: float = 14.0
var _orbit_angle: float = 0.0
var _target: Contestant
var _dive_point: Vector3
var _velocity: Vector3 = Vector3.ZERO
var _diving: bool = false
var _model: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _marker: Label3D
var _net_pos: Vector3 = Vector3.INF
var _net_yaw: float = 0.0
var _poos: Array[Dictionary] = []


func setup(p_game: GameManager) -> void:
	game = p_game


func _ready() -> void:
	_build_model()
	reset()


## Back to the harbour for a new climb.
func reset() -> void:
	active = false
	_mode = Mode.ARRIVE
	_mode_time = 0.0
	_attack_timer = FIRST_ATTACK
	_poo_timer = 14.0
	_target = null
	_marker.visible = false
	_diving = false
	_velocity = Vector3.ZERO
	_net_pos = Vector3.INF
	global_position = Vector3(260.0, 70.0, -520.0)
	for poo in _poos:
		if is_instance_valid(poo["node"]):
			(poo["node"] as Node).queue_free()
	_poos.clear()


func begin() -> void:
	active = true


## Clients: latest position from the host.
func apply_state(pos: Vector3, yaw: float, diving: bool) -> void:
	_net_pos = pos
	_net_yaw = yaw
	_diving = diving


## Host: what to send to clients.
func get_state() -> Array:
	return [global_position, _model.rotation.y, _diving]


func _process(delta: float) -> void:
	_time += delta
	# Flap (or tuck the wings in for a dive).
	var flap := sin(_time * (14.0 if not _diving else 4.0)) * (0.7 if not _diving else 0.1)
	var tuck := 0.9 if _diving else 0.0
	_wing_l.rotation = Vector3(0.0, tuck, flap)
	_wing_r.rotation = Vector3(0.0, -tuck, -flap)
	_model.rotation.x = lerpf(_model.rotation.x, 0.5 if _diving else 0.0, 6.0 * delta)
	if not multiplayer.is_server() and _net_pos != Vector3.INF:
		global_position = global_position.lerp(_net_pos, clampf(10.0 * delta, 0.0, 1.0))
		_model.rotation.y = lerp_angle(_model.rotation.y, _net_yaw, clampf(10.0 * delta, 0.0, 1.0))
	if _marker.visible and is_instance_valid(_target):
		_marker.global_position = _target.global_position + Vector3.UP * 3.0
	_update_poos(delta)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or game == null:
		return
	_mode_time += delta
	var goal := global_position
	var speed := CIRCLE_SPEED
	match _mode:
		Mode.ARRIVE:
			# Join the circle on the side it's coming from (not through the tower).
			_orbit_angle = atan2(global_position.z, global_position.x)
			goal = _orbit_point()
			speed = 26.0
			if not active:
				return
			if global_position.distance_to(goal) < 6.0:
				_set_mode(Mode.CIRCLE)
				_announce("arrive", "", "")
		Mode.CIRCLE:
			_orbit_angle += delta * CIRCLE_SPEED / ORBIT_RADIUS
			goal = _orbit_point()
			_attack_timer -= delta
			_poo_timer -= delta
			if _poo_timer <= 0.0:
				_poo_timer = randf_range(POO_GAP.x, POO_GAP.y)
				_drop_poo()
			if _attack_timer <= 0.0:
				_target = _pick_target()
				if _target != null:
					_set_mode(Mode.WARN)
					_announce("warn", str(_target.name), "")
				else:
					_attack_timer = 4.0
		Mode.WARN:
			# Hover up ahead of the target (where they can see it), screeching, then go.
			if not _valid_target():
				_set_mode(Mode.CIRCLE)
			else:
				var p := _target.global_position
				var out := Vector3(p.x, 0.0, p.z).normalized()
				var ahead := Vector3(-p.z, 0.0, p.x).normalized()
				goal = p + ahead * 6.0 + out * 2.5 + Vector3.UP * 6.5
				speed = 18.0
				if _mode_time >= WARN_TIME:
					_dive_point = _target.global_position + Vector3.UP * 0.9
					_set_mode(Mode.DIVE)
		Mode.DIVE:
			_diving = true
			if not _valid_target() or _mode_time > 2.5:
				_announce("miss", str(_target.name) if is_instance_valid(_target) else "", "")
				_escape()
			else:
				var aim := _target.global_position + Vector3.UP * 0.9
				_dive_point = _dive_point.move_toward(aim, DIVE_TRACKING * delta)
				goal = _dive_point
				speed = DIVE_SPEED
				if global_position.distance_to(aim) < HIT_DISTANCE:
					_hit(_target)
				elif global_position.distance_to(_dive_point) < 1.0:
					# Swooped through where they were: missed!
					_announce("miss", str(_target.name), "")
					_escape()
		Mode.ESCAPE:
			goal = _orbit_point() + Vector3.UP * 10.0
			speed = 18.0
			if _mode_time > 2.0:
				_set_mode(Mode.CIRCLE)
	var to_goal := goal - global_position
	var want := to_goal.normalized() * speed if to_goal.length() > 0.2 else Vector3.ZERO
	_velocity = _velocity.lerp(want, clampf((6.0 if _mode == Mode.DIVE else 3.5 if _mode == Mode.ESCAPE else 2.5) * delta, 0.0, 1.0))
	global_position += _velocity * delta
	if _velocity.length() > 0.5:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-_velocity.x, -_velocity.z), clampf(8.0 * delta, 0.0, 1.0))


func _set_mode(mode: Mode) -> void:
	_mode = mode
	_mode_time = 0.0
	_diving = mode == Mode.DIVE
	_marker.visible = mode == Mode.WARN or mode == Mode.DIVE
	if mode == Mode.WARN:
		SoundManager.world(self, "squawk", global_position, 1.0, 10.0)


func _escape() -> void:
	_target = null
	_orbit_angle = atan2(global_position.z, global_position.x)
	# Flap straight back up rather than skidding along the path.
	_velocity = _velocity * 0.4 + Vector3.UP * 12.0
	_attack_timer = randf_range(ATTACK_GAP.x, ATTACK_GAP.y)
	_set_mode(Mode.ESCAPE)


## Circles a little above the middle of the climbers.
func _orbit_point() -> Vector3:
	var height := 10.0
	var count := 0
	for c in _climbers():
		height += c.global_position.y
		count += 1
	if count > 0:
		height = (height - 10.0) / float(count) + 9.0
	return Vector3(cos(_orbit_angle) * ORBIT_RADIUS, height, sin(_orbit_angle) * ORBIT_RADIUS)


func _climbers() -> Array[Contestant]:
	var out: Array[Contestant] = []
	for node in get_tree().get_nodes_in_group("contestants"):
		var c := node as Contestant
		if c == null or (game.race_manager != null and game.race_manager.has_finished(c)):
			continue
		if c.visible and c.controls_enabled and c.global_position.y > 2.0:
			out.append(c)
	return out


## Usually whoever's highest (it likes a leader), sometimes anyone.
func _pick_target() -> Contestant:
	var climbers := _climbers()
	if climbers.is_empty():
		return null
	if randf() < 0.55:
		var best := climbers[0]
		for c in climbers:
			if c.global_position.y > best.global_position.y:
				best = c
		return best
	return climbers[randi() % climbers.size()]


func _valid_target() -> bool:
	return is_instance_valid(_target) and _target.visible and _target.controls_enabled


func _hit(victim: Contestant) -> void:
	var push := Vector3(_velocity.x, 0.0, _velocity.z).normalized() * 6.0 + Vector3.UP * 7.0
	var landed := StatusEffects.try_knock(victim, push, 1.0)
	var stolen := ""
	if landed:
		var holder := victim.get_node_or_null("ItemHolder") as ItemHolder
		if holder != null and not holder.is_empty():
			stolen = ItemKinds.display_name(holder.kind)
			holder.clear()
	var event := "hit" if landed else "blocked"
	_feathers(victim.global_position + Vector3.UP * 1.2)
	_announce(event, str(victim.name), stolen)
	_escape()


func _drop_poo() -> void:
	var climbers := _climbers()
	if climbers.is_empty():
		return
	var victim := climbers[randi() % climbers.size()]
	var from := global_position + Vector3.DOWN * 1.0
	var to := victim.global_position + Vector3(randf_range(-0.6, 0.6), 0.9, randf_range(-0.6, 0.6))
	_spawn_poo(from, to, str(victim.name), true)
	net_event.emit("poo", [from, to, str(victim.name)])


## A falling poo bomb (on the host it can hit; elsewhere it's just for show).
func _spawn_poo(from: Vector3, to: Vector3, victim_name: String, live: bool) -> void:
	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.5
	sphere.material = CourseBuilder.make_material(Color(0.95, 0.95, 0.9))
	blob.mesh = sphere
	game.add_child(blob)
	blob.global_position = from
	_poos.append({"node": blob, "from": from, "to": to, "t": 0.0, "victim": victim_name, "live": live})
	SoundManager.world(self, "whoosh", from, 1.6, 2.0)


func _update_poos(delta: float) -> void:
	for i in range(_poos.size() - 1, -1, -1):
		var poo := _poos[i]
		var node := poo["node"] as Node3D
		var t := float(poo["t"]) + delta / 1.1
		poo["t"] = t
		if not is_instance_valid(node):
			_poos.remove_at(i)
			continue
		var victim := game.find_contestant(str(poo["victim"]))
		var to: Vector3 = poo["to"]
		if victim != null and t < 0.8:
			to = victim.global_position + Vector3.UP * 0.9
			poo["to"] = to
		var from: Vector3 = poo["from"]
		node.global_position = from.lerp(to, t * t)
		if t >= 1.0:
			var hit := victim != null and victim.global_position.distance_to(node.global_position) < 1.5
			FX.burst(self, "paint", node.global_position, Color(0.95, 0.95, 0.9), 0.9)
			SoundManager.world(self, "splat", node.global_position, 1.4, 2.0)
			if hit:
				PaintSplat.stick(victim, Color(0.95, 0.95, 0.9))
				if bool(poo["live"]):
					_announce("poo", str(poo["victim"]), "")
			node.queue_free()
			_poos.remove_at(i)


func _feathers(pos: Vector3) -> void:
	FX.burst(self, "poof", pos, Color.WHITE, 1.6)
	FX.burst(self, "feathers", pos, Color.WHITE, 1.4)
	FX.burst(self, "impact", pos, Color.WHITE, 1.2)
	SoundManager.world(self, "squawk", pos, 1.25, 10.0)
	SoundManager.world(self, "punch", pos, 0.9, 4.0)


func _announce(event: String, target_name: String, detail: String) -> void:
	gull_event.emit(event, target_name, detail)
	net_event.emit("gull", [event, target_name, detail])


## Clients: an event from the host.
func apply_remote_event(event: String, args: Array) -> void:
	match event:
		"gull":
			var kind := str(args[0])
			var target_name := str(args[1])
			_target = game.find_contestant(target_name)
			_marker.visible = kind == "warn"
			if kind == "warn":
				SoundManager.world(self, "squawk", global_position, 1.0, 10.0)
			if (kind == "hit" or kind == "blocked") and _target != null:
				_feathers(_target.global_position + Vector3.UP * 1.2)
			gull_event.emit(kind, target_name, str(args[2]))
		"poo":
			_spawn_poo(args[0], args[1], str(args[2]), false)


# --- The bird ---------------------------------------------------------------------

func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Gull"
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	var white := Color(0.95, 0.95, 0.93)
	var grey := Color(0.55, 0.58, 0.62)
	_blob(Vector3(0.55, 0.45, 1.0), Vector3(0.0, 0.0, 0.0), white)
	_blob(Vector3(0.32, 0.32, 0.34), Vector3(0.0, 0.28, -0.82), white)
	# Beak: yellow with the red spot, pointing forward (-Z).
	var beak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.09
	cone.height = 0.45
	cone.material = CourseBuilder.make_material(Color(1.0, 0.8, 0.1))
	beak.mesh = cone
	beak.position = Vector3(0.0, 0.24, -1.25)
	beak.rotation.x = -PI * 0.5
	_model.add_child(beak)
	var spot := CourseBuilder.make_box_mesh(Vector3(0.05, 0.05, 0.06), Color(0.9, 0.1, 0.05))
	spot.position = Vector3(0.0, 0.2, -1.32)
	_model.add_child(spot)
	# Angry eyes and eyebrows.
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.06
		ball.height = 0.12
		ball.material = CourseBuilder.make_material(Color(0.05, 0.05, 0.05))
		eye.mesh = ball
		eye.position = Vector3(side * 0.17, 0.36, -0.98)
		_model.add_child(eye)
		var brow := CourseBuilder.make_box_mesh(Vector3(0.16, 0.03, 0.04), Color(0.15, 0.15, 0.15))
		brow.position = Vector3(side * 0.16, 0.45, -1.0)
		brow.rotation.z = side * 0.45
		_model.add_child(brow)
		# Orange feet tucked under.
		var foot := CourseBuilder.make_box_mesh(Vector3(0.12, 0.05, 0.2), Color(1.0, 0.55, 0.1))
		foot.position = Vector3(side * 0.15, -0.42, 0.35)
		_model.add_child(foot)
	# Tail.
	var tail := CourseBuilder.make_box_mesh(Vector3(0.4, 0.06, 0.45), grey.darkened(0.3))
	tail.position = Vector3(0.0, 0.05, 1.05)
	_model.add_child(tail)
	_wing_l = _wing(-1.0, grey)
	_wing_r = _wing(1.0, grey)
	_marker = Label3D.new()
	_marker.text = "!"
	_marker.font = GameFonts.title()
	_marker.font_size = 160
	_marker.pixel_size = 0.01
	_marker.modulate = Color(1.0, 0.2, 0.1)
	_marker.outline_size = 20
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.visible = false
	add_child(_marker)
	_marker.top_level = true


func _blob(size: Vector3, pos: Vector3, colour: Color) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.material = CourseBuilder.make_material(colour)
	mi.mesh = sphere
	mi.scale = size * 2.0
	mi.position = pos
	_model.add_child(mi)


func _wing(side: float, colour: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.45, 0.2, -0.1)
	_model.add_child(pivot)
	var wing := CourseBuilder.make_box_mesh(Vector3(1.5, 0.05, 0.55), colour)
	wing.position = Vector3(side * 0.75, 0.0, 0.0)
	pivot.add_child(wing)
	var tip := CourseBuilder.make_box_mesh(Vector3(0.45, 0.06, 0.4), Color(0.08, 0.08, 0.1))
	tip.position = Vector3(side * 1.6, 0.0, 0.05)
	pivot.add_child(tip)
	return pivot
