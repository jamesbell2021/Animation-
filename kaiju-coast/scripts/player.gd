class_name Player
extends Node3D
## You, in first person: sit in any gun or the airship's nose gun and fire it yourself. The heavy
## machine gun overheats; the rocket launcher has a magazine and splash. Your damage grows with the
## level of the gun you're in, and weak points take triple damage. The view model hangs off the
## camera as a solid, like everything else.

var active: bool = false
var seat: Variant = null
var yaw: float = 0.0
var pitch: float = 0.0
var weapon: String = "gun"
var heat: float = 0.0
var over: float = 0.0
var ammo: int = 4
var reload: float = 0.0
var cd: float = 0.0
var firing: bool = false
var zoom: bool = false
var fov: float = 1.15
var kick: float = 0.0
var hit_t: float = 0.0
var crit_t: float = 0.0
var look: Kaiju = null
var look_t: float = 0.0
var sens: float = 0.0022

var _vm: Node3D
var _gun_vm: Node3D
var _rkt_vm: Node3D
var _gun_line: ShaderMaterial
var _rocket_tip: Node3D


func _ready() -> void:
	sens = float(Game.load_setting("sensitivity", 0.0022))


## Builds the view model under the camera (called by Main once the camera exists).
func attach_view_model(cam: Camera3D) -> void:
	_vm = Node3D.new()
	cam.add_child(_vm)
	_vm.scale = Vector3.ONE * 0.5
	_gun_vm = Node3D.new()
	_vm.add_child(_gun_vm)
	_gun_line = Mats.make_line(2.6)
	var g: SolidBuilder = SolidBuilder.new()
	for s: float in [-0.28, 0.28]:
		g.tube(Vector3(1.1 + s, -1.05, -1.4), Vector3(1.1 + s, -1.05, -5.8), 0.13, 0.11, 6, Mats.JADE, 2, 3)
		g.tube(Vector3(1.1 + s, -1.05, -5.4), Vector3(1.1 + s, -1.05, -5.9), 0.2, 0.2, 6, Mats.JADE)
	g.box(Vector3(1.1, -1.1, -1.55), Vector3(1.0, 0.7, 1.3), Mats.JADE)
	g.box(Vector3(1.1, -1.05, -2.9), Vector3(0.45, 0.35, 1.4), Mats.JADE)
	g.tube(Vector3(1.1, -1.5, -1.3), Vector3(1.1, -2.1, -1.1), 0.12, 0.12, 5, Mats.JADE)
	g.attach(_gun_vm, Mats.fill(), _gun_line)
	_rkt_vm = Node3D.new()
	_vm.add_child(_rkt_vm)
	var r: SolidBuilder = SolidBuilder.new()
	r.tube(Vector3(1.15, -1.0, -1.6), Vector3(1.15, -1.0, -6.0), 0.3, 0.3, 10, Mats.GOLD, 3, 5)
	r.tube(Vector3(1.15, -1.0, -5.6), Vector3(1.15, -1.0, -6.2), 0.4, 0.4, 10, Mats.GOLD)
	r.box(Vector3(1.15, -1.45, -2.6), Vector3(0.3, 0.5, 0.5), Mats.GOLD)
	r.attach(_rkt_vm, Mats.fill(), Mats.line(2.4))
	_rocket_tip = Node3D.new()
	_rkt_vm.add_child(_rocket_tip)
	var tip: SolidBuilder = SolidBuilder.new()
	tip.cone(Vector3(1.15, -1.0, -6.0), Vector3(1.15, -1.0, -6.8), 0.24, 6, Mats.FIRE)
	tip.attach(_rocket_tip, Mats.fill(), Mats.line(3.0))
	_vm.visible = false


func seat_pos() -> Vector3:
	if seat is String:
		return Game.zep.seat_pos()
	var t: Turret = seat
	return t.pad.pos + Vector3(0, (9.0 if t.pad.fort else 13.0) + float(t.lvl) * 0.6, 0)


func seat_name() -> String:
	if seat is String:
		return "雷神丸 RAIJIN-MARU · NOSE GUN"
	var t: Turret = seat
	return "%s %s · LV %d" % [Game.TT[t.type]["jp"], Game.TT[t.type]["name"], t.lvl]


func seat_mult() -> float:
	if seat is String:
		return 1.25
	return 1.0 + 0.22 * float((seat as Turret).lvl - 1)


func seats() -> Array:
	var s: Array = []
	for t: Turret in Game.turrets:
		s.append(t)
	if not Game.zep.down:
		s.append("zep")
	return s


func enter(s: Variant) -> void:
	if Game.state != Game.State.PLAY:
		return
	if s == null:
		if Game.sel is String and Game.sel == "zep":
			s = "zep"
		elif Game.sel is Pad and (Game.sel as Pad).turret != null:
			s = (Game.sel as Pad).turret
		elif not Game.turrets.is_empty():
			s = Game.turrets[0]
		elif not Game.zep.down:
			s = "zep"
	if s == null:
		Game.sfx.play("deny")
		return
	if s is String and Game.zep.down:
		Game.sfx.play("deny")
		Game.banner.emit("", "THE AIRSHIP IS DOWN", 1.4)
		return
	if seat is Turret:
		(seat as Turret).manned = false
	seat = s
	active = true
	if s is Turret:
		var t: Turret = s
		t.manned = true
		yaw = t.yaw
		pitch = clampf(t.pitch, -0.3, 0.6)
	else:
		yaw = Game.zep.yaw
		pitch = -0.35
	firing = false
	zoom = false
	ammo = 4 + int(Game.armory["rkt"])
	reload = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.rig.set_mode("fps")
	_vm.visible = true
	_show_weapon()
	Game.hud.on_seat_changed()
	Game.sfx.play("click")


func exit_seat() -> void:
	if not active:
		return
	if seat is Turret:
		(seat as Turret).manned = false
	active = false
	seat = null
	firing = false
	zoom = false
	_vm.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.rig.set_mode("command" if Game.state == Game.State.PLAY else "title")
	Game.hud.on_seat_changed()


func next_seat() -> void:
	var s: Array = seats()
	if s.is_empty():
		return
	var i: int = -1
	for j: int in range(s.size()):
		if typeof(s[j]) == typeof(seat) and s[j] == seat:
			i = j
	enter(s[(i + 1) % s.size()])


func swap() -> void:
	weapon = "rocket" if weapon == "gun" else "gun"
	Game.sfx.play("reload")
	_show_weapon()
	Game.hud.on_seat_changed()


func set_weapon(w: String) -> void:
	if w != weapon:
		swap()


func _show_weapon() -> void:
	_gun_vm.visible = weapon == "gun"
	_rkt_vm.visible = weapon == "rocket"


func on_hit(weak: bool) -> void:
	hit_t = 0.18
	if weak:
		crit_t = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: InputEventMouseMotion = event
		var s: float = sens * fov / 1.15
		yaw -= m.relative.x * s
		pitch -= m.relative.y * s
	elif event is InputEventMouseButton:
		var b: InputEventMouseButton = event
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and b.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if b.button_index == MOUSE_BUTTON_LEFT:
			firing = b.pressed
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			zoom = b.pressed
		elif b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if b.pressed:
				swap()


func update(dt: float) -> void:
	if not active:
		return
	if seat is String:
		if Game.zep.down:
			exit_seat()
			return
	elif not Game.turrets.has(seat):
		exit_seat()
		return
	# Keys and gamepad nudge the aim too.
	var kx: float = float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
	var ky: float = float(Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S))
	var jx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var jy: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(jx) < 0.15:
		jx = 0.0
	if absf(jy) < 0.15:
		jy = 0.0
	yaw -= (kx * 1.4 + jx * 2.2) * dt * fov
	pitch += (ky * 1.0 - jy * 1.6) * dt * fov
	var pad_fire: bool = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.4
	var pad_zoom: bool = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.4
	pitch = clampf(pitch, -1.35 if seat is String else -0.35, 1.25)
	fov = lerpf(fov, 0.45 if (zoom or pad_zoom) else 1.15, minf(1.0, dt * 10.0))
	if seat is Turret:
		var t: Turret = seat
		t.yaw = yaw
		t.pitch = pitch
	cd -= dt
	kick = maxf(0.0, kick - dt * 7.0)
	hit_t -= dt
	crit_t -= dt
	var cam: Camera3D = Game.rig.cam
	var b: Basis = cam.global_transform.basis
	var fwd: Vector3 = -b.z.normalized()
	var muzzle: Vector3 = cam.global_position + b.x.normalized() * 0.8 - b.y.normalized() * 0.75 + fwd * 4.0
	var far: Vector3 = cam.global_position + fwd * 400.0
	var mult: float = seat_mult()
	var shoot: bool = firing or pad_fire or Input.is_physical_key_pressed(KEY_SPACE) and Game.phase == "wave"
	if weapon == "gun":
		if over > 0.0:
			over -= dt
			if over <= 0.0:
				heat = 0.35
		else:
			heat = maxf(0.0, heat - dt * 0.42)
		if shoot and cd <= 0.0 and over <= 0.0:
			cd = 1.0 / 13.0
			kick = 1.0
			heat += 0.04 * (1.0 - 0.12 * float(Game.armory["gun"]))
			if heat >= 1.0:
				heat = 1.0
				over = 2.0
				Game.sfx.play("deny")
			var sp: float = (0.008 + heat * 0.012) * 400.0
			var d: Vector3 = (far - muzzle + Vector3(randf_range(-sp, sp), randf_range(-sp, sp), randf_range(-sp, sp))).normalized()
			Game.combat.fire({"kind": "bullet", "pos": muzzle, "vel": d * 1100.0, "dmg": 8.0 * mult * (1.0 + 0.25 * float(Game.armory["gun"])), "dt": "kin", "by": "p", "life": 1.3})
			Game.fx.muzzle(muzzle, Mats.TRACER, 1.6)
			Game.sfx.play("gun", 0.8)
			Game.shake = maxf(Game.shake, 0.15)
	else:
		if reload > 0.0:
			reload -= dt
			if reload <= 0.0:
				ammo = 4 + int(Game.armory["rkt"])
				Game.sfx.play("reload")
		if shoot and cd <= 0.0 and ammo > 0 and reload <= 0.0:
			cd = 0.3
			ammo -= 1
			kick = 2.2
			var d2: Vector3 = (far - muzzle).normalized()
			Game.combat.fire({"kind": "rocket", "pos": muzzle, "vel": d2 * 160.0, "acc": 650.0, "max": 520.0,
				"dmg": 85.0 * mult * (1.0 + 0.3 * float(Game.armory["rkt"])), "dt": "exp", "splash": 28.0 + 5.0 * float(Game.armory["rkt"]), "by": "p", "life": 4.0})
			Game.fx.sparks(muzzle, 10, Mats.FIRE, 30.0, 0.0)
			Game.sfx.play("rocket", 0.9)
			Game.shake = maxf(Game.shake, 0.5)
			if ammo == 0:
				reload = 2.1
	# What's under the crosshair.
	var h: Dictionary = Game.combat.seg_hit(cam.global_position, cam.global_position + fwd * 1600.0)
	if not h.is_empty():
		look = h["k"]
		look_t = 1.2
	else:
		look_t -= dt
		if look_t <= 0.0 or (look != null and (not is_instance_valid(look) or look.dying or not Game.kaiju.has(look))):
			look = null
	# View model: recoil, sway and barrel heat.
	_vm.position = Vector3(0.3 + sin(Game.t * 1.7) * 0.02, -0.22 - kick * 0.03, kick * 0.09)
	var hc: Color = Mats.JADE
	if over > 0.0:
		hc = Mats.BLOOD if sin(Game.t * 20.0) > 0.0 else Mats.FIRE
	elif heat > 0.7:
		hc = Mats.FIRE
	elif heat > 0.4:
		hc = Mats.GOLD
	_gun_line.set_shader_parameter("tint", Vector3(hc.r / Mats.JADE.r, hc.g / Mats.JADE.g, hc.b / Mats.JADE.b))
	_rocket_tip.visible = ammo > 0 and reload <= 0.0


func manual_reload() -> void:
	if weapon == "rocket" and ammo < 4 + int(Game.armory["rkt"]) and reload <= 0.0:
		reload = 2.1
