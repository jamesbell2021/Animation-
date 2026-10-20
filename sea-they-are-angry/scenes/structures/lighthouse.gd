class_name Lighthouse
extends Structure

const RADIUS := 1.6
const TOP_RADIUS := 1.15
const TOWER_BASE := 0.6
const TOWER_TOP := 8.2
const SEGMENTS := 12
const BODY_COLOR := Color(0.88, 0.86, 0.80)
const RUIN_COLOR := Color(0.35, 0.3, 0.28)
const BAND_COLOR := Color(0.62, 0.12, 0.10)
const IRON := Color(0.14, 0.15, 0.16)
const GLASS_DARK := Color(0.10, 0.13, 0.16)
const GLASS_LIT := Color(1.0, 0.78, 0.45)
const REFUEL_UNITS := 40.0
const REFUEL_COST := {"bio": 1}
const DIRTY_UNITS := 30.0
const BRASS := Color(0.78, 0.6, 0.28)
const COPPER := Color(0.72, 0.4, 0.24)

var lamp: Lamp
var _body_mat: StandardMaterial3D
# The render texture averages a little under white: lifted so the paint reads as painted.
const HARL_LIFT := 1.12
var _glass_mat: StandardMaterial3D
# Fittings added by upgrades, shown from the level in the key on.
var _fittings := {2: [], 3: []}

func _init() -> void:
	id = "lighthouse"
	max_hp = 200

func _radius_at(y: float) -> float:
	return lerpf(RADIUS, TOP_RADIUS, (y - TOWER_BASE) / (TOWER_TOP - TOWER_BASE))

func _ring(y0: float, y1: float, pad: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.bottom_radius = _radius_at(y0) + pad
	m.top_radius = _radius_at(y1) + pad
	m.height = y1 - y0
	m.radial_segments = SEGMENTS
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.position = Vector3(0.0, (y0 + y1) * 0.5, 0.0)
	add_child(mi)
	return mi

func _cyl(r_bottom: float, r_top: float, h: float, y: float, mat: Material, segs: int = SEGMENTS) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.bottom_radius = r_bottom
	m.top_radius = r_top
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.position = Vector3(0.0, y, 0.0)
	add_child(mi)
	return mi

func _build() -> void:
	add_to_group("lighthouse")
	# Painted render over stone, a rubble plinth, a boarded door.
	var stone := Look.textured("rubble", Color(1.05, 1.05, 1.05), 1.4, 0.9, 1.2)
	var iron := Look.flat_mat(IRON, 0.6)
	var band := Look.textured("harl", BAND_COLOR * HARL_LIFT, 1.2, 0.8, 0.7)
	_body_mat = Look.textured("harl", BODY_COLOR * HARL_LIFT, 1.2, 0.85, 0.7)
	# Stone plinth with a dark door facing the camera.
	_cyl(2.15, 1.95, 0.7, 0.35, stone, 10)
	var door := Geo.box(self, Vector3(0.75, 1.35, 0.2), Color(0.18, 0.13, 0.09), Vector3(0.0, 1.25, 1.52))
	door.material_override = Look.textured("planks", Color(0.55, 0.38, 0.27), 0.9)
	var lintel := Geo.box(self, Vector3(0.95, 0.12, 0.3), Color(0.40, 0.39, 0.37), Vector3(0.0, 1.98, 1.52))
	lintel.material_override = Look.textured("rubble", Color(1.2, 1.2, 1.2), 0.6)
	# Tapered tower with two red bands and a couple of small windows.
	_ring(TOWER_BASE, TOWER_TOP, 0.0, _body_mat)
	_ring(2.7, 3.8, 0.02, band)
	_ring(5.4, 6.5, 0.02, band)
	for y in [4.6, 7.2]:
		var r := _radius_at(y)
		Geo.box(self, Vector3(0.32, 0.5, 0.1), Color(0.12, 0.14, 0.17), Vector3(0.0, y, r - 0.02))
	# Gallery deck and railing.
	var deck := _cyl(1.6, 1.6, 0.16, 8.28, iron, 14)
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rail := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.48
	torus.outer_radius = 1.54
	torus.rings = 20
	torus.ring_segments = 4
	rail.mesh = torus
	rail.material_override = iron
	rail.position = Vector3(0.0, 8.85, 0.0)
	rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rail)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var post := Geo.box(self, Vector3(0.05, 0.55, 0.05), IRON, Vector3(sin(a) * 1.51, 8.6, cos(a) * 1.51))
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Lantern room: glazing that glows when the lamp is lit, iron mullions, red dome.
	_glass_mat = Look.glow_mat(GLASS_DARK, 0.0)
	var glass := _cyl(0.85, 0.85, 1.0, 8.86, _glass_mat, 10)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.3
		var m := Geo.box(self, Vector3(0.06, 1.0, 0.06), IRON, Vector3(sin(a) * 0.86, 8.86, cos(a) * 0.86))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var roof := _cyl(0.98, 0.12, 0.62, 9.67, Look.flat_mat(BAND_COLOR, 0.7), 10)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ball := Geo.sphere(self, 0.13, IRON, Vector3(0.0, 10.05, 0.0))
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_fittings()
	Geo.cyl_shape(self, RADIUS, 8.0, Vector3(0.0, 4.0, 0.0))
	lamp = Lamp.new()
	lamp.lighthouse = self
	lamp.position = Vector3(0.0, 8.6, 0.0)
	add_child(lamp)

# Level 2: brass hoops round the tower and a brass gallery rail. Level 3: a copper
# dome and iron storm shutters braced against the wall.
func _build_fittings() -> void:
	var brass := Look.flat_mat(BRASS, 0.35)
	brass.metallic = 0.6
	for y in [2.6, 5.3, 8.0]:
		var hoop := _ring(y, y + 0.14, 0.05, brass)
		_fittings[2].append(hoop)
	var rail := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.58
	torus.rings = 20
	torus.ring_segments = 4
	rail.mesh = torus
	rail.material_override = brass
	rail.position = Vector3(0.0, 8.62, 0.0)
	add_child(rail)
	_fittings[2].append(rail)
	var copper := Look.flat_mat(COPPER, 0.4)
	copper.metallic = 0.5
	var dome := _cyl(1.02, 0.14, 0.66, 9.69, copper, 10)
	_fittings[3].append(dome)
	var iron := Look.flat_mat(IRON, 0.6)
	for y in [4.6, 7.2]:
		var r := _radius_at(y)
		for side in [-1.0, 1.0]:
			var shutter := Geo.box(self, Vector3(0.2, 0.56, 0.05), IRON, Vector3(side * 0.27, y, r + 0.02))
			shutter.material_override = iron
			shutter.rotation.y = side * 0.5
			_fittings[3].append(shutter)
	for n in _fittings[2] + _fittings[3]:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false

## Show the fittings for an upgrade level, 1 to 3.
func set_level(l: int) -> void:
	for k in _fittings:
		for n in _fittings[k]:
			n.visible = l >= k

## Lantern glazing brightness, 0 (unlit) to about 1.3 (boosted). Called by the lamp.
func set_lantern(k: float) -> void:
	if _glass_mat == null:
		return
	_glass_mat.albedo_color = GLASS_DARK.lerp(GLASS_LIT, clampf(k, 0.0, 1.0))
	_glass_mat.emission = GLASS_LIT
	_glass_mat.emission_energy_multiplier = 3.0 * k

func _refresh() -> void:
	if _body_mat:
		_body_mat.albedo_color = RUIN_COLOR.lerp(BODY_COLOR * HARL_LIFT, health_ratio())

func display_name() -> String:
	return "lighthouse"

func surface_distance(p: Vector3) -> float:
	return maxf(0.0, Geo.flat_dist(p, global_position) - RADIUS)

func repair_cost() -> Dictionary:
	return {"driftwood": 1, "scrap": 1}

func repair(amount: int) -> void:
	super.repair(amount)
	if lamp:
		lamp._recover()

func _can_refuel() -> bool:
	return lamp != null and lamp.fuel < Lamp.FUEL_MAX - 1.0 and Stock.can_afford(REFUEL_COST)

func interact_prompt() -> String:
	var parts: Array[String] = []
	if is_damaged():
		parts.append(super.interact_prompt())
	elif _can_refuel():
		parts.append("[E] Refuel (1 bio)")
	if Stock.get_amount("dirty_fuel") > 0 and lamp != null:
		parts.append("[F] Dirty fuel")
	parts.append("[R] Operate lamp")
	return "   ".join(parts)

func work_kind() -> String:
	if is_damaged() and (Stock.can_afford(repair_cost()) or not _can_refuel()):
		return super.work_kind()
	if _can_refuel():
		return "can"
	return ""

func interact(player: Node) -> bool:
	if is_damaged():
		if Stock.can_afford(repair_cost()) or not _can_refuel():
			return super.interact(player)
	if _can_refuel():
		Stock.spend(REFUEL_COST)
		lamp.refuel_clean(REFUEL_UNITS)
		Audio.sfx("refuel", global_position + Vector3(0.0, 1.0, 0.0))
		Events.message.emit("Lamp refuelled  (%d%%)" % roundi(lamp.fuel))
		return true
	return false

## Dirty fuel: oil and all, poured in. Burns hot for a while, and the sea knows.
func use_dirty(_player: Node) -> bool:
	if lamp == null or not Stock.spend({"dirty_fuel": 1}):
		return false
	lamp.refuel_dirty(DIRTY_UNITS)
	Audio.sfx("refuel", global_position + Vector3(0.0, 1.0, 0.0), 0.0, 0.0)
	Audio.sfx("ignite", global_position + Vector3(0.0, 8.0, 0.0), -4.0, 0.0)
	Events.message.emit("Dirty fuel in: the light burns hot  (%d%%).  The sea smells it..." % roundi(lamp.fuel))
	return true
