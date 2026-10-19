class_name PrizePresent
extends Node3D
## A glowing present that floats and spins above the winner, then bursts open
## with fireworks when the prize is revealed.

var target: Node3D

var _box: Node3D
var _time: float = 0.0


func _ready() -> void:
	_box = Node3D.new()
	_box.name = "Box"
	add_child(_box)
	var wrap := CourseBuilder.make_box_mesh(Vector3(1.1, 1.0, 1.1), Color(0.55, 0.05, 0.12))
	_box.add_child(wrap)
	var lid := CourseBuilder.make_box_mesh(Vector3(1.24, 0.24, 1.24), Color(0.6, 0.06, 0.14))
	lid.position = Vector3(0.0, 0.56, 0.0)
	_box.add_child(lid)
	var gold := CourseBuilder.accent(0)
	CourseBuilder.add_neon_strip(_box, Vector3(0.2, 1.32, 1.28), Vector3(0.0, 0.08, 0.0), gold, "RibbonA")
	CourseBuilder.add_neon_strip(_box, Vector3(1.28, 1.32, 0.2), Vector3(0.0, 0.08, 0.0), gold, "RibbonB")
	for side: float in [-1.0, 1.0]:
		var bow := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.3
		sphere.material = CourseBuilder.make_neon_material(gold, 2.0)
		bow.mesh = sphere
		bow.position = Vector3(side * 0.2, 0.8, 0.0)
		bow.rotation.z = side * 0.6
		_box.add_child(bow)
	FX.attach(self, "sparkle", Vector3.ZERO, Color(2.0, 1.6, 0.6))
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(target):
		global_position = target.global_position + Vector3.UP * (3.2 + sin(_time * 3.0) * 0.2)
	_box.rotation.y += delta * 2.0
	# Shakes harder as the reveal gets closer.
	var shake := minf(_time / 2.0, 1.0) * 0.12
	_box.rotation.z = sin(_time * 40.0) * shake
	_box.rotation.x = cos(_time * 33.0) * shake


## Bursts open: fireworks, gold and sparkles, then disappears.
func pop() -> void:
	var pos := global_position + Vector3.UP * 0.4
	FX.burst(self, "fireworks", pos, Color.WHITE, 1.6)
	FX.burst(self, "coins", pos, Color.WHITE, 2.0)
	FX.burst(self, "sparkle", pos, Color(2.5, 2.0, 0.8), 2.0)
	FX.ring(self, global_position - Vector3.UP * 3.0, 6.0, CourseBuilder.accent(0))
	SoundManager.world(self, "boom", pos, 1.3, 2.0)
	queue_free()
