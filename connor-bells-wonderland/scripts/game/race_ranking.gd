class_name RaceRanking
extends RefCounted
## Live running order. Finished contestants rank first by finishing place;
## the rest rank by checkpoints passed, then distance along -Z, then height.

const CHECKPOINT_WEIGHT := 1000.0
const HEIGHT_WEIGHT := 2.0


## Returns contestants sorted from first to last.
static func compute(contestants: Array[Contestant], race_manager: RaceManager, checkpoint_manager: CheckpointManager) -> Array[Contestant]:
	var places: Dictionary = {}
	if race_manager != null:
		for entry in race_manager.get_results():
			places[str(entry.get("name", ""))] = int(entry.get("place", 0))
	var scored: Array = []
	for c in contestants:
		if not is_instance_valid(c):
			continue
		scored.append({"contestant": c, "score": _score(c, places, checkpoint_manager)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var result: Array[Contestant] = []
	for item in scored:
		result.append(item["contestant"])
	return result


## 1-based position of [param contestant] in [param ranking], or 0 if absent.
static func position_of(contestant: Contestant, ranking: Array[Contestant]) -> int:
	var index := ranking.find(contestant)
	return index + 1 if index >= 0 else 0


static func _score(c: Contestant, places: Dictionary, checkpoint_manager: CheckpointManager) -> float:
	if places.has(str(c.name)):
		return 1.0e9 - float(places[str(c.name)])
	var progress := 0
	if checkpoint_manager != null:
		progress = checkpoint_manager.get_progress(c) + 1
	return float(progress) * CHECKPOINT_WEIGHT - c.global_position.z + c.global_position.y * HEIGHT_WEIGHT
