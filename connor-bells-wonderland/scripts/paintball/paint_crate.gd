class_name PaintCrate
extends Node3D
## A glowing crate of paint tins. Run into it to refill your paintballs; it
## comes back after a while. The PaintballManager decides who gets it.

var active: bool = true

var _visual: Node3D
var _time: float = 0.0


func _ready() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var box := CourseBuilder.make_box_mesh(Vector3(1.0, 0.5, 0.7), Color(0.12, 0.12, 0.15))
	box.position = Vector3(0.0, 0.25, 0.0)
	_visual.add_child(box)
	CourseBuilder.add_neon_strip(_visual, Vector3(1.04, 0.08, 0.74), Vector3(0.0, 0.5, 0.0), CourseBuilder.accent(1), "Rim")
	for i in range(4):
		var tin := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.15
		cyl.height = 0.3
		cyl.material = CourseBuilder.make_neon_material(CourseBuilder.accent(i), 1.2)
		tin.mesh = cyl
		tin.position = Vector3(-0.3 + float(i % 2) * 0.6, 0.65, -0.15 + float(i / 2) * 0.3)
		_visual.add_child(tin)
	var label := Label3D.new()
	label.text = "PAINT"
	label.font_size = 64
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = CourseBuilder.accent(1)
	label.outline_size = 10
	label.position = Vector3(0.0, 1.3, 0.0)
	_visual.add_child(label)
	FX.attach(_visual, "sparkle", Vector3(0.0, 0.6, 0.0), Color(0.6, 1.5, 2.0))


func _process(delta: float) -> void:
	_time += delta
	if _visual.visible:
		_visual.rotation.y += delta * 1.2
		_visual.position.y = 0.15 + sin(_time * 2.5) * 0.1


func set_active(on: bool) -> void:
	if on != active and is_inside_tree():
		FX.burst(self, "sparkle" if on else "paint", global_position + Vector3.UP * 0.6, CourseBuilder.accent(1), 1.0)
	active = on
	_visual.visible = on
