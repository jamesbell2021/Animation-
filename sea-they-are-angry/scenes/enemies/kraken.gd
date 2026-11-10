class_name Kraken
extends Node3D
## The last night (docs/STORY.md): the kraken. It rises off the east of the holm and
## wrecks the old camp, from the east and then from the north; then it comes round to
## the east beach for the lighthouse. Its arms slam what they reach (a reared arm is the
## warning), and an arm lying ashore can be cut back. The focused beam held in its eyes
## blinds it: it stops, its arms drop, and everything that hits it then counts for more.
## When its strength is gone it dies, and the fog goes with it.
##
## This script is the rules. KrakenBody is how it looks and moves; KrakenPart is what
## the keepers' weapons find.

signal died
signal phase_changed(phase: String)

const BASE_HP := 4200
const ARM_HP := 80
## What cutting an arm back costs it.
const SEVER_DAMAGE := 160
const ARM_REGROW := 15.0
const ARM_REACH := 24.0
## Seconds between slams while it has its sight, by phase.
const SLAM_EVERY_CAMP := 1.7
const SLAM_EVERY_LIGHT := 2.3
const SLAM_WINDUP := 1.25
const SLAM_RADIUS := 2.7
const SLAM_KEEPER := 32
const SLAM_STRUCTURE := 75
const SLAM_LIGHTHOUSE := 9
## One slam in this many, at the lighthouse, is for the tower itself.
const TOWER_SHARE := 3
## The focused beam held on its eyes this long blinds it, for this long; then it keeps
## its head turned for a while and can't be blinded again.
const DAZZLE_TIME := 1.3
const BLIND_TIME := 7.5
const BLIND_REST := 5.0
const BLIND_MULT := 2.5
## What the beam itself does to it, a second, blind and still lit.
const BEAM_DPS := 22.0
const FIRE_DPS := 9.0
const MOVE_SPEED := 4.2
## Where it rises, where it lies to reach each half of the camp, its way round the
## north of the holm, and where it lies for the lighthouse: hauled half up the east
## beach, near enough that the lamp can look down into its eyes.
const RISE_AT := Vector2(68.5, 4.0)
const CAMP_NORTH := Vector2(50.0, -14.5)
const WAY := [Vector2(34.0, -15.0), Vector2(24.0, -8.0)]
const LIGHT_AT := Vector2(18.3, -3.2)
## How long it gives each side of the camp at most.
const CAMP_TIME := 38.0
const HEAD_SPOTS := 7
const HEAD_SPOT_R := 4.4
const HEAD_SPOT_Y := 1.0
## Kirkhaven's people on the crag: how often each looses at it, and what it does.
const FIGHTER_EVERY := 4.5
const FIGHTER_DMG := 9
const FIGHTER_RANGE := 34.0

var lighthouse: Lighthouse
var camp: Camp
var players: Array = []
## Villagers standing with the keepers (StoryRock sets them).
var fighters: Array = []
var body: KrakenBody
var hp := BASE_HP
var max_hp := BASE_HP
## "rise", "camp_east", "camp_north", "cross", "light", "dying", "dead".
var phase := ""
var blinded := 0.0
var arms_cut := 0

var _phase_t := 0.0
var _dazzle := 0.0
var _lit_t := 0.0
var _rest := 0.0
var _slow := 0.0
var _slam_t := 2.0
var _slams := 0
var _arm_hp: Array[int] = []
var _arm_back: Array[float] = []
var _head: Array[KrakenPart] = []
var _tips: Array[KrakenPart] = []
var _way: Array[Vector2] = []
var _burning := 0.0
var _fire_acc := 0.0
var _beam_acc := 0.0
var _fighter_t: Array[float] = []
var _hit_frame := -1
var _hit_kind := ""
var _told_blind := false

func _ready() -> void:
	add_to_group("kraken")
	max_hp = roundi(float(BASE_HP) * (1.0 + 0.35 * float(Players.humans() - 1)) * Difficulty.creatures())
	hp = max_hp
	global_position = Vector3(RISE_AT.x, Terrain.SEA_LEVEL, RISE_AT.y)
	body = KrakenBody.new()
	add_child(body)
	body.slammed.connect(_on_slammed)
	body.died.connect(_on_body_died)
	for i in KrakenBody.ARMS:
		_arm_hp.append(ARM_HP)
		_arm_back.append(0.0)
		var tip := KrakenPart.new()
		tip.kraken = self
		tip.arm = i
		add_child(tip)
		tip.top_level = true
		tip.global_position = Vector3(0.0, -60.0, 0.0)
		_tips.append(tip)
	for i in HEAD_SPOTS:
		var spot := KrakenPart.new()
		spot.kraken = self
		add_child(spot)
		spot.top_level = true
		spot.global_position = Vector3(0.0, -60.0, 0.0)
		_head.append(spot)
	_enter("rise")

func _enter(p: String) -> void:
	phase = p
	_phase_t = 0.0
	match p:
		"rise":
			body.face(Vector3(Terrain.CAMP_C.x, 0.0, Terrain.CAMP_C.y))
			body.rise(6.0)
			Audio.sfx("kraken_rise", global_position, 8.0, 0.0)
			Feel.shake(0.5)
		"camp_east":
			_roar()
		"camp_north":
			_way = [Vector2(66.0, -12.0), CAMP_NORTH]
		"cross":
			_way.assign(WAY)
			_way.append(LIGHT_AT)
			_all_rest()
		"light":
			_roar()
		"dying":
			_all_rest()
			body.set_blinded(false)
			body.die(7.0)
			Audio.sfx("kraken_die", global_position, 8.0, 0.0)
			Feel.shake(0.8)
			for part in _head + _tips:
				part.queue_free()
			_head.clear()
			_tips.clear()
	phase_changed.emit(p)

func _roar() -> void:
	body.roar_pose(2.5)
	Audio.sfx("kraken_roar", global_position, 9.0, 0.0)
	Feel.shake(0.6)
	_slam_t = 3.0

func _all_rest() -> void:
	for i in KrakenBody.ARMS:
		body.arm_rest(i)

## The eyes, for the lamp's cone.
func eye_points() -> Array:
	var out: Array = []
	if body != null and phase != "dying" and phase != "dead" and body.risen > 0.6:
		for e in body.eye_points():
			out.append(e)
	return out

func health_ratio() -> float:
	return float(hp) / float(maxi(max_hp, 1))

func is_blind() -> bool:
	return blinded > 0.0

# ---- light ----

## The lamp (or a searchlight) has its eyes this frame.
func lit(mode: int, delta: float) -> void:
	if phase == "dying" or phase == "dead" or phase == "rise":
		return
	_lit_t = 0.2
	if mode != Lamp.Mode.FOCUSED:
		# A wide beam worries it: it is slower to strike.
		_slow = 0.4
		return
	if blinded > 0.0 or _rest > 0.0:
		return
	_dazzle += delta * 2.0
	if _dazzle >= DAZZLE_TIME:
		_blind()

func _blind() -> void:
	blinded = BLIND_TIME
	_dazzle = 0.0
	body.set_blinded(true)
	Audio.sfx("kraken_blind", global_position, 8.0, 0.0)
	Feel.shake(0.4)
	Events.message.emit("The light is in its eyes: it's blind! Hit it with everything!" if not _told_blind else "Blind again! Now!")
	_told_blind = true

func _unblind() -> void:
	blinded = 0.0
	_rest = BLIND_REST
	body.set_blinded(false)
	_roar()

# ---- being hurt ----

## A weapon has found one of its parts.
func struck(arm: int, amount: int, kind: String, from_dir: Vector3, source: Node, at: Vector3) -> void:
	if phase == "dying" or phase == "dead" or phase == "rise":
		return
	# A blast or a sheet of flame covers several of its parts at once: count it once.
	if kind == "bomb" or kind == "flame" or kind == "fire":
		var f := Engine.get_physics_frames()
		if f == _hit_frame and kind == _hit_kind:
			return
		_hit_frame = f
		_hit_kind = kind
	if arm >= 0:
		_hurt_arm(arm, amount, from_dir, at)
		return
	var dmg := roundi(float(amount) * (BLIND_MULT if blinded > 0.0 else 1.0))
	_hurt(dmg)
	body.hurt_flash()
	FX.spray(get_parent(), at + Vector3(0.0, 1.2, 0.0), from_dir, Color(0.45, 0.55, 0.42))
	if source is Player and not source.ai:
		Feel.blow(false, dmg >= 60)
		FX.damage_number(get_parent(), at + Vector3(randf_range(-0.5, 0.5), 2.4, 0.0), dmg)

func _hurt(dmg: int) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - dmg)
	if hp == 0:
		_enter("dying")

func _hurt_arm(arm: int, amount: int, from_dir: Vector3, at: Vector3) -> void:
	if not body.arm_out(arm):
		return
	_arm_hp[arm] -= amount
	FX.spray(get_parent(), at + Vector3(0.0, 0.6, 0.0), from_dir, Color(0.45, 0.55, 0.42))
	Audio.sfx("hit", at, -2.0)
	if _arm_hp[arm] <= 0:
		_sever(arm)

func _sever(arm: int) -> void:
	arms_cut += 1
	_arm_hp[arm] = ARM_HP
	_arm_back[arm] = ARM_REGROW
	body.sever(arm)
	_tips[arm].global_position = Vector3(0.0, -60.0, 0.0)
	Audio.sfx("kraken_sever", body.arm_tip(arm), 6.0, 0.05)
	Events.message.emit("An arm cut back!")
	_hurt(SEVER_DAMAGE)

## Fire on it (a petrol bomb, the flamer, a burning pool).
func burn(t: float, _arm: int) -> void:
	_burning = maxf(_burning, t)

# ---- what it does ----

func _physics_process(delta: float) -> void:
	if phase == "dead" or phase == "dying" or Net.is_client():
		return
	_phase_t += delta
	_rest = maxf(0.0, _rest - delta)
	_slow = maxf(0.0, _slow - delta)
	_lit_t = maxf(0.0, _lit_t - delta)
	if _lit_t <= 0.0:
		_dazzle = maxf(0.0, _dazzle - delta)
	for i in KrakenBody.ARMS:
		if _arm_back[i] > 0.0:
			_arm_back[i] -= delta
			if _arm_back[i] <= 0.0:
				body.regrow(i, 4.0)
	if _burning > 0.0:
		_burning -= delta
		_fire_acc += FIRE_DPS * (BLIND_MULT if blinded > 0.0 else 1.0) * delta
		if _fire_acc >= 1.0:
			var n := int(_fire_acc)
			_fire_acc -= float(n)
			_hurt(n)
	if blinded > 0.0:
		blinded -= delta
		if _lit_t > 0.0:
			_beam_acc += BEAM_DPS * Lamp.dps_mult * delta
			if _beam_acc >= 1.0:
				var n := int(_beam_acc)
				_beam_acc -= float(n)
				_hurt(n)
		if blinded <= 0.0 and hp > 0:
			_unblind()
	if hp <= 0:
		return
	_place_parts()
	_fighters(delta)
	match phase:
		"rise":
			if _phase_t > 7.0:
				_enter("camp_east")
		"camp_east":
			_camp(delta)
			if _phase_t > CAMP_TIME or _camp_in_reach().is_empty():
				_enter("camp_north")
		"camp_north":
			if not _way.is_empty():
				_swim(delta)
			else:
				_camp(delta)
				if _phase_t > CAMP_TIME * 1.6 or _camp_in_reach().is_empty():
					_enter("cross")
		"cross":
			_swim(delta)
			if _way.is_empty():
				_enter("light")
		"light":
			body.face(lighthouse.global_position)
			_at_light(delta)

func _swim(delta: float) -> void:
	if _way.is_empty():
		return
	var to := Vector3(_way[0].x, Terrain.SEA_LEVEL, _way[0].y) - global_position
	to.y = 0.0
	if to.length() < 0.8:
		_way.pop_front()
		return
	global_position += to.normalized() * MOVE_SPEED * delta
	body.face(global_position + to)

# What of the camp still stands within its arms' reach.
func _camp_in_reach() -> Array:
	var out: Array = []
	if camp == null or not is_instance_valid(camp):
		return out
	var all: Array = []
	all.append_array(camp.targets())
	for w in camp.wire:
		if not w.is_destroyed():
			all.append(w)
	if camp.turbine != null and not camp.turbine.is_destroyed() and not all.has(camp.turbine):
		all.append(camp.turbine)
	for s in all:
		if Geo.flat_dist((s as Node3D).global_position, global_position) <= ARM_REACH:
			out.append(s)
	return out

func _free_arm(target: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in KrakenBody.ARMS:
		if not body.arm_out(i) or body.arm_busy(i):
			continue
		var d := body.arm_tip(i).distance_to(target)
		if d < best_d:
			best_d = d
			best = i
	return best

func _slam_due(delta: float, every: float) -> bool:
	if blinded > 0.0:
		return false
	_slam_t -= delta * (0.5 if _slow > 0.0 else 1.0)
	if _slam_t > 0.0:
		return false
	_slam_t = every * randf_range(0.8, 1.2)
	return true

func _camp(delta: float) -> void:
	body.face(Vector3(Terrain.CAMP_C.x, 0.0, Terrain.CAMP_C.y))
	if not _slam_due(delta, SLAM_EVERY_CAMP):
		return
	var near := _camp_in_reach()
	# A keeper who has come over to fight it there is fair game too.
	var k := _keeper_in_reach()
	var at := Vector3.INF
	if k != null and (near.is_empty() or randf() < 0.3):
		at = k.global_position
	elif not near.is_empty():
		at = (near[randi() % near.size()] as Node3D).global_position
	if at == Vector3.INF:
		return
	var arm := _free_arm(at)
	if arm >= 0:
		body.arm_slam(arm, at, SLAM_WINDUP)

func _keeper_in_reach() -> Player:
	var best: Player = null
	var best_d := ARM_REACH
	for p in players:
		if not is_instance_valid(p) or p.downed or p.operating or p.is_inside():
			continue
		var d := Geo.flat_dist(p.global_position, global_position)
		if d < best_d:
			best_d = d
			best = p
	return best

func _at_light(delta: float) -> void:
	if not _slam_due(delta, SLAM_EVERY_LIGHT):
		return
	_slams += 1
	var at := Vector3.INF
	if _slams % TOWER_SHARE == 0 and not lighthouse.is_destroyed():
		# Up the crag at the tower itself.
		var dir := (global_position - lighthouse.global_position)
		dir.y = 0.0
		at = lighthouse.global_position + dir.normalized() * 1.8
	else:
		var k := _keeper_in_reach()
		if k != null:
			# Where they will be, near enough: a keeper who keeps moving gets clear.
			at = k.global_position + Vector3(k.velocity.x, 0.0, k.velocity.z) * 0.5
		else:
			var home := Enemy.nearest_home(global_position)
			if home != null and Geo.flat_dist(home.global_position, global_position) <= ARM_REACH:
				at = home.global_position
	if at == Vector3.INF:
		return
	var arm := _free_arm(at)
	if arm >= 0:
		body.arm_slam(arm, at, SLAM_WINDUP)

# An arm has come down.
func _on_slammed(arm: int, at: Vector3) -> void:
	if phase == "dying" or phase == "dead":
		return
	Audio.sfx("kraken_slam", at, 6.0, 0.08)
	Feel.shake(0.45, at)
	FX.splinters(get_parent(), at + Vector3(0.0, 0.5, 0.0))
	for s in get_tree().get_nodes_in_group("structures"):
		if not (s is Structure) or s.is_destroyed():
			continue
		if s == lighthouse:
			if s.surface_distance(at) <= SLAM_RADIUS:
				s.take_damage(SLAM_LIGHTHOUSE)
		elif s.surface_distance(at) <= SLAM_RADIUS:
			s.take_damage(SLAM_STRUCTURE)
	for p in players:
		if is_instance_valid(p) and Geo.flat_dist(p.global_position, at) <= SLAM_RADIUS and absf(p.global_position.y - at.y) < 3.0:
			p.take_damage(SLAM_KEEPER, at)
	for v in get_tree().get_nodes_in_group("villagers"):
		if v.exposed() and Geo.flat_dist(v.global_position, at) <= SLAM_RADIUS:
			v.take()

# The places a weapon can find it: across the front of its head, and at the tip of each
# arm that is lying ashore.
func _place_parts() -> void:
	var toward := lighthouse.global_position if phase == "light" or phase == "cross" else Vector3(Terrain.CAMP_C.x, 0.0, Terrain.CAMP_C.y)
	var f := toward - global_position
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var up := body.risen > 0.6
	for i in _head.size():
		var a := deg_to_rad(lerpf(-70.0, 70.0, float(i) / float(maxi(_head.size() - 1, 1))))
		var p := global_position + f.rotated(Vector3.UP, a) * HEAD_SPOT_R
		p.y = maxf(Terrain.height_at(p.x, p.z), Terrain.SEA_LEVEL) + HEAD_SPOT_Y
		_head[i].global_position = p if up else Vector3(0.0, -60.0, 0.0)
	for i in _tips.size():
		var tip := body.arm_tip(i)
		var ground := Terrain.height_at(tip.x, tip.z)
		# Only an arm on the ground can be got at.
		var ashore := body.arm_out(i) and ground > Terrain.SEA_LEVEL and tip.y < ground + 1.2
		_tips[i].global_position = Vector3(tip.x, ground, tip.z) if ashore else Vector3(0.0, -60.0, 0.0)

# Kirkhaven's people on the crag loose what they have at it.
func _fighters(delta: float) -> void:
	while _fighter_t.size() < fighters.size():
		_fighter_t.append(randf_range(1.0, FIGHTER_EVERY))
	for i in fighters.size():
		var v = fighters[i]
		if not is_instance_valid(v) or v.state == "lost":
			continue
		_fighter_t[i] -= delta
		if _fighter_t[i] > 0.0 or body.risen < 0.6:
			continue
		_fighter_t[i] = FIGHTER_EVERY * randf_range(0.8, 1.25)
		if Geo.flat_dist(v.global_position, global_position) > FIGHTER_RANGE:
			continue
		Audio.sfx("bow", v.global_position, -6.0, 0.15)
		_hurt(roundi(float(FIGHTER_DMG) * (BLIND_MULT if blinded > 0.0 else 1.0)))
		body.hurt_flash()

func _on_body_died() -> void:
	phase = "dead"
	phase_changed.emit(phase)
	died.emit()
