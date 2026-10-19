extends Node

signal changed

const KINDS := ["driftwood", "scrap", "seaweed", "bio", "food", "oil", "dirty_fuel"]

var _items := {}

func _ready() -> void:
	reset()

func reset() -> void:
	_items = {}
	for k in KINDS:
		_items[k] = 0
	_items["driftwood"] = 4
	_items["bio"] = 1
	changed.emit()

func set_all(d: Dictionary) -> void:
	reset()
	for k in d:
		_items[k] = int(d[k])
	changed.emit()

func all() -> Dictionary:
	return _items.duplicate()

func get_amount(kind: String) -> int:
	return _items.get(kind, 0)

func add(kind: String, n: int = 1) -> void:
	_items[kind] = get_amount(kind) + n
	changed.emit()

func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if get_amount(k) < cost[k]:
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		_items[k] -= cost[k]
	changed.emit()
	return true

static func cost_str(c: Dictionary) -> String:
	var parts := []
	for k in c:
		parts.append("%d %s" % [c[k], k])
	return ", ".join(parts)
