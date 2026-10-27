class_name SolidBuilder
extends RefCounted
## Builds "vector solids": a dark filled body (triangles, drawn with dark_fill) plus its glowing
## neon edges (lines, drawn with neon_line). The fill is pulled in slightly so the edge lines sit
## just proud of the surface and never z-fight with it. Solids hide what's behind them, which is
## what makes the kaiju, guns and buildings read as solid objects rather than wireframes.

const SHRINK: float = 0.965

var lines: LineBuilder = LineBuilder.new()
## Glowing filled shapes (eyes, lanterns, windows): drawn with neon_line, not dark_fill.
var glow: SurfaceTool = SurfaceTool.new()
var _fill: SurfaceTool = SurfaceTool.new()
var _fill_n: int = 0
var _glow_n: int = 0
var xf: Transform3D = Transform3D.IDENTITY:
	set(v):
		xf = v
		lines.xf = v
var _stack: Array[Transform3D] = []


func _init() -> void:
	_fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)


func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func pop() -> void:
	xf = _stack.pop_back()


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	_fill.set_color(col)
	_fill.add_vertex(xf * a)
	_fill.set_color(col)
	_fill.add_vertex(xf * b)
	_fill.set_color(col)
	_fill.add_vertex(xf * c)
	_fill_n += 1


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)


func glow_tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p: Vector3 in [a, b, c]:
		glow.set_color(col)
		glow.add_vertex(xf * p)
	_glow_n += 1


## A flat glowing quad centred on c spanning +-u, +-v. Alpha carries a seed for windows.gdshader.
func glow_quad(c: Vector3, u: Vector3, v: Vector3, col: Color) -> void:
	glow_tri(c - u - v, c + u - v, c + u + v, col)
	glow_tri(c - u - v, c + u + v, c - u + v, col)


func edge(a: Vector3, b: Vector3, col: Color) -> void:
	lines.line(a, b, col)


## Axis-aligned box from its centre and size, with all 12 edges.
func box(center: Vector3, size: Vector3, col: Color, edges: bool = true) -> void:
	var h: Vector3 = size * 0.5
	var f: Vector3 = h * SHRINK
	var p: Array[Vector3] = []
	for i: int in range(8):
		p.append(center + Vector3(f.x if (i & 1) else -f.x, f.y if (i & 2) else -f.y, f.z if (i & 4) else -f.z))
	for q: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		quad(p[q[0]], p[q[1]], p[q[2]], p[q[3]], col)
	if edges:
		lines.box(center, size, col)


## Tapered tube between two points, with end caps. `rings` adds that many intermediate edge rings.
func tube(a: Vector3, b: Vector3, r0: float, r1: float, n: int, col: Color, rings: int = 0, spokes: int = -1) -> void:
	var axis: Vector3 = b - a
	if axis.length_squared() < 1e-6:
		return
	var dir: Vector3 = axis.normalized()
	var side: Vector3 = dir.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up: Vector3 = side.cross(dir).normalized()
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for i: int in range(n):
		var t: float = TAU * float(i) / float(n)
		var o: Vector3 = side * cos(t) + up * sin(t)
		ring0.append(a + o * r0)
		ring1.append(b + o * r1)
	for i: int in range(n):
		var j: int = (i + 1) % n
		quad(a + (ring0[i] - a) * SHRINK, a + (ring0[j] - a) * SHRINK, b + (ring1[j] - b) * SHRINK, b + (ring1[i] - b) * SHRINK, col)
		tri(a, a + (ring0[j] - a) * SHRINK, a + (ring0[i] - a) * SHRINK, col)
		tri(b, b + (ring1[i] - b) * SHRINK, b + (ring1[j] - b) * SHRINK, col)
		lines.line(ring0[i], ring0[j], col)
		lines.line(ring1[i], ring1[j], col)
	var step: int = 1 if spokes < 0 else maxi(1, n / maxi(1, spokes))
	for i: int in range(0, n, step):
		lines.line(ring0[i], ring1[i], col)
	for k: int in range(1, rings + 1):
		var f: float = float(k) / float(rings + 1)
		for i: int in range(n):
			var j: int = (i + 1) % n
			lines.line(ring0[i].lerp(ring1[i], f), ring0[j].lerp(ring1[j], f), col)


## Ellipsoid centred on c. Edge lines: `elat` latitude rings and `elon` meridians.
func ellipsoid(c: Vector3, r: Vector3, nlat: int, nlon: int, col: Color, elat: int = 3, elon: int = 8) -> void:
	var pts: Array = []
	for i: int in range(nlat + 1):
		var th: float = PI * float(i) / float(nlat)
		var row: Array[Vector3] = []
		for j: int in range(nlon):
			var ph: float = TAU * float(j) / float(nlon)
			row.append(Vector3(sin(th) * cos(ph), -cos(th), sin(th) * sin(ph)))
		pts.append(row)
	for i: int in range(nlat):
		for j: int in range(nlon):
			var j2: int = (j + 1) % nlon
			var a: Vector3 = c + pts[i][j] * r * SHRINK
			var b: Vector3 = c + pts[i][j2] * r * SHRINK
			var d: Vector3 = c + pts[i + 1][j2] * r * SHRINK
			var e: Vector3 = c + pts[i + 1][j] * r * SHRINK
			quad(a, b, d, e, col)
	for k: int in range(1, elat + 1):
		var th2: float = PI * float(k) / float(elat + 1)
		var prev: Vector3 = Vector3.ZERO
		for j: int in range(nlon + 1):
			var ph2: float = TAU * float(j) / float(nlon)
			var p: Vector3 = c + Vector3(sin(th2) * cos(ph2), -cos(th2), sin(th2) * sin(ph2)) * r
			if j > 0:
				lines.line(prev, p, col)
			prev = p
	for m: int in range(elon):
		var ph3: float = TAU * float(m) / float(elon)
		var prev2: Vector3 = c + Vector3(0, -r.y, 0)
		for i: int in range(1, nlat + 1):
			var th3: float = PI * float(i) / float(nlat)
			var p2: Vector3 = c + Vector3(sin(th3) * cos(ph3), -cos(th3), sin(th3) * sin(ph3)) * r
			lines.line(prev2, p2, col)
			prev2 = p2


## A glowing (unshaded, bright) ellipsoid: eyes, lanterns, cores.
func glow_ball(c: Vector3, r: Vector3, col: Color, n: int = 6) -> void:
	for i: int in range(n):
		var th0: float = PI * float(i) / float(n)
		var th1: float = PI * float(i + 1) / float(n)
		for j: int in range(n * 2):
			var p0: float = TAU * float(j) / float(n * 2)
			var p1: float = TAU * float(j + 1) / float(n * 2)
			var a: Vector3 = c + Vector3(sin(th0) * cos(p0), -cos(th0), sin(th0) * sin(p0)) * r
			var b: Vector3 = c + Vector3(sin(th0) * cos(p1), -cos(th0), sin(th0) * sin(p1)) * r
			var d: Vector3 = c + Vector3(sin(th1) * cos(p1), -cos(th1), sin(th1) * sin(p1)) * r
			var e: Vector3 = c + Vector3(sin(th1) * cos(p0), -cos(th1), sin(th1) * sin(p0)) * r
			glow_tri(a, b, d, col)
			glow_tri(a, d, e, col)


## Cone from a base circle (centre c, radius r, axis dir) to its tip.
func cone(c: Vector3, tip: Vector3, r: float, n: int, col: Color) -> void:
	tube(c, tip, r, 0.001, n, col)


## A flat plate (both faces filled) through a closed outline, with the outline as edges.
func plate(outline: PackedVector3Array, col: Color) -> void:
	var cen: Vector3 = Vector3.ZERO
	for p: Vector3 in outline:
		cen += p
	cen /= float(outline.size())
	for i: int in range(outline.size()):
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % outline.size()]
		tri(cen, cen + (a - cen) * SHRINK, cen + (b - cen) * SHRINK, col)
	lines.polyline(outline, col, true)


func fill_mesh() -> ArrayMesh:
	if _fill_n == 0:
		return null
	_fill.generate_normals()
	return _fill.commit()


func glow_mesh() -> ArrayMesh:
	if _glow_n == 0:
		return null
	return glow.commit()


func line_mesh() -> ArrayMesh:
	return lines.build_mesh()


## Adds the fill, edge and glow meshes under `parent` with the given materials. Returns the parent.
func attach(parent: Node3D, fill_mat: Material, line_mat: Material, glow_mat: Material = null) -> Node3D:
	var f: ArrayMesh = fill_mesh()
	if f != null:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = f
		mi.material_override = fill_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	var l: ArrayMesh = line_mesh()
	if l != null:
		var ml: MeshInstance3D = MeshInstance3D.new()
		ml.mesh = l
		ml.material_override = line_mat
		ml.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ml)
	var g: ArrayMesh = glow_mesh()
	if g != null:
		var mg: MeshInstance3D = MeshInstance3D.new()
		mg.mesh = g
		mg.material_override = glow_mat if glow_mat != null else Mats.glow()
		mg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mg)
	return parent
