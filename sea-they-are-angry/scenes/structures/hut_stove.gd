class_name HutStove
extends Node3D
## The quarters hut's iron stove. A keeper feeds it driftwood and it burns for a good
## while, smoke coming out of the stovepipe; anyone standing by the hut warms through.
## The camp's place to come in from the cold, as the cottage's fire is the lighthouse's.

const COST := {"driftwood": 1}
const BURN_TIME := 260.0
const HEAT := 3.0
const RADIUS := 4.8

## Where the stovepipe comes out of the roof (for the smoke).
var pipe_top := Vector3.ZERO
var burn := 0.0
var _smoke: GPUParticles3D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("heat")

func is_lit() -> bool:
	return burn > 0.0

func heat_at(p: Vector3) -> float:
	if burn <= 0.0 or Geo.flat_dist(p, global_position) > RADIUS or absf(p.y - global_position.y) > 1.5:
		return 0.0
	return HEAT

func _process(delta: float) -> void:
	if burn > 0.0:
		burn = maxf(0.0, burn - delta)
		if _smoke == null and is_inside_tree():
			_smoke = FX.chimney_smoke(get_parent(), pipe_top)
		if burn <= 0.0 and _smoke != null:
			_smoke.queue_free()
			_smoke = null

func interact_prompt() -> String:
	if burn > 60.0:
		return "The stove's burning: warm through by the hut"
	return "[E] %s the stove (%s): warm by the hut" % ["Feed" if burn > 0.0 else "Light", Stock.cost_str(COST)]

func interact(_player: Node) -> bool:
	if burn > 60.0:
		return false
	if not Stock.spend(COST):
		Events.message.emit("Need " + Stock.cost_str(COST))
		return false
	burn = BURN_TIME
	Audio.sfx("ignite", global_position, -8.0, 0.1)
	Events.message.emit("The stove's lit: the hut will be warm for a while")
	return true
