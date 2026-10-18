class_name Particles
extends Node2D
## Sparks, smoke, shock rings, tumbling debris and floating score text, all drawn as lines.

var parts: Array = []
var debris: Array = []
var texts: Array = []


func sparks(pos: Vector2, n: int, o := {}) -> void:
	var speed: float = o.get("speed", 260.0)
	var spread: float = o.get("spread", TAU)
	var dir: float = o.get("dir", -PI / 2.0)
	var color: Color = o.get("color", Vec.GREEN)
	var life: float = o.get("life", 0.7)
	var grav: float = o.get("grav", 1.0)
	var size: float = o.get("size", 1.0)
	var white: float = o.get("white", 0.3)
	for i in n:
		var a := dir + (randf() - 0.5) * spread
		var v := speed * (0.3 + randf() * 0.9)
		parts.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * v, "life": life * (0.5 + randf() * 0.8), "max": life,
			"color": Vec.WHITE if randf() < white else color, "grav": grav, "size": size, "kind": 0})


func smoke(pos: Vector2, n: int, color := Vec.DIM) -> void:
	for i in n:
		parts.append({"pos": pos + Vector2(randf_range(-6, 6), 0), "vel": Vector2(randf_range(-25, 25), randf_range(-70, -20)),
			"life": randf_range(0.8, 1.8), "max": 1.8, "color": color, "grav": -0.15, "size": randf_range(3, 9), "kind": 1})


func ring(pos: Vector2, size: float, life: float, color := Vec.WHITE) -> void:
	parts.append({"pos": pos, "vel": Vector2.ZERO, "life": life, "max": life, "color": color, "grav": 0.0, "size": size, "kind": 2})


func debris_burst(pos: Vector2, n: int, o := {}) -> void:
	var speed: float = o.get("speed", 300.0)
	var color: Color = o.get("color", Vec.GREEN)
	var length: float = o.get("len", 14.0)
	for i in n:
		var a := -PI / 2.0 + (randf() - 0.5) * 2.4
		var v := speed * (0.3 + randf())
		debris.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * v, "ang": randf() * TAU, "av": randf_range(-14, 14),
			"len": length * (0.4 + randf()), "life": randf_range(1.5, 3.5), "color": color})


func float_text(pos: Vector2, text: String, color := Vec.GREEN, size := 12.0, life := 1.2) -> void:
	texts.append({"pos": pos, "text": text, "color": color, "size": size, "life": life, "max": life})


func clear() -> void:
	parts.clear()
	debris.clear()
	texts.clear()


func update(dt: float) -> void:
	var keep: Array = []
	for p in parts:
		p.life -= dt
		if p.life <= 0.0:
			continue
		if p.kind == 2:
			p.size += 320.0 * dt
		else:
			p.vel.y += C.GRAV * p.grav * dt
			p.pos += p.vel * dt
			if p.kind == 0 and p.pos.y > C.GROUND:
				p.pos.y = C.GROUND
				p.vel.y *= -0.45
				p.vel.x *= 0.7
				if absf(p.vel.y) < 20.0:
					p.life = minf(p.life, 0.15)
		keep.append(p)
	parts = keep
	var keep_d: Array = []
	for d in debris:
		d.life -= dt
		if d.life <= 0.0:
			continue
		d.vel.y += C.GRAV * dt
		d.pos += d.vel * dt
		d.ang += d.av * dt
		if d.pos.y > C.GROUND:
			d.pos.y = C.GROUND
			d.vel.y *= -0.4
			d.vel.x *= 0.6
			d.av *= 0.5
			if absf(d.vel.y) > 60.0:
				sparks(Vector2(d.pos.x, C.GROUND), 3, {"speed": 90.0, "life": 0.3})
				if randf() < 0.3:
					Sfx.play("spark")
		keep_d.append(d)
	debris = keep_d
	var keep_t: Array = []
	for t in texts:
		t.life -= dt
		if t.life <= 0.0:
			continue
		t.pos.y -= 28.0 * dt
		keep_t.append(t)
	texts = keep_t
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		if p.kind == 2:
			Vec.circle(self, p.pos, p.size, Vec.faded(p.color, a), 2.0)
		elif p.kind == 1:
			Vec.circle(self, p.pos, p.size * (1.5 - a * 0.5), Vec.faded(p.color, a * 0.5), 1.0)
		else:
			var k: float = 0.035 * p.size
			var tail: Vector2 = p.pos - p.vel * k
			if tail.distance_squared_to(p.pos) < 1.0:
				tail = p.pos + Vector2(1, 0)
			draw_line(p.pos, tail, Vec.faded(p.color, minf(1.0, a * 1.5)), 1.6 * p.size, true)
	for d in debris:
		var h: Vector2 = Vector2(cos(d.ang), sin(d.ang)) * d.len / 2.0
		draw_line(d.pos - h, d.pos + h, Vec.faded(d.color, clampf(d.life, 0.0, 1.0)), 2.0, true)
	for t in texts:
		Vec.text(self, t.text, t.pos, t.size, "center", Vec.faded(t.color, clampf(t.life / t.max * 1.5, 0.0, 1.0)))
