class_name HarbourProps
extends RefCounted
## Set dressing for Kirkhaven (Chapter Two, the harbour): quay furniture, fishing gear,
## boats, the kirkyard. All built in code. Each builder returns a Node3D with its origin
## at ground level. Also the mesh batcher and the shared materials the town's buildings
## use (TownHouse, Kirk), so a whole house is a handful of draw calls.

## Static scenery's collision layer (as Structure): keepers and creatures are blocked.
const SOLID_LAYER := 4
const SODIUM := Color(1.0, 0.52, 0.14)
const IRON := Color(0.085, 0.085, 0.095)
const BOAT_LEN := 7.0
const BOAT_BEAM := 2.4
## Metres per repeat of each roof covering.
## Sign lettering: the size its font is drawn at, and how much of a line is capitals.
const SIGN_PX := 64
const SIGN_CAPS := 0.72
const ROOF_TILE := {"slate": 1.15, "pantile": 1.3, "corrugated": 1.7}

# ---- one mesh per material ----

## Gathers boxes, rods and the like into one mesh per material key. A part is drawn in
## the frame `xf`; build() hangs the finished meshes on a node.
class Batch:
	extends RefCounted
	var xf := Transform3D.IDENTITY
	var _tools := {}

	func _tool(key: String) -> SurfaceTool:
		var st: SurfaceTool = _tools.get(key)
		if st == null:
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[key] = st
		return st

	func _corner(st: SurfaceTool, p: Vector3, n: Vector3, t: Vector3, uv: Vector2, col: Color) -> void:
		st.set_normal((xf.basis * n).normalized())
		var tw := (xf.basis * t).normalized()
		st.set_tangent(Plane(tw.x, tw.y, tw.z, 1.0))
		st.set_uv(uv)
		st.set_color(col)
		st.add_vertex(xf * p)

	## A four-sided face, its corners anticlockwise as seen from outside. `uvs` (four)
	## matter only to the UV-mapped materials (the roofs).
	func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color = Color.WHITE, uvs: PackedVector2Array = PackedVector2Array()) -> void:
		var n := (b - a).cross(d - a).normalized()
		smooth_quad(key, a, b, c, d, n, n, n, n, col, uvs)

	## As quad, with a normal at each corner (round things).
	func smooth_quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, col: Color = Color.WHITE, uvs: PackedVector2Array = PackedVector2Array()) -> void:
		var t := (b - a).normalized()
		if uvs.size() != 4:
			uvs = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
		elif absf(uvs[1].x - uvs[0].x) < 0.0001:
			t = (d - a).normalized() * signf(uvs[3].x - uvs[0].x)
		else:
			t *= signf(uvs[1].x - uvs[0].x)
		var st := _tool(key)
		var p: Array[Vector3] = [a, b, c, d]
		var n: Array[Vector3] = [na, nb, nc, nd]
		for i: int in [0, 2, 1, 0, 3, 2]:
			_corner(st, p[i], n[i], t, uvs[i], col)

	## A triangle, anticlockwise as seen from outside.
	func tri(key: String, a: Vector3, b: Vector3, c: Vector3, col: Color = Color.WHITE, uvs: PackedVector2Array = PackedVector2Array()) -> void:
		var n := (b - a).cross(c - a).normalized()
		var t := (b - a).normalized()
		if uvs.size() != 3:
			uvs = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE])
		var st := _tool(key)
		_corner(st, a, n, t, uvs[0], col)
		_corner(st, c, n, t, uvs[2], col)
		_corner(st, b, n, t, uvs[1], col)

	## A flat convex outline, facing `out`.
	func poly(key: String, pts: PackedVector3Array, col: Color, out: Vector3) -> void:
		for i in range(1, pts.size() - 1):
			if (pts[i] - pts[0]).cross(pts[i + 1] - pts[0]).dot(out) >= 0.0:
				tri(key, pts[0], pts[i], pts[i + 1], col)
			else:
				tri(key, pts[0], pts[i + 1], pts[i], col)

	func box(key: String, size: Vector3, pos: Vector3, col: Color = Color.WHITE, basis: Basis = Basis.IDENTITY) -> void:
		var h := size * 0.5
		for axis in 3:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			for s: float in [1.0, -1.0]:
				var n := Vector3.ZERO
				n[axis] = s * h[axis]
				var du := Vector3.ZERO
				du[u] = h[u]
				var dv := Vector3.ZERO
				dv[v] = h[v] * s
				quad(key, pos + basis * (n - du - dv), pos + basis * (n + du - dv), pos + basis * (n + du + dv), pos + basis * (n - du + dv), col)

	## A cylinder or cone up its own Y axis, centred on `pos` (as CylinderMesh): `r0` at
	## the foot, `r1` at the top. `from`..`to` for part of the way round.
	func cyl(key: String, r0: float, r1: float, h: float, pos: Vector3, col: Color = Color.WHITE, segs: int = 8, basis: Basis = Basis.IDENTITY, from: float = 0.0, to: float = TAU, caps: bool = true) -> void:
		var lean := (r0 - r1) / maxf(h, 0.0001)
		var up := Vector3(0.0, h * 0.5, 0.0)
		var girth := (r0 + r1) * 0.5
		for i in segs:
			var a0 := lerpf(from, to, float(i) / float(segs))
			var a1 := lerpf(from, to, float(i + 1) / float(segs))
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var b0 := pos + basis * (d0 * r0 - up)
			var b1 := pos + basis * (d1 * r0 - up)
			var t0 := pos + basis * (d0 * r1 + up)
			var t1 := pos + basis * (d1 * r1 + up)
			var n0 := basis * Vector3(d0.x, lean, d0.z).normalized()
			var n1 := basis * Vector3(d1.x, lean, d1.z).normalized()
			var uvs := PackedVector2Array([Vector2(a1 * girth, h), Vector2(a0 * girth, h), Vector2(a0 * girth, 0.0), Vector2(a1 * girth, 0.0)])
			smooth_quad(key, b1, b0, t0, t1, n1, n0, n0, n1, col, uvs)
			if caps:
				if r1 > 0.0001:
					tri(key, pos + basis * up, t1, t0, col, PackedVector2Array([Vector2.ZERO, Vector2(d1.x, d1.z) * r1, Vector2(d0.x, d0.z) * r1]))
				if r0 > 0.0001:
					tri(key, pos - basis * up, b0, b1, col, PackedVector2Array([Vector2.ZERO, Vector2(d0.x, d0.z) * r0, Vector2(d1.x, d1.z) * r0]))

	## A round bar from a to b.
	func rod(key: String, a: Vector3, b: Vector3, r: float, col: Color = Color.WHITE, segs: int = 6, r_end: float = -1.0) -> void:
		var y := b - a
		var length := y.length()
		if length < 0.0001:
			return
		y /= length
		var ref := Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT
		var x := y.cross(ref).normalized()
		cyl(key, r, r if r_end < 0.0 else r_end, length, (a + b) * 0.5, col, segs, Basis(x, y, x.cross(y)))

	## A ball, or with three different radii a pebble or a dome.
	func ball(key: String, radius: Vector3, pos: Vector3, col: Color = Color.WHITE, segs: int = 8, rings: int = 5) -> void:
		for j in rings:
			var p0 := -PI * 0.5 + PI * float(j) / float(rings)
			var p1 := -PI * 0.5 + PI * float(j + 1) / float(rings)
			for i in segs:
				var a0 := TAU * float(i) / float(segs)
				var a1 := TAU * float(i + 1) / float(segs)
				var u00 := Vector3(cos(a0) * cos(p0), sin(p0), sin(a0) * cos(p0))
				var u10 := Vector3(cos(a1) * cos(p0), sin(p0), sin(a1) * cos(p0))
				var u01 := Vector3(cos(a0) * cos(p1), sin(p1), sin(a0) * cos(p1))
				var u11 := Vector3(cos(a1) * cos(p1), sin(p1), sin(a1) * cos(p1))
				smooth_quad(key, pos + u10 * radius, pos + u00 * radius, pos + u01 * radius, pos + u11 * radius,
					(u10 / radius).normalized(), (u00 / radius).normalized(), (u01 / radius).normalized(), (u11 / radius).normalized(), col)

	## A ring lying flat round its own Y axis. With `bands`, it is painted in that many
	## stripes of `col` and `col2` in turn (a lifebelt).
	func torus(key: String, big_r: float, small_r: float, pos: Vector3, col: Color = Color.WHITE, basis: Basis = Basis.IDENTITY, segs: int = 12, tube: int = 6, col2: Color = Color.WHITE, bands: int = 0) -> void:
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var c := col
			if bands > 0 and (i * bands / segs) % 2 == 1:
				c = col2
			for j in tube:
				var b0 := TAU * float(j) / float(tube)
				var b1 := TAU * float(j + 1) / float(tube)
				var n00 := basis * Vector3(cos(a0) * cos(b0), sin(b0), sin(a0) * cos(b0))
				var n10 := basis * Vector3(cos(a1) * cos(b0), sin(b0), sin(a1) * cos(b0))
				var n01 := basis * Vector3(cos(a0) * cos(b1), sin(b1), sin(a0) * cos(b1))
				var n11 := basis * Vector3(cos(a1) * cos(b1), sin(b1), sin(a1) * cos(b1))
				var c0 := pos + basis * Vector3(cos(a0), 0.0, sin(a0)) * big_r
				var c1 := pos + basis * Vector3(cos(a1), 0.0, sin(a1)) * big_r
				smooth_quad(key, c1 + n10 * small_r, c0 + n00 * small_r, c0 + n01 * small_r, c1 + n11 * small_r, n10, n00, n01, n11, c)

	## Hang the meshes on `parent`: one MeshInstance3D per key, in the material `mats`
	## gives for it, else the town's shared one of that name. Returns them by key.
	func build(parent: Node3D, mats: Dictionary = {}) -> Dictionary:
		var out := {}
		for key: String in _tools:
			var st: SurfaceTool = _tools[key]
			st.index()
			var mi := MeshInstance3D.new()
			mi.name = key.capitalize().replace(" ", "")
			mi.mesh = st.commit()
			mi.material_override = mats[key] if mats.has(key) else HarbourProps.mat_for(key)
			parent.add_child(mi)
			out[key] = mi
		_tools.clear()
		return out

# ---- the town's materials (shared: one of each for every house and prop) ----

static var _shared := {}

## The shared material a batch key names.
static func mat_for(key: String) -> Material:
	match key:
		"iron":
			return iron()
		"wood":
			return timber()
		"stone":
			return rubble()
		"dressed":
			return dressed()
		"net":
			return net_mat()
		"heap":
			return heap_mat()
		"glass_off":
			return dark_glass()
		"void":
			return void_mat()
	if key.begins_with("roof_"):
		return roof_mat(key.trim_prefix("roof_"))
	return paint()

## Flat paint, the colour from the vertices.
static func paint() -> StandardMaterial3D:
	if not _shared.has("paint"):
		_shared["paint"] = Look.vertex_mat(0.8)
	return _shared["paint"]

## Cast iron and painted steel, the colour from the vertices.
static func iron() -> StandardMaterial3D:
	if not _shared.has("iron"):
		var m := Look.vertex_mat(0.5)
		m.metallic = 0.45
		_shared["iron"] = m
	return _shared["iron"]

static func _tinted(key: String, kind: String, lift: float, tile: float, roughness: float) -> StandardMaterial3D:
	if not _shared.has(key):
		var m := Look.textured(kind, Color(lift, lift, lift), tile, roughness)
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		_shared[key] = m
	return _shared[key]

## Boards, tinted by the vertices (white: bare weathered timber).
static func timber() -> StandardMaterial3D:
	return _tinted("wood", "planks", 2.4, 0.9, 0.9)

## Rubble stonework, tinted by the vertices (white: grey whinstone).
static func rubble() -> StandardMaterial3D:
	return _tinted("stone", "rubble", 2.0, 0.9, 0.92)

## Dressed and weathered stone (sills, steps, headstones), tinted by the vertices.
static func dressed() -> StandardMaterial3D:
	return _tinted("dressed", "concrete", 1.7, 1.4, 0.9)

## Harled wall in a painted colour: one material for each colour in the town.
static func harl_mat(color: Color) -> StandardMaterial3D:
	var key := "harl_" + color.to_html(false)
	if not _shared.has(key):
		# The harl texture is already near white: tint it to the colour asked for.
		_shared[key] = Look.textured("harl", Color(color.r / 0.87, color.g / 0.86, color.b / 0.82), 1.6, 0.95, 0.8)
	return _shared[key]

## A roof covering, laid by the mesh's own UVs (courses along the eaves): "slate",
## "pantile" or "corrugated".
static func roof_mat(kind: String) -> StandardMaterial3D:
	var key := "roof_" + kind
	if _shared.has(key):
		return _shared[key]
	var m: StandardMaterial3D
	match kind:
		"pantile":
			m = StandardMaterial3D.new()
			var tex := _pantile_textures()
			m.albedo_texture = tex[0]
			m.normal_enabled = true
			m.normal_texture = tex[1]
			m.roughness = 0.85
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		"corrugated":
			m = Look.textured("corrugated", Color(1.5, 1.45, 1.4), 1.0, 0.6, 1.0)
			m.metallic = 0.3
		_:
			m = Look.textured("slate", Color(1.0, 1.0, 1.04), 1.0, 0.5, 1.4)
	m.uv1_triplanar = false
	m.uv1_scale = Vector3.ONE
	# Each roof's own weathering comes from its vertices.
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	_shared[key] = m
	return m

static func roof_tile(kind: String) -> float:
	return ROOF_TILE.get(kind, 1.5)

## Unlit window glass.
static func dark_glass() -> StandardMaterial3D:
	if not _shared.has("glass_off"):
		var g := Look.flat_mat(Color(0.05, 0.06, 0.08), 0.45)
		g.metallic_specular = 0.25
		_shared["glass_off"] = g
	return _shared["glass_off"]

## The dark of an open doorway.
static func void_mat() -> StandardMaterial3D:
	if not _shared.has("void"):
		_shared["void"] = Look.flat_mat(Color(0.012, 0.012, 0.015), 1.0)
	return _shared["void"]

## Knotted netting (creels, drying nets): see-through between the strands, both sides
## showing, the colour from the vertices.
static func net_mat() -> StandardMaterial3D:
	if _shared.has("net"):
		return _shared["net"]
	var n := 32
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var strand := (x + y) % 16 < 3 or posmod(x - y, 16) < 3
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if strand else 0.0))
	img.generate_mipmaps()
	var m := Look.vertex_mat(0.95)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(9.0, 9.0, 9.0)
	_shared["net"] = m
	return m

## Heaped net and rope: a coarse weave, the colour from the vertices.
static func heap_mat() -> StandardMaterial3D:
	return _tinted("heap", "hessian", 2.3, 0.35, 1.0)

# Red clay pantiles, painted here (there is no texture of them in art/textures): rolls
# running down the slope, a shadow where each course laps the next.
static func _pantile_textures() -> Array:
	var n := 128
	var rolls := 4
	var courses := 3
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var normal := Image.create(n, n, true, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u := float(x) / float(n) * float(rolls)
			var v := float(y) / float(n) * float(courses)
			var fu := fposmod(u, 1.0)
			var fv := fposmod(v, 1.0)
			var tile := int(u) * 7 + int(v) * 13
			var vary := 0.78 + 0.4 * fposmod(sin(float(tile) * 12.9898) * 43758.5453, 1.0)
			var shade := 0.7 + 0.3 * sin(fu * TAU)
			# Each course laps the one below: a shadow under its edge, a lit lip above it.
			var lap := 0.42 if fv > 0.86 else (1.12 if fv < 0.1 else 1.0 - 0.12 * fv)
			var clay := Color(0.60, 0.25, 0.14).lerp(Color(0.46, 0.21, 0.15), fposmod(float(tile) * 0.37, 1.0))
			albedo.set_pixel(x, y, Color(clay.r * vary * shade * lap, clay.g * vary * shade * lap, clay.b * vary * shade * lap))
			var nx := -cos(fu * TAU) * 0.7
			var ny := 0.6 if fv > 0.86 else 0.0
			var nn := Vector3(nx, ny, 1.0).normalized()
			normal.set_pixel(x, y, Color(nn.x * 0.5 + 0.5, nn.y * 0.5 + 0.5, nn.z * 0.5 + 0.5))
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(normal)]

## A pitched roof drawn into a batch, its ridge along the batch's x axis: two slopes
## from the ridge (top surface at `ridge_y`) out `half_span` on plan to the eaves, and
## `half_len` each way along the ridge. Courses run along the eaves. `tint` weathers it.
static func pitched_roof(b: Batch, key: String, half_len: float, half_span: float, ridge_y: float, pitch: float, tile: float, thick: float = 0.1, tint: Color = Color.WHITE) -> void:
	var drop := half_span * tan(pitch)
	var u := half_len / tile
	var v := half_span / cos(pitch) / tile
	var under := Vector3(0.0, thick / cos(pitch), 0.0)
	var lip := under.y / tile
	for side: float in [1.0, -1.0]:
		var e_l := Vector3(-half_len * side, ridge_y - drop, half_span * side)
		var e_r := Vector3(half_len * side, ridge_y - drop, half_span * side)
		var r_r := Vector3(half_len * side, ridge_y, 0.0)
		var r_l := Vector3(-half_len * side, ridge_y, 0.0)
		b.quad(key, e_l, e_r, r_r, r_l, tint, PackedVector2Array([Vector2(-u, v), Vector2(u, v), Vector2(u, 0.0), Vector2(-u, 0.0)]))
		b.quad(key, e_r - under, e_l - under, r_l - under, r_r - under, tint, PackedVector2Array([Vector2(u, v), Vector2(-u, v), Vector2(-u, 0.0), Vector2(u, 0.0)]))
		b.quad(key, e_l - under, e_r - under, e_r, e_l, tint, PackedVector2Array([Vector2(-u, v + lip), Vector2(u, v + lip), Vector2(u, v), Vector2(-u, v)]))
		b.quad(key, e_r - under, r_r - under, r_r, e_r, tint, PackedVector2Array([Vector2(0.0, v), Vector2(0.0, 0.0), Vector2(lip, 0.0), Vector2(lip, v)]))
		b.quad(key, e_l, r_l, r_l - under, e_l - under, tint, PackedVector2Array([Vector2(lip, v), Vector2(lip, 0.0), Vector2(0.0, 0.0), Vector2(0.0, v)]))

## Lettering painted on a board: fitted into `width` by `height` metres, facing +Z, lit
## like the wall it is on (it does not glow in the dark).
static func lettering(text: String, width: float, height: float, color: Color, serif: bool = true) -> Label3D:
	var label := Label3D.new()
	var font := _sign_font(serif)
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_PX)
	label.font = font
	label.font_size = SIGN_PX
	label.pixel_size = minf(width / maxf(extent.x, 1.0), height / maxf(extent.y * SIGN_CAPS, 1.0))
	label.text = text
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return label

## How many times wider than its letters are tall a line of lettering runs: the width a
## board needs for letters of a given height.
static func lettering_aspect(text: String, serif: bool = true) -> float:
	var extent := _sign_font(serif).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_PX)
	return extent.x / maxf(extent.y * SIGN_CAPS, 1.0)

static func _sign_font(serif: bool) -> Font:
	var font := Fonts.title() if serif else Fonts.logbook()
	return font if font != null else ThemeDB.fallback_font

static func _rng(seed_value: int, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value * 7919 + salt * 104729 + 17)
	return rng

static func _root(title: String) -> Node3D:
	var root := Node3D.new()
	root.name = title
	return root

# ---- the quay ----

## A cast-iron mooring bollard, about 0.6 m.
static func bollard() -> Node3D:
	var root := _root("Bollard")
	var b := Batch.new()
	var rusty := IRON.lerp(Look.RUST, 0.3)
	b.cyl("iron", 0.25, 0.22, 0.06, Vector3(0.0, 0.03, 0.0), rusty, 10)
	b.cyl("iron", 0.15, 0.12, 0.4, Vector3(0.0, 0.26, 0.0), IRON, 10)
	b.cyl("iron", 0.12, 0.21, 0.08, Vector3(0.0, 0.5, 0.0), IRON, 10)
	b.ball("iron", Vector3(0.21, 0.08, 0.21), Vector3(0.0, 0.54, 0.0), IRON, 10, 4)
	# The horns a warp is turned round.
	b.rod("iron", Vector3(-0.27, 0.37, 0.0), Vector3(0.27, 0.37, 0.0), 0.04, IRON, 6)
	b.build(root)
	return root

# One creel drawn into a batch: a slatted base, three hoops, netting over them.
static func _creel_into(b: Batch, at: Transform3D, tint: Color) -> void:
	var keep := b.xf
	b.xf = keep * at
	var length := 0.66
	var width := 0.46
	var r := width * 0.5
	# Along x: a cylinder's own Y laid over, so its upper half is the arch.
	var along := Basis(Vector3.BACK, -PI * 0.5)
	var slat := Color(0.36, 0.3, 0.22)
	for i in 4:
		b.box("wood", Vector3(length, 0.03, 0.09), Vector3(0.0, 0.015, -width * 0.5 + 0.05 + float(i) * 0.12), slat)
	b.cyl("net", r, r, length, Vector3(0.0, 0.03, 0.0), tint, 7, along, PI * 0.5, PI * 1.5, true)
	for hx: float in [-length * 0.5 + 0.02, 0.0, length * 0.5 - 0.02]:
		b.cyl("paint", r + 0.012, r + 0.012, 0.035, Vector3(hx, 0.03, 0.0), Color(0.1, 0.1, 0.1), 7, along, PI * 0.5, PI * 1.5, false)
	b.xf = keep

## A lobster creel: a half-round pot of net on a slatted base.
static func creel() -> Node3D:
	var root := _root("Creel")
	var b := Batch.new()
	_creel_into(b, Transform3D.IDENTITY, Color(0.16, 0.3, 0.3))
	b.build(root)
	return root

## `n` creels stacked untidily, a float or two among them.
static func creel_stack(n: int, seed_value: int) -> Node3D:
	var root := _root("CreelStack")
	var rng := _rng(seed_value, 1)
	var b := Batch.new()
	var tints := [Color(0.16, 0.3, 0.3), Color(0.12, 0.22, 0.34), Color(0.5, 0.26, 0.1), Color(0.2, 0.3, 0.18)]
	var wide := clampi(ceili(sqrt(float(n)) * 1.2), 1, 5)
	var placed := 0
	var rank := 0
	while placed < n:
		# Each rank is a little pyramid; the next rank goes down behind it.
		var level := 0
		var across := wide
		while placed < n and across > 0:
			for i in across:
				if placed >= n:
					break
				var at := Vector3(float(rank) * 0.74 + rng.randf_range(-0.05, 0.05), float(level) * 0.255,
					(float(i) - float(across - 1) * 0.5) * 0.5 + rng.randf_range(-0.04, 0.04))
				var turn := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2))
				if level > 0:
					turn = turn * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
				_creel_into(b, Transform3D(turn, at), tints[rng.randi() % tints.size()])
				placed += 1
			level += 1
			across -= 1
		rank += 1
	# Floats and a coil of rope beside the stack.
	for i in mini(3, 1 + n / 4):
		var at := Vector3(rng.randf_range(-0.6, -0.4), 0.12, rng.randf_range(-0.6, 0.6))
		b.ball("paint", Vector3(0.13, 0.12, 0.13), at, [Color(0.85, 0.38, 0.12), Color(0.8, 0.75, 0.6), Color(0.75, 0.2, 0.15)][i % 3], 7, 4)
	b.torus("paint", 0.2, 0.045, Vector3(-0.55, 0.045, float(wide) * 0.25 + 0.3), Color(0.25, 0.42, 0.55), Basis.IDENTITY, 10, 5)
	b.build(root)
	return root

## `n` plastic fish boxes in stacks: faded orange, blue, yellow.
static func fish_boxes(n: int, seed_value: int) -> Node3D:
	var root := _root("FishBoxes")
	var rng := _rng(seed_value, 2)
	var b := Batch.new()
	var faded := [Color(0.80, 0.42, 0.18), Color(0.22, 0.38, 0.56), Color(0.82, 0.68, 0.24), Color(0.74, 0.74, 0.70), Color(0.2, 0.45, 0.36)]
	var size := Vector3(0.78, 0.2, 0.46)
	var left := n
	var column := 0
	while left > 0:
		var tall := mini(left, rng.randi_range(2, 5))
		var at := Vector3(float(column % 3) * 0.86 + rng.randf_range(-0.03, 0.03), 0.0, float(column / 3) * 0.6 + rng.randf_range(-0.04, 0.04))
		var col: Color = faded[rng.randi() % faded.size()]
		for k in tall:
			# A stack is mostly one colour, with the odd stray.
			var c: Color = col if rng.randf() < 0.75 else faded[rng.randi() % faded.size()]
			var turn := Basis(Vector3.UP, rng.randf_range(-0.07, 0.07) + (0.5 if k == tall - 1 and rng.randf() < 0.2 else 0.0))
			var mid := at + Vector3(0.0, (float(k) + 0.5) * size.y, 0.0)
			b.box("paint", size, mid, c, turn)
			b.box("paint", Vector3(size.x + 0.04, 0.03, size.z + 0.04), mid + Vector3(0.0, size.y * 0.5 - 0.02, 0.0), c.darkened(0.12), turn)
			if k == tall - 1:
				# The top box is open: empty, or iced.
				var inside := Color(0.82, 0.86, 0.88) if rng.randf() < 0.3 else c.darkened(0.6)
				b.box("paint", Vector3(size.x - 0.08, 0.02, size.z - 0.08), mid + Vector3(0.0, size.y * 0.5 - 0.004, 0.0), inside, turn)
		left -= tall
		column += 1
	b.build(root)
	return root

## A heap of green and orange net with a few floats.
static func net_heap(seed_value: int) -> Node3D:
	var root := _root("NetHeap")
	var rng := _rng(seed_value, 3)
	var b := Batch.new()
	var green := Color(0.10, 0.30, 0.24)
	var orange := Color(0.72, 0.33, 0.10)
	for i in 6:
		var a := TAU * float(i) / 6.0 + rng.randf_range(-0.4, 0.4)
		var out := rng.randf_range(0.0, 0.55) if i > 0 else 0.0
		var r := Vector3(rng.randf_range(0.45, 0.75), rng.randf_range(0.22, 0.42), rng.randf_range(0.4, 0.7))
		if i == 0:
			r = Vector3(0.8, 0.5, 0.7)
		var col := green.lerp(Color(0.14, 0.24, 0.3), rng.randf()) if i % 3 != 2 else orange
		b.ball("heap", r, Vector3(cos(a) * out, r.y * 0.25, sin(a) * out), col, 8, 5)
	# A fold of net thrown over the top, its floats still strung on it.
	b.cyl("net", 0.85, 0.3, 0.5, Vector3(0.0, 0.34, 0.0), orange.lerp(green, 0.35), 9, Basis(Vector3.UP, rng.randf() * TAU), 0.0, TAU, false)
	for i in 6:
		var a := rng.randf() * TAU
		var out := rng.randf_range(0.5, 1.0)
		b.ball("paint", Vector3(0.1, 0.085, 0.1), Vector3(cos(a) * out, 0.1 + (1.0 - out) * 0.5, sin(a) * out),
			[Color(0.88, 0.4, 0.12), Color(0.82, 0.78, 0.62), Color(0.85, 0.7, 0.2)][i % 3], 7, 4)
	b.build(root)
	return root

## A small wooden inshore boat, about 7 m by 2.4 m: origin at the keel amidships, her
## length along z, the BOW toward -Z. The wheelhouse is forward, the name on both bows.
static func fishing_boat(hull: Color, boat_name: String, seed_value: int) -> Node3D:
	var root := _root("FishingBoat")
	var rng := _rng(seed_value, 4)
	var b := Batch.new()
	var under: Color = [Color(0.36, 0.11, 0.08), Color(0.07, 0.07, 0.08), Color(0.12, 0.2, 0.3)][rng.randi() % 3]
	var strake: Color = [Color(0.84, 0.82, 0.74), Color(0.82, 0.66, 0.2), Color(0.7, 0.16, 0.12), Color(0.84, 0.82, 0.74)][rng.randi() % 4]
	var inside := Color(0.55, 0.57, 0.55).lerp(hull, 0.25)
	var deck_col := Color(0.5, 0.45, 0.37)
	var stations := 12
	var deck_y := 0.74
	# Each station's section, keel to gunwale, for her +x side.
	var shape := [Vector2(0.0, 0.0), Vector2(0.5, 0.13), Vector2(0.86, 0.42), Vector2(0.98, 0.86), Vector2(1.0, 1.0)]
	var rows: Array[PackedVector3Array] = []
	var deck_edge := PackedVector3Array()
	for i in stations + 1:
		var t := float(i) / float(stations)
		var fore := maxf(0.0, 1.0 - t * 3.0)
		var aft := maxf(0.0, (t - 0.75) / 0.25)
		var half := BOAT_BEAM * 0.5 * pow(sin(PI * 0.5 * minf(1.0, t / 0.45)), 0.7) * (1.0 - 0.3 * aft * aft)
		var sheer := 1.08 + 0.6 * pow(1.0 - t, 2.6) + 0.1 * t * t
		var keel := 0.5 * fore * fore + 0.1 * aft
		var row := PackedVector3Array()
		for s: Vector2 in shape:
			# Finer forward: the sections go from a round bilge to a V.
			var x := lerpf(s.x, s.y, fore * 0.75) * half
			var z := lerpf(-BOAT_LEN * 0.5, BOAT_LEN * 0.5, t) - 0.5 * s.y * pow(fore, 1.5) + 0.15 * s.y * aft
			row.append(Vector3(x, lerpf(keel, sheer, s.y), z))
		rows.append(row)
		# Where the deck meets her side at this station.
		var edge := Vector3(0.0, deck_y, row[0].z)
		for j in 4:
			if row[j].y <= deck_y and row[j + 1].y > deck_y:
				edge = row[j].lerp(row[j + 1], (deck_y - row[j].y) / (row[j + 1].y - row[j].y))
		edge.x = maxf(0.0, edge.x - 0.05)
		deck_edge.append(edge)
	var mirror := Vector3(-1.0, 1.0, 1.0)
	var cap := Vector3(0.0, 0.03, 0.0)
	for i in stations:
		for j in 4:
			var col := under if j < 2 else (hull if j == 2 else strake)
			var a := rows[i][j]
			var c := rows[i + 1][j]
			var d := rows[i + 1][j + 1]
			var e := rows[i][j + 1]
			b.quad("paint", c, a, e, d, col)
			b.quad("paint", a * mirror, c * mirror, d * mirror, e * mirror, col)
		# Deck, the bulwark's inner face, the capping rail.
		var d0 := deck_edge[i]
		var d1 := deck_edge[i + 1]
		b.quad("wood", d0 * mirror, d1 * mirror, d1, d0, deck_col)
		var g0 := rows[i][4] - Vector3(minf(0.07, rows[i][4].x), 0.0, 0.0)
		var g1 := rows[i + 1][4] - Vector3(minf(0.07, rows[i + 1][4].x), 0.0, 0.0)
		b.quad("paint", d0, d1, g1, g0, inside)
		b.quad("paint", d1 * mirror, d0 * mirror, g0 * mirror, g1 * mirror, inside)
		var o0 := rows[i][4] + Vector3(0.03, 0.0, 0.0)
		var o1 := rows[i + 1][4] + Vector3(0.03, 0.0, 0.0)
		b.quad("paint", g0 + cap, g1 + cap, o1 + cap, o0 + cap, strake.darkened(0.1))
		b.quad("paint", o0 * mirror + cap, o1 * mirror + cap, g1 * mirror + cap, g0 * mirror + cap, strake.darkened(0.1))
		b.quad("paint", o1, o0, o0 + cap, o1 + cap, strake.darkened(0.1))
		b.quad("paint", o0 * mirror, o1 * mirror, o1 * mirror + cap, o0 * mirror + cap, strake.darkened(0.1))
	# The transom.
	var stern := PackedVector3Array()
	for j in range(4, -1, -1):
		stern.append(rows[stations][j])
	for j in range(1, 5):
		stern.append(rows[stations][j] * mirror)
	b.poly("paint", stern, hull, Vector3.BACK)
	# Keel, stem and rudder.
	b.box("wood", Vector3(0.1, 0.14, BOAT_LEN * 0.74), Vector3(0.0, -0.03, 0.35), Color(0.3, 0.26, 0.22))
	b.rod("wood", rows[1][0] + Vector3(0.0, -0.05, 0.0), rows[0][2], 0.055, Color(0.3, 0.26, 0.22), 5)
	b.rod("wood", rows[0][2], rows[0][4] + Vector3(0.0, 0.16, -0.03), 0.055, Color(0.3, 0.26, 0.22), 5)
	b.box("wood", Vector3(0.05, 0.85, 0.36), Vector3(0.0, 0.45, BOAT_LEN * 0.5 + 0.3), Color(0.3, 0.26, 0.22))
	# The wheelhouse, forward: white boards, windows all round, a door aft.
	var house_z := -BOAT_LEN * 0.17
	var house := Vector3(1.25, 1.7, 1.45)
	var white := Color(0.84, 0.83, 0.77)
	b.box("paint", house, Vector3(0.0, deck_y + house.y * 0.5, house_z), white)
	b.box("paint", Vector3(house.x + 0.2, 0.07, house.z + 0.3), Vector3(0.0, deck_y + house.y + 0.035, house_z - 0.03), hull.darkened(0.2))
	var pane_y := deck_y + house.y - 0.5
	for sx: float in [-0.3, 0.3]:
		b.box("glass_off", Vector3(0.48, 0.42, 0.03), Vector3(sx, pane_y, house_z - house.z * 0.5 - 0.005))
	for sx: float in [-1.0, 1.0]:
		for k in 2:
			b.box("glass_off", Vector3(0.03, 0.42, 0.5), Vector3(sx * (house.x * 0.5 + 0.005), pane_y, house_z - 0.33 + 0.64 * float(k)))
	b.box("wood", Vector3(0.55, 1.35, 0.03), Vector3(-0.2, deck_y + 0.72, house_z + house.z * 0.5 + 0.01), Color(0.42, 0.3, 0.2))
	# Foremast with a derrick, a light at the truck, a forestay to the stemhead.
	var spar := Color(0.56, 0.44, 0.3)
	var mast_z := -BOAT_LEN * 0.36
	var truck := Vector3(0.0, 4.1, mast_z)
	b.rod("wood", Vector3(0.0, deck_y, mast_z), truck, 0.06, spar, 6, 0.04)
	b.rod("wood", Vector3(-0.35, 3.3, mast_z), Vector3(0.35, 3.3, mast_z), 0.025, spar, 4)
	b.rod("iron", Vector3(0.4, deck_y + house.y, house_z + 0.5), Vector3(0.4, deck_y + house.y + 1.3, house_z + 0.55), 0.012, IRON, 3)
	b.rod("iron", truck, rows[0][4] + Vector3(0.0, 0.16, -0.03), 0.012, IRON, 3)
	b.ball("paint", Vector3(0.07, 0.07, 0.07), truck + Vector3(0.0, 0.06, 0.0), Color(0.85, 0.85, 0.8), 6, 4)
	# A mizzen aft on most, its tanned sail furled along the boom.
	if rng.randf() < 0.65:
		var miz_z := BOAT_LEN * 0.4
		b.rod("wood", Vector3(0.0, deck_y, miz_z), Vector3(0.0, 3.0, miz_z + 0.1), 0.045, spar, 5, 0.03)
		b.rod("wood", Vector3(0.0, 1.75, miz_z), Vector3(0.0, 1.95, miz_z + 1.3), 0.03, spar, 5)
		b.rod("paint", Vector3(0.0, 1.83, miz_z + 0.08), Vector3(0.0, 2.02, miz_z + 1.2), 0.075, Color(0.42, 0.19, 0.12), 6)
	# The working deck aft: a pot hauler, fish boxes, a creel or two, a coil of rope.
	b.cyl("iron", 0.1, 0.1, 0.5, Vector3(0.62, deck_y + 0.25, 0.4), IRON.lerp(Look.RUST, 0.4), 6)
	b.cyl("iron", 0.16, 0.16, 0.08, Vector3(0.62, deck_y + 0.54, 0.4), Color(0.6, 0.5, 0.1), 8, Basis(Vector3.RIGHT, 0.5))
	var box_cols := [Color(0.80, 0.42, 0.18), Color(0.22, 0.38, 0.56), Color(0.82, 0.68, 0.24)]
	for k in rng.randi_range(1, 3):
		b.box("paint", Vector3(0.7, 0.2, 0.42), Vector3(-0.35, deck_y + 0.1 + 0.2 * float(k), 1.2 + rng.randf_range(-0.04, 0.04)), box_cols[rng.randi() % 3], Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)))
	for k in rng.randi_range(1, 2):
		_creel_into(b, Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.2, 0.2)), Vector3(0.3, deck_y + 0.26 * float(k), 2.05)), Color(0.16, 0.3, 0.3))
	b.torus("paint", 0.2, 0.05, Vector3(-0.3, deck_y + 0.05, 0.25), Color(0.62, 0.52, 0.34), Basis.IDENTITY, 10, 5)
	# Old tyres over the side for fenders.
	for sx: float in [-1.0, 1.0]:
		for i: int in [6, 9]:
			var at := rows[i][3] * Vector3(sx, 1.0, 1.0) + Vector3(sx * 0.09, -0.12, 0.0)
			b.torus("paint", 0.2, 0.08, at, Color(0.04, 0.04, 0.04), Basis(Vector3.BACK, PI * 0.5), 10, 5)
	b.build(root)
	# Her name on each bow, lying along the planking.
	if boat_name != "":
		for sx: float in [-1.0, 1.0]:
			var p0 := rows[2][2].lerp(rows[2][3], 0.55) * Vector3(sx, 1.0, 1.0)
			var p1 := rows[4][2].lerp(rows[4][3], 0.55) * Vector3(sx, 1.0, 1.0)
			var top := rows[3][3] * Vector3(sx, 1.0, 1.0)
			var low := rows[3][2] * Vector3(sx, 1.0, 1.0)
			var x_axis := (p0 - p1).normalized() * sx
			var z_axis := x_axis.cross(top - low).normalized()
			var label := lettering(boat_name, 1.25, 0.3, Color(0.92, 0.9, 0.82) if hull.get_luminance() < 0.5 else Color(0.08, 0.08, 0.1), false)
			label.transform = Transform3D(Basis(x_axis, z_axis.cross(x_axis), z_axis), (p0 + p1) * 0.5 + z_axis * 0.02)
			root.add_child(label)
	return root

## A 1980s swan-neck steel street lamp, its arm reaching toward +Z. The lantern's bowl is
## the MeshInstance3D "Lens" (its own material: set its emission), and the Marker3D
## "Bulb" is where its light belongs. `height` is the bowl's height.
static func lamp_post(height: float = 4.6) -> Node3D:
	var root := _root("LampPost")
	var b := Batch.new()
	var steel := Color(0.36, 0.38, 0.37)
	var reach := 0.95
	# A base compartment with the fuse-box door, then the tapering shaft.
	b.cyl("iron", 0.15, 0.13, 0.05, Vector3(0.0, 0.025, 0.0), steel.darkened(0.3), 10)
	b.cyl("iron", 0.1, 0.1, 1.1, Vector3(0.0, 0.6, 0.0), steel, 10)
	b.box("iron", Vector3(0.11, 0.42, 0.02), Vector3(0.0, 0.62, 0.098), steel.lightened(0.18))
	b.box("iron", Vector3(0.02, 0.03, 0.012), Vector3(0.03, 0.62, 0.112), IRON)
	b.cyl("iron", 0.1, 0.07, 0.08, Vector3(0.0, 1.19, 0.0), steel, 10)
	var neck := height - 0.4
	b.rod("iron", Vector3(0.0, 1.23, 0.0), Vector3(0.0, neck, 0.0), 0.07, steel, 8, 0.048)
	# The swan neck: a quarter turn over to the arm.
	var bend := 0.45
	var prev := Vector3(0.0, neck, 0.0)
	for i in 4:
		var a := deg_to_rad(80.0) * float(i + 1) / 4.0
		var p := Vector3(0.0, neck + sin(a) * bend, (1.0 - cos(a)) * bend)
		b.rod("iron", prev, p, 0.047, steel, 6, 0.045)
		prev = p
	var tip := Vector3(0.0, prev.y + 0.04, reach - 0.25)
	b.rod("iron", prev, tip, 0.045, steel, 6, 0.04)
	# The lantern: a thin canopy with the bowl slung under it.
	var head := Vector3(0.0, tip.y, reach + 0.1)
	b.box("iron", Vector3(0.25, 0.05, 0.74), head + Vector3(0.0, 0.03, 0.0), steel.lightened(0.1))
	b.box("iron", Vector3(0.16, 0.1, 0.16), head + Vector3(0.0, 0.0, -0.3), steel)
	b.build(root)
	var lens := MeshInstance3D.new()
	lens.name = "Lens"
	var bowl := CapsuleMesh.new()
	bowl.radius = 0.11
	bowl.height = 0.62
	bowl.radial_segments = 10
	bowl.rings = 3
	lens.mesh = bowl
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.58, 0.5)
	glass.roughness = 0.25
	glass.emission_enabled = true
	glass.emission = SODIUM
	glass.emission_energy_multiplier = 0.0
	lens.material_override = glass
	lens.position = head + Vector3(0.0, -0.06, 0.04)
	lens.rotation.x = PI * 0.5
	lens.scale = Vector3(1.0, 1.0, 0.75)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lens)
	var bulb := Marker3D.new()
	bulb.name = "Bulb"
	bulb.position = lens.position + Vector3(0.0, -0.08, 0.0)
	root.add_child(bulb)
	return root

## A red telephone kiosk, glazed on three sides, its door toward +Z. The OmniLight3D
## "Light" inside starts at energy 0: turn it up and the glass shows the lit inside.
static func phone_box() -> Node3D:
	var root := _root("PhoneBox")
	var b := Batch.new()
	var red := Color(0.62, 0.07, 0.06)
	var side := 0.9
	var h := side * 0.5
	b.box("paint", Vector3(side + 0.04, 0.12, side + 0.04), Vector3(0.0, 0.06, 0.0), Color(0.1, 0.1, 0.1))
	b.box("paint", Vector3(side - 0.1, 0.02, side - 0.1), Vector3(0.0, 0.13, 0.0), Color(0.4, 0.4, 0.38))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box("paint", Vector3(0.09, 1.92, 0.09), Vector3(sx * (h - 0.045), 1.08, sz * (h - 0.045)), red)
	# The solid back, the telephone and a notice on it.
	b.box("paint", Vector3(side - 0.16, 1.92, 0.04), Vector3(0.0, 1.08, -h + 0.04), red.darkened(0.15))
	b.box("paint", Vector3(0.46, 0.7, 0.02), Vector3(0.0, 1.3, -h + 0.07), Color(0.75, 0.74, 0.68))
	b.box("paint", Vector3(0.22, 0.3, 0.12), Vector3(0.05, 1.25, -h + 0.13), Color(0.06, 0.06, 0.07))
	b.box("paint", Vector3(0.5, 0.03, 0.2), Vector3(0.0, 0.95, -h + 0.16), Color(0.2, 0.2, 0.2))
	# Three glazed sides: wide panes with a narrow one each side, eight rows of them.
	for face in 3:
		var turn := Basis(Vector3.UP, [0.0, PI * 0.5, -PI * 0.5][face])
		b.xf = Transform3D(turn, Vector3.ZERO)
		b.box("paint", Vector3(side - 0.18, 0.2, 0.03), Vector3(0.0, 0.22, h - 0.03), red)
		for row in 9:
			b.box("paint", Vector3(side - 0.18, 0.028, 0.03), Vector3(0.0, 0.33 + float(row) * 0.21, h - 0.03), red)
		for bar: float in [-0.21, 0.21]:
			b.box("paint", Vector3(0.028, 1.7, 0.03), Vector3(bar, 1.17, h - 0.03), red)
		b.box("glass", Vector3(side - 0.18, 1.7, 0.008), Vector3(0.0, 1.17, h - 0.04))
	b.xf = Transform3D.IDENTITY
	b.box("paint", Vector3(0.03, 0.2, 0.03), Vector3(0.3, 1.1, h + 0.01), Color(0.7, 0.6, 0.3))
	# The head: a white TELEPHONE panel on each face, a shallow dome over it.
	b.box("paint", Vector3(side, 0.26, side), Vector3(0.0, 2.17, 0.0), red)
	for face in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * float(face))
		b.box("paint", Vector3(0.62, 0.13, 0.012), turn * Vector3(0.0, 2.17, h + 0.004), Color(0.86, 0.84, 0.76), turn)
	b.ball("paint", Vector3(h + 0.01, 0.17, h + 0.01), Vector3(0.0, 2.3, 0.0), red, 8, 6)
	var pane := StandardMaterial3D.new()
	pane.albedo_color = Color(0.55, 0.62, 0.62, 0.22)
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.roughness = 0.1
	pane.cull_mode = BaseMaterial3D.CULL_DISABLED
	b.build(root, {"glass": pane})
	var plate := lettering("TELEPHONE", 0.56, 0.1, Color(0.08, 0.08, 0.08), false)
	plate.position = Vector3(0.0, 2.17, h + 0.014)
	root.add_child(plate)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.9, 0.68)
	light.light_energy = 0.0
	light.omni_range = 3.5
	light.shadow_enabled = false
	light.position = Vector3(0.0, 1.9, 0.0)
	root.add_child(light)
	return root

## A park bench: cast-iron ends, painted slats. It faces +Z.
static func bench() -> Node3D:
	var root := _root("Bench")
	var b := Batch.new()
	var slat := Color(0.2, 0.3, 0.22)
	var width := 1.7
	var lean := Basis(Vector3.RIGHT, -0.22)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (width * 0.5 - 0.12)
		b.box("iron", Vector3(0.05, 0.44, 0.06), Vector3(x, 0.22, 0.2), IRON)
		b.box("iron", Vector3(0.05, 0.92, 0.06), Vector3(x, 0.44, -0.22), IRON, lean)
		b.box("iron", Vector3(0.05, 0.05, 0.5), Vector3(x, 0.4, 0.0), IRON)
		b.box("iron", Vector3(0.05, 0.04, 0.5), Vector3(x, 0.64, 0.02), IRON)
		b.box("iron", Vector3(0.05, 0.22, 0.04), Vector3(x, 0.53, 0.25), IRON)
	for i in 4:
		b.box("paint", Vector3(width, 0.03, 0.095), Vector3(0.0, 0.445, -0.16 + 0.12 * float(i)), slat.darkened(0.08 * float(i % 2)))
	for i in 3:
		b.box("paint", Vector3(width, 0.095, 0.03), Vector3(0.0, 0.58 + 0.12 * float(i), -0.245 - 0.027 * float(i)), slat.darkened(0.08 * float(i % 2)), lean)
	b.build(root)
	return root

## A lifebelt on its post: a red-and-white ring on a red board. It faces +Z.
static func lifebelt_stand() -> Node3D:
	var root := _root("LifebeltStand")
	var b := Batch.new()
	var red := Color(0.72, 0.1, 0.07)
	var white := Color(0.88, 0.87, 0.82)
	b.box("paint", Vector3(0.1, 1.75, 0.1), Vector3(0.0, 0.875, 0.0), white)
	b.box("paint", Vector3(0.104, 0.25, 0.104), Vector3(0.0, 0.3, 0.0), red)
	b.box("paint", Vector3(0.82, 0.82, 0.05), Vector3(0.0, 1.32, 0.07), red.darkened(0.25))
	b.box("paint", Vector3(0.9, 0.05, 0.16), Vector3(0.0, 1.755, 0.07), white)
	b.torus("paint", 0.27, 0.075, Vector3(0.0, 1.32, 0.17), red, Basis(Vector3.RIGHT, PI * 0.5), 16, 6, white, 8)
	# The heaving line, coiled on a peg under the ring.
	b.torus("paint", 0.09, 0.03, Vector3(0.0, 0.98, 0.12), Color(0.8, 0.74, 0.55), Basis(Vector3.RIGHT, PI * 0.5), 8, 4)
	b.build(root)
	return root

## A headstone: a slab, a rounded top, now and then a ringed cross or a table stone;
## some lean. Its face is toward +Z.
static func gravestone(seed_value: int) -> Node3D:
	var root := _root("Gravestone")
	var rng := _rng(seed_value, 5)
	var b := Batch.new()
	var stone: Color = [Color(0.56, 0.55, 0.52), Color(0.47, 0.46, 0.44), Color(0.56, 0.46, 0.38), Color(0.4, 0.42, 0.38)][rng.randi() % 4]
	stone = stone.lerp(Look.MOSS, rng.randf_range(0.0, 0.25))
	var kind := rng.randi() % 8
	var w := rng.randf_range(0.5, 0.75)
	var h := rng.randf_range(0.7, 1.2)
	var thick := rng.randf_range(0.1, 0.16)
	if kind < 6 and rng.randf() < 0.45:
		# Sunk and leaning.
		b.xf = Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.16, 0.16)) * Basis(Vector3.RIGHT, rng.randf_range(-0.14, 0.14)), Vector3(0.0, -0.04, 0.0))
	var faces := Basis(Vector3.RIGHT, PI * 0.5)
	match kind:
		6:
			# A ringed cross on a stepped base.
			b.box("dressed", Vector3(0.62, 0.22, 0.5), Vector3(0.0, 0.11, 0.0), stone.darkened(0.1))
			b.box("dressed", Vector3(0.42, 0.14, 0.34), Vector3(0.0, 0.29, 0.0), stone)
			b.box("dressed", Vector3(0.17, 1.35, 0.13), Vector3(0.0, 1.03, 0.0), stone)
			b.box("dressed", Vector3(0.66, 0.16, 0.13), Vector3(0.0, 1.36, 0.0), stone)
			b.torus("dressed", 0.24, 0.045, Vector3(0.0, 1.36, 0.0), stone, faces, 12, 4)
		7:
			# A table stone on two low walls.
			for sz: float in [-0.6, 0.6]:
				b.box("dressed", Vector3(0.7, 0.4, 0.14), Vector3(0.0, 0.2, sz), stone.darkened(0.15))
			b.box("dressed", Vector3(0.95, 0.1, 1.85), Vector3(0.0, 0.45, 0.0), stone)
		_:
			if kind < 3:
				# A round-topped stone.
				b.box("dressed", Vector3(w, h - w * 0.5, thick), Vector3(0.0, (h - w * 0.5) * 0.5, 0.0), stone)
				b.cyl("dressed", w * 0.5, w * 0.5, thick, Vector3(0.0, h - w * 0.5, 0.0), stone, 8, faces, PI, TAU)
			elif kind == 3:
				# Shouldered: a narrower head on a broad slab.
				b.box("dressed", Vector3(w, h * 0.8, thick), Vector3(0.0, h * 0.4, 0.0), stone)
				b.box("dressed", Vector3(w * 0.6, h * 0.2, thick), Vector3(0.0, h * 0.9, 0.0), stone)
				b.cyl("dressed", w * 0.3, w * 0.3, thick, Vector3(0.0, h, 0.0), stone, 6, faces, PI, TAU)
			else:
				b.box("dressed", Vector3(w, h, thick), Vector3(0.0, h * 0.5, 0.0), stone)
				b.box("dressed", Vector3(w + 0.08, 0.07, thick + 0.05), Vector3(0.0, h + 0.035, 0.0), stone.darkened(0.08))
			# What is left of the lettering.
			for i in 3:
				b.box("dressed", Vector3(w * (0.6 - 0.1 * float(i)), 0.035, 0.01), Vector3(0.0, h * 0.62 - 0.1 * float(i), thick * 0.5 + 0.004), stone.darkened(0.35))
	b.build(root)
	return root

## A rubble wall along x, centred on the origin, with a cope of stones set on edge.
## Solid: a StaticBody3D "Body" with a box the wall's size.
static func wall(length: float, height: float = 1.0) -> Node3D:
	var root := _root("Wall")
	var rng := _rng(roundi(length * 100.0), 6)
	var b := Batch.new()
	var thick := 0.5
	var cope := minf(0.2, height * 0.3)
	var grey := Color(0.6, 0.58, 0.54)
	b.box("stone", Vector3(length, height - cope, thick), Vector3(0.0, (height - cope) * 0.5, 0.0), grey)
	var x := -length * 0.5
	while x < length * 0.5 - 0.05:
		var run := minf(rng.randf_range(0.13, 0.24), length * 0.5 - x)
		var tall := cope * rng.randf_range(0.75, 1.25)
		b.box("stone", Vector3(run - 0.015, tall, thick * rng.randf_range(0.8, 0.94)), Vector3(x + run * 0.5, height - cope + tall * 0.5, 0.0),
			grey.darkened(rng.randf_range(0.0, 0.3)), Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12)))
		x += run
	b.build(root)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = SOLID_LAYER
	body.collision_mask = 0
	root.add_child(body)
	Geo.box_shape(body, Vector3(length, height, thick), Vector3(0.0, height * 0.5, 0.0))
	return root

## An iron quay ladder: its foot at the origin, rising `height` to the quay's edge, the
## quay wall behind it (-Z). Its rails loop over the top and back onto the quay.
static func ladder(height: float) -> Node3D:
	var root := _root("QuayLadder")
	var b := Batch.new()
	var rusty := IRON.lerp(Look.RUST, 0.45)
	var off := 0.12
	for sx: float in [-0.21, 0.21]:
		b.box("iron", Vector3(0.05, height, 0.02), Vector3(sx, height * 0.5, off), rusty)
		# The hoop over the top, down to the quay half a metre back.
		var pts := [Vector3(sx, height, off), Vector3(sx, height + 0.8, off), Vector3(sx, height + 0.95, off - 0.12), Vector3(sx, height + 0.95, off - 0.42), Vector3(sx, height + 0.8, off - 0.54), Vector3(sx, height, off - 0.54)]
		for i in pts.size() - 1:
			b.rod("iron", pts[i], pts[i + 1], 0.022, rusty, 5)
		var y := 0.6
		while y < height:
			b.rod("iron", Vector3(sx, y, off), Vector3(sx, y, 0.0), 0.015, rusty, 4)
			y += 1.2
	var rung := 0.25
	while rung < height + 0.01:
		b.rod("iron", Vector3(-0.21, rung, off), Vector3(0.21, rung, off), 0.014, rusty.darkened(0.2), 5)
		rung += 0.28
	b.build(root)
	return root

## A coopered barrel, 0.9 m.
static func barrel() -> Node3D:
	var root := _root("Barrel")
	var b := Batch.new()
	var stave := Color(0.44, 0.32, 0.2)
	var radii := [0.25, 0.31, 0.31, 0.25]
	for i in 3:
		b.cyl("wood", radii[i], radii[i + 1], 0.3, Vector3(0.0, 0.15 + 0.3 * float(i), 0.0), stave, 12, Basis.IDENTITY, 0.0, TAU, i != 1)
	b.cyl("wood", 0.225, 0.225, 0.012, Vector3(0.0, 0.9, 0.0), stave.darkened(0.25), 12)
	for hoop: Array in [[0.06, 0.268], [0.27, 0.312], [0.63, 0.312], [0.84, 0.268]]:
		b.cyl("iron", hoop[1], hoop[1], 0.04, Vector3(0.0, hoop[0], 0.0), IRON.lerp(Look.RUST, 0.35), 12, Basis.IDENTITY, 0.0, TAU, false)
	b.build(root)
	return root

## A hand winch at a slip head: a drum of wire between two iron frames, gear and
## cranks. The wire leads off toward +Z (down the slip).
static func winch() -> Node3D:
	var root := _root("Winch")
	var b := Batch.new()
	var rusty := IRON.lerp(Look.RUST, 0.5)
	var across := Basis(Vector3.BACK, -PI * 0.5)
	for sx: float in [-0.42, 0.42]:
		b.box("wood", Vector3(0.16, 0.12, 1.3), Vector3(sx, 0.06, 0.0), Color(0.3, 0.25, 0.2))
		b.rod("iron", Vector3(sx, 0.12, -0.5), Vector3(sx, 0.92, 0.0), 0.04, rusty, 4)
		b.rod("iron", Vector3(sx, 0.12, 0.5), Vector3(sx, 0.92, 0.0), 0.04, rusty, 4)
		b.box("iron", Vector3(0.05, 0.08, 0.6), Vector3(sx, 0.5, 0.0), rusty)
		# A crank each side on the top shaft.
		b.rod("iron", Vector3(sx * 1.3, 0.92, 0.0), Vector3(sx * 1.3, 0.92 - 0.3 * signf(sx), 0.12), 0.022, IRON, 4)
		b.rod("iron", Vector3(sx * 1.3, 0.92 - 0.3 * signf(sx), 0.12), Vector3(sx * 1.75, 0.92 - 0.3 * signf(sx), 0.12), 0.028, Color(0.3, 0.22, 0.15), 5)
	b.rod("iron", Vector3(-0.56, 0.92, 0.0), Vector3(0.56, 0.92, 0.0), 0.025, IRON, 5)
	b.cyl("iron", 0.07, 0.07, 0.1, Vector3(0.3, 0.92, 0.0), IRON, 8, across)
	# The drum with its wire, flanges, and the big gear the pinion turns.
	b.cyl("iron", 0.13, 0.13, 0.78, Vector3(0.0, 0.5, 0.0), rusty, 8, across)
	b.cyl("iron", 0.19, 0.19, 0.46, Vector3(-0.08, 0.5, 0.0), Color(0.3, 0.3, 0.31), 10, across)
	for fx: float in [-0.33, 0.17]:
		b.cyl("iron", 0.27, 0.27, 0.03, Vector3(fx, 0.5, 0.0), rusty, 12, across)
	b.cyl("iron", 0.34, 0.34, 0.05, Vector3(0.3, 0.5, 0.0), Color(0.36, 0.12, 0.08), 14, across)
	b.rod("iron", Vector3(-0.08, 0.66, 0.1), Vector3(-0.08, 0.04, 1.9), 0.012, Color(0.3, 0.3, 0.31), 3)
	b.build(root)
	return root

## An old iron anchor laid up on a stone plinth as a monument, 2.2 m in the shank.
static func anchor() -> Node3D:
	var root := _root("Anchor")
	var b := Batch.new()
	var plinth := 0.32
	b.box("dressed", Vector3(3.0, plinth, 1.9), Vector3(0.0, plinth * 0.5, 0.0), Color(0.6, 0.58, 0.54))
	b.box("dressed", Vector3(3.2, 0.1, 2.1), Vector3(0.0, 0.05, 0.0), Color(0.5, 0.49, 0.46))
	b.box("iron", Vector3(0.5, 0.2, 0.02), Vector3(0.0, plinth * 0.55, 0.955), Color(0.5, 0.4, 0.18))
	# She lies on her stock, one fluke dug in and the other in the air: the shank (the
	# frame's Y) runs from the crown down to the ring, the arms are along the frame's X.
	var tilt := deg_to_rad(22.0)
	var shank := Vector3(-cos(tilt), -sin(tilt), 0.0)
	var arms := Vector3(-sin(tilt), cos(tilt), 0.0)
	b.xf = Transform3D(Basis(arms, shank, Vector3.BACK), Vector3(1.05, plinth + 0.9, 0.0))
	var black := IRON.lerp(Look.RUST, 0.15)
	var long := 2.2
	b.rod("iron", Vector3.ZERO, Vector3(0.0, long, 0.0), 0.075, black, 6, 0.055)
	for sx: float in [-1.0, 1.0]:
		b.rod("iron", Vector3.ZERO, Vector3(sx * 0.45, 0.16, 0.0), 0.075, black, 6, 0.065)
		b.rod("iron", Vector3(sx * 0.45, 0.16, 0.0), Vector3(sx * 0.78, 0.55, 0.0), 0.065, black, 6, 0.05)
		b.box("iron", Vector3(0.05, 0.4, 0.34), Vector3(sx * 0.72, 0.5, 0.0), black, Basis(Vector3.BACK, sx * 0.7))
	b.ball("iron", Vector3(0.1, 0.1, 0.1), Vector3.ZERO, black, 6, 4)
	# The stock, square to the arms, and the ring.
	b.rod("iron", Vector3(0.0, long - 0.22, -0.8), Vector3(0.0, long - 0.22, 0.8), 0.06, black, 6)
	for sz: float in [-0.8, 0.8]:
		b.ball("iron", Vector3(0.09, 0.09, 0.09), Vector3(0.0, long - 0.22, sz), black, 6, 4)
	b.torus("iron", 0.15, 0.03, Vector3(0.0, long + 0.14, 0.0), black, Basis(Vector3.RIGHT, PI * 0.5), 10, 5)
	b.build(root)
	return root
