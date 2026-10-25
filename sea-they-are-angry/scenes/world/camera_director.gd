class_name CameraDirector
extends Node
## The game's camera. Each island has its own framing, the whole island seen from the
## south (Bad North style): the main island's as it always was, and the holm's. A keeper
## is framed by the island they're on, the view panning from one to the other as they
## cross the bridge.
##
## When the people playing (not the computer's helpers) are on one island, the screen is
## one view. When they're apart it splits, Baldur's Gate style: a line through the
## middle of the screen, square to the way from one to the other, each side showing its
## own keepers' island. It eases apart as they separate and closes up again as they come
## back together. Up to three ways (three people on three spots).
##
## The first view is the main camera (P1's: the mouse aims through it); the others are
## drawn into SubViewports sharing the world and laid over it by the split shader. While
## the screen is whole nothing extra is drawn.

## The main island's framing (main.gd's camera position less its target) and focus.
const OFFSET := Vector3(0.0, 38.0, 26.0)
const MAIN_FOCUS := Vector3(0.0, 3.0, 1.0)
const HOLM_FOCUS := Vector3(Terrain.HOLM_C.x + 0.5, Terrain.HOLM_HEIGHT, Terrain.HOLM_C.y + 1.0)
## Views this far apart (m) split the screen; closer than JOIN_BELOW they join again.
const SPLIT_FROM := 9.0
const JOIN_BELOW := 4.0
## How long the split takes to open or close (s).
const SPLIT_TIME := 0.7
## How quickly a view follows its keepers from one island to the other.
const FOLLOW := 2.2
## Split, each view pulls back a little to show more of its island in half the screen.
const SPLIT_PULL := 1.15
const MAX_VIEWS := 3
const LINE_PX := 2.5

var main_camera: Camera3D
## The keepers to frame. Those with `ai` set are the computer's and don't get a view.
var players: Array = []

var _foci := {}
var _together := {}
var _groups: Array = []      # Array of Arrays of players; the first holds P1
var _split := 0.0
var _subs: Array[SubViewport] = []
var _sub_cams: Array[Camera3D] = []
var _layer: CanvasLayer
var _overlay: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	name = "CameraDirector"
	_layer = CanvasLayer.new()
	_layer.layer = -1
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/split_screen.gdshader")
	_overlay.material = _mat
	_overlay.visible = false
	_layer.add_child(_overlay)
	var root := get_viewport()
	for i in MAX_VIEWS - 1:
		var sv := SubViewport.new()
		sv.name = "View%d" % (i + 2)
		sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		sv.msaa_3d = root.msaa_3d
		sv.screen_space_aa = root.screen_space_aa
		sv.use_taa = root.use_taa
		sv.use_debanding = root.use_debanding
		sv.scaling_3d_mode = root.scaling_3d_mode
		sv.scaling_3d_scale = root.scaling_3d_scale
		sv.positional_shadow_atlas_size = root.positional_shadow_atlas_size
		sv.audio_listener_enable_3d = false
		add_child(sv)
		var cam := Camera3D.new()
		sv.add_child(cam)
		cam.current = true
		_subs.append(sv)
		_sub_cams.append(cam)
	_mat.set_shader_parameter("view1", _subs[0].get_texture())
	_mat.set_shader_parameter("view2", _subs[1].get_texture())

## Where a keeper standing at p should be framed from: their island, or between the two
## on the bridge.
static func focus_for(p: Vector3) -> Vector3:
	var t := 0.0
	if Terrain.on_bridge(p.x, p.z):
		t = clampf(Terrain.bridge_coords(p.x, p.z).x, 0.0, 1.0)
	elif Terrain.on_holm(p.x, p.z):
		t = 1.0
	return MAIN_FOCUS.lerp(HOLM_FOCUS, smoothstep(0.0, 1.0, t))

func _people() -> Array:
	var out := []
	for p in players:
		if is_instance_valid(p) and not bool(p.get("ai")):
			out.append(p)
	if out.is_empty():
		for p in players:
			if is_instance_valid(p):
				out.append(p)
	return out

## How many views the screen shows (1 when whole).
func view_count() -> int:
	return _groups.size() if _split > 0.0 else 1

## How far open the split is (0 whole, 1 split).
func split_amount() -> float:
	return _split

func _process(delta: float) -> void:
	if main_camera == null:
		return
	var people := _people()
	if people.is_empty():
		return
	for p in people:
		var want := focus_for(p.global_position)
		if not _foci.has(p):
			_foci[p] = want
		else:
			_foci[p] = (_foci[p] as Vector3).lerp(want, 1.0 - exp(-delta * FOLLOW))
	for k in _foci.keys():
		if not is_instance_valid(k) or not people.has(k):
			_foci.erase(k)
	var groups := _group(people)
	var want_split := 1.0 if groups.size() > 1 else 0.0
	if groups.size() > 1:
		_groups = groups
	_split = move_toward(_split, want_split, delta / SPLIT_TIME)
	if _split <= 0.0:
		_groups = [people]
	_place(delta)

# Keepers whose views are close share one; apart, they each get their own. Pairs that
# were together stay together until further apart than they had to be to join.
func _group(people: Array) -> Array:
	var parent := {}
	for p in people:
		parent[p] = p
	var find := func(x):
		while parent[x] != x:
			x = parent[x]
		return x
	for i in people.size():
		for j in range(i + 1, people.size()):
			var a = people[i]
			var b = people[j]
			var key := _pair_key(a, b)
			var d := (_foci[a] as Vector3).distance_to(_foci[b])
			var was := bool(_together.get(key, true))
			var now := d < SPLIT_FROM if was else d < JOIN_BELOW
			_together[key] = now
			if now:
				parent[find.call(a)] = find.call(b)
	var by_root := {}
	var order := []
	for p in people:
		var r = find.call(p)
		if not by_root.has(r):
			by_root[r] = []
			order.append(r)
		by_root[r].append(p)
	var groups := []
	for r in order:
		groups.append(by_root[r])
	# P1's group first: theirs is the main camera.
	groups.sort_custom(func(x, y): return _min_idx(x) < _min_idx(y))
	if groups.size() > MAX_VIEWS:
		groups.resize(MAX_VIEWS)
	return groups

func _pair_key(a, b) -> String:
	var ia := int(a.get("idx"))
	var ib := int(b.get("idx"))
	return "%d-%d" % [mini(ia, ib), maxi(ia, ib)]

func _min_idx(g: Array) -> int:
	var m := 99
	for p in g:
		m = mini(m, int(p.get("idx")))
	return m

func _group_focus(g: Array) -> Vector3:
	var s := Vector3.ZERO
	var n := 0
	for p in g:
		if _foci.has(p):
			s += _foci[p]
			n += 1
	return s / float(maxi(n, 1))

func _place(_delta: float) -> void:
	var n := _groups.size()
	var foci: Array[Vector3] = []
	var mean := Vector3.ZERO
	for g in _groups:
		var f := _group_focus(g)
		foci.append(f)
		mean += f
	mean /= float(maxi(n, 1))
	var size := get_viewport().get_visible_rect().size
	if n <= 1 or _split <= 0.0:
		_pose(main_camera, foci[0] if n == 1 else mean, Vector2.ZERO, 1.0)
		_overlay.visible = false
		for sv in _subs:
			sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# Each view's side of the screen: the way from the middle of them all to its keepers.
	var dirs: Array[Vector2] = []
	for i in n:
		var d := Vector2(foci[i].x - mean.x, foci[i].z - mean.z)
		dirs.append(d.normalized() if d.length() > 0.01 else Vector2.from_angle(TAU * float(i) / float(n)))
	for i in _subs.size():
		var on := i + 1 < n
		if on and _subs[i].size != Vector2i(size):
			_subs[i].size = Vector2i(size)
		_subs[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	var k := _smooth(_split)
	var pull := lerpf(1.0, SPLIT_PULL, k)
	var anchors: Array[Vector2] = []
	for i in n:
		var a := size * 0.5 + Vector2(dirs[i].x * size.x, dirs[i].y * size.y) * 0.25
		anchors.append(a)
		var off := Vector2(dirs[i].x * size.x, dirs[i].y * size.y) * 0.25 * k
		var f := mean.lerp(foci[i], k)
		var cam := main_camera if i == 0 else _sub_cams[i - 1]
		if i > 0:
			cam.fov = main_camera.fov
			cam.near = main_camera.near
			cam.far = main_camera.far
		_pose(cam, f, off, pull)
	_overlay.visible = true
	_mat.set_shader_parameter("count", n)
	_mat.set_shader_parameter("size", size)
	_mat.set_shader_parameter("anchor0", anchors[0])
	_mat.set_shader_parameter("anchor1", anchors[1])
	_mat.set_shader_parameter("anchor2", anchors[2] if n > 2 else Vector2(-1e6, -1e6))
	_mat.set_shader_parameter("line_px", LINE_PX)
	_mat.set_shader_parameter("line_alpha", k)

# Put a camera on its framing of `focus`, then slide it so the focus sits `off` pixels
# from the middle of the screen (the middle of its side of a split).
func _pose(cam: Camera3D, focus: Vector3, off: Vector2, pull: float) -> void:
	cam.global_position = focus + OFFSET * pull
	cam.look_at(focus, Vector3.UP)
	if off == Vector2.ZERO:
		return
	var size := get_viewport().get_visible_rect().size
	var sp := size * 0.5 + off
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	if absf(dir.y) < 0.001:
		return
	var t := (focus.y - from.y) / dir.y
	var seen := from + dir * t
	cam.global_position += focus - seen

static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
