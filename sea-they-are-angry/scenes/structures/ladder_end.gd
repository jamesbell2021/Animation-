class_name LadderEnd
extends Node3D
## One end of a Ladder: the keeper's interact prompt and where it leads.

var prompt := ""
var to := Vector3.ZERO
var time := 1.0

func _ready() -> void:
	add_to_group("interactable")

func interact_prompt() -> String:
	return prompt

func interact(player: Node) -> bool:
	if player.has_method("climb") and not player.is_climbing():
		player.climb(to + Vector3(0.0, 0.1, 0.0), time)
		return true
	return false
