extends Node
## Films one trailer shot inside the real game, for Godot's Movie Maker. record.sh runs it once
## per shot:
##   godot --path . --write-movie takes/sell.avi --fixed-fps 30 res://tools/trailer/director.tscn -- sell
## Every shot spends WARMUP seconds setting the scene (assemble.py trims it), then plays out.
## Music is muted here: assemble.py lays one continuous music track under the whole edit,
## so cuts don't restart it. Sound effects and voices are recorded with the picture.
## Nothing is saved, so your own save file is left alone.

const WARMUP := 1.0
const BEACH := "res://scenes/beach.tscn"
const CREATOR := "res://scenes/character_creator.tscn"

## Title cards: lines of [text, size, colour], plus an optional voice line.
const CARDS := {
	"card_hello": {"lines": [["HELLO", 150, "ffd23f"], ["CHICKEN NUGGET!", 150, "ffd23f"]], "voice": "hello", "len": 1.9},
	"card_anyone": {"lines": [["BE ANYONE.", 150, "ffffff"]], "voice": "", "len": 1.3},
	"card_police": {"lines": [["DODGE THE", 120, "ffffff"], ["POLICÍA", 170, "ff5a4f"]], "voice": "policia", "len": 1.6},
	"card_legit": {"lines": [["...OR LEG IT!", 150, "ffd23f"]], "voice": "", "len": 1.2},
	"card_empire": {"lines": [["BUILD A", 120, "ffffff"], ["BEACH EMPIRE", 160, "7cc242"]], "voice": "", "len": 1.5},
	"end": {"lines": [["LOOKEE LOOKEE", 150, "ffd23f"], ["TYCOON", 190, "ffd23f"], ["VERY GOOD VERY NICE!", 64, "ffffff"],
		["Play in your browser  ·  Android", 44, "fff4dc"]], "voice": "very_good", "len": 4.5},
}

var shot := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 12345
	var args := OS.get_cmdline_user_args()
	shot = args[0] if not args.is_empty() else "sell"
	var p := get_parent()
	p.remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	# Mute the music bus; keep effects and voices.
	AudioManager.set_volumes(0.0, 0.9, 1.0)
	while AudioManager.voices.size() < AudioManager.VOICE_LINES.size():
		await frames(1)
	if CARDS.has(shot):
		await _card(CARDS[shot])
	else:
		await call("_shot_" + shot)
	if OS.get_cmdline_user_args().has("--debug"):
		print("DEBUG sales=%d revenue=%.1f stock=%d" % [Economy.day_stats.sales, Economy.day_stats.revenue, Economy.total_stock()])
	get_tree().quit()


# --- Helpers ----------------------------------------------------------------------------------

## The vendor everyone sees in the trailer (matches the app icon).
func _vendor_look() -> Dictionary:
	var a := AppearanceOptions.default_appearance()
	a.shirt = 2
	a.mouth = 4
	a.name = "Very Nice Vince"
	return a


## Fresh game state on a beach, without touching the save file.
func _setup_beach(stall_tier := 0, extra := {}) -> Node:
	Economy.new_game()
	Upgrades.reset()
	Staff.new_game()
	CharacterData.set_appearance(_vendor_look())
	Upgrades.levels = {"stall": stall_tier}
	for k in extra:
		Upgrades.levels[k] = extra[k]
	Upgrades.levels["storage"] = 2
	Economy.cash = 480.0
	for id in ["sunglasses", "flamingo", "watch", "bunny_ears", "selfie_stick", "sun_hat", "magnet", "speaker"]:
		Economy.inventory[id] = 18
	GameManager.day = 3
	GameManager.current_beach = "benidorm"
	GameManager.next_beach = "benidorm"
	GameManager.owned_beaches = ["benidorm"]
	GameManager.tutorial_step = 99
	get_tree().change_scene_to_file(BEACH)
	await frames(3)
	var beach := get_tree().current_scene
	RandomEvents._timer = 9999.0
	GameManager.hour = 13.0
	return beach


## Puts tourists around a point, already settled on their towels.
func _crowd(beach: Node, around: Vector2, count: int, spread := 520.0) -> void:
	var types := ["brits", "stag", "family", "pensioner", "influencer"]
	var made := 0
	while made < count:
		made += maxi(beach.tourists.spawn_group(types[made % types.size()], 2), 1)
	for t in beach.tourists.pool:
		if not t.is_active():
			continue
		var p: Vector2 = beach.clamp_to_sand(around + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-170, 120)))
		if p.distance_to(around) < 110.0:
			p.x += 160.0 * signf(p.x - around.x + 0.01)
		t.spot = p
		t.position = p
		t.moving = false
		t._settle()
		t.budget = 90.0  # big spenders for the camera
		t.stay_time = 300.0


func _park_police(beach: Node) -> void:
	for cop in beach.police:
		cop.position.x = 60.0 if cop.position.x < BeachBackdrop.WORLD_W * 0.5 else BeachBackdrop.WORLD_W - 60.0
		cop.cooldown = 999.0
		cop.state = Police.State.RETURN
		cop.walk_to(cop.position)


func _frame_camera(beach: Node, center: Vector2, zoom: float) -> void:
	beach.camera.follow = null
	beach.camera.set_zoom_level(zoom)
	beach.camera.position = center
	beach.camera._clamp_position()


func _clear_toasts(beach: Node) -> void:
	for c in beach.hud._toasts.get_children():
		c.queue_free()


# --- Title cards -------------------------------------------------------------------------------

class CardBackground extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(0, 0, s.x, s.y * 0.42), Color("#7fd3f7"))
		draw_circle(Vector2(s.x * 0.86, s.y * 0.15), s.y * 0.09, Color("#fff3b0"))
		draw_rect(Rect2(0, s.y * 0.42, s.x, s.y * 0.22), Color("#1e9bd7"))
		for i in 4:
			var y := s.y * (0.46 + i * 0.045)
			var pts := PackedVector2Array()
			for x in range(0, int(s.x) + 40, 40):
				pts.append(Vector2(x, y + sin(x * 0.015 + t * (1.2 + i * 0.3)) * 5.0))
			draw_polyline(pts, Color(1, 1, 1, 0.35), 4.0)
		draw_rect(Rect2(0, s.y * 0.64, s.x, s.y * 0.36), Color("#f7d89b"))
		var foam := PackedVector2Array()
		for x in range(0, int(s.x) + 30, 30):
			foam.append(Vector2(x, s.y * 0.64 + sin(x * 0.012 + t * 1.4) * 7.0))
		draw_polyline(foam, Color.WHITE, 8.0)
		# A soft dark vignette so the words pop.
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.08, 0.15, 0.1))


func _card(def: Dictionary) -> void:
	get_tree().change_scene_to_file("res://tools/trailer/blank.tscn")
	await frames(2)
	var layer := CanvasLayer.new()
	get_tree().current_scene.add_child(layer)
	var bg := CardBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -10)
	layer.add_child(box)
	var is_end := shot == "end"
	var labels: Array[Label] = []
	for line in def.lines:
		# Sizes are written for 1080p; the game renders at 720p and stretches.
		var l := UITheme.title(str(line[0]), int(float(line[1]) * 0.667))
		l.add_theme_color_override("font_color", Color(str(line[2])))
		l.add_theme_constant_override("outline_size", int(float(line[1]) * 0.12))
		box.add_child(l)
		labels.append(l)
	if is_end:
		box.offset_right = -360.0
		# The vendor waves from the right.
		var av := VendorAvatar.new()
		av.set_appearance(_vendor_look())
		av.position = Vector2(1000, 640)
		av.scale = Vector2(3.6, 3.6)
		layer.add_child(av)
		av.set_facing(-1.0)
		av.set_pose(VendorAvatar.Pose.CHEER)
	await wait(WARMUP)
	# Pop the words in one by one.
	for l in labels:
		l.pivot_offset = l.size * 0.5
		l.scale = Vector2.ZERO
	if str(def.voice) != "":
		AudioManager.say(str(def.voice), 1.0, "trailer")
	for i in labels.size():
		var tw := create_tween()
		tw.tween_property(labels[i], "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		AudioManager.play_sfx("tap", 0.05, -6.0)
		await wait(0.12)
	await wait(float(def.len))


# --- Gameplay shots -----------------------------------------------------------------------------

## Shout, the crowd comes running, coins fly.
func _shot_sell() -> void:
	var beach := await _setup_beach(3, {"display": 2})
	var v: Vendor = beach.vendor
	v.position = Vector2(1600, 600)
	v.command_toggle_stall()
	await wait(0.7)
	_park_police(beach)
	_crowd(beach, v.stall.position, 12, 380.0)
	Economy.set_markup(0)
	_frame_camera(beach, v.stall.position + Vector2(0, -70), 1.15)
	await wait(WARMUP - 0.7)
	_clear_toasts(beach)
	v.shout_cooldown = 0.0
	v.command_shout()
	# Keep the stall full: whenever a slot frees up, the next-nearest tourist comes over.
	var t := 0.0
	# The edit starts ~3 s in, once the first customers are browsing.
	while t < 10.0:
		if v.stall.has_free_slot():
			_send_shopper(beach, v)
		if (t > 3.6 and t < 3.9) or (t > 7.2 and t < 7.5):
			v.shout_cooldown = 0.0
			v.command_shout()
		await wait(0.25)
		t += 0.25


func _send_shopper(beach: Node, v: Vendor) -> void:
	var best: Tourist = null
	for tr in beach.tourists.pool:
		if tr.is_active() and tr.bought == 0 and tr.state in [Tourist.State.SUNBATHE, Tourist.State.WANDER, Tourist.State.RETURNING]:
			if best == null or tr.position.distance_to(v.position) < best.position.distance_to(v.position):
				best = tr
	if best:
		best.go_shopping(v.position)


## Rapid-fire Randomise in the Character Creator.
func _shot_creator() -> void:
	GameManager.creator_mode = "edit"
	CharacterData.set_appearance(_vendor_look())
	get_tree().change_scene_to_file(CREATOR)
	await frames(3)
	var c := get_tree().current_scene
	c._set_tab(1)
	await wait(WARMUP)
	var tabs := [1, 0, 4, 5, 2, 1, 3, 5]
	for i in 8:
		c._randomise()
		c._set_tab(tabs[i])
		await wait(0.42)
	c._say_it()
	await wait(0.6)


## A cop spots the stall, stares... the vendor pulls the ropes just in time.
func _shot_police() -> void:
	var beach := await _setup_beach(0)
	var v: Vendor = beach.vendor
	v.position = Vector2(1500, 640)
	v.command_toggle_stall()
	await wait(0.7)
	_crowd(beach, v.position, 8, 600.0)
	var cop: Police = beach.police[0]
	for other in beach.police:
		if other != cop:
			other.position.x = 80.0
	cop.position = Vector2(v.position.x + 330, BeachBackdrop.PROM_Y + 40)
	cop.state = Police.State.PATROL
	cop.cooldown = 0.0
	cop.walk_to(Vector2(v.position.x + 140, BeachBackdrop.PROM_Y + 40))
	_frame_camera(beach, Vector2(v.position.x + 110, 640), 1.25)
	await wait(WARMUP - 0.7)
	_clear_toasts(beach)
	# Wait for the cop to spot the stall, then pack up mid-stare.
	var t := 0.0
	while cop.state != Police.State.INVESTIGATE and t < 3.0:
		await wait(0.1)
		t += 0.1
	await wait(1.3)
	v.command_toggle_stall()
	await wait(3.4)


## Busted! Leg it across the sand with the cop in pursuit.
func _shot_chase() -> void:
	var beach := await _setup_beach(1)
	var v: Vendor = beach.vendor
	v.position = Vector2(1200, 620)
	v.command_toggle_stall()
	await wait(0.7)
	_crowd(beach, v.position, 10, 700.0)
	var cop: Police = beach.police[0]
	cop.position = v.stall.position + Vector2(70, 40)
	_frame_camera(beach, v.position + Vector2(0, -40), 1.2)
	await wait(WARMUP - 0.7)
	_clear_toasts(beach)
	beach._on_cop_reached_stall(cop, v.stall)
	await wait(1.4)
	(Overlay.stack.back() as Node)._choose("run")
	await frames(1)
	v.command_walk(v.position + Vector2(900, -160))
	await wait(1.6)
	v.command_walk(v.position + Vector2(500, 170))
	await wait(1.8)


## The stall grows from a blanket to a kiosk while the crew works.
func _shot_empire() -> void:
	Staff.new_game()
	var beach := await _setup_beach(0, {"cards": 3, "display": 2})
	var v: Vendor = beach.vendor
	v.position = Vector2(1600, 620)
	_park_police(beach)
	_crowd(beach, v.position, 14, 700.0)
	# Hire a crew and walk them straight to work.
	Economy.add_cash(5000.0, "trailer")
	for role in ["seller", "shouter", "lookout"]:
		Staff.candidates[0].role = role
		Staff.hire(0, "benidorm")
	beach._spawn_workers()
	for w in beach.workers:
		if w.role == "seller":
			w.position = Vector2(v.position.x - 420, 560)
			w.walk_to(w.position)
		elif w.role == "shouter":
			w.position = v.position + Vector2(260, 40)
	v.command_toggle_stall()
	_frame_camera(beach, v.position + Vector2(-120, -40), 1.05)
	await wait(WARMUP)
	_clear_toasts(beach)
	for tier in range(1, 6):
		Upgrades.levels["stall"] = tier
		v.stall.open_at(v.stall.position, tier)
		beach.fx.puff(v.stall.position + Vector2(0, -20), 10)
		AudioManager.play_sfx("upgrade")
		if tier == 3:
			v.shout_cooldown = 0.0
			v.command_shout()
		await wait(0.8)
	await wait(0.8)


## Random events: a cruise ship docks, then the rain comes.
func _shot_events() -> void:
	var beach := await _setup_beach(3, {"parasol": 1})
	var v: Vendor = beach.vendor
	v.position = Vector2(1500, 600)
	v.command_toggle_stall()
	_park_police(beach)
	_crowd(beach, v.position, 18, 900.0)
	_frame_camera(beach, Vector2(1500, 420), 0.62)
	await wait(WARMUP)
	_clear_toasts(beach)
	RandomEvents.trigger("cruise")
	beach.backdrop._t = 140.0  # ship already in frame
	await wait(2.2)
	RandomEvents.trigger("rain")
	await wait(2.2)
