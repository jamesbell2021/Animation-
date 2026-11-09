class_name Shed
extends Structure
## The oil and tool store beside the cottage. Creatures that raid the homestead batter it.
## Inside, the workbench: the old keeper's double-barrelled shotgun on the wall and his
## box of cartridges, a weed burner to rig as a flamer, tins of rat poison, and what's
## needed to make a longbow and arrows from driftwood and fill petrol bombs with bio.

const FLAMER_COST := Balance.COST_FLAMER
const BOW_COST := Balance.COST_BOW
const ARROWS_COST := Balance.COST_ARROWS
const ARROWS_MADE := Balance.ARROWS_MADE
const BOMBS_COST := Balance.COST_BOMBS
const BOMBS_MADE := Balance.BOMBS_MADE

const WIDTH := 3.2
const DEPTH := 2.6
const WALL_H := 2.3
const WALL_T := 0.2
const DOOR_X := 0.25
const DOOR_W := 0.95
const STONE := Color(0.44, 0.43, 0.40)

var _wall_mat: StandardMaterial3D
var _roof: MeshInstance3D
var _door: MeshInstance3D
## The room inside (Interior), and what's in it that comes and goes.
var interior: Interior
var _gun: Node3D
var _burner: Node3D
var _look_t := 0.0

func _init() -> void:
	id = "shed"
	max_hp = 120

func _build() -> void:
	# A rubble-built store with a slate roof and a boarded door, standing open.
	interior = Interior.new()
	add_child(interior)
	var up := interior.upper
	_wall_mat = Look.stone(STONE)
	interior.walls(self, self, WIDTH, DEPTH, WALL_H, 0.0, WALL_T, _wall_mat, DOOR_X, DOOR_W, 1.7)
	_roof = Geo.box(up, Vector3(WIDTH + 0.3, 0.12, DEPTH + 0.4), Color.WHITE, Vector3(0.0, WALL_H + 0.3, 0.0))
	_roof.material_override = Look.textured("slate", Color.WHITE, 1.0, 0.55, 1.4)
	_roof.rotation.x = deg_to_rad(-12.0)
	_door = Geo.box(up, Vector3(DOOR_W - 0.05, 1.6, 0.06), Color(0.30, 0.22, 0.14), Vector3(DOOR_X + DOOR_W * 0.5 - 0.05, 0.8, -DEPTH * 0.5 + WALL_T + 0.4))
	_door.material_override = Look.wood(Color(0.30, 0.22, 0.14))
	_door.rotation.y = deg_to_rad(80.0)
	var barrel := Geo.cyl(self, 0.28, 0.8, Color.WHITE, Vector3(-1.2, 0.4, -DEPTH * 0.5 - 0.4))
	barrel.material_override = Look.flat_mat(Color(0.18, 0.2, 0.22), 0.5)
	_furnish()

# The workbench along the back wall with a vice, the shotgun lying on it while it's in
# the shed, tins of rat poison and a sheaf of arrows; the weed burner in the corner;
# shelves of tins and a drum of oil.
func _furnish() -> void:
	var wood := Look.wood(Color(0.45, 0.33, 0.22))
	var iron := Look.flat_mat(Color(0.14, 0.14, 0.15), 0.45)
	var ix := WIDTH * 0.5 - WALL_T
	var iz := DEPTH * 0.5 - WALL_T
	var boards := Geo.box(self, Vector3(WIDTH - WALL_T * 2.0, 0.03, DEPTH - WALL_T * 2.0), Color.WHITE, Vector3(0.0, 0.015, 0.0))
	boards.material_override = Look.textured("planks", Color(0.42, 0.36, 0.3), 0.8)
	var bench := Geo.box(self, Vector3(1.6, 0.07, 0.55), Color.WHITE, Vector3(-0.1, 0.85, iz - 0.28))
	bench.material_override = wood
	for lx in [-0.8, 0.6]:
		var leg := Geo.box(self, Vector3(0.08, 0.82, 0.45), Color.WHITE, Vector3(lx, 0.41, iz - 0.28))
		leg.material_override = wood
	var vice := Geo.box(self, Vector3(0.16, 0.14, 0.18), Color.WHITE, Vector3(0.55, 0.96, iz - 0.12))
	vice.material_override = iron
	# The shotgun on the bench: two barrels and a stock.
	_gun = Node3D.new()
	_gun.position = Vector3(-0.2, 0.91, iz - 0.3)
	_gun.rotation.y = 0.15
	add_child(_gun)
	var barrels := Geo.box(_gun, Vector3(0.75, 0.05, 0.08), Color.WHITE, Vector3(0.2, 0.0, 0.0))
	barrels.material_override = Look.flat_mat(Color(0.12, 0.12, 0.13), 0.3)
	var stock := Geo.box(_gun, Vector3(0.4, 0.07, 0.07), Color.WHITE, Vector3(-0.35, -0.01, 0.0))
	stock.material_override = Look.wood(Color(0.4, 0.22, 0.12))
	for i in 3:
		var tin := Geo.cyl(self, 0.07, 0.14, Color.WHITE, Vector3(-0.75 + float(i) * 0.16, 0.96, iz - 0.42))
		tin.material_override = Look.flat_mat(Color(0.75, 0.68, 0.2) if i != 1 else Color(0.5, 0.15, 0.12), 0.4)
	for i in 5:
		var arrow := Geo.box(self, Vector3(0.7, 0.015, 0.015), Color.WHITE, Vector3(0.1, 0.9, iz - 0.5 + float(i) * 0.02))
		arrow.material_override = wood
	# The weed burner in the corner by the door: a tank and its lance.
	_burner = Node3D.new()
	_burner.position = Vector3(ix - 0.25, 0.0, -iz + 0.3)
	add_child(_burner)
	var tank := Geo.cyl(_burner, 0.16, 0.6, Color.WHITE, Vector3(0.0, 0.3, 0.0))
	tank.material_override = Look.flat_mat(Color(0.55, 0.12, 0.1), 0.5)
	var lance := Geo.box(_burner, Vector3(0.04, 1.0, 0.04), Color.WHITE, Vector3(-0.12, 0.6, 0.1))
	lance.rotation.z = 0.25
	lance.material_override = iron
	# Shelves on the end wall, tins and a coil of rope on them; a drum of oil.
	for k in 2:
		var shelf := Geo.box(self, Vector3(0.3, 0.04, 1.1), Color.WHITE, Vector3(-ix + 0.15, 0.3 + float(k) * 0.32, 0.0))
		shelf.material_override = wood
		for i in 3:
			var t := Geo.cyl(self, 0.06, 0.12, Color.WHITE, Vector3(-ix + 0.15, 0.38 + float(k) * 0.32, -0.35 + float(i) * 0.3))
			t.material_override = Look.flat_mat([Color(0.3, 0.42, 0.55), Color(0.62, 0.6, 0.55), Color(0.45, 0.5, 0.3)][(i + k) % 3], 0.5)
	var drum := Geo.cyl(self, 0.24, 0.7, Color.WHITE, Vector3(ix - 0.3, 0.35, iz - 0.3))
	drum.material_override = Look.flat_mat(Color(0.22, 0.32, 0.22), 0.5)
	_show_kit()

# The shotgun on the bench while it's in the shed; the burner while it's here.
func _show_kit() -> void:
	if _gun:
		_gun.visible = Arsenal.holder("shotgun") < 0
	if _burner:
		_burner.visible = Arsenal.holder("flamer") < 0

func _process(delta: float) -> void:
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = 0.5
		_show_kit()

func _refresh() -> void:
	if _wall_mat == null:
		return
	var hurt := 1.0 - health_ratio()
	_wall_mat.albedo_color = (Color(0.26, 0.25, 0.24).lerp(STONE, health_ratio())) * 2.6
	_roof.rotation = Vector3(deg_to_rad(-12.0) - hurt * 0.2, 0.0, hurt * 0.25)
	_roof.position.y = WALL_H + 0.3 - hurt * 0.3
	# The door hangs off one hinge, then off both.
	_door.rotation.z = hurt * 0.6

# ---- the workbench ----

# Badly damaged and the means to mend it: the hammer first. Otherwise, the workbench.
func _wants_repair() -> bool:
	return is_destroyed() or (is_damaged() and Stock.can_afford(repair_cost()))

func interact_prompt() -> String:
	if _wants_repair():
		return super.interact_prompt()
	return "[E] The workbench: shotgun, flamer, longbow, petrol bombs"

func work_kind() -> String:
	return super.work_kind() if _wants_repair() else ""

func interact(player: Node) -> bool:
	if _wants_repair():
		return super.interact(player)
	if not (player is Player):
		return false
	ChoiceMenu.open(player, "The shed", menu_rows.bind(player))
	return true

func menu_rows(p: Player) -> Array:
	var rows := []
	var arms: Arsenal = p.arsenal
	var nobody := func() -> void: pass
	# The shotgun on its pegs.
	var gun_with := Arsenal.holder("shotgun")
	if gun_with == p.idx:
		rows.append({"text": "Hang the shotgun back on the wall", "do": arms.take_away.bind("shotgun")})
	elif gun_with >= 0 and _helper(gun_with) != null:
		rows.append({"text": "Take the shotgun back from %s" % Players.NAMES[gun_with % Players.NAMES.size()], "do": take_back.bind(gun_with, p)})
	elif gun_with >= 0:
		rows.append({"text": "The shotgun: %s has it" % Players.NAMES[gun_with % Players.NAMES.size()], "enabled": false, "do": nobody})
	else:
		rows.append({"text": "Take the double-barrelled shotgun off the wall (%d cartridges in the box)" % Stock.get_amount("shells"), "do": arms.give.bind("shotgun")})
	# The weed burner.
	var flamer_with := Arsenal.holder("flamer")
	if not Run.flamer_rigged:
		rows.append({"text": "Rig a flamer from the weed burner (%s): burns bio, nice and deadly" % Stock.cost_str(FLAMER_COST),
			"enabled": Stock.can_afford(FLAMER_COST), "do": rig_flamer.bind(p)})
	elif flamer_with == p.idx:
		if Run.flamer_fuel < Arsenal.TANK - 10.0:
			rows.append({"text": "Fill the flamer's tank (%s)   %d%%" % [Stock.cost_str(Arsenal.REFILL_COST), roundi(Run.flamer_fuel)],
				"enabled": Stock.can_afford(Arsenal.REFILL_COST), "do": fill_flamer})
		rows.append({"text": "Leave the flamer in the shed", "do": arms.take_away.bind("flamer")})
	elif flamer_with >= 0:
		rows.append({"text": "The flamer: %s has it" % Players.NAMES[flamer_with % Players.NAMES.size()], "enabled": false, "do": nobody})
	else:
		rows.append({"text": "Take the flamer (tank %d%%)" % roundi(Run.flamer_fuel), "do": arms.give.bind("flamer")})
	# A longbow of one's own, and arrows for everyone's.
	if not arms.carries("bow"):
		rows.append({"text": "Make a longbow (%s): driftwood stave, kelp-cord string" % Stock.cost_str(BOW_COST),
			"enabled": Stock.can_afford(BOW_COST), "do": make_bow.bind(p)})
	else:
		# One's own made: one for a helper keeper too, who'll shoot what comes near it.
		for k in Players.nodes:
			if is_instance_valid(k) and k.ai and k.arsenal != null and not k.arsenal.carries("bow"):
				rows.append({"text": "Make a longbow for %s (%s)" % [k.keeper_name(), Stock.cost_str(BOW_COST)],
					"enabled": Stock.can_afford(BOW_COST), "do": make_bow_for.bind(k)})
	rows.append({"text": "Whittle %d arrows (%s)   %d in store" % [ARROWS_MADE, Stock.cost_str(ARROWS_COST), Stock.get_amount("arrows")],
		"enabled": Stock.can_afford(ARROWS_COST), "do": make.bind(ARROWS_COST, "arrows", ARROWS_MADE)})
	rows.append({"text": "Fill %d petrol bombs (%s: bio in a bottle, a kelp rag)   %d in store" % [BOMBS_MADE, Stock.cost_str(BOMBS_COST), Stock.get_amount("bombs")],
		"enabled": Stock.can_afford(BOMBS_COST), "do": make.bind(BOMBS_COST, "bombs", BOMBS_MADE)})
	rows.append({"text": "Rat poison: %d tins (set it as bait at a trap cairn)" % Stock.get_amount("poison"), "enabled": false, "do": nobody})
	return rows

func rig_flamer(p: Player) -> void:
	if Run.flamer_rigged or not Stock.spend(FLAMER_COST):
		return
	Run.flamer_rigged = true
	Run.flamer_fuel = Arsenal.TANK * 0.5
	Audio.sfx("hammer", global_position, -2.0, 0.1)
	Events.message.emit("The weed burner's rigged as a flamer: hold attack to burn. It drinks bio.")
	p.arsenal.give("flamer")

func fill_flamer() -> void:
	if Stock.spend(Arsenal.REFILL_COST):
		Run.flamer_fuel = Arsenal.TANK
		Audio.sfx("refuel", global_position, -2.0, 0.1)

func make_bow(p: Player) -> void:
	if p.arsenal.carries("bow") or not Stock.spend(BOW_COST):
		return
	Audio.sfx("hammer", global_position, -4.0, 0.1)
	Events.message.emit("%s has a longbow: hold attack to draw, let go to loose." % p.keeper_name())
	p.arsenal.give("bow")

func make_bow_for(k: Player) -> void:
	if k.arsenal.carries("bow") or not Stock.spend(BOW_COST):
		return
	Audio.sfx("hammer", global_position, -4.0, 0.1)
	k.arsenal.give("bow")
	k.arsenal.select("hook")
	Events.message.emit("%s has a longbow now, and will shoot what comes near (arrows from the store)." % k.keeper_name())

## A helper keeper with the shotgun (or nothing): who has it, if they're the computer's.
func _helper(idx: int) -> Player:
	if idx < 0 or idx >= Players.nodes.size():
		return null
	var k = Players.nodes[idx]
	return k if is_instance_valid(k) and k is Player and k.ai else null

func take_back(from_idx: int, p: Player) -> void:
	var k := _helper(from_idx)
	if k == null:
		return
	k.arsenal.take_away("shotgun")
	p.arsenal.give("shotgun")

func make(cost: Dictionary, kind: String, n: int) -> void:
	if Stock.spend(cost):
		Stock.add(kind, n)
		Audio.sfx("hammer", global_position, -6.0, 0.1)

func smoke_point() -> Vector3:
	return Vector3(0.0, WALL_H + 0.2, 0.0)

func display_name() -> String:
	return "shed"

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - WIDTH * 0.5)
	var dz := maxf(0.0, absf(local.z) - DEPTH * 0.5)
	return Vector2(dx, dz).length()
