extends Node2D
## Tripod Attack! State machine, input and the CRT pass. See README.md.

var state := "title"
var t := 0.0
var state_t := 0.0
var typed := 0.0
var menu_idx := 0
var touch := false
var paused := false
var map_anim := 0.0
var bf: Battlefield
var screens: Screens
var camera: Camera2D
var crt: ShaderMaterial
var _drag_id = null
var _duck_id = null
var _last_typed := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera2D.new()
	camera.position = Vector2(C.W / 2, C.H / 2)
	add_child(camera)
	bf = Battlefield.new()
	bf.process_mode = Node.PROCESS_MODE_PAUSABLE
	bf.sector_cleared.connect(_on_sector_cleared)
	bf.game_over.connect(_on_game_over)
	add_child(bf)
	screens = Screens.new()
	screens.main = self
	screens.z_index = 20
	add_child(screens)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var rect := ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt = ShaderMaterial.new()
	crt.shader = load("res://shaders/crt.gdshader")
	rect.material = crt
	layer.add_child(rect)
	enter_title()
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		# The browser build has no command line: "?smoke-test" on the page URL runs the test.
		var query = JavaScriptBridge.eval("window.location.search", true)
		if query is String and query.contains("smoke-test"):
			args.append("--smoke-test")
	for arg in args:
		if arg == "--reel":
			add_child(load("res://scripts/demo_reel.gd").new())
		if arg == "--smoke-test":
			add_child(load("res://scripts/headless_test.gd").new())
		if arg.begins_with("--shots="):
			var demo: Node = load("res://scripts/demo_shots.gd").new()
			demo.out_dir = arg.substr(8)
			add_child(demo)


func _process(dt: float) -> void:
	t += dt
	state_t += dt
	typed += dt
	if state == "map":
		map_anim += dt
	bf.visible = state != "map"
	var tn := int(typed * 36.0)
	if tn != _last_typed and tn < 400 and tn % 2 == 0 and state in ["title", "intro", "cleared", "gameover", "victory"]:
		Sfx.play("type")
	_last_typed = tn
	camera.offset = Vector2(randf_range(-bf.shake_amt, bf.shake_amt), randf_range(-bf.shake_amt, bf.shake_amt) * 0.6)
	crt.set_shader_parameter("flash", bf.flash_amt)
	crt.set_shader_parameter("flash_color", bf.flash_color)


# --- flow ---------------------------------------------------------------------------------------

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	typed = 0.0


func enter_title() -> void:
	_set_state("title")
	menu_idx = 0
	set_paused(false)
	bf.set_attract(true)
	Sfx.play_music("menu")


func menu_items() -> Array:
	var items: Array = []
	if G.has_progress():
		items.append({"label": "CONTINUE CAMPAIGN", "act": start_campaign.bind(false), "locked": false})
		items.append({"label": "NEW CAMPAIGN", "act": start_campaign.bind(true), "locked": false})
	else:
		items.append({"label": "REPLAY CAMPAIGN" if G.campaign_done else "CAMPAIGN", "act": start_campaign.bind(true), "locked": false})
	items.append({"label": "ENDLESS: BELFAST" if G.campaign_done else "ENDLESS: BELFAST (LOCKED - CLEAR EUROPE)", "act": start_endless, "locked": not G.campaign_done})
	items.append({"label": "DIFFICULTY: " + Difficulty.name_of(G.difficulty), "act": cycle_difficulty, "locked": false, "cycle": true})
	return items


func cycle_difficulty() -> void:
	G.difficulty = (G.difficulty + 1) % Difficulty.NAMES.size()
	G.persist()


func start_campaign(fresh: bool) -> void:
	if fresh:
		G.reset_campaign()
	G.endless = false
	G.score = 0
	G.lives = int(G.setting().lives)
	G.lost_sector = -1
	map_anim = 0.0
	bf.mode = "off"
	bf.reset_field()
	_set_state("map")
	Sfx.play_music("map")


func start_endless() -> void:
	G.endless = true
	G.score = 0
	G.lives = int(G.setting().lives)
	start_sector(0)


func start_sector(idx: int) -> void:
	G.sector_idx = idx
	G.reset_stats()
	G.lost_sector = -1
	bf.start_sector(idx)
	_set_state("intro")
	Sfx.play_music("menu")


func start_wave() -> void:
	bf.start_wave()
	_set_state("play")


func _on_sector_cleared() -> void:
	_set_state("cleared")


func _on_game_over() -> void:
	_set_state("gameover")
	Sfx.play("game_over")
	G.new_high = G.record_score()
	if not G.endless:
		# The Martians retake the last liberated sector.
		var last := -1
		for i in 10:
			if G.cleared[i]:
				last = i
		if last >= 0 and G.sector_idx > 0:
			G.cleared[last] = false
			G.lost_sector = last
		else:
			G.lost_sector = -1
	G.persist()


## Fire / confirm on the menus.
func press() -> void:
	match state:
		"title":
			var it: Dictionary = menu_items()[menu_idx]
			if it.locked:
				Sfx.play("blip")
				bf.fx.float_text(Vector2(C.W / 2, 300), "CLEAR THE CAMPAIGN FIRST", Vec.RED, 10.0, 1.5)
				return
			Sfx.play("select")
			it.act.call()
		"map":
			Sfx.play("select")
			start_sector(G.next_sector_idx())
		"intro":
			if typed * 36.0 < 20.0:
				return
			Sfx.play("select")
			start_wave()
		"cleared":
			if state_t < 0.8:
				return
			Sfx.play("select")
			if G.campaign_done and G.all_cleared():
				_set_state("victory")
				Sfx.play("victory")
			else:
				map_anim = 0.0
				_set_state("map")
		"gameover", "victory":
			if state_t < 1.0:
				return
			Sfx.play("select")
			enter_title()


func set_paused(p: bool) -> void:
	paused = p
	get_tree().paused = p


func menu_move(d: int) -> void:
	var n := menu_items().size()
	menu_idx = posmod(menu_idx + d, n)
	Sfx.play("blip")


# --- input --------------------------------------------------------------------------------------

func _in_duck_zone(pos: Vector2) -> bool:
	return pos.x < 226.0 and pos.y > 250.0 and pos.y < C.GROUND + 14.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_pointer_down(event.position, -1, event.button_index == MOUSE_BUTTON_RIGHT)
			else:
				_pointer_up(-1)
		return
	if event is InputEventMouseMotion:
		_pointer_move(event.position, -1)
		return
	if event is InputEventScreenTouch:
		touch = true
		if event.pressed:
			_pointer_down(event.position, event.index, false)
		else:
			_pointer_up(event.index)
		return
	if event is InputEventScreenDrag:
		_pointer_move(event.position, event.index)
		return
	if event.is_action_pressed("mute"):
		var m := Sfx.toggle_mute()
		bf.fx.float_text(Vector2(C.W / 2, 100), "SOUND OFF" if m else "SOUND ON", Vec.DIM, 10.0)
		return
	if event.is_action_pressed("pause"):
		if state == "play":
			set_paused(not paused)
			Sfx.play("blip")
		return
	if state == "title":
		if event.is_action_pressed("menu_up"):
			menu_move(-1)
		elif event.is_action_pressed("menu_down"):
			menu_move(1)
		elif (event.is_action_pressed("power_up") or event.is_action_pressed("power_down")) and menu_items()[menu_idx].get("cycle", false):
			press()
		elif event.is_action_pressed("fire") or event.is_action_pressed("duck"):
			press()
		return
	if state != "play":
		if event.is_action_pressed("fire") or event.is_action_pressed("duck"):
			press()
		return
	if event.is_action_pressed("fire"):
		if paused:
			set_paused(false)
		else:
			bf.fire()


func _pointer_down(pos: Vector2, id, right_button: bool) -> void:
	if state == "title":
		var items := menu_items()
		var i := int(floor((pos.y - 140.0 + 10.0) / 36.0))
		if i >= 0 and i < items.size() and absf(pos.x - C.W / 2) < 300.0:
			menu_idx = i
		press()
		return
	if state != "play":
		press()
		return
	if paused:
		set_paused(false)
		return
	if right_button or _in_duck_zone(pos):
		_duck_id = id
		bf.player.duck_held = true
		return
	_drag_id = id
	bf.player.drag = {"start": pos, "now": pos}


func _pointer_move(pos: Vector2, id) -> void:
	if _drag_id != null and _drag_id == id and not bf.player.drag.is_empty():
		bf.player.drag.now = pos


func _pointer_up(id) -> void:
	if _duck_id != null and _duck_id == id:
		_duck_id = null
		bf.player.duck_held = false
	if _drag_id != null and _drag_id == id:
		_drag_id = null
		var p := bf.player
		if not p.drag.is_empty():
			var d: Vector2 = p.drag.start - p.drag.now
			if d.length() > 12.0:
				p.angle = clampf(d.angle(), -1.45, 0.12)
				p.power = clampf(380.0 + d.length() * 3.6, 380.0, 1000.0)
			p.drag = {}
			if state == "play" and not paused:
				bf.fire()
