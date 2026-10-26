class_name Shed
extends Structure
## The oil and tool store beside the cottage. Creatures that raid the homestead batter it.
## Inside, the workbench: the old keeper's double-barrelled shotgun on the wall and his
## box of cartridges, a weed burner to rig as a flamer, tins of rat poison, and what's
## needed to make a longbow and arrows from driftwood and fill petrol bombs with bio.

const FLAMER_COST := {"scrap": 2}
const BOW_COST := {"driftwood": 3, "seaweed": 1}
const ARROWS_COST := {"driftwood": 1, "scrap": 1}
const ARROWS_MADE := 5
const BOMBS_COST := {"bio": 1, "seaweed": 1}
const BOMBS_MADE := 2

const WIDTH := 2.4
const DEPTH := 2.0
const WALL_H := 1.6
const STONE := Color(0.44, 0.43, 0.40)

var _wall_mat: StandardMaterial3D
var _roof: MeshInstance3D
var _door: MeshInstance3D

func _init() -> void:
	id = "shed"
	max_hp = 120

func _build() -> void:
	# A rubble-built store with a slate roof and a boarded door.
	_wall_mat = Look.stone(STONE)
	var walls := Geo.box(self, Vector3(WIDTH, WALL_H, DEPTH), Color.WHITE, Vector3(0.0, WALL_H * 0.5, 0.0))
	walls.material_override = _wall_mat
	_roof = Geo.box(self, Vector3(2.7, 0.12, 2.4), Color.WHITE, Vector3(0.0, 1.75, 0.0))
	_roof.material_override = Look.textured("slate", Color.WHITE, 1.0, 0.55, 1.4)
	_roof.rotation.x = deg_to_rad(-12.0)
	_door = Geo.box(self, Vector3(0.75, 1.25, 0.08), Color(0.30, 0.22, 0.14), Vector3(0.2, 0.62, -1.03))
	_door.material_override = Look.wood(Color(0.30, 0.22, 0.14))
	var barrel := Geo.cyl(self, 0.28, 0.8, Color.WHITE, Vector3(-0.85, 0.4, -1.35))
	barrel.material_override = Look.flat_mat(Color(0.18, 0.2, 0.22), 0.5)
	Geo.box_shape(self, Vector3(WIDTH, WALL_H, DEPTH), Vector3(0.0, WALL_H * 0.5, 0.0))

func _refresh() -> void:
	if _wall_mat == null:
		return
	var hurt := 1.0 - health_ratio()
	_wall_mat.albedo_color = (Color(0.26, 0.25, 0.24).lerp(STONE, health_ratio())) * 2.6
	_roof.rotation = Vector3(deg_to_rad(-12.0) - hurt * 0.2, 0.0, hurt * 0.25)
	_roof.position.y = 1.75 - hurt * 0.3
	# The door hangs off one hinge, then off both.
	_door.rotation.z = hurt * 0.6
	_door.position.x = 0.2 + hurt * 0.2

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
