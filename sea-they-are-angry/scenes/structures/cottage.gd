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
const WINDOW_DARK := Color(0.10, 0.12, 0.15)
const WINDOW_LIT := Color(1.0, 0.72, 0.38)
const MEAL := {"food": 1}
const MEAL_MAX_HP := 10
const FLARE_COST := {"scrap": 1}
const MIX_COST := {"oil": 1, "driftwood": 1}
const MIX_YIELD := 2

var _wall_mat: StandardMaterial3D
var _window_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _chimney_top := Vector3.ZERO
var _slabs: Array[MeshInstance3D] = []
var _ridge_y := 0.0

func _init() -> void:
	id = "cottage"
	max_hp = 150

func _build() -> void:
	_wall_mat = Look.flat_mat(WALL, 0.9)
	var stone := Look.flat_mat(STONE)
	var slate := Look.flat_mat(SLATE, 0.6)
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
	Geo.box(self, Vector3(0.62, 0.1, 0.62), Color(0.3, 0.29, 0.27), Vector3(WIDTH * 0.5 - 0.35, ridge_y + 0.72, 0.0))
	_chimney_top = Vector3(WIDTH * 0.5 - 0.35, ridge_y + 0.85, 0.0)
	# Door and windows on the side facing the lighthouse (local -Z).
	Geo.box(self, Vector3(0.8, 1.45, 0.08), Color(0.22, 0.16, 0.11), Vector3(-0.3, 0.95, -DEPTH * 0.5 - 0.03))
	_window_mat = Look.glow_mat(WINDOW_DARK, 0.0)
	for wx in [-1.45, 0.95]:
		var w := Geo.box(self, Vector3(0.6, 0.55, 0.08), WINDOW_DARK, Vector3(wx, 1.45, -DEPTH * 0.5 - 0.03))
		w.material_override = _window_mat
	var back := Geo.box(self, Vector3(0.6, 0.55, 0.08), WINDOW_DARK, Vector3(0.6, 1.45, DEPTH * 0.5 + 0.03))
	back.material_override = _window_mat
	_lamp = OmniLight3D.new()
	_lamp.light_color = WINDOW_LIT
	_lamp.omni_range = 4.5
	_lamp.light_energy = 0.0
	_lamp.position = Vector3(0.0, 1.4, -DEPTH * 0.5 - 0.8)
	add_child(_lamp)
	Geo.box_shape(self, Vector3(WIDTH, WALL_H + 0.4, DEPTH), Vector3(0.0, WALL_H * 0.5 + 0.2, 0.0))
	Cycle.phase_changed.connect(_on_phase_changed)
	_set_windows(Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT)
	FX.chimney_smoke.call_deferred(self, to_global(_chimney_top))

func _on_phase_changed(p: int) -> void:
	_set_windows(p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT)

func _set_windows(lit: bool) -> void:
	_window_mat.albedo_color = WINDOW_LIT if lit else WINDOW_DARK
	_window_mat.emission = WINDOW_LIT
	_window_mat.emission_energy_multiplier = 2.2 if lit else 0.0
	_lamp.light_energy = 1.4 if lit else 0.0

func _refresh() -> void:
	if _wall_mat:
		_wall_mat.albedo_color = Color(0.32, 0.30, 0.28).lerp(WALL, health_ratio())
	# The roof sags and slips as the cottage is battered.
	var hurt := 1.0 - health_ratio()
	for i in _slabs.size():
		_slabs[i].rotation.z = hurt * (0.22 if i == 0 else -0.14)
		_slabs[i].position.y = (WALL_H + 0.2 + _ridge_y) * 0.5 - hurt * 0.35

func smoke_point() -> Vector3:
	return Vector3(-0.6, _ridge_y, 0.2)

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
	var meal := "Eat a meal (1 food): full health"
	if gain > 0:
		meal += ", +%d max health" % gain
	rows.append({"text": meal, "enabled": Stock.can_afford(MEAL) and (p.hp < p.max_hp or gain > 0), "do": eat.bind(p)})
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
	Audio.sfx("gather", global_position, 0.0, 0.0)
	Events.message.emit("A hot meal: %s is at full strength  (%d)" % [p.keeper_name(), p.max_hp])

func load_flare(p: Player) -> void:
	if p.flares() < Player.FLARES_MAX and Stock.spend(FLARE_COST):
		Run.flares[p.idx] = p.flares() + 1
		Audio.sfx("repair", global_position, -6.0, 0.1)

func mix_fuel() -> void:
	if Stock.spend(MIX_COST):
		Stock.add("dirty_fuel", MIX_YIELD)
		Audio.sfx("refuel", global_position, -2.0, 0.1)
		Events.message.emit("+%d dirty fuel: pour it in at the lighthouse [F]" % MIX_YIELD)
