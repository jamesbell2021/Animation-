class_name DodgemCar
extends Node3D
## A dodgem car around a contestant: body in their colour, a fat rubber bumper,
## headlights, a steering wheel and the pole that sparks at the top.
## Add it to the contestant's Visual node so it turns with them.

var colour: Color = Color.RED

var _spark_timer: float = 0.0
var _pole_top: Vector3


static func fit(contestant: Contestant) -> DodgemCar:
	var visuals := contestant.get_visuals()
	if visuals == null:
		return null
	var car := DodgemCar.new()
	car.name = "DodgemCar"
	car.colour = contestant.body_colour
	visuals.add_child(car)
	visuals.driving = true
	return car


func _ready() -> void:
	var body := CourseBuilder.make_box_mesh(Vector3(1.5, 0.5, 1.9), colour)
	body.position = Vector3(0.0, 0.38, 0.0)
	add_child(body)
	var nose := CourseBuilder.make_box_mesh(Vector3(1.3, 0.3, 0.5), colour.lightened(0.15))
	nose.position = Vector3(0.0, 0.7, -0.75)
	add_child(nose)
	var seat := CourseBuilder.make_box_mesh(Vector3(1.2, 0.7, 0.25), Color(0.1, 0.1, 0.12))
	seat.position = Vector3(0.0, 0.85, 0.75)
	add_child(seat)
	var bumper := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.08
	torus.material = CourseBuilder.make_material(Color(0.05, 0.05, 0.06))
	bumper.mesh = torus
	bumper.position = Vector3(0.0, 0.2, 0.0)
	bumper.scale = Vector3(1.0, 1.4, 1.2)
	add_child(bumper)
	CourseBuilder.add_neon_strip(self, Vector3(1.52, 0.06, 1.92), Vector3(0.0, 0.64, 0.0), colour.lightened(0.3), "Trim")
	for x: float in [-0.45, 0.45]:
		var light := MeshInstance3D.new()
		var bulb := SphereMesh.new()
		bulb.radius = 0.1
		bulb.height = 0.2
		bulb.material = CourseBuilder.make_neon_material(Color(1.0, 0.95, 0.7), 4.0)
		light.mesh = bulb
		light.position = Vector3(x, 0.5, -0.97)
		add_child(light)
	var wheel := MeshInstance3D.new()
	var rim := TorusMesh.new()
	rim.inner_radius = 0.16
	rim.outer_radius = 0.22
	rim.material = CourseBuilder.make_material(Color(0.1, 0.1, 0.1))
	wheel.mesh = rim
	wheel.position = Vector3(0.0, 0.95, -0.45)
	wheel.rotation.x = -1.1
	add_child(wheel)
	# The pole up to the electric ceiling.
	var pole := CourseBuilder.make_cylinder_mesh(0.04, 2.4, Color(0.6, 0.6, 0.65))
	pole.position = Vector3(0.0, 2.0, 0.85)
	add_child(pole)
	_pole_top = Vector3(0.0, 3.2, 0.85)
	var tip := MeshInstance3D.new()
	var spark := SphereMesh.new()
	spark.radius = 0.08
	spark.height = 0.16
	spark.material = CourseBuilder.make_neon_material(Color(0.6, 0.9, 1.0), 6.0)
	tip.mesh = spark
	tip.position = _pole_top
	add_child(tip)
	_spark_timer = randf_range(0.5, 3.0)


func _process(delta: float) -> void:
	_spark_timer -= delta
	if _spark_timer <= 0.0 and is_visible_in_tree():
		_spark_timer = randf_range(1.0, 3.5)
		FX.burst(self, "electric", to_global(_pole_top), Color.WHITE, 0.5)
