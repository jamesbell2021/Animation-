class_name Fx
extends Node3D
## One-shot effects: tracers, muzzle flashes, sparks, steam puffs, blasts, floating text and
## lobbed projectiles. Everything frees itself; nothing here keeps state between calls.

signal shake_requested(amount: float)


func tracer(from: Vector3, to: Vector3, colour: Color, width := 0.05) -> void:
	var len := from.distance_to(to)
	if len < 0.01:
		return
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(width, width, len)
	mi.mesh = b
	var m := Kit.unshaded(Color(colour, 0.95))
	m.emission_enabled = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(mi.queue_free)


func flash_light(at: Vector3, colour: Color, energy := 4.0, rng := 5.0, dur := 0.09) -> void:
	var l := OmniLight3D.new()
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	l.global_position = at
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


func sparks(at: Vector3, colour: Color, amount := 16, speed := 4.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 4
	s.rings = 2
	s.material = Kit.mat(colour, 0.5, 0.0, colour, 5.0)
	p.mesh = s
	add_child(p)
	p.global_position = at
	p.emitting = true
	_free_after(p, 1.0)


func puff(at: Vector3, colour := Color(0.85, 0.87, 0.9), amount := 10, size := 0.7) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = amount
	p.lifetime = 1.1
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var grad := Gradient.new()
	grad.set_color(0, Color(colour, 0.6))
	grad.set_color(1, Color(colour, 0.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.mesh = q
	add_child(p)
	p.global_position = at
	p.emitting = true
	_free_after(p, 1.6)


func blast(at: Vector3) -> void:
	shake_requested.emit(0.9)
	flash_light(at + Vector3(0, 1.2, 0), Color(1.0, 0.6, 0.3), 9.0, 12.0, 0.5)
	var ball := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	ball.mesh = s
	var m := Kit.unshaded(Color(1.0, 0.75, 0.35, 0.9))
	ball.material_override = m
	add_child(ball)
	ball.global_position = at + Vector3(0, 0.6, 0)
	ball.scale = Vector3.ONE * 0.3
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * 2.6, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color", Color(0.4, 0.2, 0.1, 0.0), 0.45)
	tw.chain().tween_callback(ball.queue_free)
	sparks(at + Vector3(0, 0.4, 0), Color(1.0, 0.65, 0.3), 40, 9.0)
	puff(at + Vector3(0, 0.6, 0), Color(0.3, 0.27, 0.24), 18, 2.2)


func float_text(at: Vector3, text: String, colour: Color, size := 56) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Kit.title_font()
	l.font_size = size
	l.pixel_size = 0.007
	l.outline_size = 14
	l.modulate = colour
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = at
	l.scale = Vector3.ONE * 0.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", at + Vector3(0, 1.3, 0), 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


## Lob a small glowing projectile along an arc; await it to land.
func lob(from: Vector3, to: Vector3, colour: Color, dur := 0.55, height := 3.0) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.13
	s.height = 0.26
	mi.mesh = s
	mi.material_override = Kit.mat(colour, 0.4, 0.0, colour, 6.0)
	add_child(mi)
	mi.global_position = from
	var tw := create_tween()
	tw.tween_method(_lob_step.bind(mi, from, to, height), 0.0, 1.0, dur)
	await tw.finished
	mi.queue_free()


func _lob_step(k: float, mi: Node3D, from: Vector3, to: Vector3, height: float) -> void:
	if is_instance_valid(mi):
		mi.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * height, 0)


func _free_after(n: Node, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(n.queue_free)
