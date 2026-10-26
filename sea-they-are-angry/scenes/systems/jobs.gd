class_name Jobs
extends Node
## The first days' jobs: a short list on the HUD of the things a new keeper needs to have
## done once, ticking off as a person's keeper does them (the helpers' work doesn't
## count). It teaches the island, the camp and the shed without a tutorial getting in the
## way of the night. Kept with the run (Run.jobs); gone once all are done, or after the
## third night.

const LIST := [
	["gather", "Gather something on a beach (E)"],
	["repair", "Mend a fence or a building (E, with driftwood)"],
	["eat", "Eat a meal: the cottage, or the camp's mess"],
	["bridge", "Cross the rope bridge to the old camp"],
	["generator", "Fill the camp's generator with diesel"],
	["shed", "Take a weapon from the shed's workbench (Tab to change)"],
	["sow", "Sow a bed: the cottage garden, or the camp's"],
	["lamp", "At dusk, work the lamp: R at the lighthouse door"],
]
## After this night the list goes, done or not.
const UNTIL_NIGHT := 3

var players: Array = []
var _poll := 0.0

func _ready() -> void:
	Events.did.connect(_on_did)

## Whether the list is still up.
static func showing() -> bool:
	return Run.active and Run.night <= UNTIL_NIGHT and Run.jobs.size() < LIST.size()

static func done(id: String) -> bool:
	return Run.jobs.has(id)

func _on_did(what: String, keeper: Node) -> void:
	if keeper == null or not is_instance_valid(keeper) or bool(keeper.get("ai")):
		return
	tick(what)

## A job done (once).
func tick(id: String) -> void:
	if Run.jobs.has(id) or Net.is_client():
		return
	var known := false
	for j in LIST:
		known = known or j[0] == id
	if not known:
		return
	Run.jobs.append(id)
	Audio.sfx("ui_accept", Vector3.INF, -6.0, 0.0)
	if Run.jobs.size() == LIST.size():
		Events.message.emit("Every job done: you know the rock. Now keep the light until the boat comes.")

# The jobs that are a state of things rather than an action, checked twice a second.
func _process(delta: float) -> void:
	if not showing() or Net.is_client():
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	for p in players:
		if not is_instance_valid(p) or p.ai:
			continue
		if Terrain.on_holm(p.global_position.x, p.global_position.z):
			tick("bridge")
		if not Run.arms[p.idx].is_empty() or Stock.get_amount("bombs") > 0 or Stock.get_amount("arrows") > 0:
			tick("shed")
