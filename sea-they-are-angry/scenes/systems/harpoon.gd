class_name Harpoon
extends Node3D
## The boathook thrown like a harpoon at a Smotherer on the tower. It flies at the
## creature (homing a little, since it keeps climbing), knocks it off the stone, then
## drops to the tower's foot and lies there until its keeper walks over it to take it
## back. With the hook out the keeper has nothing to swing. At dawn it comes back anyway.

const SPEED := 20.0
const GRAVITY := 14.0
const PICK_UP_RANGE := 1.0
# Where it comes to rest: just out from the tower's foot.
const REST_OUT := 1.3

var keeper: Player
var target: Node3D
## On a LAN client: only for the look of it. It strikes nothing, and goes when the host
## says its keeper has the boathook back.
var puppet := false
var _vel := Vector3.ZERO
var _flying := true
var _falling := false
var _rest := Vector3.ZERO
var _glint: Node3D
var _t := 0.0

func _ready() -> void:
	add_to_group("harpoons")
	var art := Player.load_art(Player.HOOK_PATH)
	var model := Node3D.new()
	add_child(model)
	if art != null:
		art.rotation.y = PI
		art.scale = Vector3.ONE * 1.25
		model.add_child(art)
	else:
		Geo.box(model, Vector3(0.06, 0.06, 1.6), Color(0.18, 0.15, 0.12), Vector3(0.0, 0.0, -0.3))
	Cycle.phase_changed.connect(_on_phase)
	var aim := (_aim_point() - global_position)
	_vel = aim.normalized() * SPEED
	look_at(global_position + _vel, Vector3.UP)

func _aim_point() -> Vector3:
	if target != null and is_instance_valid(target):
		return target.global_position + Vector3(0.0, 1.0, 0.0)
	return global_position + Vector3(0.0, 4.0, 0.0)

func _physics_process(delta: float) -> void:
	_t += delta
	if _flying:
		# Homes on the climber: the throw is aimed where it is, and it keeps moving.
		var want := (_aim_point() - global_position)
		_vel = _vel.lerp(want.normalized() * SPEED, minf(1.0, delta * 6.0))
		global_position += _vel * delta
		look_at(global_position + _vel, Vector3.UP)
		if want.length() < 0.7 or _t > 1.5:
			_strike()
		return
	if _falling:
		_vel.y -= GRAVITY * delta
		global_position += _vel * delta
		rotate_object_local(Vector3.RIGHT, delta * 9.0)
		if global_position.y <= _rest.y + 0.08:
			_land()
		return
	# Lying at the tower's foot: its keeper takes it back by walking over it.
	if _glint:
		_glint.visible = int(_t * 2.0) % 2 == 0
	if puppet:
		if keeper == null or not is_instance_valid(keeper) or keeper.has_hook:
			queue_free()
		return
	if keeper != null and is_instance_valid(keeper) and not keeper.downed:
		if Geo.flat_dist(keeper.global_position, global_position) < PICK_UP_RANGE and absf(keeper.global_position.y - global_position.y) < 1.5:
			_give_back()

func _strike() -> void:
	_flying = false
	_falling = true
	if not puppet and target != null and is_instance_valid(target) and target.has_method("harpooned"):
		target.harpooned(keeper)
	Audio.sfx("hit", global_position, 0.0, 0.1)
	# Rebounds off the stone and drops to the tower's foot, below where it struck.
	_rest = _rest_point(global_position)
	var flat := _rest - global_position
	flat.y = 0.0
	_vel = flat.normalized() * minf(flat.length(), 3.0) + Vector3(0.0, 2.5, 0.0)

# A spot on walkable ground just out from the tower's foot, below where it struck: the
# keeper has to go round for it.
func _rest_point(hit_at: Vector3) -> Vector3:
	var lh := keeper.lamp.lighthouse if keeper != null and keeper.lamp != null else null
	var c: Vector3 = lh.global_position if lh != null else global_position
	var side := hit_at - c
	side.y = 0.0
	side = side.normalized() if side.length() > 0.05 else Vector3.BACK
	for r in [Lighthouse.RADIUS + REST_OUT, Lighthouse.RADIUS + 0.8, Lighthouse.RADIUS + 2.0]:
		for turn in [0.0, 0.4, -0.4, 0.8, -0.8]:
			var p: Vector3 = c + side.rotated(Vector3.UP, turn) * r
			if Terrain.walkable(p.x, p.z):
				return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
	var k := keeper.global_position if keeper != null else global_position
	return Vector3(k.x, Terrain.height_at(k.x, k.z), k.z)

func _land() -> void:
	_falling = false
	global_position = _rest + Vector3(0.0, 0.06, 0.0)
	# Lying flat on the ground, pointing out from the tower.
	rotation = Vector3(0.0, rotation.y, 0.0)
	Audio.sfx("hammer", global_position, -10.0, 0.2)
	FX.splinters(get_parent(), global_position)
	_glint = Node3D.new()
	add_child(_glint)
	Look.glint(_glint, Vector3(0.0, 0.25, 0.0), Color(1.0, 0.85, 0.5), 0.35)

func is_lying() -> bool:
	return not _flying and not _falling

func _give_back() -> void:
	if not puppet and keeper != null and is_instance_valid(keeper):
		keeper.take_back_hook()
	queue_free()

func _on_phase(p: int) -> void:
	if p == Cycle.Phase.DAWN:
		_give_back()
