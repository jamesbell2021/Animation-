class_name FrameLines
extends RefCounted
## Thick lines rebuilt every frame (effects, carp streamers, range rings). Writes into arrays that
## only ever grow, then uploads the used part to an ArrayMesh in one call, which is much cheaper
## than feeding an ImmediateMesh vertex by vertex.

var mesh: ArrayMesh = ArrayMesh.new()
var _v: PackedVector3Array = PackedVector3Array()
var _c: PackedColorArray = PackedColorArray()
var _uv: PackedVector2Array = PackedVector2Array()
var _uv2: PackedVector2Array = PackedVector2Array()
var _n: int = 0


func clear() -> void:
	_n = 0


func count() -> int:
	return _n / 6


func seg(a: Vector3, b: Vector3, c: Color) -> void:
	if _n + 6 > _v.size():
		var cap: int = maxi(6000, _v.size() * 2)
		_v.resize(cap)
		_c.resize(cap)
		_uv.resize(cap)
		_uv2.resize(cap)
	var i: int = _n
	var ua: Vector2 = Vector2(b.x, b.y)
	var ub: Vector2 = Vector2(a.x, a.y)
	_v[i] = a
	_v[i + 1] = b
	_v[i + 2] = b
	_v[i + 3] = a
	_v[i + 4] = b
	_v[i + 5] = a
	_c[i] = c
	_c[i + 1] = c
	_c[i + 2] = c
	_c[i + 3] = c
	_c[i + 4] = c
	_c[i + 5] = c
	_uv[i] = ua
	_uv[i + 1] = ub
	_uv[i + 2] = ub
	_uv[i + 3] = ua
	_uv[i + 4] = ub
	_uv[i + 5] = ua
	_uv2[i] = Vector2(b.z, 1.0)
	_uv2[i + 1] = Vector2(a.z, -1.0)
	_uv2[i + 2] = Vector2(a.z, 1.0)
	_uv2[i + 3] = Vector2(b.z, 1.0)
	_uv2[i + 4] = Vector2(a.z, 1.0)
	_uv2[i + 5] = Vector2(b.z, -1.0)
	_n += 6


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
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
