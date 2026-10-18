class_name Lighthouse
extends Structure

const RADIUS := 1.6
const BODY_COLOR := Color(0.85, 0.82, 0.75)
const RUIN_COLOR := Color(0.35, 0.3, 0.28)
const REFUEL_UNITS := 25.0
const REFUEL_COST := {"bio": 1}

var lamp: Lamp
var _body_mat: StandardMaterial3D

func _init() -> void:
	id = "lighthouse"
	max_hp = 200

func _build() -> void:
	var body := Geo.cyl(self, RADIUS, 8.0, BODY_COLOR, Vector3(0.0, 4.0, 0.0), 1.2)
	_body_mat = body.material_override
	# Band and cap sit around the lamp, so they must not block its shadow-casting spot light.
	var band := Geo.box(self, Vector3(2.6, 0.5, 2.6), Color(0.72, 0.12, 0.1), Vector3(0.0, 8.25, 0.0))
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cap := Geo.cyl(self, 0.9, 0.6, Color(0.12, 0.12, 0.14), Vector3(0.0, 8.7, 0.0), 0.5)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Geo.cyl_shape(self, RADIUS, 8.0, Vector3(0.0, 4.0, 0.0))
	lamp = Lamp.new()
	lamp.lighthouse = self
	lamp.position = Vector3(0.0, 8.6, 0.0)
	add_child(lamp)

func _refresh() -> void:
	if _body_mat:
		_body_mat.albedo_color = RUIN_COLOR.lerp(BODY_COLOR, health_ratio())

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
	parts.append("[R] Operate lamp")
	return "   ".join(parts)

func interact(player: Node) -> bool:
	if is_damaged():
		if Stock.can_afford(repair_cost()) or not _can_refuel():
			return super.interact(player)
	if _can_refuel():
		Stock.spend(REFUEL_COST)
		lamp.refuel_clean(REFUEL_UNITS)
		Events.message.emit("Lamp refuelled  (%d%%)" % roundi(lamp.fuel))
		return true
	return false
