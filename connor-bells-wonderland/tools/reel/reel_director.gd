extends SceneTree
## Records one shot of the promo reel with Godot's Movie Maker. Connor is played
## by the AI; game music is switched off (the reel gets one continuous track).
## tools/reel/make_reel.sh runs every shot and joins them into a vertical MP4.
##   godot --path . --write-movie out.avi --fixed-fps 30 --resolution 1080x1920 \
##     -s res://tools/reel/reel_director.gd -- --no-splash shot=race
## Each shot prints "REC <seconds>": where the usable footage starts.

const WARMUP := 45

var shot := "race"
var frame := 0
var g: Node
var caption: Label
var sub_caption: Label
var _done_at := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			shot = a.substr(5)
	var net := root.get_node("NetworkManager")
	net.local_name = "Connor"
	match shot:
		"title", "end":
			change_scene_to_file("res://scenes/menus/main_menu.tscn")
		"race", "finale":
			net.settings = {"sections": 6, "bots": 7, "difficulty": 2, "countdown": 3, "items": true, "mode": "race"}
			change_scene_to_file("res://scenes/main/main.tscn")
		"paintball":
			net.settings = {"sections": 6, "bots": 7, "difficulty": 2, "countdown": 1, "items": true, "mode": "paintball"}
			change_scene_to_file("res://scenes/main/main.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		g = current_scene
		for sm in get_nodes_in_group("sound_manager"):
			sm.set_music_enabled(false)
		_add_captions()
		_setup()
	if frame > 2:
		_direct(frame - WARMUP)
	return _done_at > 0 and frame >= _done_at


## Frame (from the start of the usable footage) to stop at.
func _end_after(seconds: float) -> void:
	_done_at = WARMUP + int(seconds * 30.0)


func _setup() -> void:
	match shot:
		"title", "end":
			# Just the live fair and the neon title: hide the menu panel and tips.
			for child in g.get_children():
				if child is PanelContainer or child is TextureRect:
					child.visible = false
			g._tip.visible = false
			g.set_process(false)
			var cam := g.get_viewport().get_camera_3d()
			if cam != null:
				cam.h_offset = 0.0
				cam.fov = 78.0
			_end_after(3.6 if shot == "title" else 3.4)
		"race":
			_bot_connor()
			g.camera.fov = 86.0
			_end_after(13.0)
		"paintball":
			var gunner := PaintballBot.new()
			g.player.add_child(gunner)
			gunner.setup(g.player, g.paintball, 2)
			g.camera.fov = 74.0
			# Start Connor near the middle, where the fighting is.
			g.player.global_position = Vector3(3.0, 1.0, 13.0)
			g.camera.set_target(g.player)
			# For the reel: Connor stays in, and the screen splat doesn't hide the action.
			g.paintball._state[str(g.player.name)]["lives"] = 99
			g.hud._overlay.visible = false
			g.hud._progress_label.visible = false
			g.hud._message_label.visible = false
			_end_after(10.0)
		"finale":
			_bot_connor()
			g.camera.fov = 86.0
			_end_after(8.5)


func _bot_connor() -> void:
	var brain := BotController.new()
	brain.name = "BotController"
	g.player.add_child(brain)
	brain.setup(g.player, g.navigation, BotProfiles.make(0, BotProfiles.Difficulty.HARD))


func _direct(f: int) -> void:
	if f == 0:
		print("REC %.3f" % (float(WARMUP) / 30.0))
	match shot:
		"title":
			if f == 20:
				_caption("", "A 3BL_INDIE GAME")
		"end":
			if f == 5:
				_caption("COMING SOON", "RACE  •  BATTLE  •  WIN STUPID PRIZES")
		"race":
			if f == 100:
				_caption("RACE TO THE CROWN!")
			if f == 150:
				g.player.get_node("ItemHolder").give(ItemKinds.Kind.CATAPULT)
			if f == 230:
				_caption("ITEMS = CHAOS")
			if f == 300:
				g.player.get_node("ItemHolder").give(ItemKinds.Kind.CONFETTI)
		"paintball":
			if f == 10:
				_caption("PAINTBALL BATTLE!", "LAST ONE STANDING WINS")
			if f == 150:
				_caption("SPLAT!")
				_force_hit_on(g.player)
			if f == 215:
				_force_hit_on(_nearest_rival(g.player))
		"finale":
			if f == -10:
				# Skip to the end: Connor at the crown, rivals around him, race over.
				var finish: Area3D = g.course.get_finish_area()
				var spot: Vector3 = finish.global_position + Vector3(0.0, -1.0, 0.0)
				var i := 0
				for c in g._contestants:
					c.global_position = spot + Vector3(float(i % 4) * 1.4 - 2.0, 0.5, float(i / 4) * 1.6 + 1.0)
					c.velocity = Vector3.ZERO
					i += 1
				g.player.global_position = spot + Vector3(0.0, 0.5, 0.0)
			if f == 0:
				g.hud._countdown_label.text = ""
				var results := []
				var place := 1
				var order: Array = [g.player]
				for c in g._contestants:
					if c != g.player:
						order.append(c)
				for c in order:
					results.append({"name": str(c.name), "place": place, "time": _toaster_time() + float(place - 1) * 1.3, "falls": place % 3, "finished": true})
					place += 1
				g.race_manager.end_with_results(results)
			if f == 1:
				# Closer camera and bigger prize text for a phone screen.
				g.camera.orbit_distance = 13.0
				g.camera.height = 3.0
				g.camera.look_height = 7.0
				g.hud._prize_lead.add_theme_font_size_override("font_size", 56)
				g.hud._prize_label.add_theme_font_size_override("font_size", 92)
				g.hud._prize_label.offset_left = -560.0
				g.hud._prize_label.offset_right = 560.0


## A finishing time that makes Prizes.pick() give the toaster (it's seeded).
func _toaster_time() -> float:
	for i in range(4000):
		var t := 70.0 + float(i) * 0.01
		if Prizes.pick("%s|%.2f|%d" % [str(g.player.name), t, g._contestants.size()]) == "a brand new toaster":
			return t
	return 74.0


func _nearest_rival(c: Contestant) -> Contestant:
	var best: Contestant = null
	for other in g.paintball.alive_contestants():
		if other != c and (best == null or other.global_position.distance_to(c.global_position) < best.global_position.distance_to(c.global_position)):
			best = other
	return best


## Fires a real paintball at [param target] from the nearest rival.
func _force_hit_on(target: Contestant) -> void:
	if target == null:
		return
	var shooter := _nearest_rival(target)
	if shooter == null:
		return
	g.paintball._state[str(target.name)]["safe"] = 0.0
	var to := target.global_position + Vector3.UP * 0.8
	var from := to + (shooter.global_position - target.global_position).normalized() * 3.0 + Vector3.UP * 0.4
	var ball := Paintball.create(g, from, (to - from).normalized() * 26.0, shooter, PaintballManager.paint_colour(shooter), true)
	ball.hit_contestant.connect(g.paintball._on_ball_hit)


func _add_captions() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	g.add_child(layer)
	caption = _label(96, CourseBuilder.accent(0))
	caption.offset_top = 330.0
	layer.add_child(caption)
	sub_caption = _label(44, CourseBuilder.accent(1))
	sub_caption.offset_top = 450.0
	layer.add_child(sub_caption)


func _label(size: int, colour: Color) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameFonts.use_title(label)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 22)
	return label


func _caption(text: String, sub: String = "") -> void:
	for pair in [[caption, text], [sub_caption, sub]]:
		var label: Label = pair[0]
		label.text = pair[1]
		label.pivot_offset = Vector2(label.size.x * 0.5, 50.0)
		label.scale = Vector2(0.2, 0.2)
		label.modulate.a = 1.0
		var tw := label.create_tween()
		tw.tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.8)
		tw.tween_property(label, "modulate:a", 0.0, 0.3)
