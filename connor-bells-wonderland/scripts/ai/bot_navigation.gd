class_name BotNavigation
extends RefCounted
## Builds a world-space waypoint route through a built FairgroundCourse.
## Each waypoint: {"pos": Vector3, "jump": bool, "wait": bool, "radius": float}.
## "jump" = gaps/steps here need a jump; "wait" = wait for a moving platform.

var waypoints: Array[Dictionary] = []


func build(course: FairgroundCourse) -> void:
	waypoints.clear()
	if course == null or course.sections.is_empty():
		push_error("BotNavigation.build: course is null or not built.")
		return
	for section in course.sections:
		for wp in _section_waypoints(section):
			var copy := wp.duplicate()
			copy["pos"] = section.to_global(wp["pos"])
			waypoints.append(copy)
	var finish := course.get_finish_area()
	if finish != null:
		waypoints.append(_wp(finish.global_position.x, finish.global_position.y - 1.5, finish.global_position.z, false, false, 1.0))


func count() -> int:
	return waypoints.size()


func get_waypoint(index: int) -> Dictionary:
	if waypoints.is_empty():
		return _wp(0.0, 0.0, 0.0)
	return waypoints[clampi(index, 0, waypoints.size() - 1)]


## Index of the closest waypoint to [param pos] (used after respawns).
func nearest_index(pos: Vector3) -> int:
	var best := 0
	var best_dist := INF
	for i in range(waypoints.size()):
		var d: float = (waypoints[i]["pos"] as Vector3).distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _wp(x: float, y: float, z: float, jump: bool = false, wait: bool = false, radius: float = 1.3) -> Dictionary:
	return {"pos": Vector3(x, y, z), "jump": jump, "wait": wait, "radius": radius}


func _section_waypoints(section: CourseSection) -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	if section is SectionBigTop:
		route = [_wp(0.0, 0.0, -10.0), _wp(0.0, 0.0, -16.0, true), _wp(0.0, 0.0, -22.0, true), _wp(0.0, 0.0, -30.0), _wp(0.0, 0.0, -38.0)]
	elif section is SectionDodgems:
		route = [_wp(0.0, 0.0, -8.0), _wp(1.0, 0.0, -18.0), _wp(-1.0, 0.0, -28.0), _wp(0.0, 0.0, -38.0), _wp(0.0, 0.0, -46.0)]
	elif section is SectionDizzyRides:
		route = [
			_wp(2.0, 0.0, -6.0), _wp(2.0, 0.0, -11.0, true), _wp(2.0, 0.0, -17.0), _wp(2.0, 0.0, -22.0, true),
			_wp(2.0, 0.0, -28.0), _wp(0.5, 0.0, -33.0, true), _wp(0.0, 0.0, -36.0, true), _wp(0.0, 0.0, -41.0, true),
			_wp(0.0, 0.0, -47.0, true), _wp(0.0, 0.0, -50.0),
		]
	elif section is SectionBouncyYard:
		route = [
			_wp(0.0, 0.0, -4.0), _wp(0.0, 0.0, -10.0, true), _wp(0.0, 0.0, -17.0, true), _wp(0.0, 0.0, -24.0, true),
			_wp(0.0, 0.0, -31.0, false, false, 2.0), _wp(0.0, 0.0, -37.0), _wp(0.0, 0.0, -41.0), _wp(0.0, 0.0, -47.0), _wp(0.0, 0.0, -50.0),
		]
	elif section is SectionHighRides:
		var h: float = (section as SectionHighRides).top_height
		route = [
			_wp(0.0, 0.0, -4.0), _wp(0.0, h * 0.5, -11.0), _wp(0.0, h, -18.0), _wp(0.0, h, -22.5, false, true, 1.0),
			_wp(0.0, h, -25.0, false, true, 1.0), _wp(0.0, h, -31.0, false, true, 1.0), _wp(0.0, h, -37.0, false, true, 1.0),
			_wp(0.0, h, -41.0), _wp(0.0, h, -45.0), _wp(0.0, 2.0, -56.0), _wp(0.0, 4.0, -64.0), _wp(0.0, 0.0, -75.0), _wp(0.0, 0.0, -78.0),
		]
	elif section is SectionFinaleTower:
		route = _tower_route(section as SectionFinaleTower)
	else:
		route = [_wp(0.0, 0.0, -section.section_length * 0.5), _wp(0.0, 0.0, -section.section_length + 2.0)]
	return route


func _tower_route(tower: SectionFinaleTower) -> Array[Dictionary]:
	var route: Array[Dictionary] = [_wp(0.0, 0.0, -8.0), _wp(0.0, 0.0, -12.5)]
	var centre := Vector3(0.0, 0.0, SectionFinaleTower.TOWER_Z)
	for i in range(tower.steps):
		var a := PI * 0.5 + deg_to_rad(tower.step_angle_degrees) * float(i)
		var h := tower.step_height * float(i + 1)
		var pos := centre + Vector3(cos(a) * (tower.ledge_radius + 0.6), h, sin(a) * (tower.ledge_radius + 0.6))
		route.append(_wp(pos.x, pos.y, pos.z, true, false, 1.0))
	var top_y := tower.step_height * float(tower.steps + 1)
	var last_a := PI * 0.5 + deg_to_rad(tower.step_angle_degrees) * float(tower.steps - 1)
	var edge := centre + Vector3(cos(last_a) * (tower.core_radius + 0.5), top_y, sin(last_a) * (tower.core_radius + 0.5))
	route.append(_wp(edge.x, edge.y, edge.z, true, false, 1.0))
	route.append(_wp(centre.x, top_y, centre.z, false, false, 1.0))
	return route
