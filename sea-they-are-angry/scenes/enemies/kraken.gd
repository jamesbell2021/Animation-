class_name Kraken
extends Node3D
## The last night (docs/STORY.md): the kraken. The fight comes in three stages, each with
## its own answer (docs/DESIGN.md, "The kraken"):
##
## 1. **It takes the camp** (phases "camp_east", "camp_north"). It lies off the holm and
##    sends its arms over the wire one at a time. Fire is the answer: the flamer or a
##    petrol bomb on an arm makes it recoil and burn; arrows sting an arm back; a
##    searchlight held on an arm makes it pull back. The camp falls in the end, but what
##    still stands when it moves on is the camp's own score.
## 2. **The crossing** ("cross"). It comes round the north of the holm for the light,
##    slowly, through the shallows, reaching for keepers on the path and the bridge. An
##    arm laid on the ground by a slam lies there a while with a pale wound on it: cut it
##    (the boathook, the shotgun) and it costs it dear, slows it, and stays gone.
## 3. **The light** ("light"). At the east beach. The focused beam held in its eyes
##    blinds it and holds it, and everything that hits it then counts for more. It
##    learns: each blinding is shorter than the last, and between them it reaches up the
##    tower to shake the keeper out of the lamp room. Near its end it rears its whole
##    body up out of the sea, a last window for every weapon.
##
## When its strength is gone it dies, and the fog goes with it. This script is the rules.
## KrakenBody is how it looks and moves; KrakenPart is what the keepers' weapons find.

signal died
signal phase_changed(phase: String)
## 1 the camp, 2 the crossing, 3 the light (0 while it rises).
signal stage_changed(stage: int)

const BASE_HP := 4800
const ARM_HP := 110
## What cutting an arm back costs it (in the crossing, much more: it is hurrying).
const SEVER_DAMAGE := 110
const SEVER_DAMAGE_CROSS := 300
const ARM_REGROW := 15.0
const ARM_REACH := 24.0
const SLAM_WINDUP := 1.25
const SLAM_RADIUS := 2.7
const SLAM_KEEPER := 32
## Over the wire its blows are aimed at the huts: a keeper caught by one is knocked about
## rather than flattened.
const SLAM_KEEPER_CAMP := 20
const SLAM_STRUCTURE := 55
const SLAM_LIGHTHOUSE := 18
const STAGE_NAMES := ["It rises", "It takes the camp", "The crossing", "The light"]

## ---- stage 1: the camp ----
## How long it gives each side of the camp at most.
const CAMP_TIME := 24.0
## One arm over the wire at a time: the wind-up is long enough to answer, and a gap after.
const CAMP_WINDUP := 1.6
const SLAM_EVERY_CAMP := 1.3
## A slam on the camp's buildings: two bring a hut down.
const SLAM_CAMP := 110
## Fire on an arm: it whips back under for this long, and won't come again for longer.
const RECOIL_TIME := 2.6
const SHY_TIME := 6.0
## How long a burning arm burns.
const ARM_BURN := 4.0
## A searchlight held on an arm this long (half as long focused) makes it pull back.
const ARM_LIGHT_TIME := 0.8
## Arrows (and shot) on an arm: this much of it stings it back.
const STING := 40

## ---- stage 2: the crossing ----
## Its speed through the shallows, and what each arm cut back on the way takes off it.
const CROSS_SPEED := 1.35
const CROSS_SLOW := 0.2
const CROSS_SLOWEST := 0.4
## Cut, it stops a moment, thrashing.
const SEVER_STALL := 3.0
const SLAM_EVERY_CROSS := 2.4
## An arm that comes down in the crossing lies there this long: the time to cut it.
const LIE_CROSS := 4.5

## ---- stage 3: the light ----
const SLAM_EVERY_LIGHT := 2.3
## One slam in this many, at the lighthouse, is for the tower itself.
const TOWER_SHARE := 3
## The focused beam held on its eyes this long blinds it. The first blinding lasts
## BLIND_TIME; each after is shorter by BLIND_LEARN, never under BLIND_MIN. Then it
## keeps its head turned for a while and can't be blinded again.
const DAZZLE_TIME := 1.3
const BLIND_TIME := 8.0
const BLIND_LEARN := 0.88
const BLIND_MIN := 4.0
const BLIND_REST := 5.0
const BLIND_MULT := 3.0
## What the beam itself does to it, a second, blind and still lit.
const BEAM_DPS := 34.0
## Sighted this long at the light, it reaches up the tower; this long after (and after
## its head comes back round to the lamp), unless it is blinded first, it shakes it: the
## lamp is hurt and its keeper thrown out of the room.
const GRIP_EVERY := 13.0
const GRIP_TIME := 4.0
const GRIP_DAMAGE := 14
## The last gasp: at this share of its strength it rears up out of the sea for this long,
## and everything that hits it counts this much more.
const REAR_AT := 0.3
const REAR_TIME := 10.0
const REAR_MULT := 2.5

const FIRE_DPS := 9.0
const MOVE_SPEED := 3.2
## Where it rises, where it lies to reach each half of the camp, its way round the
## north of the holm, and where it lies for the lighthouse: hauled half up the east
## beach, near enough that the lamp can look down into its eyes.
const RISE_AT := Vector2(68.5, 4.0)
const CAMP_NORTH := Vector2(50.0, -14.5)
const WAY := [Vector2(34.0, -15.0), Vector2(24.0, -8.0)]
const LIGHT_AT := Vector2(18.3, -3.2)
const HEAD_SPOTS := 7
const HEAD_SPOT_R := 4.4
const HEAD_SPOT_Y := 1.0
## Kirkhaven's people on the crag: how often each looses at it, and what it does.
const FIGHTER_EVERY := 4.5
const FIGHTER_DMG := 6
const FIGHTER_RANGE := 34.0
const HIDE := Vector3(0.0, -60.0, 0.0)

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
var stage := 0
var blinded := 0.0
var arms_cut := 0
## How many times it has been blinded, arms cut in the crossing, arms driven back in the
## camp, and whether it has reared.
var blinds := 0
var cross_cuts := 0
var recoils := 0
var reared := false
## What of the camp still stood when it left it (-1 until then), of how many.
var camp_left := -1
var camp_had := 0

var _phase_t := 0.0
var _dazzle := 0.0
var _lit_t := 0.0
var _rest := 0.0
var _slow := 0.0
var _stall := 0.0
var _slam_t := 2.0
var _slams := 0
var _grip_t := 0.0
var _grip_arm := -1
var _grip_left := 0.0
var _rear_left := 0.0
var _arm_hp: Array[int] = []
var _arm_back: Array[float] = []
var _arm_shy: Array[float] = []
var _arm_burn: Array[float] = []
var _arm_lit: Array[float] = []
var _arm_lit_t: Array[float] = []
var _arm_sting: Array[int] = []
var _head: Array[KrakenPart] = []
var _tips: Array[KrakenPart] = []
var _way: Array[Vector2] = []
var _burning := 0.0
var _fire_acc := 0.0
var _beam_acc := 0.0
var _ember_t := 0.0
var _fighter_t: Array[float] = []
var _hit_frame := -1
var _hit_kind := ""
var _told_blind := false
var _told_cut := false
var _told_grip := false
var _told_fire := false
var _bar: CanvasLayer

func _ready() -> void:
	add_to_group("kraken")
	# The sea's mood counts for a third as much on it as on the nights' landings (a raging
	# sea is harder on the keepers already: its blows land harder).
	var sea := 1.0 + 0.35 * (Difficulty.creatures() - 1.0)
	max_hp = roundi(float(BASE_HP) * (1.0 + 0.35 * float(Players.humans() - 1)) * sea)
	hp = max_hp
	global_position = Vector3(RISE_AT.x, Terrain.SEA_LEVEL, RISE_AT.y)
	body = KrakenBody.new()
	add_child(body)
	body.slammed.connect(_on_slammed)
	body.died.connect(_on_body_died)
	for i in KrakenBody.ARMS:
		_arm_hp.append(ARM_HP)
		_arm_back.append(0.0)
		_arm_shy.append(0.0)
		_arm_burn.append(0.0)
		_arm_lit.append(0.0)
		_arm_lit_t.append(0.0)
		_arm_sting.append(0)
		var tip := KrakenPart.new()
		tip.kraken = self
		tip.arm = i
		add_child(tip)
		tip.top_level = true
		tip.global_position = HIDE
		_tips.append(tip)
	for i in HEAD_SPOTS:
		var spot := KrakenPart.new()
		spot.kraken = self
		add_child(spot)
		spot.top_level = true
		spot.global_position = HIDE
		_head.append(spot)
	_bar = preload("res://scenes/enemies/kraken_bar.gd").new()
	_bar.kraken = self
	add_child(_bar)
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
			_set_stage(1)
			camp_had = _camp_count()
		"camp_north":
			_way = [Vector2(66.0, -12.0), CAMP_NORTH]
		"cross":
			camp_left = _camp_count()
			_way.assign(WAY)
			_way.append(LIGHT_AT)
			_all_rest()
			_roar()
			_set_stage(2)
		"light":
			_roar()
			_set_stage(3)
			_grip_t = 0.0
			# What was cut in the crossing comes back now, slowly.
			for i in KrakenBody.ARMS:
				if _arm_back[i] > ARM_REGROW:
					_arm_back[i] = ARM_REGROW
		"dying":
			_all_rest()
			_release_grip()
			body.set_blinded(false)
			body.die(7.0)
			Audio.sfx("kraken_die", global_position, 8.0, 0.0)
			Feel.shake(0.8)
			for part in _head + _tips:
				part.queue_free()
			_head.clear()
			_tips.clear()
	phase_changed.emit(p)

func _set_stage(s: int) -> void:
	if s == stage:
		return
	stage = s
	stage_changed.emit(s)

func _roar() -> void:
	body.roar_pose(2.5)
	Audio.sfx("kraken_roar", global_position, 9.0, 0.0)
	Feel.shake(0.6)
	_slam_t = 3.0

func _all_rest() -> void:
	for i in KrakenBody.ARMS:
		body.arm_rest(i)

## The eyes, for the lamp's cone. None while it keeps its head turned from the lamp after
## a blinding, or is reared up out of its reach.
func eye_points() -> Array:
	var out: Array = []
	if _rest > 0.0 or _rear_left > 0.0:
		return out
	if body != null and phase != "dying" and phase != "dead" and body.risen > 0.6:
		for e in body.eye_points():
			out.append(e)
	return out

func health_ratio() -> float:
	return float(hp) / float(maxi(max_hp, 1))

func is_blind() -> bool:
	return blinded > 0.0

func is_rearing() -> bool:
	return _rear_left > 0.0

## How long the next blinding will hold it: it learns to turn its head sooner.
func blind_length() -> float:
	return maxf(BLIND_MIN, BLIND_TIME * pow(BLIND_LEARN, float(blinds)))

## Its speed through the shallows now (stage 2): every arm cut on the way slows it.
func cross_speed() -> float:
	if _stall > 0.0:
		return 0.0
	return CROSS_SPEED * maxf(CROSS_SLOWEST, 1.0 - CROSS_SLOW * float(cross_cuts))

## True while an arm is up the tower.
func gripping() -> bool:
	return _grip_arm >= 0

# What of the camp stands: its generator, huts and greenhouse.
func _camp_count() -> int:
	if camp == null or not is_instance_valid(camp):
		return 0
	return camp._keeps().size()

# ---- light ----

## The lamp (or a searchlight) has its eyes this frame.
func lit(mode: int, delta: float) -> void:
	if phase == "dying" or phase == "dead" or phase == "rise" or _rear_left > 0.0:
		return
	# Only the lighthouse lamp is strong enough to blind it, and only focused and within
	# its reach; a searchlight, a flare or the wide beam just worries it (it is slower
	# to strike).
	var lamp := lighthouse.lamp
	var strong := mode == Lamp.Mode.FOCUSED and lamp != null and lamp.is_lit() and lamp.mode == Lamp.Mode.FOCUSED \
		and Geo.flat_dist(lighthouse.global_position, global_position) <= Lamp.FOCUS_RANGE + 4.0
	if not strong:
		_slow = 0.4
		return
	_lit_t = 0.2
	if blinded > 0.0 or _rest > 0.0:
		return
	_dazzle += delta * 2.0
	if _dazzle >= DAZZLE_TIME:
		_blind()

func _blind() -> void:
	blinded = blind_length()
	blinds += 1
	_dazzle = 0.0
	_release_grip()
	body.set_blinded(true)
	Audio.sfx("kraken_blind", global_position, 8.0, 0.0)
	Feel.shake(0.4)
	Events.message.emit("The light is in its eyes: it's blind! Hit it with everything!" if not _told_blind else "Blind again! Now! (it turns its head sooner each time)")
	_told_blind = true

func _unblind() -> void:
	blinded = 0.0
	_rest = BLIND_REST
	body.set_blinded(false)
	_roar()

## A light on one of its arms (stage 1): the camp's searchlights drive them back.
func lit_arm(arm: int, mode: int, delta: float) -> void:
	if stage != 1 or phase == "rise" or arm < 0 or arm >= _arm_lit.size() or not body.arm_out(arm):
		return
	_arm_lit_t[arm] = 0.15
	_arm_lit[arm] += delta * (2.0 if mode == Lamp.Mode.FOCUSED else 1.0)
	if _arm_lit[arm] >= ARM_LIGHT_TIME:
		_recoil(arm, "light")

## Where a light can find an arm, tip first (stage 1 only: later the lamp is for its eyes).
func arm_light_points(arm: int) -> Array:
	var out: Array = []
	if stage != 1 or phase == "rise" or body == null or arm < 0 or not body.arm_out(arm):
		return out
	var pts := body.arm_points(arm)
	for k in range(pts.size() - 1, 0, -1):
		out.append(pts[k])
	return out

# The arm flinches back under the water and won't come again for a while.
func _recoil(arm: int, why: String) -> void:
	if phase == "dying" or phase == "dead" or not body.arm_out(arm):
		return
	body.recoil(arm, RECOIL_TIME)
	_arm_shy[arm] = SHY_TIME
	_arm_lit[arm] = 0.0
	_arm_sting[arm] = 0
	_tips[arm].global_position = HIDE
	recoils += 1
	_slam_t = maxf(_slam_t, 1.0)
	Audio.sfx("kraken_sever", body.arm_tip(arm), -2.0, 0.15)
	if why == "fire" and not _told_fire:
		_told_fire = true
		Events.message.emit("Fire! It can't abide the fire either: burn its arms back!")

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
		_hurt_arm(arm, amount, kind, from_dir, at)
		return
	var dmg := roundi(float(amount) * _mult())
	_hurt(dmg)
	body.hurt_flash()
	FX.spray(get_parent(), at + Vector3(0.0, 1.2, 0.0), from_dir, Color(0.45, 0.55, 0.42))
	if source is Player and not source.ai:
		Feel.blow(false, dmg >= 60)
		FX.damage_number(get_parent(), at + Vector3(randf_range(-0.5, 0.5), 2.4, 0.0), dmg)

# What a hit on its head counts for now: more blind, more reared.
func _mult() -> float:
	var m := 1.0
	if blinded > 0.0:
		m = BLIND_MULT
	if _rear_left > 0.0:
		m = maxf(m, REAR_MULT)
	return m

func _hurt(dmg: int) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - dmg)
	if hp == 0:
		_enter("dying")

static func _is_fire(kind: String) -> bool:
	return kind == "bomb" or kind == "flame" or kind == "fire"

func _hurt_arm(arm: int, amount: int, kind: String, from_dir: Vector3, at: Vector3) -> void:
	if not body.arm_out(arm):
		return
	_arm_hp[arm] -= amount
	FX.spray(get_parent(), at + Vector3(0.0, 0.6, 0.0), from_dir, Color(0.45, 0.55, 0.42))
	Audio.sfx("hit", at, -2.0)
	if _arm_hp[arm] <= 0:
		_sever(arm)
		return
	if stage == 1:
		# Over the wire, fire drives an arm back and sets it burning; arrows sting it back.
		if _is_fire(kind):
			_hurt(amount)
			_burn_arm(arm, ARM_BURN)
		else:
			_arm_sting[arm] += amount
			if _arm_sting[arm] >= STING:
				_recoil(arm, "sting")

func _burn_arm(arm: int, t: float) -> void:
	if phase == "dying" or phase == "dead":
		return
	_arm_burn[arm] = maxf(_arm_burn[arm], t)
	_burning = maxf(_burning, t)
	_recoil(arm, "fire")

func _sever(arm: int) -> void:
	arms_cut += 1
	_arm_hp[arm] = ARM_HP
	_arm_back[arm] = ARM_REGROW
	body.sever(arm)
	body.set_wound(arm, Vector3.INF)
	_tips[arm].global_position = HIDE
	Audio.sfx("kraken_sever", body.arm_tip(arm), 6.0, 0.05)
	if arm == _grip_arm:
		_grip_arm = -1
	if stage == 2:
		# On its way it can least afford it: it costs it more, it stops, it is slower
		# after, and the arm does not grow again until it is at the light.
		cross_cuts += 1
		_stall = SEVER_STALL
		_arm_back[arm] = 9999.0
		Events.message.emit("An arm cut back! It slows.")
		_hurt(SEVER_DAMAGE_CROSS)
	else:
		Events.message.emit("An arm cut back!")
		_hurt(SEVER_DAMAGE)

## Fire on it (a petrol bomb, the flamer, a burning pool).
func burn(t: float, arm: int) -> void:
	if phase == "dying" or phase == "dead" or phase == "rise":
		return
	if arm >= 0 and stage == 1 and body.arm_out(arm):
		_burn_arm(arm, maxf(t, ARM_BURN))
		return
	_burning = maxf(_burning, t)

# ---- what it does ----

func _physics_process(delta: float) -> void:
	if phase == "dead" or phase == "dying" or Net.is_client():
		return
	_phase_t += delta
	_rest = maxf(0.0, _rest - delta)
	_slow = maxf(0.0, _slow - delta)
	_stall = maxf(0.0, _stall - delta)
	_lit_t = maxf(0.0, _lit_t - delta)
	if _lit_t <= 0.0:
		_dazzle = maxf(0.0, _dazzle - delta)
	for i in KrakenBody.ARMS:
		_arm_shy[i] = maxf(0.0, _arm_shy[i] - delta)
		_arm_lit_t[i] -= delta
		if _arm_lit_t[i] <= 0.0:
			_arm_lit[i] = maxf(0.0, _arm_lit[i] - delta)
		if _arm_back[i] > 0.0:
			_arm_back[i] -= delta
			if _arm_back[i] <= 0.0:
				body.regrow(i, 4.0)
	_burn_fx(delta)
	if _burning > 0.0:
		_burning -= delta
		_fire_acc += FIRE_DPS * _mult() * delta
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
				_swim(delta, MOVE_SPEED)
			else:
				_camp(delta)
				if _phase_t > CAMP_TIME or _camp_in_reach().is_empty():
					_enter("cross")
		"cross":
			_swim(delta, cross_speed())
			_crossing(delta)
			if _way.is_empty():
				_enter("light")
		"light":
			body.face(lighthouse.global_position)
			_at_light(delta)

func _swim(delta: float, speed: float) -> void:
	if _way.is_empty():
		return
	var to := Vector3(_way[0].x, Terrain.SEA_LEVEL, _way[0].y) - global_position
	to.y = 0.0
	if to.length() < 0.8:
		_way.pop_front()
		return
	global_position += to.normalized() * minf(speed * delta, to.length())
	body.face(global_position + to)

# A burning arm: flames and embers along it.
func _burn_fx(delta: float) -> void:
	_ember_t -= delta
	var puff := _ember_t <= 0.0
	if puff:
		_ember_t = 0.18
	for i in KrakenBody.ARMS:
		if _arm_burn[i] <= 0.0:
			continue
		_arm_burn[i] -= delta
		if puff:
			var pts := body.arm_points(i)
			if pts.size() > 3:
				var p: Vector3 = pts[randi_range(pts.size() / 2, pts.size() - 1)]
				if p.y > Terrain.SEA_LEVEL:
					FX.embers(get_parent(), p)

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
		if not body.arm_out(i) or body.arm_busy(i) or _arm_shy[i] > 0.0 or i == _grip_arm:
			continue
		var d := body.arm_tip(i).distance_to(target)
		if d < best_d:
			best_d = d
			best = i
	return best

func _any_busy() -> bool:
	for i in KrakenBody.ARMS:
		if body.arm_busy(i):
			return true
	return false

func _slam_due(delta: float, every: float) -> bool:
	if blinded > 0.0 or _rear_left > 0.0:
		return false
	_slam_t -= delta * (0.5 if _slow > 0.0 else 1.0)
	if _slam_t > 0.0:
		return false
	_slam_t = every * randf_range(0.8, 1.2)
	return true

# Stage 1: one arm over the wire at a time.
func _camp(delta: float) -> void:
	body.face(Vector3(Terrain.CAMP_C.x, 0.0, Terrain.CAMP_C.y))
	if _any_busy() or not _slam_due(delta, SLAM_EVERY_CAMP):
		return
	var near := _camp_in_reach()
	# Its arms are for the camp: a keeper who has come over to fight it there is in
	# danger where they land, but is only gone for once nothing of the camp is in reach.
	var at := Vector3.INF
	var k := _keeper_in_reach() if near.is_empty() else null
	if k != null:
		at = k.global_position
	elif not near.is_empty():
		at = (near[randi() % near.size()] as Node3D).global_position
	if at == Vector3.INF:
		return
	var arm := _free_arm(at)
	if arm >= 0:
		body.arm_slam(arm, at, CAMP_WINDUP)

# Stage 2: on its way round, it reaches for keepers on the path and the bridge, and
# for anything of theirs within reach.
func _crossing(delta: float) -> void:
	if not _slam_due(delta, SLAM_EVERY_CROSS):
		return
	var at := Vector3.INF
	var k := _keeper_in_reach()
	if k != null:
		at = k.global_position + Vector3(k.velocity.x, 0.0, k.velocity.z) * 0.4
	else:
		var home := Enemy.nearest_home(global_position)
		if home != null and Geo.flat_dist(home.global_position, global_position) <= ARM_REACH:
			at = home.global_position
	if at == Vector3.INF:
		return
	var arm := _free_arm(at)
	if arm >= 0:
		body.arm_slam(arm, at, SLAM_WINDUP, LIE_CROSS)

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

# Stage 3.
func _at_light(delta: float) -> void:
	# The last gasp.
	if not reared and hp <= roundi(float(max_hp) * REAR_AT):
		_rear()
	if _rear_left > 0.0:
		_rear_left -= delta
		if _rear_left <= 0.0:
			_rear_left = 0.0
			_slam_t = 2.0
		return
	_step_grip(delta)
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

# It heaves itself up out of the sea: everything at it now.
func _rear() -> void:
	reared = true
	_rear_left = REAR_TIME
	_release_grip()
	if blinded > 0.0:
		blinded = 0.0
		body.set_blinded(false)
	_all_rest()
	body.rear(REAR_TIME)
	Audio.sfx("kraken_roar", global_position, 10.0, 0.0)
	Audio.sfx("kraken_rise", global_position, 6.0, 0.0)
	Feel.shake(0.9)
	Events.message.emit("It rears up out of the sea! Everything you have, now!")
	phase_changed.emit("rear")

# Sighted a while at the light, it gets an arm up the tower; if it is not blinded before
# the grip closes, it shakes the tower and the keeper out of the lamp room.
func _step_grip(delta: float) -> void:
	if blinded > 0.0 or lighthouse.is_destroyed():
		return
	if _grip_arm < 0:
		_grip_t += delta
		if _grip_t < GRIP_EVERY:
			return
		var top := lighthouse.lamp.global_position if lighthouse.lamp != null else lighthouse.global_position + Vector3(0.0, 14.0, 0.0)
		var arm := _free_arm(top)
		if arm < 0:
			return
		_grip_t = 0.0
		_grip_arm = arm
		# Its head turned away from the lamp, it can't be blinded until it looks back:
		# the grip gives the lamp that long and GRIP_TIME more.
		_grip_left = GRIP_TIME + _rest
		body.arm_reach(arm, top)
		Audio.sfx("kraken_roar", global_position, 2.0, 0.1)
		Events.message.emit("It has an arm up the tower! Blind it before it shakes you out of the lamp room!" if not _told_grip else "An arm up the tower again!")
		_told_grip = true
		return
	if not body.arm_out(_grip_arm):
		_grip_arm = -1
		return
	_grip_left -= delta
	if _grip_left > 0.0:
		return
	_release_grip()
	_shake_tower()

func _release_grip() -> void:
	if _grip_arm >= 0:
		body.arm_rest(_grip_arm)
	_grip_arm = -1
	_grip_left = 0.0

func _shake_tower() -> void:
	Feel.shake(0.9, lighthouse.global_position)
	Audio.sfx("kraken_slam", lighthouse.global_position, 6.0, 0.05)
	lighthouse.take_damage(GRIP_DAMAGE)
	var lamp := lighthouse.lamp
	if lamp != null and lamp.operator is Player and is_instance_valid(lamp.operator):
		var op := lamp.operator as Player
		if op.operating:
			op._toggle_operate()
			Events.message.emit("It has shaken the tower: %s is thrown from the lamp!" % Players.NAMES[op.idx % Players.NAMES.size()])
			return
	Events.message.emit("It has shaken the tower!")

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
			s.take_damage(SLAM_CAMP if stage == 1 else SLAM_STRUCTURE)
	for p in players:
		if is_instance_valid(p) and Geo.flat_dist(p.global_position, at) <= SLAM_RADIUS and absf(p.global_position.y - at.y) < 3.0:
			p.take_damage(SLAM_KEEPER_CAMP if stage == 1 else SLAM_KEEPER, at)
	for v in get_tree().get_nodes_in_group("villagers"):
		if v.exposed() and Geo.flat_dist(v.global_position, at) <= SLAM_RADIUS:
			v.take()

# The places a weapon can find it: across the front of its head, and on each arm where
# it lies on the ground (the outer half of it). From the crossing on, that place shows a
# pale wound: where to cut.
func _place_parts() -> void:
	var toward := lighthouse.global_position if stage >= 2 else Vector3(Terrain.CAMP_C.x, 0.0, Terrain.CAMP_C.y)
	var f := toward - global_position
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var up := body.risen > 0.6
	for i in _head.size():
		var a := deg_to_rad(lerpf(-70.0, 70.0, float(i) / float(maxi(_head.size() - 1, 1))))
		var p := global_position + f.rotated(Vector3.UP, a) * HEAD_SPOT_R
		p.y = maxf(Terrain.height_at(p.x, p.z), Terrain.SEA_LEVEL) + HEAD_SPOT_Y
		_head[i].global_position = p if up else HIDE
	for i in _tips.size():
		var at := _arm_ground_point(i)
		_tips[i].global_position = at if at != Vector3.INF else HIDE
		var mark := at if stage >= 2 else Vector3.INF
		body.set_wound(i, mark)
		if mark != Vector3.INF and stage == 2 and not _told_cut:
			_told_cut = true
			Events.message.emit("An arm down on the rock: cut it at the pale wound! (boathook, shotgun)")

# Where on the ground an arm can be got at: the furthest of its outer points lying on
# land. Over the wire (stage 1), an arm reared over the land can be got at where it
# comes over (the middle of it), not under the blow it is about to strike.
func _arm_ground_point(i: int) -> Vector3:
	if not body.arm_out(i):
		return Vector3.INF
	var pts := body.arm_points(i)
	for k in range(pts.size() - 1, pts.size() / 2 - 1, -1):
		var p: Vector3 = pts[k]
		var g := Terrain.height_at(p.x, p.z)
		if g > Terrain.SEA_LEVEL + 0.1 and p.y < g + 1.8:
			return Vector3(p.x, g, p.z)
	if stage == 1 and body.arm_busy(i):
		var aim: Vector3 = body._arms[i].slam_at
		for k in range(pts.size() / 2, pts.size()):
			var p: Vector3 = pts[k]
			var g2 := Terrain.height_at(p.x, p.z)
			if g2 > Terrain.SEA_LEVEL + 0.1 and Geo.flat_dist(p, aim) > SLAM_RADIUS + 1.5:
				return Vector3(p.x, g2, p.z)
	return Vector3.INF

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
		_hurt(roundi(float(FIGHTER_DMG) * _mult()))
		body.hurt_flash()

func _on_body_died() -> void:
	phase = "dead"
	phase_changed.emit(phase)
	died.emit()
