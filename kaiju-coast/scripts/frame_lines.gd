class_name FrameLines
extends RefCounted
## Thick lines rebuilt every frame (effects, carp streamers, range rings). Writes into arrays that
## only ever grow, then uploads the used part to an ArrayMesh in one call, which is much cheaper
## than feeding an ImmediateMesh vertex by vertex.
##
## Each segment is four vertices (both sides of each end) and six indices from a shared pattern,
## in the same vertex layout as LineBuilder's six-vertex strips (see thick_line.gdshaderinc).

var mesh: ArrayMesh = ArrayMesh.new()
var _v: PackedVector3Array = PackedVector3Array()
var _c: PackedColorArray = PackedColorArray()
var _uv: PackedVector2Array = PackedVector2Array()
var _uv2: PackedVector2Array = PackedVector2Array()
var _idx: PackedInt32Array = PackedInt32Array()
var _n: int = 0


func clear() -> void:
	_n = 0


func count() -> int:
	return _n / 4


func _grow() -> void:
	var cap: int = maxi(4000, _v.size() * 2)
	var old: int = _v.size()
	_v.resize(cap)
	_c.resize(cap)
	_uv.resize(cap)
	_uv2.resize(cap)
	# a-left, a-right, b-right, b-left: two triangles per segment.
	_idx.resize(cap / 4 * 6)
	for s: int in range(old / 4, cap / 4):
		var b: int = s * 4
		var j: int = s * 6
		_idx[j] = b
		_idx[j + 1] = b + 1
		_idx[j + 2] = b + 2
		_idx[j + 3] = b
		_idx[j + 4] = b + 2
		_idx[j + 5] = b + 3


func seg(a: Vector3, b: Vector3, c: Color) -> void:
	if _n + 4 > _v.size():
		_grow()
	var i: int = _n
	_v[i] = a
	_v[i + 1] = a
	_v[i + 2] = b
	_v[i + 3] = b
	_c[i] = c
	_c[i + 1] = c
	_c[i + 2] = c
	_c[i + 3] = c
	var ua: Vector2 = Vector2(b.x, b.y)
	var ub: Vector2 = Vector2(a.x, a.y)
	_uv[i] = ua
	_uv[i + 1] = ua
	_uv[i + 2] = ub
	_uv[i + 3] = ub
	_uv2[i] = Vector2(b.z, 1.0)
	_uv2[i + 1] = Vector2(b.z, -1.0)
	_uv2[i + 2] = Vector2(a.z, 1.0)
	_uv2[i + 3] = Vector2(a.z, -1.0)
	_n += 4


func commit() -> void:
	mesh.clear_surfaces()
	if _n == 0:
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v.slice(0, _n)
	arrays[Mesh.ARRAY_COLOR] = _c.slice(0, _n)
	arrays[Mesh.ARRAY_TEX_UV] = _uv.slice(0, _n)
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2.slice(0, _n)
	arrays[Mesh.ARRAY_INDEX] = _idx.slice(0, _n / 4 * 6)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
