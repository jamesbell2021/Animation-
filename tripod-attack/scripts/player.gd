class_name Player
extends Node2D
## The artilleryman: kneels behind the sandbags with a rocket launcher, ducks under the Heat-Ray.

const RELOAD_TIME := 1.05

var angle := -0.55
var power := 680.0
var reload := 0.0
var inv := 0.0
var recoil := 0.0
var fire_flash := 0.0
var burn_t := 0.0
var duck := false
var duck_held := false           # from input (keys, button, touch zone)
var drag := {}                   # {"start": Vector2, "now": Vector2} while dragging back
var show_preview := true
var t := 0.0
var fx: Particles


func shoulder() -> Vector2:
	return Vector2(C.PLAYER_X + 4.0 * C.PS, C.GROUND - (22.0 if duck else 48.0) * C.PS)


func muzzle() -> Vector2:
	return shoulder() + Vector2(cos(angle), sin(angle)) * 42.0 * C.PS


func update(dt: float) -> void:
	t += dt
	reload = maxf(0.0, reload - dt)
	inv = maxf(0.0, inv - dt)
	recoil = maxf(0.0, recoil - dt * 4.0)
	fire_flash = maxf(0.0, fire_flash - dt)
	burn_t = maxf(0.0, burn_t - dt)
	if Input.is_action_pressed("aim_up"):
		angle -= 1.3 * dt
	if Input.is_action_pressed("aim_down"):
		angle += 1.3 * dt
	if Input.is_action_pressed("power_up"):
		power += 420.0 * dt
	if Input.is_action_pressed("power_down"):
		power -= 420.0 * dt
	if not drag.is_empty():
		var d: Vector2 = drag.start - drag.now
		if d.length() > 12.0:
			angle = d.angle()
			power = 380.0 + d.length() * 3.6
	angle = clampf(angle, -1.45, 0.12)
	power = clampf(power, 380.0, 1000.0)
	duck = (duck_held or Input.is_action_pressed("duck")) and burn_t <= 0.0
	queue_redraw()


## Fires if the launcher is ready. Returns {"pos", "vel"} or an empty dictionary.
func try_fire() -> Dictionary:
	if reload > 0.0 or duck or burn_t > 0.0:
		return {}
	var m := muzzle()
	var dir := Vector2(cos(angle), sin(angle))
	reload = RELOAD_TIME
	recoil = 1.0
	fire_flash = 0.08
	if fx:
		fx.sparks(m, 10, {"speed": 220.0, "dir": angle, "spread": 0.7, "color": Vec.AMBER, "life": 0.3, "white": 0.6})
		fx.sparks(shoulder() - dir * 30.0, 14, {"speed": 260.0, "dir": angle + PI, "spread": 0.9, "color": Vec.DIM, "life": 0.35})
		fx.float_text(m + Vector2(26, -30), "FIRE", Vec.GREEN, 10.0, 0.45)
	Sfx.play("launch")
	return {"pos": m, "vel": dir * power}


## Struck by the Heat-Ray, a falling machine or a stamping foot.
func hurt() -> void:
	inv = 2.6
	burn_t = 0.9
	duck = false
	if fx:
		fx.sparks(Vector2(C.PLAYER_X, C.GROUND - 40), 60, {"speed": 300.0, "color": Vec.WHITE, "life": 1.0, "white": 1.0})
		fx.sparks(Vector2(C.PLAYER_X, C.GROUND - 40), 30, {"speed": 200.0, "color": Vec.RED, "life": 0.8})


func _draw() -> void:
	if not visible:
		return
	var S := C.PS
	var x := C.PLAYER_X
	var hip_y := C.GROUND - 8.0 * S
	var sh := shoulder()
	var head_y := sh.y - 11.0 * S
	var rec := recoil * 5.0 * S
	var shown := not (inv > 0.0 and int(t * 18.0) % 2 == 0 and burn_t <= 0.0)
	var col := Vec.GREEN
	if burn_t > 0.0:
		col = Vec.WHITE if int(t * 30.0) % 2 == 1 else Vec.RED
	if shown:
		# kneeling legs
		Vec.poly(self, PackedVector2Array([Vector2(x - 2 * S, hip_y), Vector2(x - 16 * S, hip_y + 4 * S), Vector2(x - 10 * S, C.GROUND)]), col, 2.0)
		Vec.poly(self, PackedVector2Array([Vector2(x - 2 * S, hip_y), Vector2(x + 12 * S, hip_y - 8 * S), Vector2(x + 14 * S, C.GROUND)]), col, 2.0)
		Vec.line(self, Vector2(x + 8 * S, C.GROUND), Vector2(x + 20 * S, C.GROUND), col, 2.0)
		# torso and pack
		Vec.line(self, Vector2(x - 2 * S, hip_y), Vector2(sh.x - 4 * S - rec, sh.y + 2 * S), col, 2.5)
		Vec.poly(self, PackedVector2Array([Vector2(sh.x - 16 * S - rec, sh.y + 4 * S), Vector2(sh.x - 16 * S - rec, hip_y - 4 * S), Vector2(x - 4 * S, hip_y - 2 * S)]), col, 1.6)
		Vec.poly(self, PackedVector2Array([Vector2(sh.x - 15 * S - rec, sh.y + 8 * S), Vector2(sh.x - 11 * S - rec, sh.y + 8 * S), Vector2(sh.x - 11 * S - rec, hip_y - 6 * S), Vector2(sh.x - 15 * S - rec, hip_y - 6 * S)]), col, 1.2, true)
		# head with helmet
		Vec.circle(self, Vector2(sh.x - 1 * S - rec, head_y), 6 * S, col, 2.0)
		Vec.poly(self, PackedVector2Array([Vector2(sh.x - 9 * S - rec, head_y - 1 * S), Vector2(sh.x - 7 * S - rec, head_y - 8 * S), Vector2(sh.x + 5 * S - rec, head_y - 8 * S), Vector2(sh.x + 7 * S - rec, head_y - 1 * S)]), col, 1.8)
		# the launcher tube on the shoulder
		var p := Vector2(sh.x - rec, sh.y)
		var c := Vector2(cos(angle), sin(angle))
		var nrm := Vector2(-c.y, c.x)
		var L0 := -22.0 * S
		var L1 := 42.0 * S
		var r := 4.0 * S
		Vec.poly(self, PackedVector2Array([p + c * L0 + nrm * r, p + c * L1 + nrm * r, p + c * L1 - nrm * r, p + c * L0 - nrm * r]), col, 2.0, true)
		Vec.circle(self, p + c * L1, 5.5 * S, col, 1.6)
		Vec.line(self, p + c * 10 * S, p + c * 10 * S + nrm * 12 * S, col, 1.6)
		# arms
		Vec.line(self, Vector2(sh.x - 4 * S - rec, sh.y + 2 * S), p + c * 14 * S + nrm * 6 * S, col, 2.0)
		Vec.line(self, Vector2(sh.x - 4 * S - rec, sh.y + 2 * S), p + c * -6 * S + nrm * 6 * S, col, 2.0)
		if fire_flash > 0.0:
			var m := p + c * L1
			for i in 6:
				var aa := angle + (randf() - 0.5) * 1.2
				Vec.line(self, m, m + Vector2(cos(aa), sin(aa)) * randf_range(14, 40), Vec.WHITE, 1.5)
		if reload > 0.0 and not duck:
			var w := 40.0
			var f := 1.0 - reload / RELOAD_TIME
			Vec.line(self, Vector2(x - w / 2, head_y - 26), Vector2(x - w / 2 + w * f, head_y - 26), Vec.DIM, 2.0)
	# sandbags, drawn over the man
	for row in [[C.SANDBAG_L, C.SANDBAG_R, C.GROUND - 15.0], [C.SANDBAG_L + 10.0, C.SANDBAG_R - 8.0, C.GROUND - 30.0], [C.SANDBAG_L + 22.0, C.SANDBAG_R - 20.0, C.GROUND - 45.0]]:
		var bx: float = row[0]
		while bx < row[1] - 6.0:
			var w: float = minf(30.0, row[1] - bx)
			Vec.poly(self, PackedVector2Array([Vector2(bx, row[2] + 15), Vector2(bx + 3, row[2]), Vector2(bx + w - 3, row[2]), Vector2(bx + w, row[2] + 15)]), Vec.GREEN, 1.6)
			bx += 30.0
		Vec.line(self, Vector2(row[0], row[2] + 15), Vector2(row[1], row[2] + 15), Vec.GREEN, 1.6)
	# aim preview: dotted ballistic arc
	if not duck and show_preview and (not drag.is_empty() or reload <= 0.0):
		var pos := muzzle()
		var vel := Vector2(cos(angle), sin(angle)) * power
		var step := 0.05
		var n := 22 if not drag.is_empty() else 9
		var alpha := 0.9 if not drag.is_empty() else 0.35
		for i in n:
			var th := 260.0 if i * step < 0.7 else 0.0
			vel += vel.normalized() * th * step
			vel.y += C.GRAV * step
			pos += vel * step
			if pos.y > C.GROUND:
				break
			Vec.dot(self, pos, 1.6, Vec.faded(Vec.DIM if i % 2 == 1 else Vec.GREEN, alpha))
	if not drag.is_empty():
		Vec.line(self, drag.start, drag.now, Vec.DIM, 1.0)
		Vec.circle(self, drag.start, 6.0, Vec.DIM, 1.0)
		Vec.circle(self, drag.now, 10.0, Vec.GREEN, 1.4)
