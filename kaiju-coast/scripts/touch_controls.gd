class_name TouchControls
extends Control
## On-screen controls for phones and tablets. In first person: drag anywhere to aim, a floating
## stick on the left (flies the airship, nudges a gun's aim), and buttons for fire, zoom, weapon
## swap, reload, next gun, leave and the special attacks. In the command view, pinch to zoom; taps and drags already
## work because Godot turns the first finger into mouse clicks.

const STICK_R: float = 80.0
const AIM_SENS: float = 0.0045

## Shows the controls without a touchscreen (screenshots and tests: run with `-- --touch`).
static var forced: bool = false

var stick_id: int = -1
var stick_origin: Vector2 = Vector2.ZERO
var stick_pos: Vector2 = Vector2.ZERO
var aim_id: int = -1
var held: Dictionary = {}        ## button name -> touch index
var _touches: Dictionary = {}    ## command view: touch index -> position
var _pinch_d: float = 0.0


static func enabled() -> bool:
	return forced or DisplayServer.is_touchscreen_available()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _active() -> bool:
	return Game.state == Game.State.PLAY and not Game.paused and Game.player != null and Game.player.active and not Game.hud.menu_open()


## Stick deflection, -1..1 on each axis (y is down).
func stick() -> Vector2:
	if stick_id < 0:
		return Vector2.ZERO
	return (stick_pos - stick_origin).limit_length(STICK_R) / STICK_R


func _buttons() -> Dictionary:
	var w: float = size.x
	var h: float = size.y
	var b: Dictionary = {
		"fire": [Vector2(w - 140, h - 190), 74.0, "撃", "FIRE"],
		"zoom": [Vector2(w - 290, h - 120), 46.0, "眼", "ZOOM"],
		"swap": [Vector2(w - 300, h - 255), 42.0, "替", "SWAP"],
		"next": [Vector2(w - 80, 150), 38.0, "次", "NEXT"],
		"exit": [Vector2(w - 180, 150), 38.0, "退", "EXIT"],
	}
	if Game.player.weapon == "rocket":
		b["reload"] = [Vector2(w - 100, h - 345), 38.0, "装", "RELOAD"]
	# Special attacks land where the crosshair points.
	var x: float = 60.0
	for k: String in Abilities.ORDER:
		if Game.abilities.unlocked(k):
			b[k] = [Vector2(x, 150), 34.0, str(Abilities.DEFS[k]["jp"]).left(1), str(Abilities.DEFS[k]["name"]).get_slice(" ", 0)]
			x += 84.0
	return b


func _hit_button(p: Vector2) -> String:
	var bs: Dictionary = _buttons()
	for name: String in bs:
		var c: Vector2 = bs[name][0]
		if p.distance_to(c) <= float(bs[name][1]) * 1.15:
			return name
	return ""


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not enabled():
		return
	if not _active():
		_release_all()
		_command_touch(event)
		return
	_touches.clear()
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			var name: String = _hit_button(t.position)
			if name != "":
				held[name] = t.index
				_press(name)
			elif t.position.x < size.x * 0.4 and t.position.y > size.y * 0.35 and stick_id < 0:
				stick_id = t.index
				stick_origin = t.position
				stick_pos = t.position
			elif aim_id < 0:
				aim_id = t.index
		else:
			for name2: String in held.keys():
				if int(held[name2]) == t.index:
					held.erase(name2)
					_release(name2)
			if t.index == stick_id:
				stick_id = -1
			if t.index == aim_id:
				aim_id = -1
		get_viewport().set_input_as_handled()
	else:
		var d: InputEventScreenDrag = event
		if d.index == stick_id:
			stick_pos = d.position
		elif d.index == aim_id:
			var pl: Player = Game.player
			var s: float = AIM_SENS * pl.fov / 1.15 * (pl.sens / 0.0022)
			pl.yaw -= d.relative.x * s
			pl.pitch -= d.relative.y * s * (-1.0 if pl.invert_y else 1.0)
		get_viewport().set_input_as_handled()
	queue_redraw()


## Pinch with two fingers to zoom the command view.
func _command_touch(event: InputEvent) -> void:
	if Game.state != Game.State.PLAY or Game.paused or Game.hud.menu_open():
		_touches.clear()
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		_pinch_d = _spread()
	else:
		var d: InputEventScreenDrag = event
		if not _touches.has(d.index):
			return
		_touches[d.index] = d.position
		var nd: float = _spread()
		if _pinch_d > 10.0 and nd > 10.0:
			Game.rig.zoom = clampf(Game.rig.zoom * _pinch_d / nd, 0.45, 1.6)
		_pinch_d = nd


func _spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var ps: Array = _touches.values()
	return (ps[0] as Vector2).distance_to(ps[1] as Vector2)


func _press(name: String) -> void:
	var pl: Player = Game.player
	match name:
		"fire":
			pl.firing = true
		"zoom":
			pl.zoom = true
		"swap":
			pl.swap()
		"reload":
			pl.manual_reload()
		"next":
			pl.next_seat()
		"exit":
			_release_all()
			pl.exit_seat()
		"air", "storm", "flood":
			Game.abilities.request(name)


func _release(name: String) -> void:
	if name == "fire":
		Game.player.firing = false
	elif name == "zoom":
		Game.player.zoom = false


func _release_all() -> void:
	if held.is_empty() and stick_id < 0 and aim_id < 0:
		return
	for name: String in held.keys():
		_release(name)
	held.clear()
	stick_id = -1
	aim_id = -1
	queue_redraw()


func _process(_delta: float) -> void:
	var show: bool = enabled() and _active()
	if show != visible:
		visible = show
		if not show:
			_release_all()
	if visible:
		queue_redraw()


func _draw() -> void:
	var font: Font = Mats.font_hud()
	var bs: Dictionary = _buttons()
	for name: String in bs:
		var c: Vector2 = bs[name][0]
		var r: float = bs[name][1]
		var on: bool = held.has(name)
		var col: Color = (Mats.SHU if name == "fire" else (Mats.GOLD if Abilities.DEFS.has(name) else Mats.CYAN))
		if Abilities.DEFS.has(name) and not Game.abilities.is_ready(name):
			col = Color(0.5, 0.5, 0.55)
		draw_circle(c, r, Color(0, 0, 0, 0.35 if not on else 0.55))
		draw_arc(c, r, 0, TAU, 40, Color(col, 0.9 if on else 0.55), 3.0 if on else 2.0, true)
		var big: int = int(r * 0.6)
		var jp: String = bs[name][2]
		var en: String = bs[name][3]
		draw_string(font, c + Vector2(-r, big * 0.25), jp, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, big, Color(col, 0.95))
		draw_string(font, c + Vector2(-r, big * 0.25 + 16), en, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 11, Color(1, 1, 1, 0.75))
		if Abilities.DEFS.has(name):
			var left: float = float(Game.abilities.cd[name]) / float(Abilities.DEFS[name]["cd"])
			if left > 0.0:
				draw_arc(c, r + 5.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 32, Color(Mats.GOLD, 0.8), 3.0, true)
	# Stick: a faint hint where it lives, or the live stick under the thumb.
	var o: Vector2 = stick_origin if stick_id >= 0 else Vector2(250, size.y - 250)
	draw_arc(o, STICK_R, 0, TAU, 40, Color(Mats.CYAN, 0.5 if stick_id >= 0 else 0.25), 2.0, true)
	draw_circle(o + stick() * STICK_R, 30.0, Color(Mats.CYAN, 0.35 if stick_id >= 0 else 0.12))
	if stick_id < 0:
		var lab: String = "MOVE" if Game.player.seat is String else "AIM"
		draw_string(font, o + Vector2(-STICK_R, STICK_R + 22), lab, HORIZONTAL_ALIGNMENT_CENTER, STICK_R * 2.0, 12, Color(1, 1, 1, 0.4))
	if aim_id < 0 and stick_id < 0 and not Game.player.firing:
		draw_string(font, Vector2(size.x * 0.5 - 200, size.y * 0.5 + 120), "drag anywhere to aim", HORIZONTAL_ALIGNMENT_CENTER, 400, 14, Color(1, 1, 1, 0.3))
