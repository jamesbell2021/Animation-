extends Node
## Films one trailer shot inside the real game, for Godot's Movie Maker. record.sh runs it once
## per shot:
##   godot --path . --write-movie takes/bar.avi --fixed-fps 30 res://tools/trailer/director.tscn -- bar
## Every shot spends WARMUP seconds setting the scene (assemble.py trims it), then plays out.
## Music is muted here: assemble.py lays one continuous music track under the whole edit,
## so cuts don't restart it. Sound effects and voices are recorded with the picture.
## Nothing is saved, so your own save file is left alone.

const WARMUP := 1.0
const HOTEL_SCENE := "res://scenes/hotel.tscn"

## Title cards: lines of [text, size at 1080p, colour], plus an optional voice line.
const CARDS := {
	"card_from": {"lines": [["FROM THE PEOPLE WHO BROUGHT YOU", 62, "ffffff"], ["LOOKEE LOOKEE", 130, "ffd23f"],
		["TYCOON", 150, "ffd23f"]], "voice": "", "len": 2.2},
	"card_presents": {"lines": [["3BL_INDIE", 84, "fff4dc"], ["NOW PRESENTS...", 140, "ffffff"]], "voice": "", "len": 1.4},
	"card_title": {"lines": [["ZERO STAR", 180, "ffd23f"], ["HOTEL", 220, "ffd23f"]], "voice": "oi_oi", "len": 1.9},
	"card_lads": {"lines": [["DRUNKEN LADS.", 140, "ffffff"], ["€1 PINTS.", 150, "ffd23f"]], "voice": "ere_we_go", "len": 1.4},
	"card_roaches": {"lines": [["COCKROACHES.", 150, "b9f6a0"]], "voice": "", "len": 1.0},
	"card_lounger": {"lines": [["SUNLOUNGER", 130, "ffffff"], ["WARS.", 190, "ff5a4f"]], "voice": "", "len": 1.2},
	"card_pool": {"lines": [["SWIMMING POOL", 120, "ffffff"], ["SAFETY?!", 170, "7fd3f7"]], "voice": "", "len": 1.1},
	"card_stars": {"lines": [["FROM ZERO STARS...", 120, "ffffff"], ["...TO THREE?", 170, "ffd23f"]], "voice": "", "len": 1.4},
	"end": {"lines": [["ZERO STAR", 150, "ffd23f"], ["HOTEL", 190, "ffd23f"], ["Can you reach three stars?", 64, "ffffff"],
		["Android  ·  Play in your browser", 44, "fff4dc"]], "voice": "cheers", "len": 4.5},
}

var shot := ""
var world: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 2468
	var args := OS.get_cmdline_user_args()
	shot = args[0] if not args.is_empty() else "bar"
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
	get_tree().quit()


# --- Helpers ----------------------------------------------------------------------------------

## The manager everyone sees in the trailer (matches the app icon).
func _manager_look() -> Dictionary:
	var a := AppearanceOptions.default_appearance()
	a.shirt = 2
	a.shirt_color = "e2673f"
	a.mouth = 4
	a.chain = 1
	a.badge = "MANAGER"
	a.name = "Big Steve"
	return a


## Fresh hotel state without touching the save file. opts: rooms (open count), quality,
## upgrades {id: level}, staff [roles], stars, hour.
func _setup_hotel(opts := {}) -> void:
	Economy.new_game()
	Upgrades.reset()
	Staff.new_game()
	Hotel.new_game()
	Hotel.name_of_hotel = "Hotel Paradiso"
	CharacterData.set_appearance(_manager_look())
	Economy.cash = 99999.0
	for id in opts.get("upgrades", {}):
		Upgrades.levels[id] = int(opts.upgrades[id])
	for i in int(opts.get("rooms", 2)):
		Hotel.rooms[i].open = true
		Hotel.rooms[i].quality = int(opts.get("quality", 0))
		Hotel.rooms[i].dirt = 15.0
		Hotel.rooms[i].roaches = 0
	for role in opts.get("staff", []):
		Staff.hire(role)
	Hotel.stars = int(opts.get("stars", 0))
	Economy.cash = 640.0
	GameManager.day = 4
	GameManager.first_day_hints = false
	get_tree().change_scene_to_file(HOTEL_SCENE)
	await frames(3)
	world = get_tree().current_scene
	RandomEvents.enabled = false
	world._booking_timer = 9999.0
	world._thief_timer = 9999.0
	world._checkouts_done = true
	GameManager.hour = float(opts.get("hour", 15.0))
	world._hour_mark = int(GameManager.hour)
	_clear_toasts()


func _clear_toasts() -> void:
	for c in world.hud._toasts.get_children():
		c.queue_free()
	if world.hud._banner:
		world.hud._banner.visible = false


## Books a group straight into a room, already checked in.
func _group(type_id: String, room: int, size: int) -> Array:
	var g := {
		"id": Hotel._next_group_id, "type": type_id, "room": room, "size": size, "nights": 3,
		"happiness": 70.0, "seed": _rng.randi(), "reasons": {}, "arrived": true,
	}
	Hotel._next_group_id += 1
	Hotel.rooms[room].group = g.id
	Hotel.groups.append(g)
	var before: int = world.guests.size()
	world._spawn_group(g, false)
	var out: Array = world.guests.slice(before)
	for guest: Guest in out:
		guest._think = 999.0
	return out


func _at_bar(g: Guest, drunk := 3.0) -> void:
	g.stool = world.claim_stool(g)
	g.position = HotelLayout.stool(g.stool)
	g.state = Guest.S.DRINK
	g.drunk = drunk
	g._pint_timer = _rng.randf_range(0.3, 2.5)
	g._think = 999.0
	g.face(Vector2(HotelLayout.BAR_COUNTER_X, 0))


func _on_lounger(g: Guest) -> void:
	g.lounger = world.claim_lounger(g)
	g.position = HotelLayout.lounger(g.lounger) + Vector2(-50, -12)
	g.state = Guest.S.LOUNGE
	g.avatar.set_pose(VendorAvatar.Pose.LIE)
	g._think = 999.0


func _swimming(g: Guest, x: float) -> void:
	g.position = Vector2(x, HotelLayout.SWIM_Y)
	g.state = Guest.S.SWIM
	g.avatar.set_pose(VendorAvatar.Pose.SWIM)
	g._think = 999.0


func _frame(center: Vector2, zoom: float) -> void:
	world.camera.set_zoom_level(zoom)
	world.camera.position = center
	world.camera._clamp_position()


# --- Title cards -------------------------------------------------------------------------------

## A sunset on the Costa with a grubby hotel silhouette on the right.
class CardBackground extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		for i in 8:
			var y0 := s.y * 0.075 * i
			draw_rect(Rect2(0, y0, s.x, s.y * 0.075 + 1), Color("#6a4c93").lerp(Color("#ff9e5e"), i / 7.0))
		draw_circle(Vector2(s.x * 0.2, s.y * 0.6), s.y * 0.13, Color("#ffd166"))
		draw_rect(Rect2(0, s.y * 0.6, s.x, s.y * 0.14), Color("#1e7fb8"))
		for i in 3:
			var y := s.y * (0.62 + i * 0.035)
			var pts := PackedVector2Array()
			for x in range(0, int(s.x) + 40, 40):
				pts.append(Vector2(x, y + sin(x * 0.015 + t * (1.2 + i * 0.3)) * 4.0))
			draw_polyline(pts, Color(1, 1, 1, 0.3), 3.0)
		draw_rect(Rect2(0, s.y * 0.74, s.x, s.y * 0.26), Color("#e8c98a"))
		# The hotel: three floors, a few lit windows, one flickering.
		var r := Rect2(s.x * 0.845, s.y * 0.34, s.x * 0.13, s.y * 0.44)
		draw_rect(r, Color("#3b2a45"))
		for f in 3:
			for k in 3:
				var w := Rect2(r.position.x + 16 + k * (r.size.x - 32) / 3.0, r.position.y + 24 + f * (r.size.y - 40) / 3.0, (r.size.x - 32) / 3.0 - 14, 38)
				var lit := (f * 3 + k) % 4 != 1
				if f == 1 and k == 2:
					lit = fmod(t, 1.3) > 0.2
				draw_rect(w, Color("#ffe08a") if lit else Color("#2a2035"))
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.05, 0.03, 0.1, 0.12))


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
	if is_end or shot == "card_title":
		box.offset_right = -360.0
		var av := VendorAvatar.new()
		av.set_appearance(_manager_look())
		av.position = Vector2(1000, 650)
		av.scale = Vector2(3.4, 3.4)
		layer.add_child(av)
		av.set_facing(-1.0)
		av.set_pose(VendorAvatar.Pose.CHEER)
	await wait(WARMUP)
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

## The hotel on day one: boarded-up rooms, the swamp, a cockroach. Slow push in on the sign.
func _shot_establish() -> void:
	await _setup_hotel({"rooms": 2, "hour": 9.0})
	Hotel.rooms[0].roaches = 3
	Hotel.rooms[0].dirt = 70.0
	Hotel.rooms_changed.emit()
	_group("lads", 0, 3)
	_frame(Vector2(900, 470), 0.62)
	await wait(WARMUP)
	_clear_toasts()
	var tw := create_tween()
	tw.tween_property(world.camera, "position", Vector2(820, 420), 3.2).set_trans(Tween.TRANS_SINE)
	await wait(1.2)
	world.manager.say("Welcome to Hotel Paradiso!", "shout", 2.0)
	await wait(2.2)


## Happy hour with €1 pints: the bar fills, coins fly, then a punch-up. The manager wades in.
func _shot_bar() -> void:
	await _setup_hotel({"rooms": 4, "quality": 1, "hour": 20.5, "upgrades": {"bar": 1}, "staff": ["barman"]})
	var lads := _group("lads", 0, 4)
	var hens := _group("hens", 1, 3)
	var crowd: Array = lads + hens
	for g: Guest in crowd:
		_at_bar(g, 2.5 + _rng.randf() * 1.5)
	_frame(Vector2(HotelLayout.BAR_X0 + 280.0, 640), 1.05)
	await wait(WARMUP)
	_clear_toasts()
	lads[0].say("OI OI!", "shout", 1.4)
	AudioManager.say("oi_oi", 1.0, "trailer")
	for k in 6:
		world.serve_pint(crowd[k % crowd.size()])
		await wait(0.3)
	hens[0].say("WOOOO!", "shout", 1.2)
	AudioManager.say("woo", 1.3, "trailer2")
	await wait(0.6)
	var inc: Incident = world._start_incident("fight", lads[1].position, [lads[1], lads[2]])
	_clear_toasts()
	await wait(1.1)
	world.manager.position = Vector2(HotelLayout.BAR_X0 + 20.0, HotelLayout.GROUND_Y)
	world.dispatch_manager(inc)
	await wait(2.6)


## A filthy room crawling with cockroaches. SPLAT, SPLAT, SPLAT. Housekeeping!
func _shot_roaches() -> void:
	await _setup_hotel({"rooms": 4, "hour": 11.0, "staff": ["cleaner"]})
	Hotel.rooms[1].roaches = 7
	Hotel.rooms[1].dirt = 90.0
	Hotel.rooms_changed.emit()
	var c := HotelLayout.room_rect(1).get_center()
	_frame(c + Vector2(0, 10), 1.8)
	for s in world.staff_nodes:
		s.position = Vector2(HotelLayout.STAIR_X0 + 40.0, HotelLayout.level_y(1))
		s._poll = 99.0
	await wait(WARMUP)
	_clear_toasts()
	await wait(0.5)
	var list: Array = world.roaches.get(1, []).duplicate()
	for k in mini(5, list.size()):
		if is_instance_valid(list[k]):
			world.squash(list[k])
		await wait(0.28)
	for s in world.staff_nodes:
		s._poll = 0.0
		s.say("Housekeeping!", "shout", 1.5)
	AudioManager.say("housekeeping", 1.0, "trailer")
	await wait(1.8)


## Pool time: the loungers are full, a mum comes for one anyway. Towels out.
func _shot_lounger() -> void:
	await _setup_hotel({"rooms": 4, "hour": 13.0, "upgrades": {"pool": 1}})
	var mums_a := _group("mums", 0, 3)
	var mums_b := _group("mums", 1, 3)
	var hens := _group("hens", 2, 2)
	_on_lounger(mums_a[0])
	_on_lounger(mums_a[1])
	_on_lounger(mums_a[2])
	_on_lounger(hens[0])
	_swimming(hens[1], HotelLayout.POOL_X0 + 300.0)
	for k in mums_b.size():
		var g: Guest = mums_b[k]
		g.position = Vector2(HotelLayout.POOL_X0 - 260.0 - k * 40.0, HotelLayout.GROUND_Y)
		g.state = Guest.S.ROOM
		g._think = 999.0
	_frame(Vector2(HotelLayout.lounger(1).x + 80.0, 640), 1.25)
	await wait(WARMUP)
	_clear_toasts()
	mums_b[0].say("That's MY lounger!", "bad", 1.4)
	await wait(0.5)
	world._start_lounger_war(mums_b[0], mums_a[1])
	_clear_toasts()
	await wait(1.0)
	world._start_lounger_war(mums_b[1], mums_a[2])
	_clear_toasts()
	await wait(2.2)


## A lad belly-flops into the deep end. The lifeguard sprints in with the ring.
func _shot_pool() -> void:
	await _setup_hotel({"rooms": 4, "hour": 14.0, "upgrades": {"pool": 2}, "staff": ["lifeguard"]})
	var lads := _group("lads", 0, 3)
	_swimming(lads[0], HotelLayout.POOL_X0 + 260.0)
	_swimming(lads[1], HotelLayout.POOL_X0 + 420.0)
	_on_lounger(lads[2])
	for s in world.staff_nodes:
		s._poll = 99.0
	_frame(Vector2(HotelLayout.POOL_X0 + 260.0, 640), 1.2)
	await wait(WARMUP)
	_clear_toasts()
	lads[0].say("WATCH THIS!", "shout", 1.2)
	AudioManager.play_sfx("splash")
	await wait(0.8)
	world._start_incident("pool", lads[0].position, [lads[0]])
	_clear_toasts()
	await wait(0.8)
	for s in world.staff_nodes:
		s._poll = 0.0
	await wait(3.0)


## Wide night shot: a rave rattles a room, a telly goes, a thief legs it past security.
func _shot_chaos() -> void:
	await _setup_hotel({"rooms": 8, "hour": 23.6, "upgrades": {"floors": 1}, "staff": ["security"]})
	var lads := _group("lads", 1, 4)
	_group("hens", 5, 3)
	for g: Guest in lads:
		g.position = HotelLayout.room_spot(1, _rng)
		g.state = Guest.S.ROOM
		g.drunk = 4.0
	_frame(Vector2(900, 470), 0.62)
	await wait(WARMUP)
	_clear_toasts()
	world._start_incident("music", HotelLayout.room_door(1), [], 1)
	await wait(0.6)
	world._start_incident("music", HotelLayout.room_door(5), [], 5)
	await wait(0.6)
	var v: Incident = world._start_incident("vandal", HotelLayout.room_door(1), [], 1)
	v.guests = lads
	AudioManager.play_sfx("smash")
	world.fx.puff(HotelLayout.room_rect(1).get_center(), 10, Color(0.8, 0.8, 0.8, 0.9))
	_clear_toasts()
	await wait(2.6)


## Money in, upgrades on: rooms go Grim to Nice, the pool gets a slide, the stars light up.
func _shot_upgrade() -> void:
	await _setup_hotel({"rooms": 4, "hour": 12.0})
	_frame(Vector2(1150, 470), 0.62)
	await wait(WARMUP)
	_clear_toasts()
	Economy.cash = 99999.0
	var steps := [
		["pool"], ["room", 0], ["room", 1], ["floors"], ["bar"], ["star"], ["room", 2], ["room", 3],
		["open", 4], ["open", 5], ["reception"], ["pool"], ["star"], ["bar"], ["open", 6], ["open", 7], ["star"],
	]
	for st in steps:
		match st[0]:
			"room":
				while int(Hotel.rooms[st[1]].quality) < 3:
					Hotel.upgrade_room(st[1])
				world.fx.puff(HotelLayout.room_rect(st[1]).get_center(), 8)
			"open":
				Hotel.open_room(st[1])
				Hotel.rooms[st[1]].quality = 3
				Hotel.rooms_changed.emit()
				world.fx.puff(HotelLayout.room_rect(st[1]).get_center(), 8)
			"star":
				Hotel.stars += 1
				Hotel.stars_changed.emit(Hotel.stars)
				AudioManager.play_sfx("star")
			_:
				Upgrades.buy(st[0])
		AudioManager.play_sfx("upgrade", 0.05, -4.0)
		_clear_toasts()
		await wait(0.3)
	AudioManager.play_sfx("cheer")
	world.manager.say("THREE STARS!", "shout", 2.0)
	await wait(1.6)
