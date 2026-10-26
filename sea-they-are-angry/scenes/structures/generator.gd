class_name Generator
extends Structure
## The camp's diesel generator, in its brick house. From dusk to dawn it powers the
## four towers' searchlights and the huts' lights, burning diesel as it goes, faster the
## more it has running. Keepers keep it filled from the jerrycans that wash up on the
## holm's beaches (the oil can, with diesel in the store). Run dry, the camp goes dark.

const FUEL_MAX := 100.0
## Fuel one jerrycan of diesel puts in.
const CAN_UNITS := 35.0
## Fuel a second just running; whatever it powers adds its own draw (set_draw).
const IDLE_DRAW := 0.03
## Research: a governor makes it burn this much of what it did.
const GOVERNOR := 0.67
## Below this the lights it powers flicker and dim.
const LOW := 15.0
const HOUSE := Vector3(2.6, 2.3, 3.2)
const BRICK := Color(0.42, 0.24, 0.18)

var fuel := FUEL_MAX
var running := false
var _draw := {}
var _sound: AudioStreamPlayer3D
var _exhaust: GPUParticles3D
var _warned := false
var _flick := 0.0

func _init() -> void:
	id = "generator"
	max_hp = 120

func _ready() -> void:
	fuel = Run.camp_fuel
	super._ready()
	add_to_group("camp")
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Audio.stream("generator")
	_sound.bus = "SFX"
	_sound.unit_size = 6.0
	_sound.max_distance = 45.0
	_sound.volume_db = -8.0
	_sound.position = Vector3(0.0, 1.0, 0.0)
	add_child(_sound)
	Cycle.phase_changed.connect(_on_phase)
	_update_running()

func _build() -> void:
	# A squat concrete engine house with a corrugated roof, its door rusted, its exhaust
	# up through the roof.
	var walls := Geo.box(self, HOUSE, Color.WHITE, Vector3(0.0, HOUSE.y * 0.5, 0.0))
	walls.material_override = Look.camp("concrete", 1.5, true, 0.92)
	var roof := Geo.box(self, Vector3(HOUSE.x + 0.3, 0.12, HOUSE.z + 0.3), Color.WHITE, Vector3(0.0, HOUSE.y + 0.05, 0.0))
	roof.material_override = Look.camp("corrugated", 1.2, true, 0.7, 0.35)
	roof.rotation.x = 0.06
	var door := Geo.box(self, Vector3(0.08, 1.8, 1.0), Color.WHITE, Vector3(-HOUSE.x * 0.5 - 0.02, 0.9, 0.0))
	door.material_override = Look.camp("rust", 1.0, false, 0.75, 0.4)
	var vent := Geo.box(self, Vector3(0.06, 0.4, 0.9), Color.WHITE, Vector3(HOUSE.x * 0.5 + 0.02, 1.7, 0.4))
	vent.material_override = Look.camp("rust", 1.0, false, 0.75, 0.4)
	var exhaust := Geo.cyl(self, 0.12, 1.2, Color.WHITE, Vector3(0.6, HOUSE.y + 0.6, -0.8))
	exhaust.material_override = Look.camp("rust", 0.5, false, 0.75, 0.4)
	Geo.box_shape(self, HOUSE, Vector3(0.0, HOUSE.y * 0.5, 0.0))

func display_name() -> String:
	return "the generator"

func smoke_point() -> Vector3:
	return Vector3(0.6, HOUSE.y + 1.2, -0.8)

# To its walls, not its middle: creatures reach it, and keepers mend it, from outside.
func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - HOUSE.x * 0.5)
	var dz := maxf(0.0, absf(local.z) - HOUSE.z * 0.5)
	return Vector2(dx, dz).length()

func repair_cost() -> Dictionary:
	return {"scrap": 1, "driftwood": 1}

## Something it powers, drawing this much fuel a second (0 stops the draw).
func set_draw(who: Object, per_s: float) -> void:
	if per_s <= 0.0:
		_draw.erase(who)
	else:
		_draw[who] = per_s

## True while it's running: the camp has light.
func has_power() -> bool:
	return running

## How bright what it powers burns: full, or flickering as it runs low on fuel.
func power_level() -> float:
	if not running:
		return 0.0
	if fuel >= LOW:
		return 1.0
	return clampf(0.55 + 0.3 * sin(_flick * 23.0) * sin(_flick * 7.0) + randf_range(-0.15, 0.15), 0.2, 1.0)

func draw_total() -> float:
	var total := IDLE_DRAW
	for k in _draw.keys():
		if is_instance_valid(k):
			total += float(_draw[k])
	if Research.has("governor"):
		total *= GOVERNOR
	return total

func _on_phase(_p: int) -> void:
	_warned = false
	_update_running()

func _night() -> bool:
	return Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT

func _update_running() -> void:
	if Net.is_client() and Net.playing():
		return
	_set_running(Run.active and _night() and fuel > 0.0 and not is_destroyed())

## A LAN client: running and fuel as the host has them.
func net_apply(f: float, run: bool) -> void:
	fuel = f
	_set_running(run)

func _set_running(want: bool) -> void:
	if want == running:
		return
	running = want
	if not is_inside_tree():
		return
	if running:
		_sound.play()
		Audio.sfx("ignite", global_position, -10.0, 0.05)
		if _exhaust == null:
			_exhaust = FX.smoke(self, to_global(Vector3(0.6, HOUSE.y + 1.25, -0.8)), Color(0.2, 0.2, 0.21, 0.55),
				16, 2.2, Vector3(0.1, 1.0, 0.05).normalized(), 12.0, 0.8, 1.4, 0.12, 0.35, 0.8)
	else:
		_sound.stop()
		_draw.clear()
		if _exhaust != null:
			_exhaust.queue_free()
			_exhaust = null

func _physics_process(delta: float) -> void:
	_flick += delta
	if Net.is_client() and Net.playing():
		return
	if not running:
		if Run.active and _night() and fuel > 0.0 and not is_destroyed():
			_update_running()
		return
	fuel = maxf(0.0, fuel - draw_total() * delta)
	Run.camp_fuel = fuel
	if fuel < LOW and not _warned:
		_warned = true
		Events.message.emit("The camp's generator is running low on diesel.")
	if fuel <= 0.0:
		Events.message.emit("The generator has run dry: the camp is dark.")
		_update_running()
	elif is_destroyed():
		_update_running()

func _can_fill() -> bool:
	return Stock.get_amount("diesel") > 0 and fuel <= FUEL_MAX - CAN_UNITS * 0.5

func work_kind() -> String:
	if is_damaged() and Stock.can_afford(repair_cost()):
		return "hammer"
	if not is_destroyed() and _can_fill():
		return "can"
	return ""

func interact_prompt() -> String:
	if is_damaged():
		return super.interact_prompt()
	if _can_fill():
		return "[E] Fill the generator: 1 diesel  (%d%%)" % roundi(fuel)
	return ""

func interact(player: Node) -> bool:
	if is_damaged() and (Stock.can_afford(repair_cost()) or not _can_fill()):
		return super.interact(player)
	if _can_fill() and Stock.spend({"diesel": 1}):
		fuel = minf(FUEL_MAX, fuel + CAN_UNITS)
		Run.camp_fuel = fuel
		Audio.sfx("refuel", global_position, -2.0)
		Events.message.emit("Generator filled  (%d%%)" % roundi(fuel))
		_update_running()
		return true
	return false

## Fill it straight from the store (a helper at day's end, tests).
func top_up() -> bool:
	if _can_fill() and Stock.spend({"diesel": 1}):
		fuel = minf(FUEL_MAX, fuel + CAN_UNITS)
		Run.camp_fuel = fuel
		_update_running()
		return true
	return false
