class_name Boarder
extends Enemy
## What comes up out of the water after the Mary Ann (the Escape, docs/ESCAPE.md). It
## swims up alongside to a place on her gunwale, then climbs her side. While it is in
## the water or on her side, anything that hits it (the boathook, an arrow, the shotgun,
## the flamer) knocks it back into the sea, and that is the end of it. Once it is over
## the gunwale it goes for the people: the drowned for one of the seven (and over the
## side with them), or a keeper when there is none; the bloated for whoever is nearest,
## to burst among them.
##
## Two kinds, one class: "drowned" (the Smotherer's model, a quick climber) and
## "bloated" (the Bloated's, slow, heavy, and it bursts). It lives in the boat's frame,
## which never moves: everything it stands on is EscapeMap's.

const SWIM_TIME := 2.2
const BOARD_TIME := 0.55
const GRAB_RANGE := 1.05
const GRAB_TIME := 1.3
const STRIKE_RANGE := 1.35
const STRIKE_EVERY := 1.15
const STRIKE_DMG := 12
const BLOAT_RANGE := 1.5
const BLOAT_TIME := 1.25
const BURST_RADIUS := 3.0
const BURST_DMG := 28
const BURST_TAKES := 2.2
const BURST_HULL := 5
## A boathook blow aimed outward at one this close to the rail puts it over the side.
const RAIL_SHOVE := 0.9
const RETARGET := 0.5
## A pale sea-glow on their skin, so they read against the dark hull at night.
const GLOW_DROWNED := Color(0.45, 0.7, 0.75)
const GLOW_BLOATED := Color(0.5, 0.75, 0.4)

## "drowned" or "bloated".
var kind := "drowned"
## Which gunwale slot (EscapeMap.slot_point) it comes up at.
var slot := 0
## How long its climb takes (the sea's mood sets it).
var climb_time := 5.0
## The Escape, for the seven and the hull.
var escape: Node
var _visual: Node3D
var _side := 1.0
var _from := Vector3.ZERO
var _climb := 0.0
var _goal: Node3D = null
var _path: Array[Vector3] = []
var _retarget := 0.0
var _strike_t := 0.0
var _struck := false
var _splash_t := 0.0
var _off := false
var _prey: Node3D = null
var _mark: Label3D

## Set before it is added: its kind and the slot it makes for.
func setup(p_kind: String, p_slot: int, p_climb: float) -> void:
	kind = p_kind
	slot = p_slot
	climb_time = p_climb
	if kind == "bloated":
		max_hp = 50
		speed = 1.35
		mass = 2.0
		turn_rate = 5.0
		poise_hits = 3
	else:
		max_hp = 30
		speed = 2.5
		mass = 1.2
		turn_rate = 9.0
		poise_hits = 2
	hp = max_hp

func _ready() -> void:
	super._ready()
	add_to_group("boarders")
	var p := EscapeMap.slot_point(slot)
	_side = EscapeMap.side_of(p)
	# Out in the water off her quarter, coming up alongside.
	_from = p + Vector3(-2.6, 0.0, _side * 2.6)
	global_position = _from
	change_state(&"Swim")

# It comes out of the water its own way (Swim).
func _enter_Emerge() -> void:
	pass

func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if kind == "bloated":
		if _load_rig("bloated", _visual):
			rig.mass = 4.0
			rig.thickness = 1.5
			rig.tint(Color.WHITE, GLOW_BLOATED, 0.35)
			_rig_eye("eye.L", Color(0.8, 1.0, 0.35), 0.32)
			_rig_eye("eye.R", Color(0.8, 1.0, 0.35), 0.32)
		else:
			Geo.sphere(_visual, 0.6, Color(0.4, 0.46, 0.39), Vector3(0.0, 1.0, 0.0))
		Geo.cyl_shape(self, 0.5, 1.7, Vector3(0.0, 0.9, 0.0))
	else:
		if _load_rig("smotherer", _visual):
			rig.mass = 2.0
			rig.thickness = 0.7
			rig.tint(Color.WHITE, GLOW_DROWNED, 0.3)
			_rig_eye("eye.L", Color(0.75, 0.9, 1.0), 0.26, 10.0)
			_rig_eye("eye.R", Color(0.75, 0.9, 1.0), 0.26, 10.0)
		else:
			Geo.box(_visual, Vector3(0.42, 1.8, 0.3), Color(0.62, 0.68, 0.66), Vector3(0.0, 0.9, 0.0))
		Geo.cyl_shape(self, 0.35, 1.9, Vector3(0.0, 0.95, 0.0))
	_build_mark()

# A mark over the gunwale where it clings: half of them come up her far side, where the
# hull hides them from the camera. Pale while it swims, reddening as it climbs.
func _build_mark() -> void:
	_mark = Label3D.new()
	_mark.text = "!"
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	_mark.fixed_size = true
	_mark.pixel_size = 0.0022
	_mark.font_size = 44
	_mark.outline_size = 10
	_mark.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	var f := Fonts.title()
	if f != null:
		_mark.font = f
	add_child(_mark)

func _show_mark() -> void:
	if _mark == null:
		return
	_mark.visible = clinging()
	if not _mark.visible:
		return
	var k := _climb if state != &"Swim" else 0.0
	_mark.modulate = Color(0.85, 0.95, 0.95, 0.55).lerp(Color(1.0, 0.3, 0.22, 1.0), k)
	_mark.position = Vector3(0.0, EscapeMap.DECK_Y + 1.1 - global_position.y, 0.0)
	_mark.scale = Vector3.ONE * (1.0 + 0.25 * k * absf(sin(state_t * 8.0)))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_show_mark()

func fire_size() -> Vector2:
	return Vector2(1.6, 2.2) if kind == "bloated" else Vector2(1.1, 2.1)

func pick_target() -> Node3D:
	return _goal

## In the water or on her side: one blow sends it back.
func clinging() -> bool:
	return state == &"Swim" or state == &"Climb" or state == &"Board"

## Over the gunwale and loose on her deck.
func aboard() -> bool:
	return hp > 0 and not clinging() and state != &"Flee"

## How far up her side it is (0 in the water, 1 at the gunwale).
func climb_progress() -> float:
	return _climb

## The place on her deck to strike at it from while it clings to her side.
func rail_point() -> Vector3:
	return EscapeMap.slot_rail(slot)

# Its feet, in the world, while it swims and climbs: _visual hangs below its middle so
# that weapons find it at the gunwale's height.
func _hang(feet_y: float) -> void:
	_visual.position = Vector3(0.0, feet_y - global_position.y, 0.0)

func _face_in() -> void:
	face(Vector3(0.0, 0.0, -_side), true)

func _tick_Swim(delta: float) -> void:
	var k := clampf(state_t / SWIM_TIME, 0.0, 1.0)
	var to := EscapeMap.slot_point(slot)
	global_position = _from.lerp(to, smoothstep(0.0, 1.0, k))
	face(to - _from if k < 0.8 else Vector3(0.0, 0.0, -_side), k >= 0.8)
	velocity = Vector3.ZERO
	var tall := 1.7 if kind == "bloated" else 1.85
	_hang(Terrain.SEA_LEVEL - tall + 0.35 + sin(state_t * 3.0) * 0.08)
	_splash_t -= delta
	if _splash_t <= 0.0:
		_splash_t = 0.35
		FX.splash(get_parent(), Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z), 0.35)
	if state_t >= SWIM_TIME:
		change_state(&"Climb")

func _enter_Climb() -> void:
	_face_in()
	Audio.sfx("splash", global_position, -4.0, 0.2)
	if rig != null and rig.has_clips():
		if rig.has_clip("climb"):
			var natural := float(rig.clips.get("climb", {}).get("rise", 0.9)) / maxf(rig.clip_length("climb"), 0.1)
			rig.activity("climb", clampf(1.4 / climb_time / maxf(natural, 0.05), 0.3, 2.0))
		else:
			# The bloated has no climbing clip: arms up over the rail.
			rig.layer("upper_arm.L", Vector3(-2.5, 0.0, -0.2))
			rig.layer("upper_arm.R", Vector3(-2.5, 0.0, 0.2))
			rig.layer("forearm.L", Vector3(-0.4, 0.0, 0.0))
			rig.layer("forearm.R", Vector3(-0.4, 0.0, 0.0))

func _tick_Climb(_delta: float) -> void:
	velocity = Vector3.ZERO
	_face_in()
	_climb = clampf(state_t / climb_time, 0.0, 1.0)
	var tall := 1.7 if kind == "bloated" else 1.85
	var low := Terrain.SEA_LEVEL - tall + 0.4
	var high := EscapeMap.DECK_Y - 0.95
	# Hand over hand: in pulls, not a glide.
	var pulls := 4.0
	var k: float = (floor(_climb * pulls) + smoothstep(0.0, 1.0, fmod(_climb * pulls, 1.0))) / pulls
	_hang(lerpf(low, high, k))
	_visual.position.z = _side * 0.12 * (1.0 - k)
	if _climb >= 1.0:
		change_state(&"Board")

func _enter_Board() -> void:
	_from = global_position
	Audio.sfx("creak", global_position, 0.0, 0.2)
	if rig != null and rig.has_clips():
		rig.activity("")
		for b in ["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R"]:
			rig.layer(b, Vector3.ZERO)

func _tick_Board(_delta: float) -> void:
	velocity = Vector3.ZERO
	var k := clampf(state_t / BOARD_TIME, 0.0, 1.0)
	var to := Vector3(_from.x, EscapeMap.DECK_Y, _side * (EscapeMap.WALK_HALF - 0.15))
	global_position = _from.lerp(to, k) + Vector3(0.0, sin(k * PI) * 0.5, 0.0)
	_hang(lerpf(EscapeMap.DECK_Y - 0.95, global_position.y, k))
	if k >= 1.0:
		_visual.position = Vector3.ZERO
		_climb = 1.0
		if escape != null:
			escape.call("boarded", self)
		change_state(&"Aboard")

# ---- loose on the deck ----

func _people() -> Array:
	return escape.call("people_aboard") if escape != null else []

func _keepers() -> Array:
	var out := []
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and not p.downed and p.hp > 0 and p.visible:
			out.append(p)
	return out

func _choose() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var list: Array = _people()
	if kind == "bloated" or list.is_empty():
		list = list + _keepers()
	for n in list:
		var d := Geo.flat_dist(global_position, (n as Node3D).global_position)
		# The drowned want the seven: a keeper only when none are left.
		if kind == "drowned" and n is Player and not _people().is_empty():
			d += 99.0
		if d < best_d:
			best_d = d
			best = n
	return best

func _tick_Aboard(delta: float) -> void:
	_retarget -= delta
	if _retarget <= 0.0 or _goal == null or not is_instance_valid(_goal) or not _goal.visible:
		_retarget = RETARGET
		var g := _choose()
		if g != _goal:
			_goal = g
		if _goal != null:
			_path = EscapeMap.path(global_position, _goal.global_position)
	if _goal == null:
		velocity = Vector3.ZERO
		return
	var gap := Geo.flat_dist(global_position, _goal.global_position)
	if kind == "bloated" and gap < BLOAT_RANGE:
		change_state(&"Bloat")
		return
	if kind == "drowned":
		if _goal is Villager and gap < GRAB_RANGE:
			_prey = _goal
			change_state(&"Grab")
			return
		if _goal is Player and gap < STRIKE_RANGE:
			_strike(delta)
			return
	_strike_t = 0.0
	while _path.size() > 1 and Geo.flat_dist(global_position, _path[0]) < 0.45:
		_path.pop_front()
	var to := (_path[0] if not _path.is_empty() else _goal.global_position) - global_position
	to.y = 0.0
	if to.length() < 0.05:
		velocity = Vector3.ZERO
		return
	var dir := to.normalized()
	face(dir)
	velocity = dir * speed * speed_mult
	_stay_aboard(delta)

# Its next step stays on her deck: slide along the bulwark or the wheelhouse.
func _stay_aboard(delta: float) -> void:
	var p := global_position
	var next := p + velocity * delta
	if not EscapeMap.walkable(next.x, next.z):
		if EscapeMap.walkable(next.x, p.z):
			velocity.z = 0.0
		elif EscapeMap.walkable(p.x, next.z):
			velocity.x = 0.0
		else:
			velocity = Vector3.ZERO
	global_position.y = EscapeMap.DECK_Y

func _strike(delta: float) -> void:
	velocity = Vector3.ZERO
	face(_goal.global_position - global_position)
	var before := _strike_t
	_strike_t += delta
	var hit_at := STRIKE_EVERY * 0.6
	if before < 0.05 and _strike_t >= 0.05 and rig != null:
		rig.shot("strike")
	if before < hit_at and _strike_t >= hit_at and Geo.flat_dist(global_position, _goal.global_position) < STRIKE_RANGE + 0.3:
		_goal.take_damage(STRIKE_DMG, global_position)
	if _strike_t >= STRIKE_EVERY:
		_strike_t = 0.0

func _enter_Grab() -> void:
	velocity = Vector3.ZERO
	if rig != null:
		rig.shot("strike")
	Audio.sfx("groan", global_position, 0.0, 0.2)

func _tick_Grab(_delta: float) -> void:
	velocity = Vector3.ZERO
	if _prey == null or not is_instance_valid(_prey) or String(_prey.get("state")) == "lost":
		change_state(&"Aboard")
		return
	face(_prey.global_position - global_position)
	if state_t >= GRAB_TIME:
		if escape != null:
			escape.call("take_villager", _prey, self)
		elif _prey.has_method("take"):
			_prey.take()
		_prey = null
		# Over the side, and the one it took with it.
		change_state(&"Flee")

func _enter_Bloat() -> void:
	velocity = Vector3.ZERO
	Audio.sfx("groan", global_position, -2.0, 0.05)
	if rig != null and rig.has_clips():
		rig.activity("bloat", rig.clip_length("bloat") / BLOAT_TIME)

func _tick_Bloat(_delta: float) -> void:
	velocity = Vector3.ZERO
	var k := clampf(state_t / BLOAT_TIME, 0.0, 1.0)
	if rig != null:
		rig.tint(Color.WHITE.lerp(Color(1.6, 1.8, 1.3), k), Color(0.8, 1.0, 0.6), k * 1.2)
	var s := 1.0 + 0.3 * k * absf(sin(state_t * 12.0))
	_visual.scale = Vector3(s, s, s)
	if state_t >= BLOAT_TIME:
		_burst()

func _burst() -> void:
	var c := global_position
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and Geo.flat_dist(c, p.global_position) <= BURST_RADIUS:
			p.take_damage(BURST_DMG, c)
	var near: Node3D = null
	var near_d := BURST_TAKES
	for v in _people():
		var d := Geo.flat_dist(c, (v as Node3D).global_position)
		if d < near_d:
			near_d = d
			near = v
	if near != null and escape != null:
		escape.call("take_villager", near, self)
	if escape != null:
		escape.call("hull_hit", BURST_HULL, c, "burst")
	FX.burst(get_parent(), c + Vector3(0.0, 0.9, 0.0))
	Audio.sfx("burst", c, 0.0)
	hp = 0
	Events.enemy_killed.emit(self)
	queue_free()

## The light has reached them, or it has one of the seven: over the side and away.
func flee() -> void:
	if hp <= 0 or state == &"Flee":
		return
	if clinging():
		_drop_off()
		return
	change_state(&"Flee")

func _enter_Flee() -> void:
	velocity = Vector3.ZERO
	_from = global_position
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	if rig != null and rig.is_ragdoll():
		rig.get_up(0.05)

func _tick_Flee(_delta: float) -> void:
	velocity = Vector3.ZERO
	var k := clampf(state_t / 0.7, 0.0, 1.0)
	var side := EscapeMap.side_of(_from)
	var to := Vector3(_from.x, Terrain.SEA_LEVEL - 1.5, side * (EscapeMap.CLIMB_OUT + 0.8))
	global_position = _from.lerp(to, k) + Vector3(0.0, sin(k * PI) * 1.4, 0.0)
	face(Vector3(0.0, 0.0, side), true)
	if k >= 1.0:
		FX.splash(get_parent(), Vector3(to.x, Terrain.SEA_LEVEL, to.z), 1.2)
		Audio.sfx("splash", to, 0.0, 0.1)
		hp = 0
		queue_free()

# Lets go of her side and drops back into the sea, unhurt (the light at the end).
func _drop_off() -> void:
	hp = 0
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	FX.splash(get_parent(), Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z), 1.0)
	Audio.sfx("splash", global_position, -2.0, 0.1)
	var tw := create_tween()
	tw.tween_property(_visual, "position:y", _visual.position.y - 2.5, 0.6)
	tw.tween_callback(queue_free)

# ---- hurt ----

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if puppet or hp <= 0 or state == &"Flee":
		return
	if source is Player:
		last_hit = source.hit_kind
	if clinging():
		_knock_off(from_dir, source, amount)
		return
	# At the rail, a boathook blow aimed outward puts it over the side.
	if source is Player and source.hit_kind == "hook" and state != &"Bloat" and absf(global_position.z) > RAIL_SHOVE \
			and Vector3(from_dir.x, 0.0, from_dir.z).normalized().dot(Vector3(0.0, 0.0, EscapeMap.side_of(global_position))) > 0.3:
		_knock_off(from_dir, source, amount, true)
		return
	if state == &"Bloat" and hp - amount <= 0:
		# Killed as it swells: it bursts anyway.
		hp = 1
		return
	super.take_damage(amount, from_dir, source)

## Back into the sea: a blow while it swam or clung on, or a shove over the rail.
func _knock_off(from_dir: Vector3, source: Node, amount: int, overboard: bool = false) -> void:
	if _off:
		return
	_off = true
	hp = 0
	var out := Vector3(0.0, 0.0, EscapeMap.side_of(global_position))
	if source != null:
		FX.spray(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), from_dir if from_dir != Vector3.ZERO else out, Color(0.55, 0.65, 0.45))
		Audio.sfx("hit", global_position)
	if source is Player and not source.ai:
		Feel.blow(true, amount >= 30)
		FX.damage_number(get_parent(), global_position + Vector3(0.0, 1.8, 0.0), amount)
	if last_hit == "":
		last_hit = "hook"
	if escape != null:
		escape.call("knocked_off", self, overboard)
	Events.enemy_killed.emit(self)
	var at := Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z + out.z * (1.2 if overboard else 0.4))
	var parent := get_parent()
	get_tree().create_timer(0.45 if overboard else 0.3).timeout.connect(func() -> void:
		if is_instance_valid(parent) and parent.is_inside_tree():
			FX.splash(parent, at, 1.3)
			Audio.sfx("splash", at, 0.0, 0.15))
	var push := out * 5.0 + Vector3(0.0, 3.0 if overboard else 1.5, 0.0)
	if rig == null or not _ragdoll_corpse(push * rig.mass * 10.0):
		queue_free()
