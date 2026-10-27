class_name Zeppelin
extends Node3D
## The airship Raijin-maru: circles the bay with a sweeping searchlight and koinobori carp
## streamers, fires broadside guns, and with upgrades drops bombs and launches rocket pods.
## Tengu hunt it; when shot down it falls into the sea and returns 30 seconds later.

var hp: float = 300.0
var max_hp: float = 300.0
var down: bool = false
var down_t: float = 0.0
var fall: float = 0.0
var splashed: bool = false
var ang: float = 0.0
var yaw: float = 0.0
var roll: float = 0.0
var vel: Vector3 = Vector3.ZERO
var lvl: Dictionary = {"bomb": 0, "armor": 0, "pods": 0}
var cd: float = 0.0
var bomb_cd: float = 0.0
var pod_cd: float = 0.0
var pilot_speed: float = 22.0
## Cruising height: 125, or higher to clear any kaiju standing under the hull.
var alt: float = 125.0
var _rejoin: float = 1.0                ## 0..1 blend back onto the patrol path after you fly it
var _rejoin_from: Vector3 = Vector3.ZERO

var _body: Node3D
var _line: ShaderMaterial
var _props: Array[Node3D] = []
var _carp: FrameLines = FrameLines.new()
var _light: MeshInstance3D
var _gun: Node3D


func _ready() -> void:
	_line = Mats.make_line(2.4)
	_body = Node3D.new()
	add_child(_body)
	var sb: SolidBuilder = SolidBuilder.new()
	var c: Color = Mats.PAPER
	sb.ellipsoid(Vector3.ZERO, Vector3(24, 24, 84), 10, 16, c, 5, 12)
	for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		sb.push(Transform3D(Basis(Vector3.BACK, a), Vector3.ZERO))
		sb.plate(PackedVector3Array([Vector3(0, 12, 52), Vector3(0, 38, 84), Vector3(0, 32, 96), Vector3(0, 10, 82)]), c)
		sb.pop()
	sb.box(Vector3(0, -28, -26), Vector3(12, 8, 40), c)
	for s: float in [-1.0, 1.0]:
		sb.edge(Vector3(s * 6, -24, -40), Vector3(s * 10, -19, -34), c * 0.7)
		sb.edge(Vector3(s * 6, -24, -12), Vector3(s * 10, -20, -10), c * 0.7)
		sb.edge(Vector3(-s * 5, -4, 14), Vector3(s * 29, -8, 14), c * 0.7)
		sb.ellipsoid(Vector3(s * 29, -8, 14), Vector3(3.4, 3.4, 8), 4, 8, c, 1, 4)
		# Mitsudomoe crest on each flank.
		var ctr: Vector3 = Vector3(s * 24.4, 2, -20)
		sb.lines.circle(ctr, 10.0, Vector3.UP, Vector3.BACK, Mats.SHU, 20)
		sb.lines.circle(ctr, 10.8, Vector3.UP, Vector3.BACK, Mats.GOLD, 20)
		for k: int in range(3):
			var a0: float = TAU * float(k) / 3.0
			var prev: Vector3 = ctr
			for i: int in range(1, 9):
				var f: float = float(i) / 8.0
				var a1: float = a0 + f * 2.6
				var p: Vector3 = ctr + Vector3(0, cos(a1), sin(a1)) * f * 8.0
				sb.edge(prev, p, Mats.SHU)
				prev = p
		for i2: int in range(6):
			var wc: Color = Mats.GOLD
			wc.a = randf()
			sb.glow_quad(Vector3(s * 6.15, -28, -42.0 + float(i2) * 6.5), Vector3(0, 0, 1.4), Vector3(0, 1.4, 0), wc)
	sb.attach(_body, Mats.fill(), _line, Mats.windows())
	for s2: float in [-1.0, 1.0]:
		var pr: Node3D = Node3D.new()
		pr.position = Vector3(s2 * 29, -8, 22.6)
		_body.add_child(pr)
		var lb: LineBuilder = LineBuilder.new()
		for k2: int in range(3):
			var a2: float = TAU * float(k2) / 3.0
			lb.line(Vector3.ZERO, Vector3(cos(a2), sin(a2), 0) * 7.0, Mats.WHITE)
		lb.circle(Vector3.ZERO, 7.2, Vector3.RIGHT, Vector3.UP, Mats.WHITE * 0.3, 16)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = lb.build_mesh()
		mi.material_override = Mats.line(2.0)
		pr.add_child(mi)
		_props.append(pr)
	# Nose gun under the gondola.
	_gun = Node3D.new()
	_gun.position = Vector3(0, -33, -46)
	_body.add_child(_gun)
	var gb: SolidBuilder = SolidBuilder.new()
	gb.ellipsoid(Vector3.ZERO, Vector3(2.4, 2.0, 2.4), 4, 8, Mats.JADE, 1, 4)
	gb.tube(Vector3(0, -0.5, -1), Vector3(0, -0.5, -9), 0.5, 0.4, 5, Mats.JADE)
	gb.attach(_gun, Mats.fill(), Mats.line(2.6))
	# Carp streamers, rebuilt every frame.
	var cm: MeshInstance3D = MeshInstance3D.new()
	cm.mesh = _carp.mesh
	cm.material_override = Mats.line(2.6)
	_body.add_child(cm)
	# Searchlight cone.
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 26.0
	cone.height = 160.0
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 16
	var bm: ShaderMaterial = ShaderMaterial.new()
	bm.shader = preload("res://shaders/beam.gdshader")
	_light = MeshInstance3D.new()
	_light.mesh = cone
	_light.material_override = bm
	add_child(_light)
	var lab: Label3D = Label3D.new()
	lab.font = Mats.font_display()
	lab.text = "雷神丸"
	lab.font_size = 96
	lab.pixel_size = 0.12
	lab.modulate = Color(2.4, 0.5, 0.45)
	lab.shaded = false
	lab.position = Vector3(0, 30, -10)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_body.add_child(lab)
	reset()


func reset() -> void:
	lvl = {"bomb": 0, "armor": 0, "pods": 0}
	max_hp = 300.0
	hp = max_hp
	down = false
	fall = 0.0
	ang = 0.0
	roll = 0.0
	_place(0.0)


func seat_pos() -> Vector3:
	return global_transform * Vector3(0, -36, -48)


func piloted() -> bool:
	return Game.player != null and Game.player.active and Game.player.seat is String


## You're at the helm: A/D (or the left stick, or the touch stick) turn, W/S throttle up and down.
func _fly(dt: float) -> void:
	var steer: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var throttle: float = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var jx: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var jy: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(jx) > 0.2:
		steer += jx
	if absf(jy) > 0.2:
		throttle -= jy
	var ts: Vector2 = Game.hud.touch.stick()
	steer += ts.x
	throttle -= ts.y
	pilot_speed = clampf(pilot_speed + throttle * 22.0 * dt, 6.0, 60.0)
	var turn: float = -clampf(steer, -1.0, 1.0) * 0.5
	# Keep it over the bay: turn back in when it strays too far.
	var home: Vector3 = Vector3(0, 0, -300) - position
	if absf(position.x) > 700.0 or position.z < -1000.0 or position.z > 160.0:
		turn += wrapf(Game.yaw_to(home.x, home.z) - yaw, -PI, PI) * 0.8
	yaw += turn * dt
	roll = lerpf(roll, clampf(-turn * 0.5, -0.2, 0.2), minf(1.0, dt * 2.0))
	var fwd: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	vel = fwd * pilot_speed
	position += vel * dt
	position.y = lerpf(position.y, alt + sin(Game.t * 0.4) * 3.0, minf(1.0, dt * 1.5))
	# When you let go, pick the nearest point of the patrol loop and drift back onto it.
	ang = atan2((position.z + 80.0) / 105.0, position.x / 230.0)
	_rejoin = 0.0
	_rejoin_from = position


## Climb over tall kaiju (the Dai-Oni stands nearly as high as the patrol height) and come back
## down once they're clear. The gondola hangs about 36 below the hull's centre.
func _update_alt(dt: float) -> void:
	var want: float = 125.0
	for k: Kaiju in Game.kaiju:
		if k.dying or k.def["air"] or Vector2(k.position.x - position.x, k.position.z - position.z).length() > 110.0:
			continue
		for h: Dictionary in k.hits:
			want = maxf(want, float(h["p"].y) + float(h["r"]) + 50.0)
	alt = move_toward(alt, want, dt * (40.0 if want > alt else 12.0))


func _aim_nose_gun(at: Vector3) -> void:
	var d: Vector3 = at - _gun.global_position
	if d.length_squared() < 1.0:
		return
	d = d.normalized()
	_gun.global_basis = Basis.looking_at(d, Vector3.FORWARD if absf(d.y) > 0.97 else Vector3.UP)


func _place(dt: float) -> void:
	var nx: float = cos(ang) * 230.0
	var nz: float = -80.0 + sin(ang) * 105.0
	var np: Vector3 = Vector3(nx, alt + sin(Game.t * 0.4) * 3.0, nz)
	if _rejoin < 1.0:
		_rejoin = minf(1.0, _rejoin + dt / 4.0)
		np = _rejoin_from.lerp(np, smoothstep(0.0, 1.0, _rejoin))
	if dt > 0.0:
		vel = (np - position) / dt
		var ny: float = Game.yaw_to(np.x - position.x, np.z - position.z)
		var dyaw: float = wrapf(ny - yaw, -PI, PI)
		yaw += dyaw
		roll = lerpf(roll, clampf(-dyaw / maxf(dt, 0.001) * 0.6, -0.15, 0.15), dt)
	position = np


func update(dt: float) -> void:
	for p: Node3D in _props:
		p.rotate_z(dt * 22.0)
	if down:
		down_t += dt
		if fall < 1.0:
			fall = minf(1.0, fall + dt * 0.22)
			position.y -= dt * (8.0 + fall * 60.0)
			roll += dt * 0.2
			if randf() < 0.6:
				Game.fx.boom(position + Vector3(randf_range(-40, 40), randf_range(-10, 10), randf_range(-40, 40)), 1.0, Mats.FIRE)
			if position.y < 5.0 and not splashed:
				splashed = true
				fall = 1.0
				Game.fx.boom(Vector3(position.x, 2, position.z), 5.0, Mats.FIRE)
				Game.fx.ring(Vector3(position.x, 0.6, position.z), 20.0, 70.0, 3.0, Mats.CYAN)
				Game.sfx.play_at("boom_big", position, 1.2)
		visible = fall < 1.0
		_body.rotation = Vector3(-fall * 0.6, 0, roll)
		rotation.y = yaw
		_light.visible = false
		if down_t > 30.0:
			down = false
			hp = max_hp
			fall = 0.0
			roll = 0.0
			ang += PI
			visible = true
			splashed = false
			_place(0.0)
			Game.banner.emit("雷神丸 再出撃", "RAIJIN-MARU IS BACK IN THE AIR", 2.4)
			Game.hud_dirty.emit()
		return
	_update_alt(dt)
	if piloted():
		_fly(dt)
	else:
		ang += dt * 0.05
		_place(dt)
	rotation.y = yaw
	_body.rotation = Vector3(0, 0, roll)
	_draw_carp()
	_sweep_light()
	var low: bool = hp < max_hp * 0.3 and sin(Game.t * 10.0) > 0.0
	_line.set_shader_parameter("tint", Vector3(1.0, 0.1, 0.2) if low else Vector3(1, 1, 1))
	_gun.visible = not (Game.player.active and Game.player.seat is String)
	_weapons(dt)


func _sweep_light() -> void:
	_light.visible = true
	var sa: float = sin(Game.t * 0.4) * 0.7
	var ground: Vector3 = position + Vector3(-sin(yaw + sa) * 150.0, 0, -cos(yaw + sa) * 150.0 - 40.0)
	ground.y = 0.0
	var from: Vector3 = global_transform * Vector3(0, -32, -30)
	var d: Vector3 = ground - from
	var len: float = d.length()
	# CylinderMesh is centred on its origin along Y: put it halfway and point -Y at the ground.
	var y_axis: Vector3 = -d / len
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD).normalized()
	if x_axis.length_squared() < 0.01:
		x_axis = Vector3.RIGHT
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	_light.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis).scaled(Vector3(1, len / 160.0, 1)), from + d * 0.5)


func _draw_carp() -> void:
	_carp.clear()
	var cols: Array[Color] = [Mats.SHU, Mats.BOLT, Mats.GOLD]
	for k: int in range(3):
		var prev_c: Vector3 = Vector3.ZERO
		var prev_r: float = 0.0
		for i: int in range(9):
			var f: float = float(i) / 8.0
			var wob: float = sin(Game.t * 5.0 - float(i) * 0.8 + float(k) * 2.0)
			var r: float = lerpf(4.0, 1.2, f)
			var c: Vector3 = Vector3(float(k - 1) * 6.0 + wob * 3.0 * f, 34.0 - float(k) * 6.0 - f * 6.0 + cos(Game.t * 4.0 - float(i) + float(k)) * 2.0 * f, 98.0 + float(i) * 6.0 + float(k) * 4.0)
			for s: int in range(8):
				var a0: float = TAU * float(s) / 8.0
				var a1: float = TAU * float(s + 1) / 8.0
				_carp.seg(c + Vector3(cos(a0), sin(a0), 0) * r, c + Vector3(cos(a1), sin(a1), 0) * r, cols[k])
			if i > 0:
				for s2: int in [0, 2, 4, 6]:
					var a2: float = TAU * float(s2) / 8.0
					_carp.seg(prev_c + Vector3(cos(a2), sin(a2), 0) * prev_r, c + Vector3(cos(a2), sin(a2), 0) * r, cols[k] * 0.7)
			prev_c = c
			prev_r = r
	_carp.commit()


func _weapons(dt: float) -> void:
	cd -= dt
	var manned: bool = Game.player.active and Game.player.seat is String
	var C: Combat = Game.combat
	if cd <= 0.0 and not manned:
		var best: Kaiju = null
		var bd: float = 330.0
		for k: Kaiju in Game.kaiju:
			if k.dying or not k.exposed:
				continue
			var d: float = k.aim.distance_to(position)
			if d < bd:
				bd = d
				best = k
		if best != null:
			cd = 0.55
			# The nose gun under the gondola swings onto the target and fires from its barrel.
			var tt: float = _gun.global_position.distance_to(best.aim) / 600.0
			var lead: Vector3 = best.aim + best.vel * tt
			_aim_nose_gun(lead)
			var m: Vector3 = _gun.global_transform * Vector3(0, -0.5, -9.5)
			var dir: Vector3 = (lead - m).normalized()
			C.fire({"kind": "shell", "pos": m, "vel": dir * 600.0, "dmg": 14.0, "dt": "kin", "by": "z", "life": 1.2})
			Game.fx.muzzle(m, Mats.TRACER, 3.0)
			Game.sfx.play_at("cannon", m, 0.6)
		else:
			cd = 0.3
	if int(lvl["pods"]) > 0:
		pod_cd -= dt
		if pod_cd <= 0.0:
			var tgt: Kaiju = null
			var bd2: float = 420.0
			for k2: Kaiju in Game.kaiju:
				if k2.dying or not k2.exposed:
					continue
				var d2: float = Vector2(k2.aim.x - position.x, k2.aim.z - position.z).length()
				if d2 < bd2:
					bd2 = d2
					tgt = k2
			if tgt != null:
				pod_cd = 2.4 / float(lvl["pods"])
				for s: float in [-1.0, 1.0]:
					var out: Vector3 = global_transform.basis.x.normalized() * s
					C.fire({"kind": "prkt", "pos": global_transform * Vector3(s * 28, -8, 0), "vel": out * 40.0 + Vector3(0, -10, 0), "acc": 380.0, "max": 360.0,
						"homing": tgt, "dmg": 30.0 + 18.0 * float(lvl["pods"]), "dt": "exp", "splash": 18.0, "by": "z", "life": 6.0})
				Game.sfx.play_at("rocket", position, 0.6)
			else:
				pod_cd = 0.5
	if int(lvl["bomb"]) > 0:
		bomb_cd -= dt
		if bomb_cd <= 0.0:
			var under: Kaiju = null
			for k3: Kaiju in Game.kaiju:
				if not k3.dying and not k3.def["air"] and Vector2(k3.position.x - position.x, k3.position.z - position.z).length() < 85.0:
					under = k3
					break
			if under != null:
				bomb_cd = 2.6 / float(lvl["bomb"])
				C.fire({"kind": "bomb", "pos": position + Vector3(0, -20, 0), "vel": Vector3(vel.x, -5, vel.z), "g": 70.0,
					"dmg": 70.0 + 55.0 * float(lvl["bomb"]), "dt": "exp", "splash": 30.0, "by": "z", "life": 6.0})
				Game.fx.text(position + Vector3(0, -30, 0), "投下!", Mats.WHITE, 8.0, 0.8)
			else:
				bomb_cd = 0.4
