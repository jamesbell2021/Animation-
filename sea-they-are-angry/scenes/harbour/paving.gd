class_name Paving
extends RefCounted
## Kirkhaven's street surfaces, laid just over the terrain (whose 0.45 m grid of painted
## vertices cannot show a sett): granite setts on the quay, the wynds and the streets,
## flagstone pavements and their kerbs along the house fronts, dressed blocks on the
## pier; over those the tyre tracks, stains and puddles; and the small things set in the
## ground (drains, mooring rings, rope ends, the kirk steps, weeds at the wall feet).
## All of it is for looking at: nothing here has a collision shape, and nothing in a
## street stands higher than a kerb. HarbourMain calls lay() and dress().

## Metres per repeat of each texture.
const SETT_TILE := 4.8
const FLAG_TILE := 3.6
const BLOCK_TILE := 3.0
## The setts' mesh is cut to about the terrain's own grid.
const CELL := 0.45
## How far each surface lies over the terrain.
const SETT_LIFT := 0.02
const FLAG_LIFT := 0.045
const KERB_LIFT := 0.08
const STAIN_LIFT := 0.032
const WET_LIFT := 0.037
## Over the flags, a stain or a puddle lies this much higher again.
const ON_FLAGS := 0.026
## More again on the ramps, where the terrain's facets stand off its true surface.
const SLOPE_LIFT := 0.03
## Where the quay's paving stops: just under the coping.
const EDGE := HarbourMap.QUAY_Z - 0.24
## Setts dissolve, stone by stone, where their cover falls toward this.
const SCISSOR := 0.33
## Vertex colours are half the tint (so a tint can lighten as well as darken).
const HALF := 0.5
const KERB_W := 0.16
const STEP_RUN := 0.2
const PARAPET_H := 0.95

## Pavements: [x from, x to, the wall's z, the kerb's z].
const PAVEMENTS := [
	[-32.3, -12.2, -1.5, 0.2], [-7.9, 7.8, -1.5, 0.2], [12.2, 24.7, -1.5, 0.2],
	[-28.6, -22.0, -13.6, -12.4], [-19.8, -13.4, -13.6, -12.4], [-8.2, -1.8, -13.6, -12.4],
	[1.8, 8.2, -13.6, -12.4], [12.4, 33.4, -13.6, -12.4],
]
## Puddles: [x, z, half-width, half-depth, 1 if it lies on a pavement]. On level ground
## only: the gutters, the foot of the brae behind the front row, the back lanes, the pier.
const PUDDLES := [
	[-6.3, 0.95, 1.2, 0.42, 0], [2.3, 1.05, 1.5, 0.5, 0], [17.4, 0.9, 1.0, 0.4, 0], [-22.6, 1.0, 1.3, 0.45, 0],
	[-18.6, 3.4, 1.5, 0.8, 0], [12.9, 3.2, 1.1, 0.7, 0], [-1.2, 3.6, 0.9, 0.55, 0], [22.6, 3.0, 0.8, 0.5, 0],
	[-10.3, -7.75, 1.5, 0.5, 0], [9.6, -7.8, 1.3, 0.45, 0], [-3.4, -7.8, 1.6, 0.32, 0], [19.0, -7.8, 1.8, 0.3, 0],
	[-10.4, -4.4, 0.55, 1.0, 0], [10.5, -3.2, 0.5, 0.8, 0],
	[0.3, -16.8, 0.8, 1.1, 0], [-10.9, -16.0, 1.3, 0.9, 0], [10.3, -17.2, 1.0, 0.8, 0], [-5.0, -19.65, 1.8, 0.28, 0],
	[1.0, 12.6, 0.9, 0.6, 0], [-2.6, 27.2, 1.2, 0.7, 0], [2.4, 22.6, 0.7, 0.5, 0],
	[-15.0, -0.6, 0.7, 0.4, 1], [4.6, -0.5, 0.6, 0.35, 1],
]
## Drain gratings: [x, z, turn in degrees]. In the gutters and at the foot of each wynd.
const DRAINS := [
	[-27.0, 0.62, 0], [-15.4, 0.62, 0], [-2.9, 0.62, 0], [6.4, 0.62, 0], [20.4, 0.62, 0],
	[-10.0, -7.2, 0], [10.0, -7.2, 0], [0.0, -14.3, 90], [-10.9, -18.9, 0],
]
## Iron covers: [x, z].
const COVERS := [[-21.6, 2.9], [13.6, 2.2], [0.9, 9.4]]
## Mooring rings: [x, z].
const RINGS := [
	[-31.6, 5.3], [-21.2, 5.3], [-6.6, 5.3], [12.2, 5.3], [18.9, 5.3],
	[-1.95, 12.0], [1.95, 16.2], [4.55, 23.4], [-4.5, 28.6],
]
## Rope ends left lying: [x, z, heading in degrees, metres, colour].
const ROPES := [
	[-23.7, 4.5, 200, 2.4, 0], [-7.4, 4.8, 150, 1.8, 1], [5.7, 4.3, 20, 2.2, 0], [22.2, 3.9, 170, 1.6, 2],
	[-18.4, 2.2, 80, 1.5, 1], [1.4, 15.0, 100, 2.6, 0], [-3.6, 26.3, 300, 2.0, 2], [27.4, 0.2, 40, 1.7, 0],
	[-13.2, 3.5, 10, 1.4, 2],
]
const ROPE_COLS := [Color(0.62, 0.52, 0.34), Color(0.2, 0.38, 0.56), Color(0.78, 0.38, 0.12)]

static var _noise: FastNoiseLite
static var _rects: Array[Rect2] = []
static var _made := {}

# ---- one mesh per surface ----

## Gathers ground-hugging faces into one mesh: points with their colour, UV and
## tangent, then triangles between them.
class Sheet:
	extends RefCounted
	var _v := PackedVector3Array()
	var _n := PackedVector3Array()
	var _t := PackedFloat32Array()
	var _c := PackedColorArray()
	var _uv := PackedVector2Array()
	var _i := PackedInt32Array()

	## Add a point; returns its number. `along` is the way its texture's U runs.
	func point(p: Vector3, uv: Vector2, col: Color, up: Vector3 = Vector3.UP, along: Vector3 = Vector3.RIGHT) -> int:
		_v.append(p)
		_n.append(up)
		_t.append(along.x)
		_t.append(along.y)
		_t.append(along.z)
		_t.append(1.0)
		_c.append(col)
		_uv.append(uv)
		return _v.size() - 1

	## A triangle that shows from the side `out` points to.
	func tri(a: int, b: int, c: int, out: Vector3 = Vector3.UP) -> void:
		if (_v[b] - _v[a]).cross(_v[c] - _v[a]).dot(out) > 0.0:
			_i.append(a)
			_i.append(c)
			_i.append(b)
		else:
			_i.append(a)
			_i.append(b)
			_i.append(c)

	## A four-sided face, its corners in order round it.
	func quad(a: int, b: int, c: int, d: int, out: Vector3 = Vector3.UP) -> void:
		tri(a, b, c, out)
		tri(a, c, d, out)

	## A soft-edged blot lying on the ground (a stain, a puddle): `col` with its alpha
	## out to `core` of the radius, fading to nothing at a wavering rim.
	func blot(at: Vector2, radius: Vector2, col: Color, lift: float, rng: RandomNumberGenerator, core: float = 0.6, turn: float = 0.0) -> void:
		var segs := 14
		var p1 := rng.randf() * TAU
		var p2 := rng.randf() * TAU
		var p3 := rng.randf() * TAU
		var rim := Color(col.r, col.g, col.b, 0.0)
		var mid := point(Paving._at(at, lift), Vector2.ZERO, col)
		var inner := PackedInt32Array()
		var outer := PackedInt32Array()
		for k in segs:
			var a := TAU * float(k) / float(segs)
			var r := 1.0 + 0.22 * sin(a * 2.0 + p1) + 0.14 * sin(a * 3.0 + p2) + 0.08 * sin(a * 5.0 + p3)
			var d := Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(turn) * r
			inner.append(point(Paving._at(at + d * core, lift), Vector2.ZERO, col))
			outer.append(point(Paving._at(at + d, lift), Vector2.ZERO, rim))
		for k in segs:
			var k1 := (k + 1) % segs
			tri(mid, inner[k], inner[k1])
			quad(inner[k], outer[k], outer[k1], inner[k1])

	## A soft-edged stripe on the ground along `pts`, `half` wide each side of them,
	## fading in and out over `fade` points at its ends.
	func stripe(pts: PackedVector2Array, half: float, col: Color, lift: float, fade: int = 2) -> void:
		var last := pts.size() - 1
		var prev := PackedInt32Array()
		for k in pts.size():
			var dir := (pts[mini(k + 1, last)] - pts[maxi(k - 1, 0)]).normalized()
			var side := Vector2(-dir.y, dir.x)
			var a := col.a
			if fade > 0:
				a *= clampf(float(mini(k, last - k)) / float(fade), 0.0, 1.0)
			var row := PackedInt32Array()
			for w: float in [-1.0, -0.45, 0.45, 1.0]:
				var c := Color(col.r, col.g, col.b, a if absf(w) < 1.0 else 0.0)
				row.append(point(Paving._at(pts[k] + side * half * w, lift), Vector2.ZERO, c))
			if k > 0:
				for m in 3:
					quad(prev[m], prev[m + 1], row[m + 1], row[m])
			prev = row

	## The finished mesh, in `mat`. It throws no shadow (it lies on the ground).
	func commit(title: String, mat: Material) -> MeshInstance3D:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _v
		arrays[Mesh.ARRAY_NORMAL] = _n
		arrays[Mesh.ARRAY_TANGENT] = _t
		arrays[Mesh.ARRAY_COLOR] = _c
		arrays[Mesh.ARRAY_TEX_UV] = _uv
		arrays[Mesh.ARRAY_INDEX] = _i
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = title
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi

# ---- where things are ----

static func _setup() -> void:
	if _noise != null:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 62
	_noise.frequency = 0.11
	_noise.fractal_octaves = 3
	for b: Array in HarbourMap.BUILDINGS:
		_rects.append(Rect2(float(b[0]) - float(b[2]) * 0.5, float(b[1]) - float(b[4]) * 0.5, float(b[2]), float(b[4])))

## 1 on the two ramps (the brae between the streets, the kirk brae), 0 on the level.
static func _on_slope(z: float) -> float:
	return maxf(smoothstep(-7.2, -8.0, z) * smoothstep(-14.0, -13.2, z), smoothstep(-19.4, -20.0, z))

## The point `lift` over the terrain at p (x, z).
static func _at(p: Vector2, lift: float) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.y) + lift + SLOPE_LIFT * _on_slope(p.y), p.y)

static func _up(z: float) -> Vector3:
	return Vector3.UP if _on_slope(z) <= 0.0 else Terrain.normal_at(0.0, z)

## How far a point is from the nearest house wall (0 inside one).
static func _wall_dist(x: float, z: float) -> float:
	var best := 99.0
	for r in _rects:
		var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
		var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
		best = minf(best, sqrt(dx * dx + dz * dz))
	return best

static func _under_roof(x: float, z: float) -> bool:
	for r in _rects:
		if r.grow(-0.5).has_point(Vector2(x, z)):
			return true
	return false

## How much of the setts is left at a point: 1 in the town, falling away raggedly at
## its ends (the rocks, the strand, the foot of the kirk brae) and in a few worn hollows.
static func sett_cover(x: float, z: float) -> float:
	_setup()
	# The kirk steps take over from the setts at the foot of the brae.
	if z < -20.2 and absf(x - HarbourMap.KIRK_GATE.x) < HarbourMap.GATE_HALF + 0.3:
		return 0.0
	var wob := _noise.get_noise_2d(x * 3.0 - 20.0, z * 3.0 + 9.0)
	var c := smoothstep(-36.4, -33.8, x + wob * 1.5)
	c *= 1.0 - smoothstep(35.4, 37.4, x + wob * 1.5)
	c *= smoothstep(-21.3, -20.25, z + wob * 0.7)
	c *= 1.0 - smoothstep(24.9, 26.3, x + wob) * smoothstep(-0.5, 1.2, z + wob * 0.8)
	# Hollows where the setts have gone, out of the way of the carts.
	var quiet := maxf(smoothstep(-13.8, -14.6, z), maxf(smoothstep(-27.0, -30.0, x), smoothstep(26.0, 29.0, x)))
	var hollow := smoothstep(0.3, 0.52, _noise.get_noise_2d(x * 2.4 + 70.0, z * 2.4 - 33.0))
	return c * (1.0 - 0.8 * hollow * quiet)

# The setts' tint at a point (to be halved into a vertex colour): patchy, damp and
# green at the foot of the walls, dark and wet toward the quay's edge and the slips.
static func _sett_tint(x: float, z: float) -> Color:
	var broad := _noise.get_noise_2d(x * 1.2, z * 1.2)
	var fine := _noise.get_noise_2d(x * 5.0 + 40.0, z * 5.0)
	var v := 1.0 + broad * 0.24 + fine * 0.12
	var c := Color(v * (1.0 + fine * 0.05), v, v * (1.0 - fine * 0.07))
	var foot := 1.0 - smoothstep(0.1, 1.2, _wall_dist(x, z))
	# The streets behind the front get little sun.
	var shade := 0.0 if z > -1.5 else 1.0
	c = c * (1.0 - foot * (0.2 + 0.14 * shade))
	c.g *= 1.0 + foot * 0.06 * shade
	if shade > 0.0:
		c = c * Color(0.9, 0.93, 0.88)
	else:
		var wet := smoothstep(3.3, 5.8, z)
		for s: float in HarbourMap.SLIPS:
			wet = maxf(wet, (1.0 - smoothstep(2.4, 5.2, absf(x - s))) * smoothstep(0.8, 5.4, z))
		wet *= 1.0 - smoothstep(HarbourMap.STRAND_X - 1.0, HarbourMap.STRAND_X + 1.0, x)
		c = c * lerpf(1.0, 0.58, wet * wet)
		# The middle of the apron is worn pale by wheels and boots.
		c = c * (1.0 + 0.1 * exp(-pow((z - 2.7) / 1.3, 2.0)))
	return c

static func _pack(c: Color, a: float = 1.0) -> Color:
	return Color(clampf(c.r * HALF, 0.0, 1.0), clampf(c.g * HALF, 0.0, 1.0), clampf(c.b * HALF, 0.0, 1.0), a)

# ---- textures and materials (made once) ----

static func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func _noise_bytes(px: int, frequency: float, seed_value: int) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = frequency
	n.fractal_octaves = 2
	return n.get_seamless_image(px, px).get_data()

# A tiling texture of coursed stones, painted here: `rows` courses down the image of
# `cols` stones each (a stone is `stone` metres, along its course and across it), each
# course broken against the next, every stone its own length, colour and set. Returns
# [albedo, normal]. With "loose", a stone's alpha is how firmly it is set (see SCISSOR).
static func _coursed(px: int, cols: int, rows: int, stone: Vector2, o: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", 1))
	var joint: float = float(o.get("joint", 0.02)) * 0.5
	var shoulder: float = o.get("shoulder", 0.02)
	var jitter: float = o.get("jitter", 0.15)
	var vary: float = o.get("vary", 0.15)
	var grain_k: float = o.get("grain", 0.25)
	var relief: float = o.get("relief", 1.0)
	var worn: float = o.get("worn", 0.05)
	var crack_p: float = o.get("cracks", 0.0)
	var loose: bool = o.get("loose", false)
	var round_r: float = o.get("round", 0.03)
	var rough_edge: float = o.get("rough_edge", 0.01)
	var palette: Array = o["palette"]
	var dirt: Color = o.get("joint_col", Color(0.15, 0.14, 0.12))
	var moss: Color = o.get("moss", Color(0.17, 0.2, 0.11))
	var grain := _noise_bytes(px, 0.3, 11 + rows)
	var blotch := _noise_bytes(px, 3.0 / float(px), 23 + cols)
	var count := cols * rows
	var span := cols + 5
	# Per course: how far it is shifted, and where each stone in it starts. Per stone:
	# its colour, how proud it stands, how it tips, how firmly it is set, any crack.
	var shift := PackedFloat32Array()
	var bound := PackedFloat32Array()
	var tone := PackedColorArray()
	var proud := PackedFloat32Array()
	var hold := PackedFloat32Array()
	var tip_u := PackedFloat32Array()
	var tip_v := PackedFloat32Array()
	var crack := PackedFloat32Array()
	shift.resize(rows)
	bound.resize(rows * span)
	tone.resize(count)
	proud.resize(count)
	hold.resize(count)
	tip_u.resize(count)
	tip_v.resize(count)
	crack.resize(count)
	for r in rows:
		shift[r] = (0.5 if r % 2 == 1 else 0.0) + rng.randf_range(-0.12, 0.12)
		var jit := PackedFloat32Array()
		for c in cols:
			jit.append(rng.randf_range(-jitter, jitter))
		for e in span:
			bound[r * span + e] = float(e - 2) + shift[r] + jit[posmod(e - 2, cols)]
		for c in cols:
			var s := r * cols + c
			var bx := posmod(int((float(c) + 0.5 + shift[r]) / float(cols) * float(px)), px)
			var by := mini(int((float(r) + 0.5) / float(rows) * float(px)), px - 1)
			var big := float(blotch[by * px + bx]) / 255.0
			var base: Color = palette[rng.randi() % palette.size()]
			var val := (1.0 + rng.randf_range(-vary, vary)) * (0.88 + 0.24 * big)
			tone[s] = Color(base.r * val, base.g * val, base.b * val)
			proud[s] = rng.randf_range(0.7, 1.0)
			hold[s] = 0.37 + 0.63 * clampf(0.55 * rng.randf() + 0.9 * (big - 0.25), 0.0, 1.0)
			tip_u[s] = rng.randf_range(-0.5, 0.5)
			tip_v[s] = rng.randf_range(-0.5, 0.5)
			crack[s] = rng.randf() * PI if rng.randf() < crack_p else -1.0
	var rgba := PackedByteArray()
	rgba.resize(px * px * 4)
	var high := PackedFloat32Array()
	high.resize(px * px)
	for y in px:
		var v := (float(y) + 0.5) / float(px) * float(rows)
		var r := mini(int(v), rows - 1)
		var fv := v - float(r)
		var dv := minf(fv, 1.0 - fv) * stone.y
		var base_i := r * span + 2
		var sh := shift[r]
		for x in px:
			var u := (float(x) + 0.5) / float(px) * float(cols)
			var c := int(floorf(u - sh))
			if u < bound[base_i + c]:
				c -= 1
			elif u >= bound[base_i + c + 1]:
				c += 1
			var left := bound[base_i + c]
			var right := bound[base_i + c + 1]
			var du := minf(u - left, right - u) * stone.x
			var d := minf(du, dv)
			# Rounded at the corners, and no edge quite straight.
			if du < round_r and dv < round_r:
				d = round_r - sqrt((round_r - du) * (round_r - du) + (round_r - dv) * (round_r - dv))
			var s := r * cols + posmod(c, cols)
			var i := y * px + x
			var g := float(grain[i]) / 255.0
			d += (g - 0.5) * rough_edge
			var top := clampf((d - joint) / shoulder, 0.0, 1.0)
			top = top * top * (3.0 - 2.0 * top)
			var mid := (u - (left + right) * 0.5) * stone.x
			var across := (fv - 0.5) * stone.y
			if crack[s] >= 0.0:
				var off := absf(mid * cos(crack[s]) + across * sin(crack[s]) + (g - 0.5) * 0.03)
				if off < 0.012:
					top *= 0.35 + 0.65 * off / 0.012
			var lit := (1.0 - grain_k * 0.5 + grain_k * g) * (1.0 - 0.16 * (1.0 - clampf((d - joint) / worn, 0.0, 1.0)))
			var t := tone[s]
			var cr := t.r * lit
			var cg := t.g * lit
			var cb := t.b * lit
			if top < 0.999:
				var green := clampf((float(blotch[i]) / 255.0 - 0.5) * 4.0, 0.0, 1.0)
				cr = lerpf(lerpf(dirt.r, moss.r, green), cr, top)
				cg = lerpf(lerpf(dirt.g, moss.g, green), cg, top)
				cb = lerpf(lerpf(dirt.b, moss.b, green), cb, top)
			rgba[i * 4] = clampi(int(cr * 255.0), 0, 255)
			rgba[i * 4 + 1] = clampi(int(cg * 255.0), 0, 255)
			rgba[i * 4 + 2] = clampi(int(cb * 255.0), 0, 255)
			rgba[i * 4 + 3] = int(hold[s] * 255.0) if loose else 255
			high[i] = top * (proud[s] + mid / stone.x * tip_u[s] + across / stone.y * tip_v[s]) + (g - 0.5) * grain_k * 0.5
	# The normal map, from the heights.
	var nrm := PackedByteArray()
	nrm.resize(px * px * 3)
	for y in px:
		var above := posmod(y - 1, px) * px
		var below := ((y + 1) % px) * px
		var here := y * px
		for x in px:
			var dx := (high[here + (x + 1) % px] - high[here + posmod(x - 1, px)]) * relief
			var dy := (high[below + x] - high[above + x]) * relief
			var k := 1.0 / sqrt(dx * dx + dy * dy + 1.0)
			var i := (here + x) * 3
			nrm[i] = int((-dx * k * 0.5 + 0.5) * 255.0)
			nrm[i + 1] = int((dy * k * 0.5 + 0.5) * 255.0)
			nrm[i + 2] = int((k * 0.5 + 0.5) * 255.0)
	var albedo := Image.create_from_data(px, px, false, Image.FORMAT_RGBA8, rgba)
	var normal := Image.create_from_data(px, px, false, Image.FORMAT_RGB8, nrm)
	albedo.generate_mipmaps()
	normal.generate_mipmaps(true)
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(normal)]

# A stone surface: its texture tinted by the vertices (see HALF), lit like any other.
static func _stone_mat(key: String, tex: Array, roughness: float, bump: float) -> StandardMaterial3D:
	if _made.has(key):
		return _made[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex[0]
	# Twice over (in linear light), to undo the halved vertex colours.
	m.albedo_color = Color(1.353, 1.353, 1.353)
	m.vertex_color_use_as_albedo = true
	m.normal_enabled = true
	m.normal_texture = tex[1]
	m.normal_scale = bump
	m.roughness = roughness
	m.metallic_specular = 0.4
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_made[key] = m
	return m

## Granite setts, about 30 cm by 16: greys, a pink and a blue among them.
static func sett_mat() -> StandardMaterial3D:
	if not _made.has("setts"):
		var tex := _coursed(32 if _headless() else 512, 16, 30, Vector2(0.3, 0.16), {
			"seed": 1987, "joint": 0.026, "shoulder": 0.03, "jitter": 0.22, "vary": 0.12, "grain": 0.3, "relief": 1.4,
			"worn": 0.06, "loose": true, "round": 0.04, "rough_edge": 0.012, "joint_col": Color(0.19, 0.175, 0.15),
			"palette": [Color(0.5, 0.5, 0.49), Color(0.47, 0.47, 0.48), Color(0.52, 0.49, 0.47), Color(0.45, 0.47, 0.5),
				Color(0.5, 0.48, 0.44), Color(0.54, 0.54, 0.53), Color(0.39, 0.39, 0.4)],
		})
		var m := _stone_mat("setts", tex, 0.86, 1.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = SCISSOR
	return _made["setts"]

## Big worn flagstones for the pavements.
static func flag_mat() -> StandardMaterial3D:
	if not _made.has("flags"):
		var tex := _coursed(32 if _headless() else 256, 4, 6, Vector2(0.9, 0.6), {
			"seed": 31, "joint": 0.022, "shoulder": 0.02, "jitter": 0.24, "vary": 0.13, "grain": 0.2, "relief": 0.8,
			"worn": 0.22, "cracks": 0.2, "joint_col": Color(0.16, 0.15, 0.13),
			"palette": [Color(0.56, 0.55, 0.51), Color(0.6, 0.57, 0.5), Color(0.5, 0.52, 0.52), Color(0.62, 0.57, 0.48)],
		})
		_stone_mat("flags", tex, 0.8, 0.9)
	return _made["flags"]

## Large dressed blocks: the pier's deck, the kerbs, the sills at the slip heads.
static func block_mat() -> StandardMaterial3D:
	if not _made.has("blocks"):
		var tex := _coursed(32 if _headless() else 256, 4, 7, Vector2(BLOCK_TILE / 4.0, BLOCK_TILE / 7.0), {
			"seed": 77, "joint": 0.026, "shoulder": 0.035, "jitter": 0.24, "vary": 0.08, "grain": 0.36, "relief": 0.9,
			"worn": 0.12, "cracks": 0.06, "round": 0.02, "joint_col": Color(0.17, 0.165, 0.15),
			"palette": [Color(0.5, 0.495, 0.47), Color(0.53, 0.515, 0.485), Color(0.47, 0.47, 0.46), Color(0.52, 0.5, 0.46)],
		})
		_stone_mat("blocks", tex, 0.9, 1.0)
	return _made["blocks"]

# Dirt on the stones: colour and strength from the vertices, drawn before the fog.
static func _stain_mat() -> StandardMaterial3D:
	if not _made.has("stain"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.95
		m.metallic_specular = 0.2
		m.render_priority = -2
		_made["stain"] = m
	return _made["stain"]

# Standing water and wet stone: dark and smooth, so the lamps lie in it at night.
static func _wet_mat() -> StandardMaterial3D:
	if not _made.has("wet"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.2
		m.metallic_specular = 1.0
		m.render_priority = -1
		_made["wet"] = m
	return _made["wet"]

# ---- laying it ----

## Lay the town's surfaces as children of `parent`: five meshes. Call it once
## Terrain.chapter is 2 (it follows Terrain.height_at).
static func lay(parent: Node3D) -> void:
	_setup()
	var root := Node3D.new()
	root.name = "Paving"
	parent.add_child(root)
	var setts := Sheet.new()
	var flags := Sheet.new()
	var blocks := Sheet.new()
	var stains := Sheet.new()
	var wet := Sheet.new()
	_lay_setts(setts)
	_lay_pavements(flags, blocks, stains)
	_lay_pier(blocks)
	_lay_wear(stains)
	_lay_wet(wet)
	root.add_child(setts.commit("Setts", sett_mat()))
	root.add_child(flags.commit("Flags", flag_mat()))
	root.add_child(blocks.commit("Blocks", block_mat()))
	root.add_child(stains.commit("Stains", _stain_mat()))
	root.add_child(wet.commit("Wet", _wet_mat()))

# Setts over the whole town but under its roofs. Their courses run across the way the
# carts go: up and down the quay and the street behind it, across the wynds and lanes.
static func _lay_setts(sheet: Sheet) -> void:
	var x0 := -38.2
	var z0 := -21.9
	var nx := ceili((38.6 - x0) / CELL)
	var nz := ceili((EDGE - z0) / CELL)
	var dx := (38.6 - x0) / float(nx)
	var dz := (EDGE - z0) / float(nz)
	var at := PackedVector3Array()
	var tint := PackedColorArray()
	for j in nz + 1:
		var z := z0 + dz * float(j)
		for i in nx + 1:
			var x := x0 + dx * float(i)
			at.append(_at(Vector2(x, z), SETT_LIFT))
			var cover := sett_cover(x, z)
			tint.append(_pack(_sett_tint(x, z), cover) if cover > 0.2 else Color(0.5, 0.5, 0.5, cover))
	for j in nz:
		var zc := z0 + dz * (float(j) + 0.5)
		var up := _up(zc)
		# Across the wynds (between the front row's houses) and the back lanes.
		var turned := (zc < -1.5 and zc > -7.5) or zc < -13.6
		var along := Vector3.RIGHT if turned else Vector3.BACK
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			if maxf(maxf(tint[a].a, tint[b].a), maxf(tint[c].a, tint[d].a)) < SCISSOR - 0.05:
				continue
			if _under_roof(x0 + dx * (float(i) + 0.5), zc):
				continue
			var ids := PackedInt32Array()
			for k: int in [a, b, d, c]:
				var p := at[k]
				var uv := Vector2(p.x, p.z) / SETT_TILE if turned else Vector2(p.z, -p.x) / SETT_TILE
				ids.append(sheet.point(p, uv, tint[k], up, along))
			sheet.quad(ids[0], ids[1], ids[2], ids[3])

# A rectangle of ground, cut into cells of about `cell` and laid `lift` over the terrain.
# `tint` gives the colour at (x, z); `slide` shifts the texture.
static func _patch(sheet: Sheet, r: Rect2, cell: float, lift: float, tile: float, tint: Callable, slide: Vector2 = Vector2.ZERO) -> void:
	var nx := maxi(1, ceili(r.size.x / cell))
	var nz := maxi(1, ceili(r.size.y / cell))
	var ids := PackedInt32Array()
	for j in nz + 1:
		var z := r.position.y + r.size.y * float(j) / float(nz)
		var up := _up(z)
		for i in nx + 1:
			var x := r.position.x + r.size.x * float(i) / float(nx)
			var col: Color = tint.call(x, z)
			ids.append(sheet.point(_at(Vector2(x, z), lift), Vector2(x, z) / tile + slide, col, up))
	for j in nz:
		for i in nx:
			var a := ids[j * (nx + 1) + i]
			var c := ids[(j + 1) * (nx + 1) + i]
			sheet.quad(a, ids[j * (nx + 1) + i + 1], ids[(j + 1) * (nx + 1) + i + 1], c)

# A kerb from a to b (x, z), KERB_W wide on the side `side` points to: its top, and its
# face down to the setts. `course` picks which of the block texture's courses it is cut from.
static func _kerb(sheet: Sheet, a: Vector2, b: Vector2, side: Vector2, course: int) -> void:
	var total := a.distance_to(b)
	var n := maxi(1, ceili(total / 1.8))
	var dir := (b - a) / total
	var along := Vector3(dir.x, 0.0, dir.y)
	var out := Vector3(side.x, 0.0, side.y)
	var v0 := (float(course % 7) + 0.3) / 7.0
	var v1 := v0 + KERB_W / BLOCK_TILE
	var slide := float(course) * 0.37
	for k in n:
		var p := a + dir * total * float(k) / float(n)
		var q := a + dir * total * float(k + 1) / float(n)
		var u0 := total * float(k) / float(n) / BLOCK_TILE + slide
		var u1 := total * float(k + 1) / float(n) / BLOCK_TILE + slide
		var g := 1.3 + _noise.get_noise_2d(p.x * 3.0, p.y * 3.0 + 50.0) * 0.2
		var top := _pack(Color(g, g, g * 0.98))
		var face := _pack(Color(g, g, g) * 0.7)
		var i0 := sheet.point(_at(p, KERB_LIFT), Vector2(u0, v0), top, Vector3.UP, along)
		var i1 := sheet.point(_at(q, KERB_LIFT), Vector2(u1, v0), top, Vector3.UP, along)
		var i2 := sheet.point(_at(q + side * KERB_W, KERB_LIFT), Vector2(u1, v1), top, Vector3.UP, along)
		var i3 := sheet.point(_at(p + side * KERB_W, KERB_LIFT), Vector2(u0, v1), top, Vector3.UP, along)
		sheet.quad(i0, i1, i2, i3)
		var j0 := sheet.point(_at(p + side * KERB_W, KERB_LIFT), Vector2(u0, v0), face, out, along)
		var j1 := sheet.point(_at(q + side * KERB_W, KERB_LIFT), Vector2(u1, v0), face, out, along)
		var j2 := sheet.point(_at(q + side * KERB_W, 0.0), Vector2(u1, v1), face, out, along)
		var j3 := sheet.point(_at(p + side * KERB_W, 0.0), Vector2(u0, v1), face, out, along)
		sheet.quad(j0, j1, j2, j3, out)

# The pavements: flags from each row's house fronts out to a kerb, the kerb returned to
# the wall at each end, a dark line of gutter along its foot. And the flags of the
# kirk path, above and below its steps.
static func _lay_pavements(flags: Sheet, blocks: Sheet, stains: Sheet) -> void:
	for i in PAVEMENTS.size():
		var row: Array = PAVEMENTS[i]
		var x0 := float(row[0])
		var x1 := float(row[1])
		var wall := float(row[2])
		var kerb := float(row[3])
		var tint := func(x: float, z: float) -> Color:
			var g := 1.0 + _noise.get_noise_2d(x * 2.2 + 11.0, z * 2.2) * 0.26
			g *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 0.7, absf(z - wall)))
			return _pack(Color(g, g, g * 0.97))
		_patch(flags, Rect2(x0, wall, x1 - x0, kerb - wall), 0.85, FLAG_LIFT, FLAG_TILE, tint, Vector2(float(i) * 0.23, float(i) * 0.31))
		_kerb(blocks, Vector2(x0 - KERB_W, kerb), Vector2(x1 + KERB_W, kerb), Vector2(0.0, 1.0), i)
		_kerb(blocks, Vector2(x0, wall + 0.05), Vector2(x0, kerb), Vector2(-1.0, 0.0), i + 2)
		_kerb(blocks, Vector2(x1, wall + 0.05), Vector2(x1, kerb), Vector2(1.0, 0.0), i + 3)
		var gutter := PackedVector2Array()
		var x := x0 - 0.3
		while x < x1 + 0.6:
			gutter.append(Vector2(x, kerb + KERB_W + 0.13 + _noise.get_noise_2d(x * 4.0, kerb) * 0.05))
			x += 0.9
		stains.stripe(gutter, 0.2, Color(0.016, 0.016, 0.012, 0.5), STAIN_LIFT)
	# The kirk path: a landing at the door, another at the foot of the steps.
	var gate := HarbourMap.KIRK_GATE
	var half := HarbourMap.GATE_HALF - 0.05
	var path := func(x: float, z: float) -> Color:
		var g := 0.95 + _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.2
		return _pack(Color(g, g, g * 0.96))
	_patch(flags, Rect2(gate.x - half, -24.62, half * 2.0, 0.82), 0.45, FLAG_LIFT, FLAG_TILE, path)
	_patch(flags, Rect2(gate.x - half - 0.3, -20.34, half * 2.0 + 0.6, 0.9), 0.45, FLAG_LIFT, FLAG_TILE, path, Vector2(0.4, 0.1))

# The pier's deck in dressed blocks, darker and wetter toward its edges; a sill of the
# same blocks across each slip's head.
static func _lay_pier(blocks: Sheet) -> void:
	var stem := HarbourMap.PIER_HALF - 0.15
	var head := HarbourMap.PIER_HEAD_HALF - 0.15
	var from := HarbourMap.PIER_HEAD_FROM - 0.1
	var deck := func(x: float, z: float) -> Color:
		var half := stem if z < from else head
		var inset := minf(half - absf(x), HarbourMap.PIER_END - 0.15 - z)
		var g := 0.9 + _noise.get_noise_2d(x * 2.0 + 5.0, z * 2.0) * 0.3
		g *= lerpf(0.62, 1.0, smoothstep(0.0, 1.1, inset))
		# Worn pale down the middle, where everyone walks.
		g *= 1.0 + 0.1 * exp(-pow(x / 0.9, 2.0))
		return _pack(Color(g, g, g * 0.98))
	_patch(blocks, Rect2(-stem, EDGE, stem * 2.0, from - EDGE), 0.82, SETT_LIFT, BLOCK_TILE, deck)
	_patch(blocks, Rect2(-head, from, head * 2.0, HarbourMap.PIER_END - 0.15 - from), 0.86, SETT_LIFT, BLOCK_TILE, deck)
	var sill := func(x: float, _z: float) -> Color:
		var g := 0.74 + _noise.get_noise_2d(x * 3.0, 9.0) * 0.16
		return _pack(Color(g, g * 1.03, g * 0.96))
	for s: float in HarbourMap.SLIPS:
		var half := HarbourMap.SLIP_HALF + 0.35
		_patch(blocks, Rect2(s - half, EDGE, half * 2.0, HarbourMap.QUAY_Z - EDGE), 0.9, SETT_LIFT + 0.006, BLOCK_TILE, sill, Vector2(0.17, 0.06))

# What use has left on the stones: cart and tyre ruts along the quay, up the wynds and
# along the street behind; oil where engines stand; rust under the ironwork; green at
# the slip heads; the damp line along the walls of the wynds.
static func _lay_wear(stains: Sheet) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var rut := Color(0.02, 0.018, 0.015, 0.44)
	for off: float in [-0.7, 0.7]:
		# Along the quay.
		var pts := PackedVector2Array()
		var x := -28.6
		while x <= 24.2:
			pts.append(Vector2(x, 2.75 + off + sin(x * 0.17) * 0.22 + _noise.get_noise_2d(x * 2.0, 5.0 + off) * 0.25))
			x += 0.9
		stains.stripe(pts, 0.24, rut, STAIN_LIFT, 3)
		# Along the street behind, below the wynd lamps.
		pts = PackedVector2Array()
		x = -29.0
		while x <= 31.0:
			pts.append(Vector2(x, -9.3 + off + sin(x * 0.21 + 1.0) * 0.2))
			x += 0.9
		stains.stripe(pts, 0.24, rut, STAIN_LIFT, 3)
		# Up each wynd from the quay.
		for wynd: float in [-10.0, 10.0]:
			pts = PackedVector2Array()
			var z := 2.2
			while z >= -8.6:
				pts.append(Vector2(wynd + off * 0.95 + sin(z * 0.4 + wynd) * 0.12, z))
				z -= 0.45
			stains.stripe(pts, 0.22, rut, STAIN_LIFT, 3)
	# The damp, green line where the wynds' setts meet their walls, and along the backs
	# of the front row at the foot of the brae.
	var damp := Color(0.02, 0.035, 0.014, 0.42)
	for wx: float in [-12.2, -7.9, 7.8, 12.2]:
		var inward := 0.2 if wx < -10.0 or (wx > 0.0 and wx < 10.0) else -0.2
		stains.stripe(PackedVector2Array([Vector2(wx + inward, -1.3), Vector2(wx + inward, -3.4), Vector2(wx + inward, -5.5), Vector2(wx + inward, -7.6)]), 0.26, damp, STAIN_LIFT, 0)
	var back := PackedVector2Array()
	var bx := -32.0
	while bx <= 33.0:
		back.append(Vector2(bx, -7.72 + _noise.get_noise_2d(bx * 3.0, 2.0) * 0.06))
		bx += 1.1
	stains.stripe(back, 0.3, damp, STAIN_LIFT, 2)
	# Oil and diesel: the winches, the fuel berth, the fish shed's doors, where vans stand.
	var oil := Color(0.012, 0.011, 0.012, 0.38)
	for at: Array in [[-11.4, 3.9, 1.0, 0.8], [11.4, 3.9, 0.9, 0.7], [-6.2, 4.3, 1.2, 0.7], [-22.3, 0.9, 1.6, 0.9], [-20.0, 2.6, 0.7, 0.5],
			[3.0, 2.7, 0.8, 0.5], [16.0, 2.4, 0.6, 0.45], [29.6, -1.0, 1.4, 0.7], [-30.8, 5.0, 0.9, 0.5], [0.5, 21.6, 0.9, 0.6], [-9.6, -9.6, 0.7, 0.5],
			[6.5, -9.2, 0.6, 0.4], [-24.0, 3.2, 0.5, 0.4]]:
		stains.blot(Vector2(float(at[0]), float(at[1])), Vector2(float(at[2]), float(at[3])), oil, STAIN_LIFT, rng, 0.45, rng.randf() * PI)
	# Rust washed out of the bollards and rings.
	var rust := Color(0.13, 0.045, 0.015, 0.4)
	for bxz: Array in [[-29.0, 5.25], [-23.0, 5.25], [-8.0, 5.25], [-5.0, 5.25], [5.0, 5.25], [8.0, 5.25], [21.5, 5.25], [24.0, 5.25]]:
		stains.blot(Vector2(float(bxz[0]) + 0.1, float(bxz[1]) - 0.15), Vector2(0.5, 0.42), rust, STAIN_LIFT, rng, 0.4)
	for ring: Array in RINGS:
		stains.blot(Vector2(float(ring[0]), float(ring[1])), Vector2(0.42, 0.36), rust, STAIN_LIFT + 0.01, rng, 0.4)
	# Green where the slips come up onto the quay, and round the drains.
	var green := Color(0.03, 0.07, 0.02, 0.45)
	for s: float in HarbourMap.SLIPS:
		stains.blot(Vector2(s, 5.2), Vector2(2.7, 0.75), green, STAIN_LIFT, rng, 0.6)
		stains.blot(Vector2(s + 1.0, 4.4), Vector2(1.2, 0.6), green, STAIN_LIFT, rng, 0.4)
	for dr: Array in DRAINS:
		stains.blot(Vector2(float(dr[0]), float(dr[1])), Vector2(0.75, 0.6), Color(0.014, 0.018, 0.012, 0.5), STAIN_LIFT, rng, 0.45)

# Standing water in the low places, and the wet along the quay's edge and the slip heads.
static func _lay_wet(wet: Sheet) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var water := Color(0.022, 0.026, 0.03, 0.74)
	for p: Array in PUDDLES:
		var lift := WET_LIFT + (ON_FLAGS if int(p[4]) == 1 else 0.0)
		wet.blot(Vector2(float(p[0]), float(p[1])), Vector2(float(p[2]), float(p[3])) * 1.15, water, lift, rng, 0.55)
	var sheen := Color(0.03, 0.034, 0.036, 0.24)
	var half := HarbourMap.SLIP_HALF + 0.5
	var runs := [[-35.5, float(HarbourMap.SLIPS[0]) - half], [float(HarbourMap.SLIPS[0]) + half, -2.9],
		[2.9, float(HarbourMap.SLIPS[1]) - half], [float(HarbourMap.SLIPS[1]) + half, HarbourMap.STRAND_X - 0.2]]
	for r: Array in runs:
		var pts := PackedVector2Array()
		var x := float(r[0])
		while x < float(r[1]):
			pts.append(Vector2(x, 5.28 + _noise.get_noise_2d(x * 3.0, 77.0) * 0.12))
			x += 1.2
		pts.append(Vector2(float(r[1]), 5.28))
		wet.stripe(pts, 0.5, sheen, WET_LIFT, 1)
	for s: float in HarbourMap.SLIPS:
		wet.blot(Vector2(s, 4.9), Vector2(3.0, 0.95), Color(0.03, 0.036, 0.034, 0.34), WET_LIFT, rng, 0.6)
	# The pier's seaward end is never dry.
	wet.blot(Vector2(0.0, HarbourMap.PIER_END - 1.6), Vector2(4.6, 1.3), sheen, WET_LIFT, rng, 0.6)

# ---- the small things ----

## The things set in or lying on the paving, as children of `parent`: gratings and
## covers, mooring rings, rope ends, the kirk steps, the pier's parapet, and the weeds
## along the foot of the walls. A mesh per material, and one more for the weeds.
static func dress(parent: Node3D) -> void:
	_setup()
	var root := Node3D.new()
	root.name = "StreetDressing"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1798
	var b := HarbourProps.Batch.new()
	for d: Array in DRAINS:
		_drain(b, float(d[0]), float(d[1]), float(d[2]))
	for c: Array in COVERS:
		_cover(b, float(c[0]), float(c[1]))
	for r: Array in RINGS:
		_ring(b, float(r[0]), float(r[1]), rng)
	for r: Array in ROPES:
		_rope(b, Vector2(float(r[0]), float(r[1])), deg_to_rad(float(r[2])), float(r[3]), ROPE_COLS[int(r[4])], rng)
	_kirk_steps(b)
	_yard_footings(b)
	_parapet(b)
	var made := b.build(root)
	for key: String in made:
		# The stonework throws shadows; the things lying flat need not.
		if key != "stone" and key != "dressed":
			(made[key] as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weeds(root, rng)

# A cast-iron gully grating in its frame.
static func _drain(b: HarbourProps.Batch, x: float, z: float, turn: float) -> void:
	var keep := b.xf
	b.xf = Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), _at(Vector2(x, z), SETT_LIFT))
	b.box("iron", Vector3(0.52, 0.03, 0.38), Vector3(0.0, 0.006, 0.0), Color(0.2, 0.18, 0.16))
	for k in 6:
		b.box("iron", Vector3(0.036, 0.01, 0.29), Vector3(-0.19 + 0.076 * float(k), 0.022, 0.0), Color(0.012, 0.012, 0.012))
	b.xf = keep

# A round iron cover, ribbed.
static func _cover(b: HarbourProps.Batch, x: float, z: float) -> void:
	var at := _at(Vector2(x, z), SETT_LIFT)
	b.cyl("iron", 0.36, 0.36, 0.024, at + Vector3(0.0, 0.004, 0.0), Color(0.17, 0.16, 0.15), 16)
	b.cyl("iron", 0.3, 0.3, 0.01, at + Vector3(0.0, 0.018, 0.0), Color(0.24, 0.2, 0.17), 16)
	for k in 3:
		b.box("iron", Vector3(0.5, 0.008, 0.03), at + Vector3(0.0, 0.026, -0.12 + 0.12 * float(k)), Color(0.1, 0.1, 0.1))

# A mooring ring lying on its stone, held by a staple.
static func _ring(b: HarbourProps.Batch, x: float, z: float, rng: RandomNumberGenerator) -> void:
	var at := _at(Vector2(x, z), SETT_LIFT)
	var rusty := HarbourProps.IRON.lerp(Look.RUST, 0.55)
	var turn := Basis(Vector3.UP, rng.randf_range(-0.5, 0.5))
	b.box("dressed", Vector3(0.56, 0.03, 0.56), at + Vector3(0.0, 0.004, 0.0), Color(0.56, 0.54, 0.5), turn)
	b.box("iron", Vector3(0.1, 0.05, 0.05), at + Vector3(0.0, 0.04, 0.0), rusty, turn)
	b.torus("iron", 0.13, 0.022, at + turn * Vector3(0.0, 0.045, 0.13), rusty, turn * Basis(Vector3.RIGHT, 0.1), 12, 5)

# A rope's end left where it fell.
static func _rope(b: HarbourProps.Batch, from: Vector2, heading: float, length: float, col: Color, rng: RandomNumberGenerator) -> void:
	var p := from
	var a := heading
	var bend := rng.randf_range(-0.3, 0.3)
	var prev := _at(p, SETT_LIFT + 0.02)
	for k in ceili(length / 0.2):
		a += bend + rng.randf_range(-0.4, 0.4)
		p += Vector2(cos(a), sin(a)) * 0.2
		var q := _at(p, SETT_LIFT + 0.02)
		b.rod("paint", prev, q, 0.02, col.darkened(rng.randf() * 0.2), 5)
		prev = q
	# Now and then the rest of it, coiled down.
	if rng.randf() < 0.5:
		b.torus("paint", 0.22, 0.03, _at(from, SETT_LIFT + 0.03) + Vector3(0.24, 0.0, 0.0), col, Basis.IDENTITY, 10, 4)
		b.torus("paint", 0.14, 0.03, _at(from, SETT_LIFT + 0.05) + Vector3(0.24, 0.0, 0.0), col.darkened(0.12), Basis.IDENTITY, 8, 4)

# Stone steps up the brae to the kirk gate and on to the door: each tread level, as
# high as the brae rises behind it (no more than a kerb), worn and paler at the gate.
static func _kirk_steps(b: HarbourProps.Batch) -> void:
	var gate := HarbourMap.KIRK_GATE
	var half := HarbourMap.GATE_HALF - 0.05
	var z := -20.34
	var k := 0
	while z > -23.8:
		var far := z - STEP_RUN
		var low := Terrain.height_at(gate.x, z)
		var top := Terrain.height_at(gate.x, far) + 0.015
		if top - low > 0.03:
			var at_gate := absf((z + far) * 0.5 - gate.y) < STEP_RUN * 0.6
			var g := (0.62 if at_gate else 0.52) + 0.05 * float(k % 3)
			var wide := half * 2.0 + (0.5 if at_gate else 0.0)
			b.box("dressed", Vector3(wide, top - low + 0.08, STEP_RUN + 0.02), Vector3(gate.x, (top + low - 0.08) * 0.5, (z + far) * 0.5), Color(g, g * 0.98, g * 0.93))
		z = far
		k += 1

# The kirkyard's wall was built level across the brae: fill in under it, down to the
# earth, where the ground falls away from its foot.
static func _yard_footings(b: HarbourProps.Batch) -> void:
	var yard := HarbourMap.KIRKYARD
	var gate := HarbourMap.KIRK_GATE
	var grey := Color(0.52, 0.5, 0.47)
	var foot := Terrain.height_at(gate.x, gate.y)
	var low := Terrain.height_at(gate.x, gate.y + 0.3) - 0.12
	for side: float in [-1.0, 1.0]:
		var half := yard.size.x * 0.5 - HarbourMap.GATE_HALF
		b.box("stone", Vector3(half, foot - low + 0.02, 0.56), Vector3(gate.x + side * (HarbourMap.GATE_HALF + half * 0.5), (foot + low) * 0.5, gate.y), grey)
		# The side walls stand at the green's level; the brae drops away under their ends.
		var x := gate.x + side * yard.size.x * 0.5
		var top := Terrain.height_at(x, yard.get_center().y) + 0.02
		var z := yard.end.y
		while z > HarbourMap.RISE_2.y - 0.6:
			var under := Terrain.height_at(x, z) - 0.15
			if top - under > 0.03:
				b.box("stone", Vector3(0.54, top - under, 0.46), Vector3(x, (top + under) * 0.5, z - 0.225), grey)
			z -= 0.45

# The pier head's parapet: a rubble wall along its weather (west) side and round the
# corner of its end, standing on the coping, outside where anyone can walk.
static func _parapet(b: HarbourProps.Batch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var x := -(HarbourMap.PIER_HEAD_HALF + 0.35)
	var from := HarbourMap.PIER_HEAD_FROM - 0.55
	var to := HarbourMap.PIER_END + 0.57
	var foot := HarbourMap.QUAY_H + 0.14
	var keep := b.xf
	b.xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, foot, (from + to) * 0.5))
	HarbourProps.wall_into(b, to - from, PARAPET_H, 0.44, rng)
	b.xf = Transform3D(Basis.IDENTITY, Vector3(x + 1.9, foot, to - 0.22))
	HarbourProps.wall_into(b, 3.8, PARAPET_H * 0.6, 0.44, rng)
	b.xf = keep

# Weeds: along the foot of the walls behind the front (thickest on the north sides),
# in the hollows where the setts have gone, at the town's ragged ends, and up the kirk
# brae, thinning out from the green. The green's own tufts and shader.
static func _weeds(root: Node3D, rng: RandomNumberGenerator) -> void:
	var xforms: Array[Transform3D] = []
	for i in _rects.size():
		var r := _rects[i]
		# The houses up on the green stand in grass already.
		if r.position.y < -24.0:
			continue
		var back_row := r.position.y < -10.0
		# Each side: from, to, the way out from the wall, how thick the weeds.
		var sides := [
			[r.position, Vector2(r.end.x, r.position.y), Vector2(0.0, -1.0), 0.7],
			[r.position, Vector2(r.position.x, r.end.y), Vector2(-1.0, 0.0), 0.4 if back_row else 0.25],
			[Vector2(r.end.x, r.position.y), r.end, Vector2(1.0, 0.0), 0.4 if back_row else 0.25],
			[Vector2(r.position.x, r.end.y), r.end, Vector2(0.0, 1.0), 0.1 if back_row else 0.0],
		]
		for s: Array in sides:
			var a: Vector2 = s[0]
			var c: Vector2 = s[1]
			var out: Vector2 = s[2]
			var n := int(a.distance_to(c) / 0.3)
			for k in n:
				if rng.randf() > float(s[3]):
					continue
				var p := a.lerp(c, (float(k) + rng.randf()) / float(n)) + out * rng.randf_range(0.1, 0.3)
				if _wall_dist(p.x, p.y) < 0.08:
					continue
				_tuft(xforms, p, rng.randf_range(0.3, 0.55), rng)
	# Loose over the town: wherever the setts have gone and it is not rock or shingle.
	for i in 5200:
		var p := Vector2(rng.randf_range(-38.0, 38.4), rng.randf_range(-21.6, 5.4))
		var bare := 0.62 - sett_cover(p.x, p.y)
		if bare <= 0.0 or rng.randf() > bare * 1.6 or _wall_dist(p.x, p.y) < 0.1:
			continue
		if Terrain.slope_at(p.x, p.y) > 0.25 or HarbourMap.shore_weight(p.x, p.y) > 0.2 or Terrain.height_at(p.x, p.y) > HarbourMap.BACK_H + 0.4:
			continue
		_tuft(xforms, p, rng.randf_range(0.35, 0.7), rng)
	# The kirk brae: the green's grass straggling down to the back lane.
	var yard := HarbourMap.KIRKYARD
	for i in 2600:
		var depth := rng.randf()
		var p := Vector2(rng.randf_range(HarbourMap.WEST, HarbourMap.EAST - 1.0), -24.5 + 3.9 * depth)
		if rng.randf() < depth * depth * 1.15:
			continue
		if absf(p.x - HarbourMap.KIRK_GATE.x) < HarbourMap.GATE_HALF + 0.3:
			continue
		if absf(p.y - yard.end.y) < 0.35 and absf(p.x - yard.get_center().x) < yard.size.x * 0.5 + 0.35:
			continue
		_tuft(xforms, p, lerpf(1.1, 0.6, depth) * rng.randf_range(0.8, 1.2), rng)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Look.grass_tuft_mesh()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Weeds"
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)

static func _tuft(xforms: Array[Transform3D], p: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var turn := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
	xforms.append(Transform3D(turn, Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)))
