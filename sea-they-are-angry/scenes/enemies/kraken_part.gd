class_name KrakenPart
extends Enemy
## A place on the kraken that the keepers' weapons can find: every weapon looks for an
## Enemy near where it strikes, so the kraken sets these about itself (several across
## the front of its head, one at the tip of each arm lying ashore) and they pass what
## hits them on. A part does nothing of its own: it does not move, fall, burn or die.

var kraken: Node
## -1 for the head, else the arm this is the tip of.
var arm := -1

func _ready() -> void:
	max_hp = 99999
	super._ready()
	collision_layer = 0
	collision_mask = 0
	state = &"Kraken"

func _build() -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass

func _on_phase_changed(_p: int) -> void:
	pass

func on_dawn() -> void:
	pass

func can_ragdoll() -> bool:
	return false

func is_vulnerable() -> bool:
	return true

func salvage() -> Array:
	return []

func light_probe_points() -> Array:
	if arm < 0 and kraken != null and is_instance_valid(kraken):
		return kraken.eye_points()
	return [global_position + Vector3(0.0, 0.5, 0.0)]

func in_light(mode: int, delta: float) -> void:
	if arm < 0 and kraken != null and is_instance_valid(kraken):
		kraken.lit(mode, delta)

func set_alight(t: float) -> void:
	if kraken != null and is_instance_valid(kraken):
		kraken.burn(t, arm)

func poison(_t: float) -> void:
	pass

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if kraken == null or not is_instance_valid(kraken) or amount <= 0:
		return
	var kind := last_hit
	if source is Player:
		kind = source.hit_kind
	kraken.struck(arm, amount, kind, from_dir, source, global_position)
