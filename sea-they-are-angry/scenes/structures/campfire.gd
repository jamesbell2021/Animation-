class_name Campfire
extends Node3D
## A fire pit by the cottage door. Smoulders by day, burns up at dusk. A keeper can
## throw on a bit of driftwood and warm through: a quick heal without going inside.

const HEAL := 30
const COST := {"driftwood": 1}
const FIRE := Color(1.0, 0.55, 0.2)
const FIRE_CORE := Color(1.0, 0.85, 0.45)

var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _t := 0.0
var _lit := false
var _roar_t := 0.0

func _ready() -> void:
	add_to_group("interactable")
	for i in 8:
		var a := TAU * float(i) / 8.0
		Look.rock(self, 1400 + i, Vector3(0.3, 0.22, 0.26), Vector3(sin(a) * 0.62, 0.05, cos(a) * 0.62), Look.STONE, 0.1)
	var char_mat := Look.flat_mat(Color(0.12, 0.09, 0.07), 1.0)
	for i in 3:
		var log_mesh := Geo.cyl(self, 0.07, 0.9, Color.WHITE, Vector3(0.0, 0.12, 0.0))
		log_mesh.material_override = char_mat
		log_mesh.rotation = Vector3(deg_to_rad(80.0), TAU * float(i) / 3.0, 0.0)
	var ash := Geo.cyl(self, 0.45, 0.04, Color.WHITE, Vector3(0.0, 0.02, 0.0))
	ash.material_override = Look.flat_mat(Color(0.3, 0.28, 0.27), 1.0)
	for i in 3:
		var f := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.2 - 0.04 * float(i)
		cm.height = 0.7 - 0.15 * float(i)
		cm.radial_segments = 6
		cm.rings = 1
		f.mesh = cm
		f.material_override = Look.eye_mat(FIRE if i < 2 else FIRE_CORE, 4.0 + 2.0 * float(i))
		f.position = Vector3(0.05 * float(i - 1), cm.height * 0.5 + 0.1, 0.04 * float(i % 2))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		_flames.append(f)
	_light = OmniLight3D.new()
	_light.light_color = FIRE
	_light.omni_range = 5.5
	_light.position.y = 0.6
	_light.light_volumetric_fog_energy = 1.2
	add_child(_light)
	FX.chimney_smoke.call_deferred(self, global_position + Vector3(0.0, 0.8, 0.0))
	Cycle.phase_changed.connect(_on_phase_changed)
	_set_lit(Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT)

func _on_phase_changed(p: int) -> void:
	_set_lit(p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT)

func _set_lit(v: bool) -> void:
	_lit = v

func _process(delta: float) -> void:
	_t += delta
	_roar_t = maxf(0.0, _roar_t - delta)
	var size := (1.0 if _lit else 0.45) + _roar_t * 0.5
	for i in _flames.size():
		var n := 0.85 + 0.15 * sin(_t * (9.0 + float(i) * 3.0)) * sin(_t * 5.3 + float(i))
		_flames[i].scale = Vector3(1.0, n, 1.0) * size
	_light.light_energy = (1.6 if _lit else 0.5) * (0.85 + 0.15 * sin(_t * 17.0) * sin(_t * 7.1)) + _roar_t

func interact_prompt() -> String:
	return "[E] Throw on driftwood and warm up (+%d health)" % HEAL

func interact(player: Node) -> bool:
	if not (player is Player):
		return false
	if player.hp >= player.max_hp:
		Events.message.emit("You're warm enough.")
		return false
	if not Stock.spend(COST):
		Events.message.emit("Need " + Stock.cost_str(COST))
		return false
	player.heal(HEAL)
	_roar_t = 1.5
	FX.sparks(get_parent(), global_position + Vector3(0.0, 0.5, 0.0))
	Audio.sfx("ignite", global_position, -4.0, 0.1)
	Events.message.emit("Warmed through  (%d / %d)" % [player.hp, player.max_hp])
	return true
