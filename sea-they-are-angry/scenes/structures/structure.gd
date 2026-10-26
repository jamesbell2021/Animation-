class_name Structure
extends StaticBody3D

signal health_changed(hp: int, max_hp: int)
signal destroyed

const REPAIR_AMOUNT := 25
# Below this much health a building smoulders, so damage reads from across the island.
const SMOKE_BELOW := 0.45

@export var id: String = ""
@export var max_hp: int = 100
var hp: int = 0
var _smoke: GPUParticles3D

func _ready() -> void:
	add_to_group("structures")
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 0
	hp = max_hp
	_build()
	_refresh()
	_update_smoke()

# Virtual: create meshes and collision shapes.
func _build() -> void:
	pass

# Virtual: update visuals from hp.
func _refresh() -> void:
	pass

# Virtual: where smoke rises from when badly damaged, in local space; INF for none.
func smoke_point() -> Vector3:
	return Vector3.INF

func _update_smoke() -> void:
	var p := smoke_point()
	if p == Vector3.INF or not is_inside_tree():
		return
	var want := health_ratio() < SMOKE_BELOW
	if want and _smoke == null:
		_smoke = FX.smoke(self, to_global(p), Color(0.16, 0.15, 0.15, 0.6),
			28, 3.5, Vector3(0.2, 1.0, 0.1).normalized(), 18.0, 0.6, 1.2, 0.2, 0.9, 1.6)
	elif not want and _smoke != null:
		_smoke.queue_free()
		_smoke = null

## A LAN client: health as the host has it (no sounds or splinters: the host sends those).
func net_set_hp(v: int) -> void:
	var was := hp
	hp = clampi(v, 0, max_hp)
	health_changed.emit(hp, max_hp)
	_refresh()
	_update_smoke()
	if was > 0 and hp == 0:
		destroyed.emit()

func is_damaged() -> bool:
	return hp < max_hp

func is_destroyed() -> bool:
	return hp <= 0

func health_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)

func repair_cost() -> Dictionary:
	return {"driftwood": 1}

## Health restored per repair. Homestead buildings and fences mend faster than the
## lighthouse: a day's driftwood should go a long way toward putting a raid right.
const MEND_HOMESTEAD := 50

func repair_amount() -> int:
	return MEND_HOMESTEAD if id in ["cottage", "shed", "garden"] else REPAIR_AMOUNT

## The tool a keeper works with when using this: "hammer" for a repair they can pay for,
## "" when there's nothing to do (or it can't be afforded: interact() then says what's missing).
func work_kind() -> String:
	if is_damaged() and Stock.can_afford(repair_cost()):
		return "hammer"
	return ""

func display_name() -> String:
	return id

# Flat (XZ) distance from a point to this structure's surface.
# Players use it for interact range, the Bloated burst uses it for splash range.
func surface_distance(p: Vector3) -> float:
	return Geo.flat_dist(p, global_position)

func take_damage(amount: int) -> void:
	if hp <= 0 or amount <= 0:
		return
	hp = clampi(hp - amount, 0, max_hp)
	health_changed.emit(hp, max_hp)
	Events.structure_damaged.emit(self)
	_on_damaged()
	_refresh()
	_update_smoke()
	if hp == 0:
		destroyed.emit()
		Events.structure_destroyed.emit(self)
		Anger.add(1)

# Virtual: feedback when hit. Default: splinters and a thud.
func _on_damaged() -> void:
	if is_inside_tree():
		FX.splinters(get_parent(), global_position + Vector3(0.0, 0.8, 0.0))
		Audio.sfx("hit", global_position, -6.0, 0.15)

func repair(amount: int) -> void:
	if is_inside_tree():
		Audio.sfx("repair", global_position, -2.0)
	hp = clampi(hp + amount, 0, max_hp)
	health_changed.emit(hp, max_hp)
	_refresh()
	_update_smoke()

func interact_prompt() -> String:
	if not is_damaged():
		return ""
	return "[E] Repair %s (%s)" % [display_name(), Stock.cost_str(repair_cost())]

func interact(_player: Node) -> bool:
	if not is_damaged():
		return false
	if Stock.spend(repair_cost()):
		repair(repair_amount())
		Events.message.emit("Repaired %s  (%d/%d)" % [display_name(), hp, max_hp])
		Events.did.emit("repair", _player)
		return true
	Events.message.emit("Need " + Stock.cost_str(repair_cost()))
	return false
