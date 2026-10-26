class_name Cottage
extends Structure
## The keepers' cottage: whitewashed stone, slate roof, chimney, windows that
## glow from dusk to dawn. Inside: eat, load flares, mix dirty fuel, buy upgrades.

const WIDTH := 4.2
const DEPTH := 3.0
const WALL_H := 2.0
const WALL := Color(0.84, 0.82, 0.76)
const STONE := Color(0.42, 0.41, 0.38)
const SLATE := Color(0.20, 0.22, 0.25)
# The whitewash's tint over the harl texture (already near white).
const HARL := Color(1.0, 1.0, 0.97)
const WINDOW_DARK := Color(0.10, 0.12, 0.15)
const WINDOW_LIT := Color(1.0, 0.72, 0.38)
const MEAL := {"food": 1}
const MEAL_MAX_HP := 10
const FLARE_COST := {"scrap": 1}
const MIX_COST := {"oil": 1, "driftwood": 1}
const MIX_YIELD := 2
## Gull eggs from Gull Rock, boiled: this many make a meal for the store.
const EGGS_MEAL := {"eggs": 3}

var _wall_mat: StandardMaterial3D
var _window_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _chimney_top := Vector3.ZERO
const WINDOW_GLOW := 2.6
const LAMP_ENERGY := 1.6
var _lit := false
var _fire_t := 0.0
var _flicker := 1.0
var _smoke_fx: GPUParticles3D
var _slabs: Array[MeshInstance3D] = []
var _ridge_y := 0.0

func _init() -> void:
	id = "cottage"
	max_hp = 150

func _build() -> void:
	add_to_group("heat")
	# Whitewashed harl over rubble walls, a rubble footing and chimney, a slate roof.
	_wall_mat = Look.textured("harl", HARL, 1.2, 0.95, 0.8)
	var stone := Look.textured("rubble", Color.WHITE, 1.4, 0.9, 1.2)
	# Rubble footing, then whitewashed walls.
	var foot := Geo.box(self, Vector3(WIDTH + 0.2, 0.35, DEPTH + 0.2), STONE, Vector3(0.0, 0.1, 0.0))
	foot.material_override = stone
	var walls := Geo.box(self, Vector3(WIDTH, WALL_H, DEPTH), WALL, Vector3(0.0, WALL_H * 0.5 + 0.2, 0.0))
	walls.material_override = _wall_mat
	# Pitched slate roof from two tilted slabs, with stone gable ends under it.
	var pitch := deg_to_rad(38.0)
	var half := DEPTH * 0.5 + 0.25
	var slab_len := half / cos(pitch)
	var ridge_y := WALL_H + 0.2 + half * tan(pitch)
	for side in [-1.0, 1.0]:
		var slab := Geo.box(self, Vector3(WIDTH + 0.4, 0.14, slab_len + 0.05), SLATE, Vector3(0.0, (WALL_H + 0.2 + ridge_y) * 0.5, side * half * 0.5))
		# Courses of slates along the eaves, each lip facing down the slope: the texture
		# is turned round on the far side.
		var slate := Look.textured("slate", Color.WHITE, 1.0, 0.55, 1.4)
		slate.uv1_scale = Vector3(1.0, 1.0, side)
		slab.material_override = slate
		slab.rotation.x = side * pitch
		_slabs.append(slab)
	_ridge_y = ridge_y
	for side in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(DEPTH, ridge_y - WALL_H - 0.2, 0.2)
		gable.mesh = prism
		gable.material_override = _wall_mat
		gable.position = Vector3(side * (WIDTH * 0.5 - 0.1), (WALL_H + 0.2 + ridge_y) * 0.5, 0.0)
		gable.rotation.y = PI * 0.5
		add_child(gable)
	# Chimney on one gable end.
	var chimney := Geo.box(self, Vector3(0.55, 1.1, 0.55), STONE, Vector3(WIDTH * 0.5 - 0.35, ridge_y + 0.15, 0.0))
	chimney.material_override = stone
	var cope := Geo.box(self, Vector3(0.62, 0.1, 0.62), Color(0.3, 0.29, 0.27), Vector3(WIDTH * 0.5 - 0.35, ridge_y + 0.72, 0.0))
	cope.material_override = Look.textured("rubble", Color(0.7, 0.7, 0.7), 0.8)
	# A ridge of slate along the top, where the two pitches meet.
	var ridge := Geo.box(self, Vector3(WIDTH + 0.42, 0.12, 0.26), SLATE, Vector3(0.0, ridge_y + 0.03, 0.0))
	ridge.material_override = Look.textured("slate", Color(0.8, 0.8, 0.85), 0.5, 0.55)
	_chimney_top = Vector3(WIDTH * 0.5 - 0.35, ridge_y + 0.85, 0.0)
	# Door and windows on the side facing the lighthouse (local -Z).
	var door := Geo.box(self, Vector3(0.8, 1.45, 0.08), Color(0.22, 0.16, 0.11), Vector3(-0.3, 0.95, -DEPTH * 0.5 - 0.03))
	door.material_override = Look.textured("planks", Color(0.75, 0.5, 0.35), 0.9)
	_window_mat = Look.glow_mat(WINDOW_DARK, 0.0)
	for wx in [-1.45, 0.95]:
		var w := Geo.box(self, Vector3(0.6, 0.55, 0.08), WINDOW_DARK, Vector3(wx, 1.45, -DEPTH * 0.5 - 0.03))
		w.material_override = _window_mat
	var back := Geo.box(self, Vector3(0.6, 0.55, 0.08), WINDOW_DARK, Vector3(0.6, 1.45, DEPTH * 0.5 + 0.03))
	back.material_override = _window_mat
	# Four-pane sash windows: painted glazing bars and a sill over each glowing pane.
	var bars := Look.wood(Color(0.82, 0.8, 0.74), 0.4)
	for spot in [Vector3(-1.45, 1.45, -DEPTH * 0.5 - 0.075), Vector3(0.95, 1.45, -DEPTH * 0.5 - 0.075), Vector3(0.6, 1.45, DEPTH * 0.5 + 0.075)]:
		for piece in [[Vector3(0.66, 0.05, 0.03), Vector3(0.0, 0.0, 0.0)], [Vector3(0.05, 0.6, 0.03), Vector3(0.0, 0.0, 0.0)],
				[Vector3(0.68, 0.05, 0.04), Vector3(0.0, 0.3, 0.0)], [Vector3(0.05, 0.6, 0.04), Vector3(-0.32, 0.0, 0.0)],
				[Vector3(0.05, 0.6, 0.04), Vector3(0.32, 0.0, 0.0)]]:
			var bar := Geo.box(self, piece[0], Color.WHITE, spot + piece[1])
			bar.material_override = bars
		var sill := Geo.box(self, Vector3(0.74, 0.06, 0.16), Color.WHITE, spot + Vector3(0.0, -0.31, signf(spot.z) * 0.05))
		sill.material_override = Look.stone(Color(0.5, 0.49, 0.46), 0.6)
	_lamp = OmniLight3D.new()
	_lamp.light_color = WINDOW_LIT
	_lamp.omni_range = 4.5
	_lamp.light_energy = 0.0
	_lamp.position = Vector3(0.0, 1.4, -DEPTH * 0.5 - 0.8)
	add_child(_lamp)
	Geo.box_shape(self, Vector3(WIDTH, WALL_H + 0.4, DEPTH), Vector3(0.0, WALL_H * 0.5 + 0.2, 0.0))
	Cycle.phase_changed.connect(_on_phase_changed)
	_set_windows(Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT)
	_start_smoke.call_deferred()

func _on_phase_changed(p: int) -> void:
	_set_windows(p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT)

func _set_windows(lit: bool) -> void:
	_lit = lit
	_window_mat.albedo_color = WINDOW_LIT if lit else WINDOW_DARK
	_window_mat.emission = WINDOW_LIT
	_window_mat.emission_energy_multiplier = WINDOW_GLOW if lit else 0.0
	_lamp.light_energy = LAMP_ENERGY if lit else 0.0

func _start_smoke() -> void:
	_smoke_fx = FX.chimney_smoke(get_parent(), to_global(_chimney_top))
	if _smoke_fx:
		# A warm plume carries: little drag, so it climbs a few metres before it thins.
		var pm := _smoke_fx.process_material as ParticleProcessMaterial
		pm.damping_min = 0.05
		pm.damping_max = 0.25
		pm.initial_velocity_min = 0.4
		pm.initial_velocity_max = 0.7
		# Big soft puffs, overlapping into one plume rather than a string of beads.
		pm.scale_min = 1.6
		pm.scale_max = 2.8
		_smoke_fx.amount = 60
		_smoke_fx.lifetime = 6.0

# The fire inside and its smoke: the windows' glow and the light they throw flicker like
# an open fire with an oil lamp; the smoke thickens once the fire's built up at night and
# goes where the wind takes it: a lazy plume on a still night, torn flat in a gale.
func _process(delta: float) -> void:
	_fire_t += delta
	if _lit and _window_mat:
		var f := 0.82 + 0.1 * sin(_fire_t * 7.3) * sin(_fire_t * 2.9 + 1.0) + 0.06 * sin(_fire_t * 17.0) + randf_range(-0.05, 0.05)
		_flicker = lerpf(_flicker, f, minf(1.0, delta * 14.0))
		_window_mat.emission_energy_multiplier = WINDOW_GLOW * _flicker
		_window_mat.emission = WINDOW_LIT.lerp(Color(1.0, 0.55, 0.22), 0.5 - 0.5 * sin(_fire_t * 3.1))
		_lamp.light_energy = LAMP_ENERGY * _flicker
	if _smoke_fx == null or not is_instance_valid(_smoke_fx):
		return
	var pm := _smoke_fx.process_material as ParticleProcessMaterial
	var w := Weather.wind_now
	var strength := w.length()
	# Drift with the wind (as a steady push), rising less the harder it blows.
	pm.gravity = Vector3(w.x * 0.45, lerpf(0.45, 0.05, clampf(strength / 5.0, 0.0, 1.0)), w.z * 0.45)
	pm.direction = (Vector3(0.0, 1.0, 0.0) + w * 0.12).normalized()
	_smoke_fx.amount_ratio = 1.0 if _lit else 0.4
	_smoke_fx.speed_scale = 1.0 + clampf(strength / 6.0, 0.0, 0.4)

func _refresh() -> void:
	if _wall_mat:
		_wall_mat.albedo_color = Color(0.38, 0.35, 0.32).lerp(HARL, health_ratio())
	# The roof sags and slips as the cottage is battered.
	var hurt := 1.0 - health_ratio()
	for i in _slabs.size():
		_slabs[i].rotation.z = hurt * (0.22 if i == 0 else -0.14)
		_slabs[i].position.y = (WALL_H + 0.2 + _ridge_y) * 0.5 - hurt * 0.35

func smoke_point() -> Vector3:
	return Vector3(-0.6, _ridge_y, 0.2)

## By the cottage door the fire inside warms a keeper (while the cottage stands).
const HEAT := 2.0
const HEAT_RADIUS := 4.5

func heat_at(p: Vector3) -> float:
	if is_destroyed() or Geo.flat_dist(p, global_position) > HEAT_RADIUS or absf(p.y - global_position.y) > 1.5:
		return 0.0
	return HEAT

func display_name() -> String:
	return "cottage"

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - WIDTH * 0.5)
	var dz := maxf(0.0, absf(local.z) - DEPTH * 0.5)
	return Vector2(dx, dz).length()

# ---- inside: the keepers' menu ----

# Badly damaged and the means to mend it: the hammer comes first. Otherwise, go in.
func _wants_repair() -> bool:
	return is_destroyed() or (is_damaged() and Stock.can_afford(repair_cost()))

func interact_prompt() -> String:
	if _wants_repair():
		return super.interact_prompt()
	return "[E] Go in: eat, flares, dirty fuel, upgrades"

func work_kind() -> String:
	return super.work_kind() if _wants_repair() else ""

func interact(player: Node) -> bool:
	if _wants_repair():
		return super.interact(player)
	if not (player is Player):
		return false
	ChoiceMenu.open(player, "The cottage", menu_rows.bind(player))
	return true

## The menu's rows for this keeper (see ChoiceMenu).
func menu_rows(p: Player) -> Array:
	var rows := []
	var cap: int = Upgrades.pick("garden", Upgrades.MAXHP_CAP)
	var bonus: int = Run.max_hp_bonus[p.idx]
	var gain := mini(MEAL_MAX_HP, cap - bonus)
	var meal := "Eat a meal (1 food): fed, and full health"
	if gain > 0:
		meal += ", +%d max health" % gain
	rows.append({"text": meal, "enabled": Stock.can_afford(MEAL) and (p.hp < p.max_hp or gain > 0 or p.hunger < 90.0), "do": eat.bind(p)})
	if Stock.get_amount("eggs") > 0:
		rows.append({"text": "Boil gull eggs (%s): a meal into the store   %d eggs" % [Stock.cost_str(EGGS_MEAL), Stock.get_amount("eggs")],
			"enabled": Stock.can_afford(EGGS_MEAL), "do": boil_eggs})
	rows.append({"text": "Load a flare (%s)   %d / %d" % [Stock.cost_str(FLARE_COST), p.flares(), Player.FLARES_MAX],
		"enabled": p.flares() < Player.FLARES_MAX and Stock.can_afford(FLARE_COST), "do": load_flare.bind(p)})
	rows.append({"text": "Mix dirty fuel (1 oil, 1 driftwood: %d cans)" % MIX_YIELD, "enabled": Stock.can_afford(MIX_COST), "do": mix_fuel})
	for path in Upgrades.PATHS:
		var cost := Upgrades.next_cost(path)
		if cost.is_empty():
			rows.append({"text": "%s: fully upgraded" % Upgrades.TITLES[path], "enabled": false, "do": func() -> void: pass})
		else:
			rows.append({"text": "Upgrade %s to %d (%s): %s" % [Upgrades.TITLES[path], Upgrades.level(path) + 1, Stock.cost_str(cost), Upgrades.next_blurb(path)],
				"enabled": Stock.can_afford(cost), "do": Upgrades.buy.bind(path, get_tree())})
	return rows

func eat(p: Player) -> void:
	if not Stock.spend(MEAL):
		return
	var cap: int = Upgrades.pick("garden", Upgrades.MAXHP_CAP)
	Run.max_hp_bonus[p.idx] = mini(cap, int(Run.max_hp_bonus[p.idx]) + MEAL_MAX_HP)
	p.max_hp = Player.BASE_HP + int(Run.max_hp_bonus[p.idx])
	p.hp = p.max_hp
	p.eat_meal()
	Audio.sfx("gather", global_position, 0.0, 0.0)
	Events.message.emit("A hot meal: %s is at full strength  (%d)" % [p.keeper_name(), p.max_hp])

func boil_eggs() -> void:
	if Stock.spend(EGGS_MEAL):
		Stock.add("food", 1)
		Audio.sfx("refuel", global_position, -8.0, 0.1)
		Events.message.emit("Gull eggs on to boil: +1 food in the store.")

func load_flare(p: Player) -> void:
	if p.flares() < Player.FLARES_MAX and Stock.spend(FLARE_COST):
		Run.flares[p.idx] = p.flares() + 1
		Audio.sfx("repair", global_position, -6.0, 0.1)

func mix_fuel() -> void:
	if Stock.spend(MIX_COST):
		Stock.add("dirty_fuel", MIX_YIELD)
		Audio.sfx("refuel", global_position, -2.0, 0.1)
		Events.message.emit("+%d dirty fuel: pour it in at the lighthouse [F]" % MIX_YIELD)
