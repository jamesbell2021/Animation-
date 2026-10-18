class_name FireworksShow
extends Node3D
## Rockets that whistle up on a fiery trail and burst into peonies, gold
## willows, crackling glitter and multicolour shells, each with a flash of
## light. start_show() runs a timed display that ends in a big finale salvo;
## launch() fires a single rocket.

enum Style { PEONY, RAINBOW, WILLOW, CRACKLE, DOUBLE }

## Quiet rockets (no whistle, softer bangs) for distant background fireworks.
var loud: bool = true
## Where the show's rockets go up from and how high they burst.
var spread: float = 14.0
var height: Vector2 = Vector2(14.0, 26.0)

var _show_left: float = 0.0
var _rate: float = 2.5
var _cooldown: float = 0.0
var _finale_done: bool = true
var _rockets: Array[Dictionary] = []
var _rocket_mesh: SphereMesh


## Runs a display for [param seconds] around this node's position.
func start_show(seconds: float, rockets_per_second: float = 2.5) -> void:
	_show_left = seconds
	_rate = rockets_per_second
	_cooldown = 0.0
	_finale_done = false


func stop_show() -> void:
	_show_left = 0.0
	_finale_done = true


func is_running() -> bool:
	return _show_left > 0.0


## One rocket from [param from] to [param to]; style -1 picks at random.
func launch(from: Vector3, to: Vector3, style: int = -1, colour: Color = Color.WHITE, size: float = 2.0) -> void:
	if not is_inside_tree():
		return
	if style < 0:
		style = randi() % Style.size()
	if colour == Color.WHITE:
		colour = CourseBuilder.accent(randi() % 4) if randf() < 0.75 else Color(0.85, 0.3, 1.0)
	if _rocket_mesh == null:
		_rocket_mesh = SphereMesh.new()
		_rocket_mesh.radius = 0.16
		_rocket_mesh.height = 0.32
		_rocket_mesh.radial_segments = 6
		_rocket_mesh.rings = 3
		_rocket_mesh.material = CourseBuilder.make_neon_material(Color(1.0, 0.75, 0.4), 4.0)
	var rocket := MeshInstance3D.new()
	rocket.name = "Rocket"
	rocket.mesh = _rocket_mesh
	rocket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rocket)
	rocket.global_position = from
	FX.attach(rocket, "rocket")
	_rockets.append({"node": rocket, "from": from, "to": to, "t": 0.0, "time": randf_range(0.9, 1.3),
		"style": style, "colour": colour, "size": size, "wobble": randf() * TAU})
	if loud:
		SoundManager.world(self, "whistle", from, randf_range(0.9, 1.15), 0.0)


func _process(delta: float) -> void:
	if _show_left > 0.0:
		_show_left -= delta
		_cooldown -= delta
		if _cooldown <= 0.0:
			_cooldown = randf_range(0.4, 1.6) / maxf(_rate, 0.1)
			_launch_random(2.0)
		if _show_left < 1.6 and not _finale_done:
			_finale_done = true
			for i in range(10):
				_launch_random(2.4)
	for i in range(_rockets.size() - 1, -1, -1):
		var r := _rockets[i]
		var node: Node3D = r["node"]
		if not is_instance_valid(node):
			_rockets.remove_at(i)
			continue
		var t := float(r["t"]) + delta / float(r["time"])
		r["t"] = t
		var from: Vector3 = r["from"]
		var to: Vector3 = r["to"]
		var eased := 1.0 - pow(1.0 - minf(t, 1.0), 2.0)
		var wobble := Vector3(sin(t * 9.0 + float(r["wobble"])), 0.0, cos(t * 7.0 + float(r["wobble"]))) * 0.4 * (1.0 - t)
		node.global_position = from.lerp(to, eased) + wobble
		if t >= 1.0:
			_explode(node.global_position, int(r["style"]), r["colour"], float(r["size"]))
			node.queue_free()
			_rockets.remove_at(i)


func _launch_random(size: float) -> void:
	var base := global_position + Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
	var top := base + Vector3(randf_range(-4.0, 4.0), randf_range(height.x, height.y), randf_range(-4.0, 4.0))
	launch(base, top, -1, Color.WHITE, size)


func _explode(pos: Vector3, style: int, colour: Color, size: float) -> void:
	var hdr := Color(colour.r * 1.4, colour.g * 1.4, colour.b * 1.4)
	match style:
		Style.PEONY:
			FX.burst(self, "peony", pos, hdr, size)
		Style.RAINBOW:
			FX.burst(self, "fireworks", pos, Color.WHITE, size)
		Style.WILLOW:
			FX.burst(self, "willow", pos, Color.WHITE, size)
			colour = Color(1.0, 0.7, 0.3)
		Style.CRACKLE:
			FX.burst(self, "peony", pos, hdr, size * 0.7)
			FX.burst(self, "crackle", pos, Color.WHITE, size)
		_:
			FX.burst(self, "peony", pos, hdr, size)
			var inner := CourseBuilder.accent(randi() % 4)
			FX.burst(self, "peony", pos, Color(inner.r * 1.4, inner.g * 1.4, inner.b * 1.4), size * 0.5)
	_flash(pos, colour, size)
	if loud:
		SoundManager.world(self, "crackle" if style == Style.CRACKLE else "firework", pos, randf_range(0.8, 1.2), 6.0)


## A short burst of coloured light that lights up everything nearby.
func _flash(pos: Vector3, colour: Color, size: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 5.0
	light.omni_range = 18.0 * size
	light.shadow_enabled = false
	add_child(light)
	light.global_position = pos
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_callback(light.queue_free)
