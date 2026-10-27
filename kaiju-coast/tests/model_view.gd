extends Node
## Close-up portraits of each kaiju for checking the models:
##   godot --path . res://tests/model_view.tscn -- --out=/tmp/shots --types=orochi,oni


func _ready() -> void:
	var out: String = "/tmp"
	var types: PackedStringArray = PackedStringArray(["oni", "kani", "ryu", "tengu", "daioni", "orochi"])
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--types="):
			types = a.substr(8).split(",")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i: int in range(5):
		await get_tree().process_frame
	Game.new_game()
	Game.hud.visible = false
	for t: String in types:
		for k: Kaiju in Game.kaiju:
			k.queue_free()
		Game.kaiju.clear()
		var k2: Kaiju = Game.main.spawn_kaiju(t)
		k2.position = Vector3(0, 2 if not k2.def["air"] else 60, 30)
		k2.state = "rampage"
		k2.hp = 1e9
		var size: float = 120.0 if t in ["orochi", "daioni"] else 70.0
		for i: int in range(20):
			Game.main.step(1.0 / 30.0)
			k2.position = Vector3(0, 2 if not k2.def["air"] else 60, 30)
			Game.rig.set_mode("free")
			Game.rig.cam.global_transform = Transform3D(Basis(), k2.position + Vector3(size * 0.8, size * 0.55, -size * 1.1)).looking_at(k2.position + Vector3(0, size * 0.3, 0), Vector3.UP)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("model_%s.png" % t))
		print("saved ", t)
	get_tree().quit()
