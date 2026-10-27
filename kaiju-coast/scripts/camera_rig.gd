class_name CameraRig
extends Node3D
## One camera, three framings: a slow orbit over the bay behind the title screen, the command view
## (pan along the coast and zoom), and first person from whatever gun you're sitting in. Moves
## between them with an eased blend, and shakes for stomps and explosions.

var cam: Camera3D
var mode: String = "title"
var cmd_x: float = 0.0
var zoom: float = 1.0
var _blend: float = 1.0
var _from: Transform3D
var _from_fov: float = 60.0
var _t: float = 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.near = 0.5
	cam.far = 7000.0
	cam.fov = 60.0
	add_child(cam)
	cam.current = true


func set_mode(m: String) -> void:
	if m == mode:
		return
	mode = m
	_blend = 0.0
	_from = cam.global_transform
	_from_fov = cam.fov


func update(dt: float) -> void:
	_t += dt
	var xf: Transform3D
	var fov: float = 60.0
	match mode:
		"title":
			var a: float = _t * 0.045
			var p: Vector3 = Vector3(sin(a) * 260.0, 70.0 + sin(a * 1.7) * 30.0, 150.0 + cos(a) * 60.0)
			xf = Transform3D(Basis(), p).looking_at(Vector3(sin(a * 0.7) * 120.0, 45, -320), Vector3.UP)
			fov = 57.0
		"fps":
			var pl: Player = Game.player
			var s: Vector3 = pl.seat_pos()
			xf = Transform3D(Basis.from_euler(Vector3(pl.pitch, pl.yaw, 0)), s)
			fov = rad_to_deg(pl.fov)
		_:
			var ks: Vector2 = Vector2.ZERO
			if not Game.player.active and Game.state == Game.State.PLAY:
				ks.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
				ks.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
			cmd_x = clampf(cmd_x + ks.x * dt * 260.0 * zoom, -320.0, 320.0)
			zoom = clampf(zoom + ks.y * dt * 0.8, 0.45, 1.6)
			var pos: Vector3 = Vector3(cmd_x, 60.0 + 240.0 * zoom, 115.0 + 160.0 * zoom)
			xf = Transform3D(Basis(), pos).looking_at(Vector3(cmd_x, 0, -170.0 - 144.0 * zoom), Vector3.UP)
			var vp: Vector2 = get_viewport().get_visible_rect().size
			fov = 72.0 if vp.x < vp.y else 60.0
	if _blend < 1.0:
		_blend = minf(1.0, _blend + dt * 2.2)
		var e: float = 1.0 - pow(1.0 - _blend, 3.0)
		xf = _from.interpolate_with(xf, e)
		fov = lerpf(_from_fov, fov, e)
	if Game.shake > 0.01:
		var s2: float = Game.shake * (0.5 if mode == "fps" else 2.0)
		xf.origin += Vector3(randf_range(-s2, s2), randf_range(-s2, s2), randf_range(-s2, s2))
		if mode == "fps":
			xf.basis = xf.basis.rotated(xf.basis.x.normalized(), randf_range(-1, 1) * Game.shake * 0.006)
	Game.shake = maxf(0.0, Game.shake - dt * 3.5)
	cam.global_transform = xf
	cam.fov = fov


func blending() -> bool:
	return _blend < 1.0
