class_name Villager
extends Node3D
## One of Kirkhaven's seven, on their feet in the world: by day about their own door, at
## night shut in somewhere safe, and, when they have to cross open ground in the dark,
## prey. Anything from the sea that gets within reach of one out of doors takes them.
## Used in the town (walking the streets by HarbourMap's paths) and on the rock (in the
## camp, where they keep to the huts).

signal taken(v: Villager)
signal arrived(v: Villager)

const WALK := 2.5
const RUN := 3.0
## How near a creature has to come, and for how long, to take someone.
const TAKE_RANGE := 1.35
const TAKE_TIME := 0.45
const ARRIVE := 0.5

var id := ""
## "about" (standing by their door), "walking", "inside" (hidden, safe), "aboard", "lost".
var state := "about"
var rig: CharacterRig
var _way: Array[Vector3] = []
var _speed := WALK
var _then := ""
var _near_t := 0.0
var _label: Label3D
var _yaw := 0.0
## Standing with the keepers on the last night: in the open, but nothing's prey.
var fighting := false

func _init(p_id: String = "") -> void:
	id = p_id

func _ready() -> void:
	add_to_group("villagers")
	var w := Villagers.who(id)
	rig = CharacterRig.create(Players.MODELS[int(w.get("model", 0)) % Players.MODELS.size()])
	if rig != null:
		add_child(rig)
	_label = Label3D.new()
	_label.text = String(w.get("name", id))
	_label.font_size = 30
	_label.pixel_size = 0.008
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = Color(0.95, 0.9, 0.75, 0.9)
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	_label.position = Vector3(0.0, 2.3, 0.0)
	var f := Fonts.title()
	if f != null:
		_label.font = f
	add_child(_label)

func display_name() -> String:
	return Villagers.name_of(id)

## Out of doors where something could reach them.
func exposed() -> bool:
	return visible and (state == "about" or state == "walking")

## Go somewhere on foot; `then` is the state on getting there ("about", "inside", "aboard").
func walk_to(target: Vector3, then: String = "about", hurry: bool = false) -> void:
	if state == "lost" or state == "aboard":
		return
	visible = true
	state = "walking"
	_then = then
	_speed = RUN if hurry else WALK
	if Terrain.chapter == 2:
		_way = HarbourMap.path(global_position, target, false)
	else:
		_way = []
	_way.append(target)

## Put them somewhere at once.
func place(at: Vector3, p_state: String = "about") -> void:
	global_position = Vector3(at.x, Terrain.height_at(at.x, at.z), at.z)
	_way = []
	state = p_state
	visible = p_state == "about" or p_state == "walking"
	_set_prey(false)

## Shut in, out of sight.
func go_inside() -> void:
	if state == "lost":
		return
	state = "inside"
	visible = false
	_way = []
	_set_prey(false)

## Something from the sea has them.
func take() -> void:
	if state == "lost" or state == "aboard":
		return
	state = "lost"
	_way = []
	_set_prey(false)
	Villagers.lose(id)
	if is_inside_tree():
		Audio.sfx("scream", global_position + Vector3(0.0, 1.2, 0.0), 2.0, 0.1)
		if visible:
			FX.splash(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), 0.5)
	visible = false
	taken.emit(self)

func _set_prey(on: bool) -> void:
	if on and not is_in_group("prey"):
		add_to_group("prey")
	elif not on and is_in_group("prey"):
		remove_from_group("prey")

func _dark() -> bool:
	return Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT

func _physics_process(delta: float) -> void:
	if state == "lost" or state == "aboard" or state == "inside":
		return
	_set_prey(exposed() and _dark() and Run.active and not fighting)
	var moving := 0.0
	if state == "walking":
		while not _way.is_empty() and Geo.flat_dist(global_position, _way[0]) < ARRIVE:
			_way.pop_front()
		if _way.is_empty():
			_arrive()
		else:
			var to := _way[0] - global_position
			to.y = 0.0
			var step := to.normalized() * _speed * delta
			var p := global_position + step
			global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
			_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-delta * 8.0))
			moving = _speed
	if rig != null:
		rig.rotation.y = _yaw
		rig.locomote(moving)
	if not is_in_group("prey"):
		_near_t = 0.0
		return
	# Within a creature's reach for a moment too long, and they're gone.
	var near := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var st = e.get("state")
		if st == &"Emerge" or st == &"Retreat" or st == &"Ragdoll" or not (e is Node3D):
			continue
		if Geo.flat_dist(e.global_position, global_position) < TAKE_RANGE and absf(e.global_position.y - global_position.y) < 2.0:
			near = true
			break
	_near_t = _near_t + delta if near else maxf(0.0, _near_t - delta)
	if _near_t >= TAKE_TIME:
		take()

func _arrive() -> void:
	match _then:
		"inside":
			go_inside()
		"aboard":
			state = "aboard"
			visible = false
			_set_prey(false)
		_:
			state = "about"
	arrived.emit(self)
