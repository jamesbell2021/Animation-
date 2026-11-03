class_name UnitView
extends Node3D
## One unit on the board: a low-poly model built from primitives (to the GDD 4.2 blueprints),
## its lamp or glow, a status label, and the animations the battle's events call for.
## The model faces -Z; the node's yaw turns it to the unit's grid facing.

var unit: Unit
var body: Node3D           # everything that crouches, bobs and lunges
var muzzle: Node3D         # where shots leave from
var lamp: OmniLight3D
var _lamp_bulb: MeshInstance3D
var _label: Label3D
var _ring: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []
var _legs: Array[Node3D] = []
var _glow_light: OmniLight3D
var _flash_mat: StandardMaterial3D
var _t := 0.0
var _walking := 0.0
var _dead := false


static func create(u: Unit) -> UnitView:
	var v := UnitView.new()
	v.unit = u
	v._build()
	v.position = Kit.world(u.tile)
	v.rotation.y = Kit.yaw_for(u.facing)
	return v


func _build() -> void:
	body = Node3D.new()
	add_child(body)
	muzzle = Node3D.new()
	_flash_mat = Kit.unshaded(Color(1, 1, 1, 0.75))
	match String(unit.def.id):
		"worker":
			_build_worker()
		"crawler":
			_build_crawler()
		"hive":
			_build_hive()
		_:
			_build_soldier()
	body.add_child(muzzle)
	_label = Label3D.new()
	_label.font = Kit.body_font()
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 2.25 if unit.team == Unit.SQUAD else 1.5, 0)
	if unit.def.stationary:
		_label.position.y = 2.6
	add_child(_label)
	if unit.team == Unit.SQUAD:
		var t := TorusMesh.new()
		t.inner_radius = 0.72
		t.outer_radius = 0.82
		t.rings = 28
		_ring = MeshInstance3D.new()
		_ring.mesh = t
		_ring.material_override = Kit.unshaded(Color(Kit.BRASS, 0.9))
		_ring.scale = Vector3(1, 0.15, 1)
		_ring.position.y = 0.06
		_ring.visible = false
		add_child(_ring)
	refresh_label()


# --- models ---------------------------------------------------------------------------------

func _m(mesh: Mesh, material: Material, pos: Vector3, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	(parent if parent != null else body).add_child(mi)
	_meshes.append(mi)
	return mi


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _cyl(r_top: float, r_bot: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func _ball(r: float, segs := 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	return s


func _build_soldier() -> void:
	var id := String(unit.def.id)
	var coat := Kit.mat(unit.def.colour, 0.85)
	var trousers := Kit.mat(Color(0.18, 0.15, 0.13), 0.9)
	var skin := Kit.mat(Color(0.86, 0.68, 0.55), 0.8)
	var brass := Kit.mat(Kit.BRASS, 0.35, 0.85)
	var copper := Kit.mat(Kit.COPPER, 0.4, 0.8)
	var leather := Kit.mat(Kit.LEATHER, 0.8)
	var iron := Kit.mat(Kit.IRON, 0.5, 0.6)
	# Legs, boots, coat, belt and suspenders (GDD 4.2: the Engineer's high-waisted trousers).
	for side in [-0.13, 0.13]:
		var leg := Node3D.new()
		leg.position = Vector3(side, 0.78, 0)
		body.add_child(leg)
		_m(_box(0.17, 0.7, 0.19), trousers, Vector3(0, -0.36, 0), leg)
		_m(_box(0.19, 0.12, 0.27), leather, Vector3(0, -0.72, -0.04), leg)
		_legs.append(leg)
	_m(_box(0.5, 0.62, 0.3), coat, Vector3(0, 1.1, 0))
	_m(_box(0.52, 0.08, 0.32), leather, Vector3(0, 0.82, 0))
	for side in [-0.13, 0.13]:
		_m(_box(0.05, 0.6, 0.02), leather, Vector3(side, 1.1, -0.16))
	for side in [-0.33, 0.33]:
		_m(_box(0.13, 0.55, 0.15), coat, Vector3(side, 1.1, -0.04), null, Vector3(0.35, 0, 0))
	_m(_cyl(0.07, 0.08, 0.1), skin, Vector3(0, 1.45, 0))
	_m(_ball(0.17), skin, Vector3(0, 1.6, 0))
	# The shoulder boiler and its twin pipes.
	_m(_cyl(0.15, 0.15, 0.55, 10), brass, Vector3(0, 1.15, 0.26))
	_m(_cyl(0.155, 0.155, 0.06, 10), copper, Vector3(0, 1.35, 0.26))
	for side in [-0.08, 0.08]:
		_m(_cyl(0.025, 0.025, 0.45, 6), copper, Vector3(side, 1.55, 0.3))
	# Headwear.
	match id:
		"engineer":
			_m(_cyl(0.18, 0.19, 0.08, 10), Kit.mat(Color(0.25, 0.22, 0.2), 0.9), Vector3(0, 1.75, 0))
			_m(_box(0.26, 0.03, 0.14), Kit.mat(Color(0.25, 0.22, 0.2), 0.9), Vector3(0, 1.72, -0.18))
			for side in [-0.07, 0.07]:
				_m(_cyl(0.05, 0.05, 0.05, 8), brass, Vector3(side, 1.78, -0.12), null, Vector3(PI / 2.0, 0, 0))
		"naturalist":
			var helmet := SphereMesh.new()
			helmet.radius = 0.24
			helmet.height = 0.24
			helmet.is_hemisphere = true
			helmet.radial_segments = 10
			helmet.rings = 3
			_m(helmet, Kit.mat(Color(0.78, 0.7, 0.5), 0.9), Vector3(0, 1.66, 0))
			_m(_cyl(0.3, 0.3, 0.02, 12), Kit.mat(Color(0.75, 0.67, 0.48), 0.9), Vector3(0, 1.67, 0))
		"grenadier":
			_m(_cyl(0.16, 0.19, 0.3, 10), iron, Vector3(0, 1.82, 0))
			_m(_cyl(0.04, 0.04, 0.12, 6), brass, Vector3(0, 2.02, 0))
		"cartographer":
			_m(_cyl(0.15, 0.17, 0.2, 10), Kit.mat(Color(0.1, 0.1, 0.12), 0.7), Vector3(0, 1.82, 0))
			_m(_cyl(0.27, 0.27, 0.02, 12), Kit.mat(Color(0.1, 0.1, 0.12), 0.7), Vector3(0, 1.72, 0))
			_m(_box(0.34, 0.24, 0.12), brass, Vector3(-0.36, 0.95, 0.05))
	# Weapons, held forward at the hip.
	var hand := Vector3(0.18, 1.0, -0.3)
	match id:
		"engineer":
			_m(_cyl(0.09, 0.11, 0.5, 8), copper, hand + Vector3(0, 0, -0.05), null, Vector3(PI / 2.0, 0, 0))
			_m(_cyl(0.0, 0.08, 0.3, 8), iron, hand + Vector3(0, 0, -0.45), null, Vector3(-PI / 2.0, 0, 0))
			muzzle.position = hand + Vector3(0, 0, -0.6)
		"naturalist":
			_m(_box(0.06, 0.08, 0.9), Kit.mat(Kit.LEATHER, 0.6), hand + Vector3(0, 0.05, -0.2))
			_m(_cyl(0.025, 0.025, 0.55, 6), brass, hand + Vector3(0, 0.1, -0.5), null, Vector3(PI / 2.0, 0, 0))
			muzzle.position = hand + Vector3(0, 0.1, -0.8)
		"grenadier":
			for k in 3:
				var a := TAU * k / 3.0
				_m(_cyl(0.04, 0.04, 0.8, 6), brass, hand + Vector3(cos(a) * 0.07, 0.05 + sin(a) * 0.07, -0.3), null, Vector3(PI / 2.0, 0, 0))
			_m(_box(0.2, 0.2, 0.3), iron, hand + Vector3(0, 0.05, 0.05))
			_m(_box(0.04, 0.2, 0.04), copper, hand + Vector3(0.14, 0.15, 0.05))
			_m(_box(0.06, 0.75, 0.55), iron, Vector3(-0.38, 1.0, -0.12))
			_m(_box(0.07, 0.08, 0.57), brass, Vector3(-0.38, 1.25, -0.12))
			muzzle.position = hand + Vector3(0, 0.05, -0.72)
		"cartographer":
			_m(_box(0.07, 0.1, 0.75), Kit.mat(Kit.LEATHER, 0.6), hand + Vector3(0, 0.05, -0.15))
			_m(_cyl(0.03, 0.03, 0.5, 6), brass, hand + Vector3(0, 0.09, -0.45), null, Vector3(PI / 2.0, 0, 0))
			muzzle.position = hand + Vector3(0, 0.09, -0.72)
	# The Davy lamp on the chest.
	_lamp_bulb = _m(_ball(0.07, 6), Kit.mat(Color(1, 0.9, 0.6), 0.4, 0.0, Color(1, 0.8, 0.45), 4.0), Vector3(0, 1.22, -0.18))
	lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.52)
	lamp.light_energy = 1.5
	lamp.omni_range = Rules.LAMP_RADIUS * Kit.TILE * 1.5
	lamp.omni_attenuation = 1.3
	lamp.shadow_enabled = true
	lamp.position = Vector3(0, 1.3, -0.45)
	body.add_child(lamp)
	set_lamp(unit.lamp_on)


func _build_worker() -> void:
	var chitin := Kit.mat(Color(0.14, 0.12, 0.1), 0.35, 0.3)
	var plate := Kit.mat(Color(0.24, 0.2, 0.15), 0.4, 0.3)
	var glow := Kit.mat(Kit.PHOSPHOR, 0.4, 0.0, Kit.PHOSPHOR, 3.5)
	var thorax := _m(_ball(0.42, 10), chitin, Vector3(0, 0.6, -0.1))
	thorax.scale = Vector3(1.0, 0.7, 1.25)
	_m(_ball(0.22, 8), plate, Vector3(0, 0.66, -0.68))
	var abdomen := _m(_ball(0.36, 10), glow, Vector3(0, 0.72, 0.55))
	abdomen.scale = Vector3(1.0, 0.85, 1.25)
	for side in [-1.0, 1.0]:
		# Twin scythe mandibles.
		var m := _m(_box(0.06, 0.07, 0.5), plate, Vector3(side * 0.12, 0.55, -0.98), null, Vector3(0, side * 0.45, 0))
		m.scale = Vector3(1, 1, 1)
		_m(_ball(0.045, 6), Kit.mat(Color(0.9, 1.0, 0.6), 0.4, 0.0, Color(0.7, 1.0, 0.4), 3.0), Vector3(side * 0.1, 0.75, -0.8))
		for k in 2:
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.32, 0.55, -0.25 + k * 0.45)
			leg.rotation = Vector3(0, 0, side * 0.9)
			body.add_child(leg)
			_m(_box(0.07, 0.75, 0.07), chitin, Vector3(0, -0.32, 0), leg)
			_legs.append(leg)
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Kit.PHOSPHOR
	_glow_light.light_energy = 1.1
	_glow_light.omni_range = 3.6
	_glow_light.position = Vector3(0, 1.1, 0.55)
	body.add_child(_glow_light)
	muzzle.position = Vector3(0, 0.6, -1.1)


func _build_crawler() -> void:
	var shell := Kit.mat(Color(0.12, 0.05, 0.05), 0.3, 0.4)
	var dark := Kit.mat(Color(0.06, 0.04, 0.04), 0.5, 0.2)
	var eye := Kit.mat(Color(1, 0.2, 0.1), 0.3, 0.0, Color(1.0, 0.15, 0.05), 5.0)
	var b := _m(_ball(0.36, 10), shell, Vector3(0, 0.38, 0))
	b.scale = Vector3(1.0, 0.5, 1.6)
	_m(_ball(0.2, 8), dark, Vector3(0, 0.38, -0.62))
	for side in [-0.08, 0.08]:
		_m(_ball(0.045, 6), eye, Vector3(side, 0.46, -0.78))
	for k in 4:
		_m(_cyl(0.0, 0.07, 0.3, 5), dark, Vector3(0, 0.6, -0.3 + k * 0.22), null, Vector3(-0.4, 0, 0))
	for side in [-1.0, 1.0]:
		for k in 3:
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.25, 0.38, -0.35 + k * 0.35)
			leg.rotation = Vector3(0, 0, side * 1.1)
			body.add_child(leg)
			_m(_box(0.05, 0.6, 0.05), dark, Vector3(0, -0.27, 0), leg)
			_legs.append(leg)
	muzzle.position = Vector3(0, 0.4, -0.85)


func _build_hive() -> void:
	var flesh := Kit.mat(Color(0.1, 0.09, 0.07), 0.5, 0.1)
	var glow := Kit.mat(Kit.PHOSPHOR, 0.4, 0.0, Kit.PHOSPHOR, 2.5)
	var dome := _m(_ball(1.0, 14), flesh, Vector3(0, 0.55, 0))
	dome.scale = Vector3(1.0, 0.75, 1.0)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for k in 14:
		var a := r.randf() * TAU
		var up := r.randf_range(0.15, 0.95)
		var p := Vector3(cos(a) * sqrt(1.0 - up * up), up * 0.75, sin(a) * sqrt(1.0 - up * up)) * 0.98
		_m(_ball(r.randf_range(0.08, 0.18), 6), glow, p + Vector3(0, 0.55, 0))
	for k in 5:
		var a := TAU * k / 5.0
		_m(_cyl(0.05, 0.22, 1.4, 6), flesh, Vector3(cos(a) * 0.9, 0.5, sin(a) * 0.9), null, Vector3(cos(a) * 0.5, 0, -sin(a) * 0.5))
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Kit.PHOSPHOR
	_glow_light.light_energy = 2.0
	_glow_light.omni_range = 7.0
	_glow_light.position = Vector3(0, 2.0, 0)
	body.add_child(_glow_light)
	muzzle.position = Vector3(0, 1.0, 0)


# --- state ----------------------------------------------------------------------------------

func set_selected(on: bool) -> void:
	if _ring != null:
		_ring.visible = on


func set_lamp(on: bool) -> void:
	if lamp != null:
		lamp.visible = on
	if _lamp_bulb != null:
		_lamp_bulb.visible = on


func set_crouched(on: bool, animate := true) -> void:
	var s := Vector3(1.0, 0.72, 1.0) if on else Vector3.ONE
	if animate:
		create_tween().tween_property(body, "scale", s, 0.18)
	else:
		body.scale = s


func refresh_label() -> void:
	if _dead:
		return
	var tags: Array[String] = []
	if unit.team == Unit.SQUAD:
		tags.append("%d" % unit.hp)
		if unit.overwatch:
			tags.append("OVERWATCH")
		if unit.jammed:
			tags.append("JAMMED")
	elif unit.hp < unit.def.max_hp:
		tags.append("%d" % unit.hp)
	if unit.pinned:
		tags.append("PINNED")
	if unit.poison_turns > 0:
		tags.append("POISONED")
	_label.text = "  ".join(tags)
	var c := Kit.INK
	if unit.team == Unit.SWARM:
		c = Color(0.75, 1.0, 0.6)
	if unit.team == Unit.SQUAD and unit.hp <= unit.def.max_hp / 3:
		c = Kit.DANGER
	_label.modulate = c


# --- animation ------------------------------------------------------------------------------

func step_to(c: Vector2i, facing: int, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", Kit.world(c), dur)
	tw.tween_method(_set_yaw.bind(rotation.y), 0.0, 1.0, dur * 0.6).set_trans(Tween.TRANS_SINE)
	set_meta("yaw_goal", Kit.yaw_for(facing))
	_walking = dur


func snap_to(c: Vector2i, facing: int) -> void:
	position = Kit.world(c)
	rotation.y = Kit.yaw_for(facing)


func face(facing: int, dur := 0.15) -> void:
	set_meta("yaw_goal", Kit.yaw_for(facing))
	if dur <= 0.0:
		rotation.y = Kit.yaw_for(facing)
		return
	create_tween().tween_method(_set_yaw.bind(rotation.y), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)


func _set_yaw(k: float, from: float) -> void:
	rotation.y = lerp_angle(from, get_meta("yaw_goal", from), k)


func lunge() -> void:
	var tw := create_tween()
	tw.tween_property(body, "position:z", -0.45, 0.07)
	tw.tween_property(body, "position:z", 0.0, 0.16)


func recoil(amount := 0.08) -> void:
	var tw := create_tween()
	tw.tween_property(body, "position:z", amount, 0.04)
	tw.tween_property(body, "position:z", 0.0, 0.1)


func flash() -> void:
	for m in _meshes:
		m.material_overlay = _flash_mat
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	for m in _meshes:
		m.material_overlay = null
	var tw := create_tween()
	tw.tween_property(body, "position:x", 0.08, 0.04)
	tw.tween_property(body, "position:x", -0.06, 0.05)
	tw.tween_property(body, "position:x", 0.0, 0.05)


func die() -> void:
	_dead = true
	_label.visible = false
	set_selected(false)
	set_lamp(false)
	if _glow_light != null:
		create_tween().tween_property(_glow_light, "light_energy", 0.0, 0.6)
	var tw := create_tween().set_parallel(true)
	if unit.team == Unit.SQUAD:
		tw.tween_property(body, "rotation:x", PI / 2.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "position:y", 0.2, 0.45)
	else:
		tw.tween_property(body, "rotation:z", PI, 0.35)
		tw.tween_property(body, "position:y", 0.3, 0.35)
		tw.chain().tween_property(body, "scale", Vector3(0.9, 0.3, 0.9), 0.5)
		tw.chain().tween_property(self, "position:y", -0.4, 1.2)


func _process(delta: float) -> void:
	_t += delta
	if _dead:
		return
	if _walking > 0.0:
		_walking -= delta
		var k := sin(_t * 22.0)
		body.position.y = absf(k) * 0.07
		for i in _legs.size():
			_legs[i].rotation.x = k * 0.5 * (1.0 if i % 2 == 0 else -1.0)
	else:
		body.position.y = lerpf(body.position.y, 0.0, 0.3)
		for leg in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, 0.3)
	if _ring != null and _ring.visible:
		_ring.rotation.y += delta * 0.8
	if _glow_light != null:
		var pulse := 0.85 + 0.15 * sin(_t * (2.5 if unit.def.stationary else 4.0) + float(unit.id))
		_glow_light.light_energy = (2.0 if unit.def.stationary else 1.1) * pulse
