class_name MessTable
extends Node3D
## The trestle table in the camp's mess hut: eat here (a meal from the store) without
## crossing back to the cottage. It feeds a keeper and patches them up a little; the
## cottage's full meals (and the strength they build) stay the lighthouse's.

const MEAL := {"food": 1}
const HEAL := 30

func _ready() -> void:
	add_to_group("interactable")

func interact_prompt() -> String:
	return "[E] Eat in the mess (%s): fed, +%d health" % [Stock.cost_str(MEAL), HEAL]

func interact(player: Node) -> bool:
	if not player.has_method("eat_meal"):
		return false
	if player.hunger >= 90.0 and player.hp >= player.max_hp:
		Events.message.emit("%s isn't hungry." % player.keeper_name())
		return false
	if not Stock.spend(MEAL):
		Events.message.emit("Nothing in the store to eat: grow some, or lift the potatoes")
		return false
	player.eat_meal()
	player.heal(HEAL)
	Audio.sfx("gather", global_position, 0.0, 0.0)
	Events.message.emit("%s eats in the mess." % player.keeper_name())
	return true
