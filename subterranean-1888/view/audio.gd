class_name Audio
extends RefCounted
## Reaches the Sfx autoload by path, so classes that make sounds still compile when run
## from a --script test (where autoload names aren't globals yet) or with no audio at all.

static func play(id: String, volume_db := 0.0, pitch_spread := 0.08) -> void:
	var s := _sfx()
	if s != null:
		s.play(id, volume_db, pitch_spread)


static func ambience(on: bool) -> void:
	var s := _sfx()
	if s != null:
		s.ambience(on)


static func _sfx() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Sfx")
