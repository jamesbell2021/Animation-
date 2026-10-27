class_name Mats
extends RefCounted
## Shared materials and colours. Solids share one fill and one line material per look; kaiju get
## their own copies so they can flash white when hit.

const SEA: Color = Color(0.21, 0.84, 1.0)
const JADE: Color = Color(0.24, 1.0, 0.69)
const GOLD: Color = Color(1.0, 0.77, 0.3)
const SAKURA: Color = Color(1.0, 0.37, 0.64)
const BLOOD: Color = Color(1.0, 0.07, 0.2)
const GORE: Color = Color(0.62, 0.0, 0.1)
const WHITE: Color = Color(1, 1, 1)
const TRACER: Color = Color(1.0, 0.9, 0.42)
const FIRE: Color = Color(1.0, 0.54, 0.16)
const BOLT: Color = Color(0.62, 0.77, 1.0)
const PAPER: Color = Color(0.94, 0.89, 0.78)
const ONI: Color = Color(0.71, 0.42, 1.0)
const SHU: Color = Color(1.0, 0.23, 0.19)
const MTN: Color = Color(0.42, 0.31, 0.85)
const KANI: Color = Color(1.0, 0.48, 0.18)
const RYU: Color = Color(0.78, 1.0, 0.24)
const CYAN: Color = Color(0.36, 0.95, 1.0)
const AMBER: Color = Color(1.0, 0.68, 0.32)
const WARM: Color = Color(1.0, 0.9, 0.75)

static var _cache: Dictionary = {}
## Line width in pixels at 720p (scaled with resolution). Set by the graphics quality setting.
static var line_width: float = 1.7
static var _line_refs: Array[WeakRef] = []


static func line(energy: float = 2.4) -> ShaderMaterial:
	var key: String = "line%.2f" % energy
	if not _cache.has(key):
		_cache[key] = make_line(energy)
	return _cache[key]


## Thick neon lines (meshes from LineBuilder).
static func make_line(energy: float = 2.4) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = preload("res://shaders/neon_line.gdshader")
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("width", line_width)
	_line_refs.append(weakref(m))
	return m


## Glowing filled triangles (eyes, lanterns, cores, spines).
static func make_glow(energy: float = 3.2) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = preload("res://shaders/neon_glow.gdshader")
	m.set_shader_parameter("energy", energy)
	return m


static func set_line_width(w: float) -> void:
	line_width = w
	var alive: Array[WeakRef] = []
	for r: WeakRef in _line_refs:
		var m: ShaderMaterial = r.get_ref()
		if m != null:
			m.set_shader_parameter("width", w)
			alive.append(r)
	_line_refs = alive


static func fill() -> ShaderMaterial:
	if not _cache.has("fill"):
		_cache["fill"] = make_fill()
	return _cache["fill"]


static func make_fill(tint_amount: float = 0.07) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = preload("res://shaders/dark_fill.gdshader")
	m.set_shader_parameter("tint_amount", tint_amount)
	return m


## Bright unshaded solids (eyes, lanterns, cores).
static func glow() -> ShaderMaterial:
	if not _cache.has("glow"):
		_cache["glow"] = make_glow(3.2)
	return _cache["glow"]


static func windows(kind: String = "windows") -> ShaderMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = preload("res://shaders/windows.gdshader")
	match kind:
		"signs":
			m.set_shader_parameter("always_on", true)
			m.set_shader_parameter("energy", 2.4)
			m.set_shader_parameter("flicker", 0.22)
		"screen":
			m.set_shader_parameter("rate", 2.4)
			m.set_shader_parameter("lit_fraction", 0.55)
			m.set_shader_parameter("energy", 1.8)
			m.set_shader_parameter("flicker", 0.0)
		"chase":
			m.set_shader_parameter("chase", true)
			m.set_shader_parameter("energy", 2.6)
		"lanterns":
			m.set_shader_parameter("always_on", true)
			m.set_shader_parameter("energy", 1.5)
			m.set_shader_parameter("flicker", 0.05)
	_cache[kind] = m
	return m


static func fx_lines() -> ShaderMaterial:
	if not _cache.has("fx_lines"):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = preload("res://shaders/fx_line.gdshader")
		m.set_shader_parameter("width", line_width)
		_line_refs.append(weakref(m))
		_cache["fx_lines"] = m
	return _cache["fx_lines"]


static func fx() -> ShaderMaterial:
	if not _cache.has("fx"):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = preload("res://shaders/fx_add.gdshader")
		_cache["fx"] = m
	return _cache["fx"]


static func font_display() -> Font:
	if not _cache.has("fd"):
		_cache["fd"] = load("res://fonts/DelaGothicOne-Regular.ttf")
	return _cache["fd"]


static func font_hud() -> Font:
	if not _cache.has("fh"):
		_cache["fh"] = load("res://fonts/DotGothic16-Regular.ttf")
	return _cache["fh"]
