class_name StreetLamp
extends Structure
## One of Kirkhaven's street lamps. Switched in at its fuse box, it burns from dusk while
## the harbour's generator runs: sodium orange, a pool the fog can't lie in, and light
## enough to slow what comes out of the sea and scorch it a little. That is why they
## make for the lamps and break them. A broken one is mended with scrap.

const LIGHT_RADIUS := 6.0
const FOG_RADIUS := 8.5
## Diesel a lit lamp draws from the generator, a second.
const DRAW := 0.016
const SODIUM := Color(1.0, 0.60, 0.22)
const WHITE := Color(1.0, 0.95, 0.85)
## Godot's lights fall off with distance as well as range: from 4 m up, a pool on the
## ground wants this much.
const ENERGY := 15.0
const RANGE := 11.0
## While the kirk bell rings, every lit lamp flares: wider, and it burns like the beam.
const FLARE_RADIUS := 9.0
const HEIGHT := 4.6

## Its place in HarbourMap.LAMPS, and what it's called.
var index := 0
var label := "the lamp"
## Switched in at the fuse box. It lights when there's power.
var on := false
var generator: Generator
## Seconds of the bell's flare left.
var flare := 0.0

var _post: Node3D
var _light: OmniLight3D
var _lens_mat: StandardMaterial3D
var _lens: MeshInstance3D
var _tell: MeshInstance3D
var _halo: MeshInstance3D
var _lit := false
var _level := 0.0
var _t := 0.0

func _init() -> void:
	id = "street_lamp"
	max_hp = 60

func _build() -> void:
	add_to_group("street_lamps")
	add_to_group("fog_lights")
	add_to_group("homes")
	_post = HarbourProps.lamp_post(HEIGHT)
	# The arm reaches inland, over the quay and the street, not out over the water.
	_post.rotation.y = PI
	add_child(_post)
	_lens = _post.find_child("Lens", true, false) as MeshInstance3D
	if _lens != null:
		_lens_mat = StandardMaterial3D.new()
		_lens_mat.albedo_color = Color(0.25, 0.22, 0.18)
		_lens_mat.roughness = 0.3
		_lens_mat.emission_enabled = true
		_lens_mat.emission = SODIUM
		_lens_mat.emission_energy_multiplier = 0.0
		_lens.material_override = _lens_mat
	var bulb := _post.find_child("Bulb", true, false) as Node3D
	_light = OmniLight3D.new()
	_light.light_color = SODIUM
	_light.omni_range = RANGE
	_light.omni_attenuation = 1.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 1.6
	_light.position = to_local(bulb.global_position) + Vector3(0.0, -0.25, 0.0) if bulb != null else Vector3(0.0, HEIGHT - 0.4, 0.4)
	_light.add_to_group("flicker_lights")
	add_child(_light)
	# A halo round the head, so a burning lamp reads from above.
	_halo = Look.glint(self, _light.position + Vector3(0.0, 0.35, 0.0), SODIUM, 1.5)
	_halo.visible = false
	# A small tell-tale on the fuse box: green when it's switched in.
	_tell = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	_tell.mesh = sm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.1, 0.1, 0.1)
	tm.emission_enabled = true
	tm.emission = Color(0.3, 1.0, 0.4)
	tm.emission_energy_multiplier = 0.0
	_tell.material_override = tm
	_tell.position = Vector3(0.0, 0.95, 0.16)
	add_child(_tell)
	Geo.cyl_shape(self, 0.16, 2.2, Vector3(0.0, 1.1, 0.0))

func display_name() -> String:
	return label

func surface_distance(p: Vector3) -> float:
	return maxf(0.0, Geo.flat_dist(p, global_position) - 0.2)

func repair_cost() -> Dictionary:
	return {"scrap": 1}

func repair_amount() -> int:
	return max_hp

func smoke_point() -> Vector3:
	return Vector3.INF

## Burning now: switched in, whole, and the generator running.
func is_lit() -> bool:
	return _lit

## Creatures on a raid make for lit lamps only.
func draws_raiders() -> bool:
	return _lit

func _wants_light() -> bool:
	return on and hp > 0 and generator != null and is_instance_valid(generator) and generator.has_power()

func fog_hole() -> Vector3:
	var r := FOG_RADIUS * _level * (1.35 if flare > 0.0 else 1.0)
	return Vector3(global_position.x, global_position.z, r if _lit else 0.0)

func _physics_process(delta: float) -> void:
	_t += delta
	var want := _wants_light()
	if want != _lit:
		_lit = want
		if _lit and is_inside_tree() and Run.active:
			Audio.sfx("lamp_on", global_position, -8.0, 0.1)
	if generator != null and is_instance_valid(generator) and generator.has_power():
		generator.set_draw(self, DRAW if _lit else 0.0)
	var target := 0.0
	if _lit:
		target = generator.power_level()
		# A lamp that's been hit buzzes and stutters.
		if health_ratio() < 0.6:
			target *= 0.55 + 0.45 * absf(sin(_t * 17.0) * sin(_t * 5.3))
	_level = move_toward(_level, target, delta * 2.5)
	flare = maxf(0.0, flare - delta)
	var hot := smoothstep(0.0, 0.6, flare)
	_light.light_energy = ENERGY * _level * (1.0 + 1.6 * hot)
	_light.light_color = SODIUM.lerp(WHITE, hot)
	_light.omni_range = RANGE * (1.0 + 0.35 * hot)
	if _lens_mat != null:
		_lens_mat.emission = SODIUM.lerp(WHITE, hot)
		_lens_mat.emission_energy_multiplier = 5.0 * _level * (1.0 + hot)
	(_tell.material_override as StandardMaterial3D).emission_energy_multiplier = 2.0 if on and hp > 0 else 0.0
	if _halo != null:
		_halo.visible = _level > 0.05
	if not _lit or not Run.active or Net.is_client():
		return
	# What stands in its light is slowed and scorched; in the bell's flare, burned.
	var r := FLARE_RADIUS if flare > 0.0 else LIGHT_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("in_light"):
			continue
		if Geo.flat_dist(e.global_position, global_position) > r or absf(e.global_position.y - global_position.y) > 3.0:
			continue
		if "lit_this_frame" in e:
			e.lit_this_frame = true
		e.in_light(Lamp.Mode.FOCUSED if flare > 0.0 else Lamp.Mode.WIDE, delta)

func _refresh() -> void:
	if _post == null:
		return
	# Broken: the head hangs, the glass is gone.
	_post.rotation.z = deg_to_rad(7.0) if hp <= 0 else 0.0
	if _lens != null:
		_lens.visible = hp > 0

func _on_damaged() -> void:
	if not is_inside_tree():
		return
	Audio.sfx("hit", global_position, -6.0, 0.15)
	if hp <= 0:
		Audio.sfx("glass", global_position + Vector3(0.0, HEIGHT, 0.0), 0.0, 0.1)
		Audio.sfx("lamp_off", global_position, -4.0, 0.1)
		FX.sparks(get_parent(), global_position + Vector3(0.0, HEIGHT - 0.3, 0.3))
		Events.message.emit("%s is smashed." % (label.left(1).to_upper() + label.substr(1)))

func work_kind() -> String:
	if is_damaged() and Stock.can_afford(repair_cost()):
		return "hammer"
	return ""

func interact_prompt() -> String:
	if is_damaged():
		return "[E] Mend %s (%s)" % [label, Stock.cost_str(repair_cost())]
	if not on:
		return "[E] Switch in %s" % label
	return ""

func interact(player: Node) -> bool:
	if is_damaged():
		return super.interact(player)
	if on:
		return false
	switch_in()
	Events.did.emit("lamp_on", player)
	var night := Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT
	if generator == null or not is_instance_valid(generator) or generator.is_destroyed():
		Events.message.emit("Switched in, but the generator is wrecked: no power.")
	elif generator.fuel <= 0.0:
		Events.message.emit("Switched in, but the generator is dry: it wants diesel.")
	elif not night:
		Events.message.emit("Switched in. It will light at dusk, when the generator starts.")
	else:
		Events.message.emit("%s burns." % (label.left(1).to_upper() + label.substr(1)))
	return true

## Switch it in (a keeper at the fuse box, or a saved run).
func switch_in() -> void:
	on = true
	if not Run.lamps_on.has(index):
		Run.lamps_on.append(index)
	if is_inside_tree():
		Audio.sfx("lamp_on", global_position, -4.0, 0.05)
