class_name Rules
extends RefCounted
## Every number the rules depend on, in one place, and the pure formulas built on them.
## Nothing here touches the scene tree: the battle resolves with these, the HUD previews
## with these, and the tests check these, so the three can never disagree.
## Where the GDD left a gap or a contradiction, the value chosen is noted (see
## docs/DESIGN_NOTES.md for the reasoning).

# --- Time Units (GDD 2.1) ---------------------------------------------------------------
const TU_STEP := 4
const TU_DIAGONAL := 6
const TU_CROUCHED_STEP_EXTRA := 2   # GDD code charged 6 crouched; the table never said. +2 a step.
const TU_ROTATE_45 := 1
const TU_STANCE := 3
const TU_RELOAD := 12
const TU_DOOR := 4
const TU_VALVE := 8
const TU_HAND_FLARE := 6
const TU_MORTAR := 15
const TU_FIELD_REPAIR := 15
const TU_PATCH_UP := 15
const TU_THROW := 18
const TU_DRILL := 20
const TU_JOURNAL := 8

## Fire modes cost a share of the shooter's Max TU (GDD 2.1).
const SHOT_FRACTION := {"snap": 0.25, "aimed": 0.5, "burst": 0.6}
## A unit ending its turn holding at least this share of Max TU is on Overwatch (GDD 2.3).
const OVERWATCH_FRACTION := 1.0 / 3.0

# --- Light (GDD 2.2; the bands are made contiguous, the GDD left 0.2-0.3 and 0.7-0.8 out) ---
enum Band { PITCH, DIM, BRIGHT }
const PITCH_BELOW := 0.25
const BRIGHT_FROM := 0.75
const AMBIENT_LIGHT := 0.04
## Inside this many tiles a unit is noticed whatever its facing or the light.
const HEARING_RANGE := 2.0

# --- Accuracy (missing from the GDD; additive, then clamped) -----------------------------
const MODE_ACCURACY := {"snap": -15, "aimed": 30, "burst": -10}
const CROUCHED_SHOOTER := 10
const CROUCHED_TARGET := -10
const COVER := -20
const LIGHT_ACCURACY := {Band.PITCH: -50, Band.DIM: 0, Band.BRIGHT: 10}
const RANGE_FALLOFF_PER_TILE := 4
const MAX_SHOT_RANGE := 20.0
const FLANK_BONUS := 15
const MIN_HIT := 5
const MAX_HIT := 95
const DAMAGE_SPREAD := 0.25

# --- Steam pressure (named by the GDD's Field Repair, defined here) ----------------------
const PRESSURE_MAX := 100
const PRESSURE_REGEN := 10
const JAM_BELOW := 30
const JAM_CHANCE_PER_POINT := 2

# --- Load: Max TU = base - every kg carried over Strength / 4 ------------------------------
const CARRY_PER_STRENGTH := 0.25

# --- The swarm (GDD 6.2, with decay so one sighting doesn't pull the whole map for ever) ---
const PHEROMONE_SIGHTING := 1.0
const PHEROMONE_LURE := 2.5
const PHEROMONE_CAP := 3.0
const PHEROMONE_DECAY := 0.6
const PHEROMONE_FLOOR := 0.15
const PHEROMONE_DENSITY_RADIUS := 2.0
const AGGRO_RANGE := 15.0
const HIVE_SPAWN_EVERY := 4
const HIVE_SPAWN_CAP := 3
const NOISE_GUNFIRE := 8.0
const NOISE_MELEE := 4.0
const NOISE_BLAST := 10.0
const SEISMOGRAPH_RANGE := 10.0

# --- Flares, throws, blasts ----------------------------------------------------------------
const HAND_FLARE_RADIUS := 3.0
const MORTAR_FLARE_RADIUS := 4.0   # GDD said 7: on a 30x30 map that lit a sixth of it.
const FLARE_POWER := 1.0
const FLARE_TURNS := 3
const MORTAR_RANGE := 12.0
const THROW_RANGE := 8.0
const DYNAMITE_DAMAGE := 35
const DYNAMITE_RADIUS := 1.5
const DYNAMITE_EDGE := 0.6
const PATCH_UP_HEAL := 15

# --- Light sources -------------------------------------------------------------------------
const LAMP_POWER := 0.5
const LAMP_RADIUS := 2.5
const FUNGUS_POWER := 0.55
const FUNGUS_RADIUS := 3.0

## Eight facings, clockwise from east, in grid space (y grows "south", toward the camera).
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]
const DIR_NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]


static func shot_tu(mode: String, max_tu: int) -> int:
	return ceili(max_tu * float(SHOT_FRACTION.get(mode, 0.25)))


static func overwatch_threshold(max_tu: int) -> int:
	return ceili(max_tu * OVERWATCH_FRACTION)


static func band(light: float) -> int:
	if light < PITCH_BELOW:
		return Band.PITCH
	if light < BRIGHT_FROM:
		return Band.DIM
	return Band.BRIGHT


static func band_name(b: int) -> String:
	match b:
		Band.PITCH:
			return "Pitch black"
		Band.DIM:
			return "Dim"
	return "Bright"


## The GDD gave Max TU per class and also said it came from Agility and weight. Resolved:
## the class value is the base, and every kg (rounded up) over Strength / 4 costs 1 TU.
static func max_tu(base_tu: int, strength: int, load_kg: float) -> int:
	var over := load_kg - strength * CARRY_PER_STRENGTH
	if over <= 0.0:
		return base_tu
	return base_tu - ceili(over)


## Reaction fire (GDD 2.3, normalised). Both sides use stat x share of TU left, so the
## numbers are on the same scale; a mover spends TU with every step, so the longer it walks
## through a watched cone, the likelier the watcher fires first.
static func reaction_score(stat: int, tu: int, max_tu_value: int) -> float:
	if max_tu_value <= 0:
		return 0.0
	return stat * float(tu) / float(max_tu_value)


static func jam_chance(pressure: int) -> int:
	return maxi(0, (JAM_BELOW - pressure) * JAM_CHANCE_PER_POINT)


static func rotation_steps(from_dir: int, to_dir: int) -> int:
	var d := absi(to_dir - from_dir) % 8
	return mini(d, 8 - d)


static func dir_toward(from: Vector2i, to: Vector2i) -> int:
	var v := to - from
	if v == Vector2i.ZERO:
		return 0
	return posmod(roundi(atan2(float(v.y), float(v.x)) / (PI / 4.0)), 8)


static func dist(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Is `target` inside the cone of half-angle `half_deg` looking along `facing` from `origin`?
static func in_cone(origin: Vector2i, facing: int, target: Vector2i, half_deg: float) -> bool:
	var v := target - origin
	if v == Vector2i.ZERO:
		return true
	if half_deg >= 180.0:
		return true
	var f := Vector2(DIRS[facing]).normalized()
	return Vector2(v).normalized().dot(f) >= cos(deg_to_rad(half_deg)) - 0.001


## Is `target` behind someone at `origin` facing `facing` (more than 120 degrees off)?
static func is_behind(origin: Vector2i, facing: int, target: Vector2i) -> bool:
	var v := target - origin
	if v == Vector2i.ZERO:
		return false
	return Vector2(v).normalized().dot(Vector2(DIRS[facing]).normalized()) < -0.45


## Light from one source at distance d: full at the centre, about a quarter at the radius.
static func falloff(power: float, radius: float, d: float) -> float:
	if d > radius:
		return 0.0
	var k := d / (radius + 0.5)
	return power * (1.0 - k * k)
