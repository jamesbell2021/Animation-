class_name FxLayer
extends Node2D
## Pooled particle effects drawn by one node: coins flying out of a sale, floating "+€5" text,
## dust puffs when packing. Nothing is instantiated per effect; particles live in a fixed-size
## array (capped by Quality.particles), which keeps phones happy.

const MAX_PARTICLES := 160
const MAX_TEXTS := 12

var _p: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _font: Font


func _ready() -> void:
	z_index = 50
	z_as_relative = false
	_font = UITheme.bold_font()
	set_process(false)


func coins(pos: Vector2, amount: float) -> void:
	var n := clampi(int(2 + amount / 4.0), 2, Quality.particles)
	for i in n:
		_spawn({"pos": pos + Vector2(0, -40), "vel": Vector2(randf_range(-90, 90), randf_range(-260, -160)),
			"life": randf_range(0.7, 1.0), "kind": "coin", "r": randf_range(4.0, 6.0), "spin": randf() * TAU})
	float_text(pos + Vector2(0, -90), "+" + Lines.money(amount), Color("#ffe14d"))


func puff(pos: Vector2, count := 8, col := Color(1, 0.95, 0.85, 0.8)) -> void:
	for i in mini(count, Quality.particles):
		_spawn({"pos": pos + Vector2(randf_range(-30, 30), randf_range(-8, 4)), "vel": Vector2(randf_range(-50, 50), randf_range(-60, -20)),
			"life": randf_range(0.4, 0.7), "kind": "puff", "r": randf_range(6.0, 12.0), "col": col})


func hearts(pos: Vector2) -> void:
	for i in mini(3, Quality.particles):
		_spawn({"pos": pos + Vector2(randf_range(-12, 12), -110), "vel": Vector2(randf_range(-20, 20), -50),
			"life": 1.0, "kind": "heart", "r": 6.0})


func float_text(pos: Vector2, text: String, col := Color.WHITE, size := 26) -> void:
	if _texts.size() >= MAX_TEXTS:
		_texts.pop_front()
	_texts.append({"pos": pos, "text": text, "col": col, "life": 1.2, "max": 1.2, "size": size})
	set_process(true)


func _spawn(p: Dictionary) -> void:
	if _p.size() >= MAX_PARTICLES:
		_p.pop_front()
	p["max"] = p.life
	_p.append(p)
	set_process(true)


func _process(delta: float) -> void:
	for i in range(_p.size() - 1, -1, -1):
		var p := _p[i]
		p.life -= delta
		if p.life <= 0.0:
			_p.remove_at(i)
			continue
		if p.kind == "coin":
			p.vel.y += 620.0 * delta
		else:
			p.vel *= 0.94
		p.pos += p.vel * delta
		p.spin = float(p.get("spin", 0.0)) + delta * 12.0
	for i in range(_texts.size() - 1, -1, -1):
		_texts[i].life -= delta
		_texts[i].pos.y -= 50.0 * delta
		if _texts[i].life <= 0.0:
			_texts.remove_at(i)
	if _p.is_empty() and _texts.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for p in _p:
		var a := clampf(p.life / p.max * 2.0, 0.0, 1.0)
		match p.kind:
			"coin":
				var w: float = absf(cos(p.spin)) * p.r + 1.0
				draw_colored_polygon(_ellipse(p.pos, w + 1.5, p.r + 1.5), Color(0.45, 0.3, 0.0, a))
				draw_colored_polygon(_ellipse(p.pos, w, p.r), Color(1.0, 0.82, 0.15, a))
				draw_colored_polygon(_ellipse(p.pos + Vector2(-w * 0.3, -p.r * 0.3), w * 0.3, p.r * 0.3), Color(1, 1, 0.8, a))
			"puff":
				var c: Color = p.col
				c.a *= a
				draw_circle(p.pos, p.r * (1.5 - p.life / p.max * 0.5), c)
			"heart":
				var c2 := Color(1.0, 0.3, 0.45, a)
				draw_circle(p.pos + Vector2(-3, 0), 3.5, c2)
				draw_circle(p.pos + Vector2(3, 0), 3.5, c2)
				draw_colored_polygon(PackedVector2Array([p.pos + Vector2(-6.5, 1), p.pos + Vector2(6.5, 1), p.pos + Vector2(0, 8)]), c2)
	var cam := get_viewport().get_canvas_transform().get_scale().x
	for t in _texts:
		var a := clampf(t.life / t.max * 2.0, 0.0, 1.0)
		var size := int(t.size / maxf(cam, 0.3))
		var w := _font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos: Vector2 = t.pos - Vector2(w * 0.5, 0)
		draw_string_outline(_font, pos, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(8 / maxf(cam, 0.3)), Color(0.17, 0.1, 0.05, a))
		var c: Color = t.col
		c.a = a
		draw_string(_font, pos, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
