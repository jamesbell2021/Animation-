class_name Tripod
extends Node2D
## A Martian fighting-machine. The hood and six leg segments are RigidBody2Ds: frozen and
## driven by a procedural gait while it walks, then unfrozen and pinned together with joints the
## moment a leg breaks, so the physics engine brings it down. The node itself stays at the
## origin; every body and every drawn point is in world space.

signal collapsed(tp: Tripod)
signal hood_slammed(tp: Tripod, pos: Vector2)
signal reached_sandbags(tp: Tripod)

var fx: Particles
var field: Battlefield
var s := 1.0
var speed := 15.0
var leg_hp := 2
var cooldown := 8.0
var siren_dur := 1.5
var fire_dur := 1.15
var big := false
var attract := false

var x := 0.0
var y := 0.0
var r := 44.0
var base_y := 0.0
var L1 := 100.0
var L2 := 142.0
var hip_off: Array = []
var rest: Array = []
var legs: Array = []
var stride := 64.0
var period := 4.0
var gait_t := 0.0
var state := "walk"
var t := 0.0
var cool := 3.0
var knock := 0.0
var tent := randf() * 10.0

var alive := true
var dynamic := false
var crushed := false
var settled := false
var gone := false
var wreck_t := 0.0
var hood_glow := 0.0
var hit_flash := 0.0
var beam := {}
var score := 1000
var impact_sound_t := 0.0

var hood: RigidBody2D
var leg_bodies: Array = []       # [[upper, lower], ...]
var _hood_shape := PackedVector2Array()


func setup(cfg: Dictionary) -> void:
	s = cfg.get("scale", 1.0)
	x = cfg.get("x", C.W + 150.0)
	speed = cfg.get("speed", 15.0)
	leg_hp = cfg.get("leg_hp", 2)
	cooldown = cfg.get("cooldown", 8.0)
	siren_dur = cfg.get("siren", 1.5)
	big = cfg.get("big", false)
	cool = cfg.get("first_cool", randf_range(2.5, 5.0))
	score = 2500 if big else 1000
	r = 44.0 * s
	base_y = C.GROUND - 238.0 * s
	y = base_y
	L1 = 100.0 * s
	L2 = 142.0 * s
	hip_off = [Vector2(-24, 28) * s, Vector2(2, 34) * s, Vector2(26, 28) * s]
	rest = [-72.0 * s, 6.0 * s, 76.0 * s]
	stride = 64.0 * s
	period = stride / speed
	gait_t = randf() * period
	legs.clear()
	for i in 3:
		legs.append({"hp": leg_hp, "max": leg_hp, "foot": Vector2(x + rest[i], C.GROUND), "swing": false, "from_x": 0.0,
			"phase": i / 3.0, "knee_side": 1.0 if i == 1 else signf(rest[i]), "broken": false, "flash": 0.0})
	_hood_shape = hood_shape()
	_build_bodies()
	_place_bodies()


func hood_shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 15:
		var a := PI + PI * i / 14.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.9))
	pts.append(Vector2(r * 1.15, r * 0.2))
	pts.append(Vector2(r * 1.15, r * 0.38))
	pts.append(Vector2(-r * 1.15, r * 0.38))
	pts.append(Vector2(-r * 1.15, r * 0.2))
	return pts


func _make_body(part: String, idx: int, mass: float) -> RigidBody2D:
	var b := RigidBody2D.new()
	b.freeze = true
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.collision_layer = C.LAYER_TRIPOD
	b.collision_mask = C.LAYER_GROUND | C.LAYER_TRIPOD
	b.mass = mass
	b.contact_monitor = true
	b.max_contacts_reported = 4
	b.linear_damp = 0.15
	b.angular_damp = 0.8
	b.set_meta("tripod", self)
	b.set_meta("part", part)
	b.set_meta("idx", idx)
	b.body_entered.connect(_on_body_entered.bind(b))
	add_child(b)
	return b


func _build_bodies() -> void:
	hood = _make_body("hood", -1, 12.0 * s)
	var cs := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	poly.set_point_cloud(_hood_shape)
	cs.shape = poly
	hood.add_child(cs)
	leg_bodies.clear()
	for i in 3:
		var pair: Array = []
		for L in [L1, L2]:
			var b := _make_body("leg", i, 2.5 * s)
			var c := CollisionShape2D.new()
			var cap := CapsuleShape2D.new()
			cap.radius = 5.0 * s
			cap.height = L + 10.0 * s
			c.shape = cap
			c.rotation = PI / 2.0
			b.add_child(c)
			pair.append(b)
		leg_bodies.append(pair)


func hip(i: int) -> Vector2:
	return Vector2(x, y) + hip_off[i]


func knee(i: int) -> Vector2:
	var leg: Dictionary = legs[i]
	var h := hip(i)
	var f: Vector2 = leg.foot
	var d := clampf(h.distance_to(f), absf(L1 - L2) + 1.0, L1 + L2 - 1.0)
	var ang := (f - h).angle()
	var a := acos(clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0))
	var k1 := h + Vector2(cos(ang + a), sin(ang + a)) * L1
	var k2 := h + Vector2(cos(ang - a), sin(ang - a)) * L1
	# the knee bends outward, away from the body, like the Martian machines
	var want: float = leg.knee_side
	return k1 if (k1.x - x) * want > (k2.x - x) * want else k2


func emitter() -> Vector2:
	if dynamic:
		return hood.global_transform * Vector2(-r * 0.62, -r * 0.1)
	return Vector2(x - r * 0.62, y - r * 0.1)


static func _set_seg(b: RigidBody2D, a: Vector2, c: Vector2) -> void:
	b.global_position = (a + c) / 2.0
	b.global_rotation = (c - a).angle()


func _place_bodies() -> void:
	hood.global_position = Vector2(x, y)
	hood.global_rotation = 0.0
	for i in 3:
		var h := hip(i)
		var k := knee(i)
		_set_seg(leg_bodies[i][0], h, k)
		_set_seg(leg_bodies[i][1], k, legs[i].foot)


func _seg(b: RigidBody2D, L: float) -> Array:
	var tr := b.global_transform
	return [tr * Vector2(-L / 2.0, 0), tr * Vector2(L / 2.0, 0)]


# --- behaviour ----------------------------------------------------------------------------------

func update(dt: float) -> void:
	hit_flash = maxf(0.0, hit_flash - dt)
	for l in legs:
		l.flash = maxf(0.0, l.flash - dt)
	if dynamic:
		_update_dynamic(dt)
		queue_redraw()
		return
	t += dt
	tent += dt
	match state:
		"walk":
			if x > C.STOP_X:
				x -= speed * dt
				gait_t += dt
				_update_gait(dt, false)
			else:
				_overrun()
			y = base_y + sin(gait_t / period * PI * 6.0) * 2.5 * s
			cool -= dt
			if cool <= 0.0 and x < 880.0:
				state = "siren"
				t = 0.0
				Sfx.play("siren", 1.5 / siren_dur * (0.8 if big else 1.0))
				if fx:
					fx.float_text(Vector2(x, y - r - 40.0), "ULLA...", Vec.RED, 14.0, siren_dur)
		"siren":
			_settle_feet(dt)
			hood_glow = 0.5 + 0.5 * sin(t * 28.0)
			if t > siren_dur:
				state = "fire"
				t = 0.0
				Sfx.play("heat_ray")
				beam = {"gx": x - 70.0 * s, "prev": x - 70.0 * s, "e": emitter(), "touched": [], "dodged": false, "fresh": true}
		"fire":
			_settle_feet(dt)
			hood_glow = 1.0
			var u := clampf(t / fire_dur, 0.0, 1.0)
			beam.prev = beam.gx
			beam.gx = lerpf(x - 70.0 * s, 20.0, _ease(u))
			beam.e = emitter()
			if t > fire_dur:
				state = "walk"
				beam = {}
				hood_glow = 0.0
				cool = cooldown * randf_range(0.8, 1.25)
		"knock":
			knock -= dt
			x += 170.0 * dt
			gait_t += dt * 2.0
			_update_gait(dt, true)
			if knock <= 0.0:
				state = "walk"
				cool = 2.5
	_place_bodies()
	queue_redraw()


static func _ease(u: float) -> float:
	return 2.0 * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 2.0) / 2.0


func _settle_feet(dt: float) -> void:
	for l in legs:
		if l.swing or l.foot.y < C.GROUND:
			l.foot.y = minf(C.GROUND, l.foot.y + 260.0 * s * dt)
			if l.foot.y >= C.GROUND:
				l.swing = false


func _update_gait(_dt: float, backwards: bool) -> void:
	var ph := fposmod(gait_t / period, 1.0)
	var swing_len := 0.3
	var dir := -1.0 if backwards else 1.0
	for i in 3:
		var leg: Dictionary = legs[i]
		var lp := fposmod(ph - leg.phase + 1.0, 1.0)
		if lp < swing_len:
			if not leg.swing:
				leg.swing = true
				leg.from_x = leg.foot.x
			var k := lp / swing_len
			var target: float = x + rest[i] - dir * stride * ((1.0 - swing_len) / 2.0 + swing_len * (1.0 - k))
			leg.foot = Vector2(lerpf(leg.from_x, target, 1.0 - pow(1.0 - k, 2.0)), C.GROUND - sin(k * PI) * 30.0 * s)
		elif leg.swing:
			leg.swing = false
			leg.foot.y = C.GROUND
			Sfx.play("footstep", 1.0 / s, -2.0)
			if fx:
				fx.sparks(Vector2(leg.foot.x, C.GROUND), 5, {"speed": 70.0 * s, "color": Vec.DIM, "life": 0.4, "spread": 1.6})
				fx.smoke(Vector2(leg.foot.x, C.GROUND), 1, Vec.DIMMER)
			if field:
				field.shake(1.5 * s)


## The machine has reached the sandbags: it stamps the position flat and is driven back.
func _overrun() -> void:
	if state != "walk":
		return
	state = "knock"
	knock = 1.6
	reached_sandbags.emit(self)


# --- damage -------------------------------------------------------------------------------------

## A rocket struck body `b` at `pos`. Returns true when the rocket is spent.
func hit(b: RigidBody2D, pos: Vector2, vel: Vector2) -> bool:
	var part: String = b.get_meta("part")
	var idx: int = b.get_meta("idx")
	if dynamic:
		b.apply_impulse(vel * 0.5 * b.mass * 0.05, pos - b.global_position)
		if fx:
			fx.sparks(pos, 20, {"speed": 240.0, "life": 0.6, "white": 0.5})
			fx.float_text(pos + Vector2(0, -20), "+50", Vec.GREEN, 10.0)
		Sfx.play("leg_hit")
		G.score += 50
		return true
	if part == "hood":
		if fx:
			fx.sparks(pos, 22, {"speed": 260.0, "dir": (pos - Vector2(x, y)).angle(), "spread": 1.6, "life": 0.5, "white": 0.6})
			fx.float_text(pos + Vector2(0, -30), "ARMOUR", Vec.DIM, 9.0, 0.8)
		Sfx.play("ricochet")
		hit_flash = 0.2
		G.score += 25
		return true
	if legs[idx].broken:
		return false
	_damage_leg(idx, pos, vel)
	return true


func _damage_leg(i: int, pos: Vector2, vel: Vector2) -> void:
	var leg: Dictionary = legs[i]
	leg.hp -= 1
	leg.flash = 0.25
	hit_flash = 0.1
	if fx:
		fx.sparks(pos, 34, {"speed": 320.0, "life": 0.7, "white": 0.5})
		fx.sparks(pos, 12, {"speed": 150.0, "color": Vec.AMBER, "life": 0.5})
		fx.debris_burst(pos, 4, {"len": 8.0})
		fx.float_text(pos + Vector2(0, -24), "+100", Vec.GREEN, 11.0)
	if field:
		field.shake(5.0)
	Sfx.play("leg_hit")
	Sfx.play("explosion_small")
	G.score += 100
	if leg.hp <= 0:
		leg.broken = true
		Sfx.play("leg_break")
		if fx:
			fx.sparks(pos, 70, {"speed": 420.0, "life": 1.1, "white": 0.6})
			fx.debris_burst(pos, 12, {"len": 16.0})
			fx.float_text(Vector2(x, y - r - 30.0), "LEG DOWN!", Vec.WHITE, 14.0, 1.5)
		if field:
			field.flash(0.25, Vec.WHITE)
		if field:
			field.shake(12.0)
		collapse(vel * 0.35)


## Breaks leg `i` outright (attract mode).
func break_leg(i: int) -> void:
	var k := knee(i)
	legs[i].hp = 1
	_damage_leg(i, k, Vector2(400, -100))


func collapse(impulse: Vector2) -> void:
	if dynamic:
		return
	dynamic = true
	alive = false
	wreck_t = 0.0
	beam = {}
	hood_glow = 0.0
	G.stats.destroyed += 1
	G.score += score
	if fx:
		fx.float_text(Vector2(x, y - r - 60.0), "+" + str(score), Vec.AMBER, 16.0, 2.0)
	_place_bodies()
	for i in 3:
		var leg: Dictionary = legs[i]
		var upper: RigidBody2D = leg_bodies[i][0]
		var lower: RigidBody2D = leg_bodies[i][1]
		var k := knee(i)
		if leg.broken:
			upper.freeze = false
			upper.linear_velocity = Vector2(randf_range(-80, 80), -randf_range(60, 160))
			upper.angular_velocity = randf_range(-4, 4)
		else:
			upper.freeze = false
			_pin(hood, upper, hip(i))
		lower.freeze = false
		_pin(upper, lower, k)
	hood.freeze = false
	var v := Vector2(-speed + impulse.x + randf_range(-30, 30), impulse.y)
	hood.linear_velocity = v
	hood.angular_velocity = (1.2 if impulse.x >= 0.0 else -1.2) + randf_range(-0.6, 0.6)
	collapsed.emit(self)


func _pin(a: RigidBody2D, b: RigidBody2D, pos: Vector2) -> void:
	var j := PinJoint2D.new()
	j.position = pos
	add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	j.softness = 0.2


func _on_body_entered(_other: Node, b: RigidBody2D) -> void:
	if not dynamic or settled:
		return
	var sp := b.linear_velocity.length()
	if sp < 110.0:
		return
	var pos: Vector2
	var is_hood := b == hood
	if is_hood:
		pos = Vector2(b.global_position.x, C.GROUND)
	else:
		var e: Array = _seg(b, L1 if b == leg_bodies[b.get_meta("idx")][0] else L2)
		pos = e[0] if e[0].y > e[1].y else e[1]
		pos.y = minf(pos.y, C.GROUND)
	if fx:
		fx.sparks(pos, int(minf(60.0, sp / (6.0 if is_hood else 12.0))), {"speed": minf(420.0, sp * 0.8), "life": 0.8, "white": 0.5, "spread": 2.4})
	if is_hood and sp > 120.0:
		if fx:
			fx.debris_burst(pos, 6, {"len": 14.0, "speed": minf(400.0, sp * 0.6)})
			fx.smoke(pos, 6)
		if not crushed:
			crushed = true
			Sfx.play("collapse")
			if fx:
				fx.float_text(pos + Vector2(0, -120), "COLLAPSED", Vec.WHITE, 18.0, 1.6)
				fx.ring(pos + Vector2(0, -10), 20.0, 0.6, Vec.GREEN)
			hood_slammed.emit(self, pos)
		elif impact_sound_t <= 0.0:
			impact_sound_t = 0.15
			Sfx.play("crunch")
			hood_slammed.emit(self, pos)
		if field:
				field.shake(minf(20.0, sp / 30.0))
	elif impact_sound_t <= 0.0:
		impact_sound_t = 0.12
		Sfx.play("spark")


func _update_dynamic(dt: float) -> void:
	wreck_t += dt
	impact_sound_t -= dt
	if settled:
		if wreck_t > 14.0:
			gone = true
		return
	# A hood that came down softly onto its own legs still counts as the collapse.
	if not crushed and wreck_t > 1.2 and hood.linear_velocity.length() < 40.0:
		crushed = true
		Sfx.play("collapse")
		var pos := Vector2(hood.global_position.x, minf(C.GROUND, hood.global_position.y + r * 0.4))
		if fx:
			fx.sparks(pos, 40, {"speed": 300.0, "life": 0.8, "white": 0.5, "spread": 2.4})
			fx.debris_burst(pos, 6, {"len": 14.0})
			fx.smoke(pos, 6)
			fx.float_text(pos + Vector2(0, -120), "COLLAPSED", Vec.WHITE, 18.0, 1.6)
			fx.ring(pos, 20.0, 0.6, Vec.GREEN)
		hood_slammed.emit(self, pos)
	if crushed and fx and randf() < dt * 12.0:
		fx.sparks(hood.global_position + Vector2(randf_range(-r, r), 0), 2, {"speed": 60.0, "color": Vec.AMBER, "life": 0.6, "grav": -0.1})
		fx.smoke(hood.global_position, 1, Vec.DIMMER)
	if wreck_t > 2.5:
		var moving := false
		for b in _all_bodies():
			if b.linear_velocity.length() > 14.0 or absf(b.angular_velocity) > 0.3:
				moving = true
				break
		if not moving:
			settled = true
			for b in _all_bodies():
				b.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
				b.freeze = true


func _all_bodies() -> Array:
	var out: Array = [hood]
	for pair in leg_bodies:
		out.append(pair[0])
		out.append(pair[1])
	return out


# --- drawing ------------------------------------------------------------------------------------

func _draw() -> void:
	var dim := 1.0
	var col := Vec.GREEN
	if dynamic:
		if settled:
			dim = maxf(0.25, 1.0 - (wreck_t - 2.5) / 6.0)
		if crushed:
			col = Vec.DIM if settled else (Vec.WHITE if int(wreck_t * 30.0) % 2 == 1 else Vec.GREEN)
	elif hit_flash > 0.0:
		col = Vec.WHITE
	for i in [2, 1, 0]:
		var leg: Dictionary = legs[i]
		var up: Array = _seg(leg_bodies[i][0], L1)
		var lo: Array = _seg(leg_bodies[i][1], L2)
		var lc := col
		if not dynamic:
			if leg.flash > 0.0:
				lc = Vec.WHITE
			elif leg.hp < leg.max and int(t * 20.0) % 3 == 0:
				lc = Vec.AMBER
		lc = Vec.faded(lc, dim)
		var lw := (2.2 if i == 1 else 3.0) * s
		if dynamic and leg.broken:
			Vec.line(self, lo[0], lo[1], lc, lw)
			Vec.line(self, up[0], up[1], lc, lw)
			if not settled:
				Vec.line(self, up[0], up[0] + Vector2(randf_range(-6, 6), randf_range(0, 10)), Vec.AMBER, 1.5)
		else:
			Vec.poly(self, PackedVector2Array([up[0], up[1], lo[1]]), lc, lw)
		Vec.circle(self, up[1], 4.0 * s, lc, 1.5)
		if not dynamic:
			Vec.line(self, lo[1] + Vector2(-9 * s, 0), lo[1] + Vector2(9 * s, 0), lc, 2.0 * s)
			if leg.hp < leg.max and fx and randf() < 0.3:
				fx.sparks(up[0].lerp(up[1], randf()), 1, {"speed": 50.0, "color": Vec.AMBER, "life": 0.3})
	_draw_hood(col, dim)


func _draw_hood(col: Color, dim: float) -> void:
	var tr := hood.global_transform
	var shape := PackedVector2Array()
	for p in _hood_shape:
		shape.append(tr * p)
	shape.append(tr * Vector2(-r, 0))
	var c := Vec.faded(col, dim)
	Vec.poly(self, shape, c, 2.5 * s, true)
	Vec.line(self, tr * Vector2(-r * 1.1, r * 0.1), tr * Vector2(r * 1.1, r * 0.1), c, 1.5 * s)
	Vec.poly(self, PackedVector2Array([tr * Vector2(-r * 0.3, -r * 0.9), tr * Vector2(-r * 0.2, -r * 1.15), tr * Vector2(r * 0.2, -r * 1.15), tr * Vector2(r * 0.3, -r * 0.9)]), c, 1.5 * s)
	Vec.line(self, tr * Vector2(-r * 0.2, -r * 0.5), tr * Vector2(r * 0.5, -r * 0.5), c, 1.2 * s)
	Vec.line(self, tr * Vector2(-r * 0.15, -r * 0.3), tr * Vector2(r * 0.55, -r * 0.3), c, 1.2 * s)
	# the lens of the Heat-Ray
	var e := tr * Vector2(-r * 0.62, -r * 0.1)
	if hood_glow > 0.0 and not dynamic:
		var ga := dim * (0.5 + 0.5 * hood_glow)
		Vec.circle(self, e, r * 0.22 + hood_glow * 3.0, Vec.faded(Vec.RED, ga), 3.0 * s)
		Vec.poly(self, shape, Vec.faded(Vec.RED, ga), 1.2 * s, true)
		Vec.dot(self, e, r * 0.1, Vec.WHITE)
	else:
		Vec.circle(self, e, r * 0.18, c, 1.6 * s)
		Vec.dot(self, e, r * 0.05, c)
	# dangling tentacles
	if not dynamic:
		for k in 3:
			var bx := -r * 0.6 + k * r * 0.6
			var pts := PackedVector2Array()
			for j in 7:
				var u := j / 6.0
				pts.append(tr * Vector2(bx + sin(tent * 2.2 + k * 1.7 + u * 3.0) * 7.0 * u * s, r * 0.38 + u * 60.0 * s))
			Vec.poly(self, pts, c, 1.3 * s)
	# the beam
	if not beam.is_empty():
		var gp := Vector2(beam.gx, C.GROUND)
		Vec.line(self, e, gp, Vec.faded(Vec.RED, 0.3), 12.0 * s)
		Vec.line(self, e, gp, Vec.faded(Vec.RED, 0.85), 4.0)
		Vec.line(self, e, gp, Vec.WHITE, 1.5)
		for i in 6:
			var a := -PI / 2.0 + (randf() - 0.5) * 2.4
			var l := randf_range(10, 46)
			Vec.line(self, gp, gp + Vector2(cos(a), sin(a)) * l, Vec.RED if randf() < 0.5 else Vec.WHITE, 1.5)
		Vec.circle(self, gp, 6.0 + randf() * 8.0, Vec.WHITE, 1.5)
		Vec.circle(self, e, r * 0.3 + randf() * 5.0, Vec.RED, 2.0)
