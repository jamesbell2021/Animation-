class_name Arsenal
extends Node3D
## What a keeper fights with besides the boathook, all of it from the garden shed's
## workbench (Shed): a longbow of driftwood, the old keeper's double-barrelled shotgun
## (one gun, few cartridges), the weed burner rigged as a flamer (one, burning bio from
## its tank), and petrol bombs of bio in bottles. The keeper switches between what they
## carry (Tab or the mouse wheel, 1 to 5, the pad's d-pad); the attack button works
## whichever is in hand. Rat poison from the shed goes on the trap cairns (TrapSlot).

const ORDER := ["hook", "bow", "shotgun", "flamer", "bombs"]
const NAMES := {"hook": "Boathook", "bow": "Longbow", "shotgun": "Shotgun", "flamer": "Flamer", "bombs": "Petrol bombs"}

# The longbow: hold to draw, let go to loose. A full draw hits hard and flies flat.
const DRAW_TIME := 0.8
const MIN_DRAW := 0.2
const ARROW_DMG_MIN := 12
const ARROW_DMG_MAX := 40
const DRAW_SLOW := 0.5
# The shotgun: a cone of shot from each barrel, brutal close in. Two barrels, then the
# keeper breaks it open and loads two more from the store.
const PELLETS := 9
const SPREAD_DEG := 24.0
const SHOT_RANGE := 11.0
const PELLET_DMG := 7
const PELLET_WIDTH := 0.55
const CLOSE := 3.5
const CLOSE_MULT := 1.6
const BARREL_CD := 0.3
const RELOAD_TIME := 1.6
# The flamer: a roaring tongue of burning bio. Whatever's in it stops and burns, and
# burns on after; a tank lasts about six seconds, and refills from the store's bio.
const FLAME_RANGE := 5.5
const FLAME_HALF_DEG := 17.0
const FLAME_DPS := 34.0
const FLAME_USE := 16.0
const FLAME_AFTERBURN := 2.5
const FLAME_SLOW := 0.6
const TANK := 100.0
const REFILL_TIME := 1.5
const REFILL_COST := {"bio": 1}
# Petrol bombs: thrown where the keeper aims, a pool of fire where they smash.
const BOMB_RANGE := 12.0
const BOMB_CD := 0.8
const MUZZLE_UP := 1.25
const WOOD := Color(0.42, 0.3, 0.18)
const STEEL := Color(0.2, 0.2, 0.22)

var keeper: Player
var weapon := "hook"
## How far the bow is drawn, 0 to 1 (-1: not drawing).
var draw := -1.0
var _cd := 0.0
var _reload_t := 0.0
var _refill_t := 0.0
var _flaming := false
var _burn_acc := {}
var _models := {}
var _tank: Node3D
var _flame: GPUParticles3D
var _flame_light: OmniLight3D
var _flame_sound: AudioStreamPlayer3D
# Whether the keeper handed this frame to the arsenal: if not (busy, knocked down, in a
# menu, gone in), the bow is let down and the flame goes out.
var _ticked := false

func _init(p_keeper: Player = null) -> void:
	keeper = p_keeper

func _ready() -> void:
	_build_models()
	refresh()

## Whether this keeper has a weapon in hand to use (the boathook always).
func available(w: String) -> bool:
	match w:
		"hook":
			return true
		"bombs":
			return Stock.get_amount("bombs") > 0
		_:
			return carries(w)

func carries(w: String) -> bool:
	return keeper != null and keeper.idx < Run.arms.size() and Run.arms[keeper.idx].has(w)

## Who has one of the shed's single weapons ("shotgun", "flamer"), or -1 if it's in the shed.
static func holder(w: String) -> int:
	for i in Run.arms.size():
		if Run.arms[i].has(w):
			return i
	return -1

func give(w: String) -> void:
	if not carries(w):
		Run.arms[keeper.idx].append(w)
	select(w)

func take_away(w: String) -> void:
	Run.arms[keeper.idx].erase(w)
	if weapon == w:
		select("hook")
	else:
		refresh()

func select(w: String) -> void:
	if not available(w):
		return
	if w != weapon:
		_stop_flame()
		draw = -1.0
		_reload_t = 0.0
		_refill_t = 0.0
		weapon = w
		Audio.sfx("creak", keeper.global_position, -12.0, 0.2)
	refresh()

## The next (or previous) thing the keeper carries.
func cycle(step: int) -> void:
	var i := ORDER.find(weapon)
	for k in ORDER.size():
		i = posmod(i + step, ORDER.size())
		if available(ORDER[i]):
			select(ORDER[i])
			return

## Whether the attack button is this arsenal's to handle (anything but the boathook).
func in_hand() -> bool:
	return weapon != "hook"

## How fast the keeper can move with it: slower drawing the bow or with the flamer going.
func move_mult() -> float:
	if draw >= 0.0:
		return DRAW_SLOW
	if _flaming:
		return FLAME_SLOW
	return 1.0

func busy() -> bool:
	return draw >= 0.0 or _flaming

## Each frame the keeper is free to fight: `pressed` this frame, `held` down.
func tick(delta: float, pressed: bool, held: bool) -> void:
	_ticked = true
	if not available(weapon):
		select("hook")
		return
	_cd = maxf(0.0, _cd - delta)
	match weapon:
		"bow":
			_bow(delta, pressed, held)
		"shotgun":
			_shotgun(delta, pressed)
		"flamer":
			_flamer(delta, held)
		"bombs":
			if pressed and _cd <= 0.0:
				_throw_bomb()

## Stop anything going on (knocked down, gone in, a job).
func cease() -> void:
	draw = -1.0
	_stop_flame()

func _face() -> void:
	keeper._aim_face_t = Player.AIM_FACE_TIME
	keeper.facing = keeper.aim_yaw()
	keeper.rotation.y = keeper.facing

func _muzzle() -> Vector3:
	return keeper.global_position + Vector3(0.0, MUZZLE_UP, 0.0) + keeper.aim_dir() * 0.7

## Hurt a creature as this keeper's weapon of this kind (for the dawn tally).
static func strike(e: Node, dmg: int, dir: Vector3, by: Node, kind: String) -> void:
	if by != null and is_instance_valid(by) and by is Player:
		by.hit_kind = kind
		e.take_damage(dmg, dir, by)
		by.hit_kind = "hook"
	else:
		e.last_hit = kind
		e.take_damage(dmg, dir, null)

static func _live(e: Node) -> bool:
	return e is Enemy and e.hp > 0 and e.state != &"Emerge" and e.state != &"Retreat"

# ---- the longbow ----

func _bow(delta: float, pressed: bool, held: bool) -> void:
	if draw < 0.0:
		if pressed and _cd <= 0.0:
			if Stock.get_amount("arrows") <= 0:
				Events.message.emit("No arrows: whittle some at the shed (driftwood and scrap).")
				_cd = 0.5
				return
			draw = 0.0
			Audio.sfx("creak", keeper.global_position, -6.0, 0.2)
		return
	_face()
	if held:
		draw = minf(1.0, draw + delta / DRAW_TIME)
		return
	# Let go: loose, if it was drawn far enough to fly.
	var power := draw
	draw = -1.0
	if power < MIN_DRAW or not Stock.spend({"arrows": 1}):
		return
	_cd = 0.25
	var a := Arrow.new()
	a.shooter = keeper
	a.from = _muzzle()
	# Aimed at the body of whatever's on the ground under the aim, so a keeper up on the
	# crag can shoot down onto a beach.
	var target := keeper.flare_point() + Vector3(0.0, 0.9, 0.0)
	a.dir = (target - a.from).normalized() if target.distance_to(a.from) > 1.0 else keeper.aim_dir()
	a.damage = roundi(lerpf(ARROW_DMG_MIN, ARROW_DMG_MAX, power))
	a.speed = lerpf(18.0, Arrow.SPEED, power)
	keeper.get_parent().add_child(a)
	Audio.sfx("bow", keeper.global_position, -2.0, 0.1)
	if keeper._clips():
		keeper.rig.shot("flare")

# ---- the shotgun ----

func _shotgun(delta: float, pressed: bool) -> void:
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			var n := mini(2 - Run.barrels, Stock.get_amount("shells"))
			Stock.spend({"shells": n})
			Run.barrels += n
			Audio.sfx("hammer", keeper.global_position, -8.0, 0.1)
		return
	if not pressed or _cd > 0.0:
		return
	if Run.barrels <= 0:
		if Stock.get_amount("shells") > 0:
			_reload_t = RELOAD_TIME
			Audio.sfx("creak", keeper.global_position, -4.0, 0.1)
		else:
			Audio.sfx("trap_snap", keeper.global_position, -14.0, 0.1)
			Events.message.emit("Click. No cartridges left.")
			_cd = 0.5
		return
	_face()
	Run.barrels -= 1
	_cd = BARREL_CD
	fire_shot(keeper.aim_dir())
	if Run.barrels == 0 and Stock.get_amount("shells") > 0:
		_reload_t = RELOAD_TIME + BARREL_CD

## One barrel, along this way: each pellet strikes the first creature in its line.
func fire_shot(aim: Vector3) -> void:
	var from := _muzzle()
	var hits := {}
	for i in PELLETS:
		var a := deg_to_rad(-SPREAD_DEG * 0.5 + SPREAD_DEG * (float(i) + randf_range(0.1, 0.9)) / float(PELLETS))
		var d := aim.rotated(Vector3.UP, a)
		var best: Node = null
		var best_t := SHOT_RANGE
		for e in get_tree().get_nodes_in_group("enemies"):
			if not _live(e) or absf(e.global_position.y + 1.0 - from.y) > 2.2:
				continue
			var to: Vector3 = e.global_position - from
			to.y = 0.0
			var t := to.dot(d)
			if t <= 0.0 or t >= best_t:
				continue
			if (to - d * t).length() <= PELLET_WIDTH:
				best = e
				best_t = t
		if best != null:
			var dmg := float(PELLET_DMG) * (CLOSE_MULT if best_t < CLOSE else 1.0)
			hits[best] = float(hits.get(best, 0.0)) + dmg
	for e in hits:
		var dir: Vector3 = e.global_position - keeper.global_position
		dir.y = 0.0
		strike(e, roundi(hits[e]), dir.normalized(), keeper, "shot")
	Audio.sfx("shotgun", from, 2.0, 0.06)
	FX.sparks(keeper.get_parent(), from)
	FX.emitter(keeper.get_parent(), from, FX._puff_mesh_ref(), Color(0.75, 0.72, 0.68, 0.45), 8, 0.9, aim, 25.0, 1.5, 3.5, -0.3, 0.4, 0.9, true, true)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.45)
	flash.light_energy = 8.0
	flash.omni_range = 9.0
	keeper.get_parent().add_child(flash)
	flash.global_position = from
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.12)
	tw.tween_callback(flash.queue_free)
	keeper.shove(-aim * 1.5)
	if keeper._clips():
		keeper.rig.shot("flare")

# ---- the flamer ----

func _flamer(delta: float, held: bool) -> void:
	if _refill_t > 0.0:
		_refill_t -= delta
		if _refill_t <= 0.0:
			Run.flamer_fuel = TANK
			Audio.sfx("refuel", keeper.global_position, -4.0, 0.1)
		return
	if not held:
		_stop_flame()
		return
	if Run.flamer_fuel <= 0.0:
		_stop_flame()
		if Stock.spend(REFILL_COST):
			_refill_t = REFILL_TIME
			Events.message.emit("%s pours a bio into the flamer's tank." % keeper.keeper_name())
		elif _cd <= 0.0:
			Events.message.emit("The flamer's tank is dry, and no bio in the store.")
			_cd = 1.0
		return
	_face()
	if not _flaming:
		_flaming = true
		_flame.emitting = true
		_flame_light.visible = true
		_flame_sound.play()
		Audio.sfx("ignite", keeper.global_position, -2.0, 0.1)
	Run.flamer_fuel = maxf(0.0, Run.flamer_fuel - FLAME_USE * delta)
	_flame_light.light_energy = 3.5 + randf_range(-0.8, 0.8)
	flame_tick(delta, keeper.aim_dir())

## The stream's work for one frame, along this way.
func flame_tick(delta: float, aim: Vector3) -> void:
	var from := _muzzle()
	var half := deg_to_rad(FLAME_HALF_DEG)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _live(e) or absf(e.global_position.y + 1.0 - from.y) > 2.2:
			continue
		var to: Vector3 = e.global_position - from
		to.y = 0.0
		var d := to.length()
		if d > FLAME_RANGE or (d > 0.6 and aim.angle_to(to / d) > half):
			continue
		e.burn_tick(delta)
		e.set_alight(FLAME_AFTERBURN)
		var acc: float = float(_burn_acc.get(e, 0.0)) + FLAME_DPS * delta
		if acc >= 1.0:
			var n := int(acc)
			acc -= float(n)
			strike(e, n, Vector3.ZERO, null, "flame")
		_burn_acc[e] = acc
	for k in _burn_acc.keys():
		if not is_instance_valid(k):
			_burn_acc.erase(k)

func _stop_flame() -> void:
	if not _flaming:
		return
	_flaming = false
	if _flame != null:
		_flame.emitting = false
	if _flame_light != null:
		_flame_light.visible = false
	if _flame_sound != null:
		_flame_sound.stop()

func _physics_process(_delta: float) -> void:
	if not _ticked:
		cease()
	_ticked = false
	# The stream comes from the wand's nozzle and goes where the keeper aims.
	if _flame != null and keeper != null:
		_flame.global_position = _muzzle()
		var pm := _flame.process_material as ParticleProcessMaterial
		pm.direction = keeper.aim_dir() + Vector3(0.0, 0.08, 0.0)
		_flame_light.global_position = _muzzle() + keeper.aim_dir() * 2.0

# ---- petrol bombs ----

func _throw_bomb() -> void:
	if not Stock.spend({"bombs": 1}):
		return
	_cd = BOMB_CD
	var to := _bomb_point()
	var d := to - keeper.global_position
	d.y = 0.0
	if d.length() > BOMB_RANGE:
		to = keeper.global_position + d.normalized() * BOMB_RANGE
		to.y = maxf(Terrain.height_at(to.x, to.z), Terrain.SEA_LEVEL)
	if d.length() > 0.05:
		keeper._aim = d.normalized()
	_face()
	var b := PetrolBomb.new()
	b.thrower = keeper
	b.from = keeper.global_position + Vector3(0.0, 1.6, 0.0) + keeper.aim_dir() * 0.3
	b.to = to
	keeper.get_parent().add_child(b)
	Audio.sfx("swing", keeper.global_position, -2.0, 0.1)
	if keeper._clips() and keeper.rig.has_clip("throw"):
		keeper.rig.shot("throw")
	if Stock.get_amount("bombs") <= 0:
		select("hook")

## Where a bomb should land: under the mouse; on a pad (no cursor), at the nearest
## creature within 25° of the aim and in range, or ahead along the aim.
func _bomb_point() -> Vector3:
	if keeper.camera != null and keeper.idx == 0 and (Players.devices.size() <= keeper.idx or Players.devices[keeper.idx] == Players.KEYBOARD_MOUSE):
		return keeper.flare_point()
	var best: Node3D = null
	var best_d := BOMB_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _live(e):
			continue
		var to: Vector3 = e.global_position - keeper.global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and d > 1.5 and rad_to_deg(keeper.aim_dir().angle_to(to / d)) < 25.0:
			best = e
			best_d = d
	return best.global_position if best != null else keeper.flare_point()

# ---- what's in hand ----

## Show what's in hand (and the flamer's tank on the back while it's carried).
func refresh() -> void:
	if keeper == null or _models.is_empty():
		return
	var working: bool = keeper._job_tool != ""
	for w in _models:
		_models[w].visible = w == weapon and not working
	keeper._hook_holder.visible = weapon == "hook" and keeper.has_hook and not working
	_tank.visible = carries("flamer")

func hud_text() -> String:
	match weapon:
		"bow":
			if draw >= 0.0:
				return "Longbow drawn %d%% · %d arrows" % [roundi(draw * 100.0), Stock.get_amount("arrows")]
			return "Longbow · %d arrows" % Stock.get_amount("arrows")
		"shotgun":
			if _reload_t > 0.0:
				return "Shotgun: reloading · %d cartridges" % Stock.get_amount("shells")
			return "Shotgun %s · %d cartridges" % ["●".repeat(Run.barrels) + "○".repeat(2 - Run.barrels), Stock.get_amount("shells")]
		"flamer":
			if _refill_t > 0.0:
				return "Flamer: filling"
			return "Flamer %d%% · bio %d" % [roundi(Run.flamer_fuel), Stock.get_amount("bio")]
		"bombs":
			return "Petrol bombs %d" % Stock.get_amount("bombs")
	return "Boathook"

func _build_models() -> void:
	var pivot: Node3D = keeper._hook_pivot
	var wood := Look.wood(WOOD, 0.6)
	var steel := Look.flat_mat(STEEL, 0.35)
	steel.metallic = 0.7
	# A longbow: a driftwood stave bent in an arc, kelp-cord string.
	var bow := Node3D.new()
	bow.scale = Vector3.ONE * 1.4
	pivot.add_child(bow)
	for i in 8:
		var t := -1.0 + 2.0 * (float(i) + 0.5) / 8.0
		var seg := Geo.box(bow, Vector3(0.035, 0.18, 0.035), Color.WHITE, Vector3(0.0, t * 0.66, -0.12 - 0.12 * (1.0 - t * t)))
		seg.rotation.x = -t * 0.55
		seg.material_override = wood
	var string := Geo.box(bow, Vector3(0.008, 1.32, 0.008), Color.WHITE, Vector3(0.0, 0.0, -0.1))
	string.material_override = Look.flat_mat(Color(0.5, 0.45, 0.3))
	_models["bow"] = bow
	# The double-barrelled shotgun: walnut stock, two blued barrels side by side.
	var gun := Node3D.new()
	gun.scale = Vector3.ONE * 1.5
	pivot.add_child(gun)
	var stock := Geo.box(gun, Vector3(0.06, 0.1, 0.34), Color.WHITE, Vector3(0.0, -0.03, 0.08))
	stock.material_override = Look.wood(Color(0.32, 0.18, 0.1), 0.5)
	for sx in [-0.018, 0.018]:
		var barrel := Geo.cyl(gun, 0.016, 0.62, Color.WHITE, Vector3(sx, 0.02, -0.38))
		barrel.rotation.x = PI * 0.5
		barrel.material_override = steel
	_models["shotgun"] = gun
	# The flamer's wand: the weed burner's lance with its brass valve and hose.
	var wand := Node3D.new()
	wand.scale = Vector3.ONE * 1.5
	pivot.add_child(wand)
	var lance := Geo.cyl(wand, 0.014, 0.6, Color.WHITE, Vector3(0.0, 0.0, -0.32))
	lance.rotation.x = PI * 0.5
	lance.material_override = steel
	var bell := Geo.cyl(wand, 0.035, 0.12, Color.WHITE, Vector3(0.0, 0.0, -0.66), 0.045)
	bell.rotation.x = -PI * 0.5
	bell.material_override = Look.flat_mat(Color(0.12, 0.1, 0.09), 0.6)
	var valve := Geo.box(wand, Vector3(0.05, 0.05, 0.07), Color.WHITE, Vector3(0.0, 0.03, -0.02))
	valve.material_override = Look.flat_mat(Color(0.75, 0.58, 0.25), 0.3)
	_models["flamer"] = wand
	# A petrol bomb: a bottle of bio with a kelp rag in the neck, lit.
	var bottle := Node3D.new()
	bottle.scale = Vector3.ONE * 1.5
	pivot.add_child(bottle)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.3, 0.55, 0.3, 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	var body := Geo.cyl(bottle, 0.045, 0.16, Color.WHITE, Vector3(0.0, 0.02, -0.12))
	body.material_override = glass
	var neck := Geo.cyl(bottle, 0.018, 0.07, Color.WHITE, Vector3(0.0, 0.13, -0.12))
	neck.material_override = glass
	var rag := Geo.box(bottle, Vector3(0.03, 0.06, 0.03), Color.WHITE, Vector3(0.0, 0.19, -0.12))
	rag.material_override = Look.flat_mat(Color(0.3, 0.38, 0.2))
	Look.glint(bottle, Vector3(0.0, 0.23, -0.12), Color(1.0, 0.55, 0.2), 0.2)
	_models["bombs"] = bottle
	# The weed burner's gas bottle, strapped to the keeper's back while they carry it.
	_tank = Node3D.new()
	keeper._pose.add_child(_tank)
	_tank.position = Vector3(0.0, 1.05, 0.24)
	var cyl := Geo.cyl(_tank, 0.13, 0.5, Color.WHITE, Vector3.ZERO)
	cyl.material_override = Look.flat_mat(Color(0.62, 0.14, 0.1), 0.45)
	var cap := Geo.cyl(_tank, 0.05, 0.08, Color.WHITE, Vector3(0.0, 0.29, 0.0))
	cap.material_override = steel
	# The flame: a roaring stream of fire, its light, its roar.
	_flame = FX.emitter(self, global_position, FX._puff_mesh_ref(), Color(1.0, 0.55, 0.15, 0.95),
		64, 0.42, Vector3.FORWARD, 9.0, 11.0, 14.0, -1.5, 0.35, 1.0, false, true, 2.2)
	if _flame != null:
		_flame.emitting = false
	else:
		_flame = GPUParticles3D.new()
		_flame.process_material = ParticleProcessMaterial.new()
		add_child(_flame)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(1.0, 0.55, 0.2)
	_flame_light.omni_range = 7.0
	_flame_light.visible = false
	add_child(_flame_light)
	_flame_sound = AudioStreamPlayer3D.new()
	_flame_sound.stream = Audio.stream("flamer")
	_flame_sound.bus = "SFX"
	_flame_sound.volume_db = -2.0
	_flame_sound.unit_size = 8.0
	add_child(_flame_sound)
