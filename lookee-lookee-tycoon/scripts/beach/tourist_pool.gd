class_name TouristPool
extends Node
## Spawns and recycles tourists. Nodes are created once (up to the quality tier's cap of
## 16-30) and reused, so a busy afternoon never allocates. The crowd follows the time of day
## (quiet morning, packed afternoon, home for tea), the beach's popularity and events.

var beach: Node
var pool: Array[Tourist] = []
var _spawn_timer := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func active() -> Array[Tourist]:
	var out: Array[Tourist] = []
	for t in pool:
		if t.is_active():
			out.append(t)
	return out


func active_count() -> int:
	var n := 0
	for t in pool:
		if t.is_active():
			n += 1
	return n


## How full the beach should be at this hour (0..1).
static func crowd_curve(hour: float) -> float:
	if hour < 10.0:
		return lerpf(0.35, 0.6, hour - 9.0)
	if hour < 13.0:
		return lerpf(0.6, 1.0, (hour - 10.0) / 3.0)
	if hour < 18.0:
		return 1.0
	if hour < 20.0:
		return lerpf(1.0, 0.45, (hour - 18.0) / 2.0)
	return lerpf(0.45, 0.0, clampf(hour - 20.0, 0.0, 1.0))


func _process(delta: float) -> void:
	if not GameManager.day_running:
		return
	var b := BeachDB.get_beach(GameManager.current_beach)
	var cap := Quality.max_tourists
	var wanted := int(cap * crowd_curve(GameManager.hour) * clampf(float(b.crowd) * 0.85, 0.5, 1.0) * clampf(RandomEvents.mult("spawn"), 0.3, 1.5))
	wanted = mini(wanted, cap)
	var n := active_count()
	# Late in the day (or in the rain), send people home.
	if n > wanted + 2 and _rng.randf() < delta * 0.5:
		for t in pool:
			if t.is_active() and t.state in [Tourist.State.SUNBATHE, Tourist.State.WANDER, Tourist.State.SWIM]:
				t.leave()
				break
	_spawn_timer -= delta * RandomEvents.mult("spawn")
	if _spawn_timer <= 0.0 and n < wanted:
		_spawn_timer = _rng.randf_range(1.2, 3.0) / maxf(float(b.crowd), 0.5)
		spawn_group(_pick_type(b), -1)


func _pick_type(b: Dictionary) -> String:
	var mix: Dictionary = b.mix.duplicate()
	for type_id in mix:
		mix[type_id] = float(mix[type_id]) * RandomEvents.mult("type_" + type_id)
	return TouristTypes.weighted_pick(mix, _rng)


## Spawns a group of one type walking in from the promenade (or the sides). size -1 = random.
func spawn_group(type_id: String, size := -1) -> int:
	var t := TouristTypes.get_type(type_id)
	if size < 0:
		size = _rng.randi_range(int(t.group[0]), int(t.group[1]))
	var free := Quality.max_tourists - active_count()
	size = mini(size, free)
	if size <= 0:
		return 0
	var from: Vector2 = beach.entry_point()
	var near_x: float = beach.vendor.position.x if _rng.randf() < 0.5 else from.x
	var center: Vector2 = beach.random_sand_point(near_x, 650.0)
	for i in size:
		var tourist := _get_free()
		if tourist == null:
			return i
		var child := type_id == "family" and i >= 2
		var look := AppearanceOptions.tourist_appearance(type_id, _rng, child)
		var spot: Vector2 = beach.clamp_to_sand(center + Vector2((i - size * 0.5) * 70.0, _rng.randf_range(-30, 30)))
		tourist.activate(beach, type_id, look, from + Vector2(i * 26.0, _rng.randf_range(0, 20)), spot, child)
	return size


func _get_free() -> Tourist:
	for t in pool:
		if not t.is_active():
			return t
	if pool.size() >= Quality.MAX_TOURISTS[Quality.Tier.HIGH]:
		return null
	var t := Tourist.new()
	t.beach = beach
	pool.append(t)
	beach.world.add_child(t)
	t.deactivate()
	return t


func recycle(t: Tourist) -> void:
	t.deactivate()


func clear_all() -> void:
	for t in pool:
		if t.is_active():
			t.deactivate()
