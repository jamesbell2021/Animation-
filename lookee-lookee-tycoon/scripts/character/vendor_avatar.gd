class_name VendorAvatar
extends Node2D
## Modular cut-out cartoon character used for the player's vendor, workers, tourists and
## police. Feet are at the origin; the character is about 120 px tall at scale 1.
##
## The body is split into parts (legs, torso, arms, head, eyes, mouth, hair, hat...), each a
## child node with its own draw call. Parts only redraw when the appearance changes; walking,
## shouting and blinking just move, rotate or hide parts, so dozens of characters stay cheap
## on phones. That's also why swapping skin tone, hair or clothes is instant.
##
## Art pipeline: every part is drawn procedurally, but any layer can be replaced by a PNG at
## res://art/characters/<layer>/<style>.png (for example hair_front/afro.png). Greyscale PNGs
## are tinted with the chosen colour. See docs/ART_GUIDE.md for sizes and anchor points.

enum Pose { IDLE, WALK, RUN, LIE, SWIM, CHEER }

## A body part: a Node2D whose _draw() is delegated to a painter function on the avatar.
class Part extends Node2D:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


const OUTLINE := Color(0.17, 0.11, 0.09)
const OUTLINE_W := 2.2
const HIP_Y := -26.0
const LEG_LEN := 26.0
const TORSO_H := 36.0
const ARM_LEN := 28.0
const HEAD_R := 25.0
const SKULL := Vector2(0, -24)  # skull centre, relative to the neck
const FACE_X := 3.0             # features sit slightly forward for a 3/4 look
const GOLD := Color("#ffc928")
## PNG overrides are painted at 4x and drawn at a quarter size, so they stay sharp when zoomed.
const ART_SCALE := 4.0

## When true the avatar mirrors CharacterData (the player's vendor and menu previews).
@export var follow_character_data := false
## When true the avatar stops animating while off-screen (beach crowds).
@export var cull_offscreen := false

var appearance: Dictionary = {}
var pose: Pose = Pose.IDLE
var facing := 1.0
var move_speed := 1.0          # animation speed multiplier for walk/run cycles

var _talk_time := 0.0
var _shout_time := 0.0
var _present_time := 0.0
var _blink_timer := 2.0
var _blink_left := 0.0
var _t := 0.0
var _phase := 0.0
var _held_item := ""

# Derived look values, refreshed by _refresh_metrics().
var _skin := Color.WHITE
var _skin_dark := Color.WHITE
var _hair := Color.BLACK
var _sh := 18.0
var _waist := 16.0
var _belly := 2.0
var _arm_w := 6.0
var _leg_w := 7.0

var _rig: Node2D
var _shadow: Part
var _leg_b: Part
var _leg_f: Part
var _torso: Part
var _arm_b: Part
var _arm_f: Part
var _held: Part
var _head: Node2D
var _hair_back: Part
var _skull: Part
var _eyes_open: Part
var _eyes_closed: Part
var _brows: Part
var _nose: Part
var _beard: Part
var _mouth_closed: Part
var _mouth_open: Part
var _stache: Part
var _hair_front: Part
var _glasses: Part
var _hat: Part
var _water: Part
var _parts: Array[Part] = []

static var _tex_cache := {}
## Antialiased outlines look best at game sizes; big offline renders (icons) turn this off and
## use MSAA instead, because the line feather scales with the zoom.
static var smooth_lines := true


func _ready() -> void:
	_build()
	if appearance.is_empty():
		appearance = AppearanceOptions.default_appearance()
	if follow_character_data and has_node("/root/CharacterData"):
		var cd := get_node("/root/CharacterData")
		appearance = cd.appearance
		cd.appearance_changed.connect(_on_character_changed)
	_blink_timer = randf_range(1.0, 4.0)
	_apply_appearance()
	if cull_offscreen:
		var vis := VisibleOnScreenNotifier2D.new()
		vis.rect = Rect2(-70, -150, 140, 165)
		vis.screen_entered.connect(set_process.bind(true))
		vis.screen_exited.connect(set_process.bind(false))
		add_child(vis)


## Replace the whole look. Accepts any dictionary; missing keys get defaults.
func set_appearance(a: Dictionary) -> void:
	appearance = AppearanceOptions.sanitize(a)
	if is_inside_tree():
		_apply_appearance()


func get_head_top() -> float:
	var s := float(appearance.get("scale", 1.0)) * scale.y
	var extra := 12.0 if int(appearance.get("hat", 0)) == 5 or int(appearance.get("hair_style", 0)) in [5, 10] else 0.0
	return (HIP_Y - TORSO_H - 2.0 * HEAD_R - 8.0 - extra) * s


func set_facing(dir: float) -> void:
	if absf(dir) > 0.01:
		facing = signf(dir)


func set_pose(p: Pose) -> void:
	if pose == p:
		return
	pose = p
	if _rig == null:
		return
	_rig.rotation = 0.0
	_rig.position = Vector2.ZERO
	_leg_b.visible = p != Pose.SWIM
	_leg_f.visible = p != Pose.SWIM
	_water.visible = p == Pose.SWIM
	_shadow.visible = p != Pose.SWIM and p != Pose.LIE
	for part in [_leg_b, _leg_f, _arm_b, _arm_f]:
		part.rotation = 0.0
	# Apply the static part of the pose now, so culled (off-screen) avatars look right too.
	if p == Pose.LIE:
		_rig.rotation = -PI * 0.5
		_rig.position = Vector2(58.0 * float(appearance.get("scale", 1.0)), -6.0)
	elif p == Pose.SWIM:
		_rig.position = Vector2(0, 22.0)


## Talk for a while (mouth flaps). Shout = talk + big arm wave.
func talk(seconds := 1.2) -> void:
	_talk_time = maxf(_talk_time, seconds)


func shout(seconds := 1.3) -> void:
	_shout_time = seconds
	talk(seconds)


## Hold an arm out (showing goods to a tourist).
func present(seconds := 1.0) -> void:
	_present_time = seconds


## Item id to hold in the front hand ("" for none). Tourists carry what they bought.
func hold_item(item_id: String) -> void:
	_held_item = item_id
	if _held:
		_held.visible = item_id != ""
		_held.queue_redraw()


# --- Build -----------------------------------------------------------------------------------

func _build() -> void:
	if _rig:
		return
	_shadow = _make_part(self, _paint_shadow)
	_rig = Node2D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_arm_b = _make_part(_rig, _paint_arm_back)
	_leg_b = _make_part(_rig, _paint_leg)
	_leg_f = _make_part(_rig, _paint_leg)
	_torso = _make_part(_rig, _paint_torso)
	_head = Node2D.new()
	_head.name = "Head"
	_rig.add_child(_head)
	_hair_back = _make_part(_head, _paint_hair_back)
	_skull = _make_part(_head, _paint_skull)
	_eyes_open = _make_part(_head, _paint_eyes)
	_eyes_closed = _make_part(_head, _paint_eyes_closed)
	_brows = _make_part(_head, _paint_brows)
	_nose = _make_part(_head, _paint_nose)
	_beard = _make_part(_head, _paint_beard)
	_mouth_closed = _make_part(_head, _paint_mouth)
	_mouth_open = _make_part(_head, _paint_mouth_open)
	_stache = _make_part(_head, _paint_stache)
	_hair_front = _make_part(_head, _paint_hair_front)
	_glasses = _make_part(_head, _paint_glasses)
	_hat = _make_part(_head, _paint_hat)
	_arm_f = _make_part(_rig, _paint_arm_front)
	_held = _make_part(_arm_f, _paint_held)
	_held.visible = false
	_water = _make_part(_rig, _paint_water)
	_water.visible = false
	_eyes_closed.visible = false
	_mouth_open.visible = false


func _make_part(parent: Node, painter: Callable) -> Part:
	var p := Part.new()
	p.painter = painter
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(p)
	_parts.append(p)
	return p


func _on_character_changed(a: Dictionary) -> void:
	appearance = a
	_apply_appearance()


func _apply_appearance() -> void:
	if _rig == null:
		return
	_refresh_metrics()
	var s := float(appearance.get("scale", 1.0))
	_rig.scale = Vector2(s, s)
	_shadow.scale = Vector2(s, s)
	var leg_x := _waist * 0.45
	_leg_b.position = Vector2(-leg_x, HIP_Y)
	_leg_f.position = Vector2(leg_x, HIP_Y)
	_torso.position = Vector2(0, HIP_Y)
	_arm_b.position = Vector2(-(_sh - 2.0), HIP_Y - TORSO_H + 5.0)
	_arm_f.position = Vector2(_sh - 2.0, HIP_Y - TORSO_H + 5.0)
	_head.position = Vector2(0, HIP_Y - TORSO_H + 2.0)
	_held.position = Vector2(0, ARM_LEN + 2.0)
	_water.position = Vector2(0, HIP_Y - 4.0)
	_held.visible = _held_item != ""
	for p in _parts:
		p.queue_redraw()


func _refresh_metrics() -> void:
	var a := appearance
	_skin = AppearanceOptions.color_of(a, "skin", Color("#d8986c"))
	var burn := clampf(float(a.get("sunburn", 0.0)), 0.0, 1.0)
	if burn > 0.0:
		_skin = _skin.lerp(Color("#ff5a3c"), burn * 0.38)
	_skin_dark = _skin.darkened(0.18)
	_hair = AppearanceOptions.color_of(a, "hair_color", Color("#2a1d17"))
	match int(a.get("body", 1)):
		0: _set_body(14.0, 12.0, 0.0, 5.0, 6.0)
		2: _set_body(22.0, 23.0, 9.0, 7.5, 8.5)
		3: _set_body(24.0, 15.0, 0.0, 8.5, 8.0)
		_: _set_body(18.0, 16.0, 2.0, 6.0, 7.0)


func _set_body(sh: float, waist: float, belly: float, arm: float, leg: float) -> void:
	_sh = sh
	_waist = waist
	_belly = belly
	_arm_w = arm
	_leg_w = leg


# --- Animation -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _rig == null:
		return
	_t += delta
	_rig.scale.x = absf(_rig.scale.x) * facing
	_talk_time = maxf(_talk_time - delta, 0.0)
	_shout_time = maxf(_shout_time - delta, 0.0)
	_present_time = maxf(_present_time - delta, 0.0)

	# Blinking (and sleeping while lying down).
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_left = 0.12
		_blink_timer = randf_range(2.0, 5.0)
	_blink_left = maxf(_blink_left - delta, 0.0)
	var eyes_shut := _blink_left > 0.0 or pose == Pose.LIE
	_eyes_open.visible = not eyes_shut
	_eyes_closed.visible = eyes_shut

	# Mouth flaps while talking.
	var open := _talk_time > 0.0 and fmod(_t, 0.18) < 0.1
	_mouth_open.visible = open
	_mouth_closed.visible = not open

	var bob := 0.0
	match pose:
		Pose.WALK, Pose.RUN:
			var run := pose == Pose.RUN
			_phase += delta * (15.0 if run else 9.5) * move_speed
			var swing := sin(_phase) * (0.85 if run else 0.5)
			_leg_f.rotation = swing
			_leg_b.rotation = -swing
			_arm_f.rotation = -swing * 0.9
			_arm_b.rotation = swing * 0.9
			bob = -absf(sin(_phase)) * (4.0 if run else 2.5)
			_rig.rotation = 0.12 * facing if run else 0.0
			_torso.scale.y = 1.0
		Pose.LIE:
			_rig.rotation = -PI * 0.5
			_rig.position = Vector2(58.0 * float(appearance.get("scale", 1.0)), -6.0)
			_arm_f.rotation = 0.15
			_arm_b.rotation = -0.15
			_torso.scale.y = 1.0 + sin(_t * 1.5) * 0.02
		Pose.SWIM:
			bob = 22.0 + sin(_t * 2.2) * 2.5
			_arm_f.rotation = sin(_t * 4.0) * 1.2 - 1.2
			_arm_b.rotation = -sin(_t * 4.0) * 1.2 + 1.2
		Pose.CHEER:
			_arm_f.rotation = -2.6 + sin(_t * 12.0) * 0.25
			_arm_b.rotation = 2.6 - sin(_t * 12.0) * 0.25
			bob = -absf(sin(_t * 8.0)) * 6.0
		_:
			_leg_f.rotation = 0.0
			_leg_b.rotation = 0.0
			_arm_f.rotation = 0.08 * sin(_t * 1.8)
			_arm_b.rotation = -0.08 * sin(_t * 1.8 + 0.5)
			_torso.scale.y = 1.0 + sin(_t * 2.0) * 0.015
			_rig.rotation = 0.0

	# Gestures override the arms.
	if pose != Pose.LIE and pose != Pose.SWIM:
		if _shout_time > 0.0:
			_arm_f.rotation = -2.5 + sin(_t * 16.0) * 0.35
			_arm_b.rotation = 1.0 + sin(_t * 9.0) * 0.15
			bob -= absf(sin(_t * 10.0)) * 4.0
			_head.rotation = -0.1
		elif _present_time > 0.0:
			_arm_f.rotation = -1.35 + sin(_t * 6.0) * 0.08
			_head.rotation = 0.04
		else:
			_head.rotation = sin(_t * 1.3) * 0.03
	if pose != Pose.LIE:
		_rig.position.y = bob


# --- Drawing helpers ---------------------------------------------------------------------------

static func _ellipse(c: Vector2, rx: float, ry: float, n := 22, a0 := 0.0, a1 := TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var full := is_equal_approx(a1 - a0, TAU)
	var count := n if full else n + 1
	for i in count:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _capsule(a: Vector2, b: Vector2, r: float, n := 8) -> PackedVector2Array:
	var ang := (b - a).angle() if a != b else PI * 0.5
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(b + Vector2.from_angle(ang - PI * 0.5 + PI * float(i) / float(n)) * r)
	for i in n + 1:
		pts.append(a + Vector2.from_angle(ang + PI * 0.5 + PI * float(i) / float(n)) * r)
	return pts


static func _star(c: Vector2, r_out: float, r_in: float, points := 5, rot := -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * float(i) / float(points)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line_w := OUTLINE_W) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fill)
	if line_w > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, OUTLINE, line_w, smooth_lines)


func _circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, line_w := OUTLINE_W) -> void:
	_shape(ci, _ellipse(c, r, r, 18), fill, line_w)


func _line(ci: CanvasItem, pts: PackedVector2Array, color: Color, w: float) -> void:
	ci.draw_polyline(pts, color, w, smooth_lines)


func _i(key: String) -> int:
	return int(appearance.get(key, 0))


func _col(key: String, fallback := Color.WHITE) -> Color:
	return AppearanceOptions.color_of(appearance, key, fallback)


func _uniform() -> bool:
	return str(appearance.get("uniform", "")) == "police"


static func _override_tex(layer: String, style: String) -> Texture2D:
	var path := "res://art/characters/%s/%s.png" % [layer, art_key(style)]
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## File name for a style: "Socks & Sandals" -> "socks_and_sandals", "Buzz Cut" -> "buzz_cut".
static func art_key(style: String) -> String:
	return style.to_lower().replace("&", "and").replace("-", " ").strip_edges().replace("  ", " ").replace(" ", "_")


## Draws res://art/characters/<layer>/<style>.png instead of the procedural part if it exists.
## The PNG is centred on the layer's anchor, drawn at 1/ART_SCALE size and multiplied by the
## tint (paint tintable parts in light greys with dark outlines). See docs/ART_GUIDE.md.
func _override(ci: CanvasItem, layer: String, style: String, tint: Color, anchor: Vector2) -> bool:
	var tex := _override_tex(layer, style)
	if tex == null:
		return false
	var size := tex.get_size() / ART_SCALE
	ci.draw_texture_rect(tex, Rect2(anchor - size * 0.5, size), false, tint)
	return true


## Like _override, but first tries a body-type specific file ("hawaiian_large.png").
func _override_body(ci: CanvasItem, layer: String, style: String, tint: Color, anchor: Vector2) -> bool:
	var body: String = AppearanceOptions.BODY_TYPES[clampi(_i("body"), 0, 3)]
	if _override_tex(layer, style + " " + body) != null:
		return _override(ci, layer, style + " " + body, tint, anchor)
	return _override(ci, layer, style, tint, anchor)


# --- Painters: body ---------------------------------------------------------------------------

func _paint_shadow(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(_ellipse(Vector2.ZERO, _waist + 12.0 + _belly, 6.0), Color(0, 0, 0, 0.22))


func _paint_leg(ci: CanvasItem) -> void:
	var lw := _leg_w
	var bottoms := _i("bottoms")
	var bcol := _col("bottoms_color", Color("#1e88e5"))
	if _uniform():
		bottoms = 2
	# Leg (skin).
	_shape(ci, _capsule(Vector2(0, 2), Vector2(0, LEG_LEN - 3.0), lw * 0.5), _skin)
	# Bottoms.
	if _override_body(ci, "bottoms", "police" if _uniform() else AppearanceOptions.BOTTOMS[bottoms], bcol, Vector2(0, LEG_LEN * 0.4)):
		_paint_shoes(ci, lw)
		return
	var cover := 0.55
	match bottoms:
		1: cover = 0.68
		2, 4: cover = 0.94
		3: cover = 0.62
		5: cover = 0.28
	var w := lw * 0.5 + 2.5
	var pts := PackedVector2Array([Vector2(-w, -2), Vector2(w, -2), Vector2(w + 0.5, LEG_LEN * cover), Vector2(-w - 0.5, LEG_LEN * cover)])
	_shape(ci, pts, bcol)
	match bottoms:
		1:  # board shorts stripe
			ci.draw_rect(Rect2(-w + 1.0, LEG_LEN * cover - 5.0, w * 2.0 - 2.0, 2.5), bcol.lightened(0.5))
		3:  # cargo pocket
			_shape(ci, PackedVector2Array([Vector2(w - 5, 5), Vector2(w + 1, 5), Vector2(w + 1, 11), Vector2(w - 5, 11)]), bcol.darkened(0.15), 1.4)
		4:  # trackie stripe
			ci.draw_line(Vector2(w - 1.5, 0), Vector2(w - 1.5, LEG_LEN * cover), Color.WHITE, 2.0)
	_paint_shoes(ci, lw)


func _paint_shoes(ci: CanvasItem, lw: float) -> void:
	var foot := Vector2(2.0, LEG_LEN - 1.0)
	var shoes := _i("shoes")
	var scol := _col("shoes_color", Color("#e53935"))
	if _override(ci, "shoes", AppearanceOptions.SHOES[shoes], scol, foot):
		return
	match shoes:
		0:  # flip-flops
			_shape(ci, _ellipse(foot + Vector2(1, 2), lw * 0.75 + 2, 2.5), scol, 1.6)
			_shape(ci, _ellipse(foot, lw * 0.6, 3.0), _skin, 1.6)
			_line(ci, PackedVector2Array([foot + Vector2(-2, -2), foot + Vector2(2, 1), foot + Vector2(5, -2)]), scol.darkened(0.3), 1.8)
		1:  # sandals
			_shape(ci, _ellipse(foot + Vector2(1, 2), lw * 0.75 + 2, 2.6), Color("#8d6e63"), 1.6)
			_shape(ci, _ellipse(foot, lw * 0.6, 3.0), _skin, 1.6)
			ci.draw_line(foot + Vector2(-3, -1), foot + Vector2(5, -1), scol, 2.0)
		2:  # trainers
			_shape(ci, _capsule(foot + Vector2(-3, 0), foot + Vector2(5, 0), 4.0, 6), scol)
			ci.draw_line(foot + Vector2(-6, 3), foot + Vector2(9, 3), Color.WHITE, 2.0)
		3:  # socks and sandals: a classic
			_shape(ci, _capsule(Vector2(0, LEG_LEN * 0.55), foot, lw * 0.5 + 0.5), Color("#fafafa"))
			_shape(ci, _ellipse(foot + Vector2(1, 2), lw * 0.75 + 2, 2.6), Color("#6d4c41"), 1.6)
			ci.draw_line(foot + Vector2(-3, -1), foot + Vector2(5, -1), Color("#6d4c41"), 2.2)
		_:  # barefoot
			_shape(ci, _ellipse(foot + Vector2(1, 0.5), lw * 0.65, 3.0), _skin, 1.6)


func _torso_points(top_inset := 0.0) -> PackedVector2Array:
	var t := -TORSO_H
	return PackedVector2Array([
		Vector2(-_waist, 0), Vector2(_waist, 0),
		Vector2(_sh - top_inset, t + 7.0), Vector2(_sh - 4.0 - top_inset, t),
		Vector2(-_sh + 4.0 + top_inset, t), Vector2(-_sh + top_inset, t + 7.0),
	])


func _paint_torso(ci: CanvasItem) -> void:
	var shirt := _i("shirt")
	var scol := _col("shirt_color", Color("#00bcd4"))
	var t := -TORSO_H
	if _uniform():
		shirt = 99
		scol = Color("#9fc3ff")
	# Skin body underneath.
	_shape(ci, _torso_points(), _skin)
	if _belly > 0.0:
		_shape(ci, _ellipse(Vector2(_belly * 0.5, -11.0), _waist + _belly * 0.4, 12.0 + _belly * 0.6, 20), _skin)
	if not _override_body(ci, "shirts", "police" if shirt == 99 else AppearanceOptions.SHIRTS[clampi(shirt, 0, 6)], scol, Vector2(0, t * 0.5)):
		match shirt:
			0:  # vest top
				var pts := PackedVector2Array([
					Vector2(-_waist, 0), Vector2(_waist, 0), Vector2(_sh - 5.0, t + 8.0), Vector2(_sh - 8.0, t),
					Vector2(_sh - 11.0, t), Vector2(0, t + 12.0), Vector2(-_sh + 11.0, t), Vector2(-_sh + 8.0, t),
					Vector2(-_sh + 5.0, t + 8.0)])
				_shape(ci, pts, scol)
				_belly_fill(ci, scol)
			1, 2, 3, 5:  # t-shirt family
				_shape(ci, _torso_points(), scol)
				_belly_fill(ci, scol)
				match shirt:
					2: _hawaiian_pattern(ci, scol)
					3:
						for k: float in [-0.5, 0.0, 0.5]:
							var x: float = _sh * k
							ci.draw_line(Vector2(x, t + 2), Vector2(x * 0.9, -2), scol.lightened(0.6), 3.0)
						_shape(ci, PackedVector2Array([Vector2(-5, t), Vector2(5, t), Vector2(0, t + 6)]), Color.WHITE, 1.4)
					5:
						_shape(ci, PackedVector2Array([Vector2(-7, t), Vector2(0, t + 7), Vector2(-3, t + 1)]), scol.darkened(0.15), 1.4)
						_shape(ci, PackedVector2Array([Vector2(7, t), Vector2(0, t + 7), Vector2(3, t + 1)]), scol.darkened(0.15), 1.4)
						for yy: float in [t + 10.0, t + 15.0]:
							ci.draw_circle(Vector2(0, yy), 1.3, OUTLINE)
					1:
						ci.draw_arc(Vector2(0, t), 5.0, 0.0, PI, 10, scol.darkened(0.25), 2.0, true)
			4:  # open shirt: chest shows
				var l := PackedVector2Array([Vector2(-_waist, 0), Vector2(-4, 0), Vector2(-2, t + 14), Vector2(-6, t), Vector2(-_sh + 4, t), Vector2(-_sh, t + 7)])
				var r := PackedVector2Array([Vector2(4, 0), Vector2(_waist, 0), Vector2(_sh, t + 7), Vector2(_sh - 4, t), Vector2(6, t), Vector2(2, t + 14)])
				_shape(ci, l, scol)
				_shape(ci, r, scol)
				_hawaiian_pattern(ci, scol, true)
			99:  # police uniform
				_shape(ci, _torso_points(), scol)
				_belly_fill(ci, scol)
				_shape(ci, _star(Vector2(-_sh * 0.45, t + 11), 4.0, 1.8), GOLD, 1.2)
				ci.draw_line(Vector2(0, t + 3), Vector2(0, -3), scol.darkened(0.3), 1.5)
				ci.draw_rect(Rect2(-_sh * 0.7, t + 1, 6, 3), Color("#2b4c8c"))
				ci.draw_rect(Rect2(_sh * 0.7 - 6, t + 1, 6, 3), Color("#2b4c8c"))
			_:  # no shirt
				ci.draw_circle(Vector2(1 + _belly * 0.5, -9), 1.2, _skin_dark)
	# Waistband / belt.
	var bcol := _col("bottoms_color", Color("#1e88e5"))
	if _uniform():
		bcol = Color("#1c2b4a")
	var ww := _waist + (2.0 if _belly > 4.0 else 0.5)
	_shape(ci, PackedVector2Array([Vector2(-ww, -5), Vector2(ww, -5), Vector2(ww, 1), Vector2(-ww, 1)]), bcol, 1.6)
	if _i("bottoms") == 2 or _uniform():
		ci.draw_rect(Rect2(-ww, -4, ww * 2.0, 2.5), Color("#3e2723"))
		ci.draw_rect(Rect2(-2.5, -4.5, 5, 3.5), GOLD)
	_paint_chain(ci)
	_paint_bag(ci)


func _belly_fill(ci: CanvasItem, col: Color) -> void:
	if _belly > 0.0:
		_shape(ci, _ellipse(Vector2(_belly * 0.5, -11.0), _waist + _belly * 0.4 - 0.5, 12.0 + _belly * 0.6 - 0.5, 20), col, OUTLINE_W)
		# Re-cover the top edge so the belly blends into the shirt.
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-_waist + 2, -14), Vector2(_waist - 2, -14), Vector2(_sh - 4, -TORSO_H + 8), Vector2(-_sh + 4, -TORSO_H + 8)]), col)


func _hawaiian_pattern(ci: CanvasItem, base: Color, open := false) -> void:
	var flower := base.lightened(0.55) if base.get_luminance() < 0.6 else base.darkened(0.35)
	var spots := [Vector2(-10, -28), Vector2(8, -24), Vector2(-4, -14), Vector2(12, -9), Vector2(-13, -7), Vector2(3, -31)]
	for p: Vector2 in spots:
		if open and absf(p.x) < 7.0:
			continue
		if absf(p.x) > _sh - 3.0:
			continue
		for k in 5:
			ci.draw_circle(p + Vector2.from_angle(TAU * k / 5.0) * 2.4, 1.7, flower)
		ci.draw_circle(p, 1.3, Color("#ffe14d"))


func _paint_chain(ci: CanvasItem) -> void:
	var t := -TORSO_H
	var style := _i("chain")
	if style == 0:
		return
	var pts := PackedVector2Array()
	for k in 9:
		var f := float(k) / 8.0
		pts.append(Vector2(lerpf(-8, 8, f), t + 2.0 + sin(f * PI) * 11.0))
	match style:
		1:
			_line(ci, pts, OUTLINE, 3.6)
			_line(ci, pts, GOLD, 2.2)
		2:
			_line(ci, pts, OUTLINE, 6.0)
			_line(ci, pts, GOLD, 4.2)
			_circle(ci, Vector2(0, t + 15.0), 4.2, GOLD, 1.6)
		3:
			for p in pts:
				ci.draw_circle(p, 1.9, Color("#fff8e1"))


func _paint_bag(ci: CanvasItem) -> void:
	match _i("bag"):
		1:  # bum bag
			var c := _col("hat_color", Color("#212121")).darkened(0.1)
			ci.draw_line(Vector2(-_waist, -6), Vector2(_waist, -6), OUTLINE, 2.0)
			_shape(ci, _capsule(Vector2(-3 + _belly * 0.5, -5), Vector2(6 + _belly * 0.5, -5), 4.5, 6), c)
			ci.draw_line(Vector2(-4 + _belly * 0.5, -6), Vector2(7 + _belly * 0.5, -6), GOLD, 1.0)
		2:  # cross-body
			ci.draw_line(Vector2(_sh - 4, -TORSO_H + 1), Vector2(-_waist + 2, -4), Color("#4e342e"), 3.0)
			_shape(ci, PackedVector2Array([Vector2(-_waist - 3, -10), Vector2(-_waist + 7, -10), Vector2(-_waist + 7, -1), Vector2(-_waist - 3, -1)]), Color("#6d4c41"), 1.6)


func _paint_arm_back(ci: CanvasItem) -> void:
	_paint_arm(ci, false)


func _paint_arm_front(ci: CanvasItem) -> void:
	_paint_arm(ci, true)


func _paint_arm(ci: CanvasItem, front: bool) -> void:
	var skin := _skin if front else _skin.darkened(0.08)
	var w := _arm_w
	var hand := Vector2(0, ARM_LEN)
	_shape(ci, _capsule(Vector2(0, 0), hand - Vector2(0, 2), w * 0.5), skin)
	var shirt := _i("shirt")
	var scol := _col("shirt_color", Color("#00bcd4"))
	var sleeve := 0.0
	match shirt:
		1, 2, 3, 5: sleeve = 11.0
		4: sleeve = 13.0
	if _uniform():
		sleeve = 12.0
		scol = Color("#9fc3ff")
	if not front:
		scol = scol.darkened(0.08)
	if sleeve > 0.0:
		_shape(ci, PackedVector2Array([Vector2(-w * 0.5 - 2.5, -3), Vector2(w * 0.5 + 2.5, -3), Vector2(w * 0.5 + 3.0, sleeve), Vector2(-w * 0.5 - 3.0, sleeve)]), scol)
	_circle(ci, hand, w * 0.5 + 2.0, skin)
	if front:
		match _i("watch"):
			1:
				ci.draw_rect(Rect2(-w * 0.5 - 0.5, ARM_LEN - 8, w + 1, 3.5), GOLD)
			2:  # the legendary arm full of watches
				for k in 4:
					var y := ARM_LEN - 8.0 - k * 4.5
					if y < sleeve + 1.0:
						break
					ci.draw_rect(Rect2(-w * 0.5 - 1.0, y, w + 2.0, 3.0), GOLD if k % 2 == 0 else Color("#cfd8dc"))
					ci.draw_circle(Vector2(w * 0.5 + 0.5, y + 1.5), 1.8, Color.WHITE)
			3:
				ci.draw_rect(Rect2(-w * 0.5 - 0.5, ARM_LEN - 8, w + 1, 4), Color("#212121"))
				ci.draw_rect(Rect2(w * 0.5 - 1.0, ARM_LEN - 8.5, 3, 5), Color("#40c4ff"))


func _paint_held(ci: CanvasItem) -> void:
	if _held_item != "":
		ItemArt.draw_item(ci, _held_item, Vector2(4, 4), 18.0)


func _paint_water(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(_ellipse(Vector2.ZERO, _waist + 22.0, 7.0), Color(0.75, 0.95, 1.0, 0.85))
	ci.draw_polyline(_ellipse(Vector2.ZERO, _waist + 22.0, 7.0), Color.WHITE, 2.0, true)


# --- Painters: head ---------------------------------------------------------------------------

func _paint_skull(ci: CanvasItem) -> void:
	var c := SKULL
	# Neck.
	_shape(ci, PackedVector2Array([Vector2(-6, 4), Vector2(6, 4), Vector2(6, c.y + 12), Vector2(-6, c.y + 12)]), _skin_dark)
	# Ears.
	for sx: float in [-1.0, 1.0]:
		_circle(ci, c + Vector2(sx * (HEAD_R - 1.0) + FACE_X * 0.3, 1.0), 5.0, _skin)
	if _override(ci, "skull", "head", _skin, c):
		pass
	else:
		_shape(ci, _ellipse(c, HEAD_R, HEAD_R + 1.0, 28), _skin)
	# Cheeks.
	for sx: float in [-1.0, 1.0]:
		ci.draw_colored_polygon(_ellipse(c + Vector2(sx * 14.0 + FACE_X, 8.0), 4.5, 3.0, 12), Color(1.0, 0.45, 0.45, 0.22))
	# Earrings.
	var ear_y := c.y + 6.0
	match _i("earrings"):
		1:
			for sx: float in [-1.0, 1.0]:
				ci.draw_circle(Vector2(sx * (HEAD_R - 1.0) + FACE_X * 0.3, ear_y), 2.0, GOLD)
		2:
			for sx: float in [-1.0, 1.0]:
				ci.draw_arc(Vector2(sx * (HEAD_R - 1.0) + FACE_X * 0.3, ear_y + 3.5), 3.5, 0, TAU, 14, GOLD, 1.6, true)


func _eye_centers() -> Array[Vector2]:
	return [SKULL + Vector2(-9.0 + FACE_X, -1.0), SKULL + Vector2(9.0 + FACE_X, -1.0)]


func _paint_eyes(ci: CanvasItem) -> void:
	var iris := _col("eye_color", Color("#3b2314"))
	var style := _i("eyes")
	if _override(ci, "eyes", AppearanceOptions.EYES[style], Color.WHITE, SKULL + Vector2(FACE_X, -1.0)):
		return
	for e in _eye_centers():
		var look := Vector2(1.2, 0.0)
		match style:
			1:  # sleepy
				_circle(ci, e, 5.5, Color.WHITE, 1.8)
				ci.draw_circle(e + look + Vector2(0, 1.5), 3.0, iris)
				ci.draw_colored_polygon(_ellipse(e, 6.3, 6.3, 14, PI, TAU), _skin)
				_line(ci, PackedVector2Array([e + Vector2(-6, 0), e + Vector2(6, 0)]), OUTLINE, 2.0)
			2:  # wide
				_circle(ci, e, 7.2, Color.WHITE, 1.8)
				ci.draw_circle(e + look, 3.0, iris)
				ci.draw_circle(e + look, 1.5, Color.BLACK)
			3:  # happy ^^
				_line(ci, _ellipse(e + Vector2(0, 2), 5.0, 4.5, 10, PI, TAU), OUTLINE, 2.6)
			4:  # narrow
				_shape(ci, _ellipse(e, 6.5, 3.2, 16), Color.WHITE, 1.8)
				ci.draw_circle(e + look, 2.4, iris)
				ci.draw_circle(e + look, 1.2, Color.BLACK)
			5:  # sparkly
				_circle(ci, e, 6.6, Color.WHITE, 1.8)
				ci.draw_circle(e + look, 4.6, iris)
				ci.draw_circle(e + look, 2.0, Color.BLACK)
				ci.draw_circle(e + look + Vector2(-1.6, -1.8), 1.6, Color.WHITE)
				ci.draw_circle(e + look + Vector2(1.5, 1.4), 0.9, Color.WHITE)
			_:  # round
				_circle(ci, e, 6.0, Color.WHITE, 1.8)
				ci.draw_circle(e + look, 3.4, iris)
				ci.draw_circle(e + look, 1.7, Color.BLACK)
				ci.draw_circle(e + look + Vector2(-1.2, -1.3), 1.1, Color.WHITE)


func _paint_eyes_closed(ci: CanvasItem) -> void:
	if _override(ci, "eyes", "closed", _skin, SKULL + Vector2(FACE_X, -1.0)):
		return
	for e in _eye_centers():
		_line(ci, _ellipse(e + Vector2(0, -1.5), 5.0, 3.5, 10, 0.0, PI), OUTLINE, 2.4)


func _brow_color() -> Color:
	return _hair.darkened(0.25) if _hair.get_luminance() > 0.25 else _hair.lightened(0.05)


func _paint_brows(ci: CanvasItem) -> void:
	var col := _brow_color()
	var y := SKULL.y - 10.0
	var style := _i("brows")
	if _override(ci, "brows", AppearanceOptions.BROWS[style], col, Vector2(FACE_X, y)):
		return
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var cx := sx * 9.0 + FACE_X
		match style:
			1:  # bushy
				_line(ci, PackedVector2Array([Vector2(cx - 6, y + 1), Vector2(cx, y - 2), Vector2(cx + 6, y + 1)]), col, 5.0)
			2:  # angry
				_line(ci, PackedVector2Array([Vector2(cx - 5 * sx, y - 2), Vector2(cx + 5 * sx, y + 2.5)]), col, 3.6)
			3:  # raised
				_line(ci, PackedVector2Array([Vector2(cx - 5, y - 1), Vector2(cx, y - 5), Vector2(cx + 5, y - 1)]), col, 3.0)
			4:  # unibrow
				if i == 0:
					_line(ci, PackedVector2Array([Vector2(-15 + FACE_X, y + 1), Vector2(-4 + FACE_X, y - 1), Vector2(0 + FACE_X, y + 1), Vector2(4 + FACE_X, y - 1), Vector2(15 + FACE_X, y + 1)]), col, 4.0)
			5:  # thin
				_line(ci, PackedVector2Array([Vector2(cx - 5, y), Vector2(cx, y - 2), Vector2(cx + 5, y)]), col, 1.6)
			_:
				_line(ci, PackedVector2Array([Vector2(cx - 5, y + 0.5), Vector2(cx, y - 2), Vector2(cx + 5, y + 0.5)]), col, 3.0)


func _paint_nose(ci: CanvasItem) -> void:
	var p := SKULL + Vector2(FACE_X + 1.5, 6.0)
	var col := _skin_dark
	if _override(ci, "nose", AppearanceOptions.NOSES[_i("nose")], _skin, p):
		return
	match _i("nose"):
		1:
			_shape(ci, _ellipse(p + Vector2(1, 1), 6.0, 5.0, 16), col, 1.8)
		2:
			_shape(ci, PackedVector2Array([p + Vector2(-2, -8), p + Vector2(7, 3), p + Vector2(-2, 3)]), col, 1.8)
		3:
			_circle(ci, p, 4.8, col, 1.8)
		4:
			_shape(ci, _ellipse(p, 7.0, 3.6, 16), col, 1.8)
			ci.draw_circle(p + Vector2(-3, 1), 1.1, OUTLINE)
			ci.draw_circle(p + Vector2(3, 1), 1.1, OUTLINE)
		_:
			_shape(ci, _ellipse(p, 3.4, 2.8, 12), col, 1.6)


func _mouth_pos() -> Vector2:
	return SKULL + Vector2(FACE_X, 14.0)


func _paint_mouth(ci: CanvasItem) -> void:
	var m := _mouth_pos()
	if _override(ci, "mouth", AppearanceOptions.MOUTHS[_i("mouth")], Color.WHITE, m):
		return
	match _i("mouth"):
		1, 4:  # big smile / gold tooth
			_shape(ci, _ellipse(m + Vector2(0, -2), 8.0, 7.0, 12, 0.0, PI), Color("#7a1f1f"), 2.0)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-7, -2), m + Vector2(7, -2), m + Vector2(6, 1), m + Vector2(-6, 1)]), Color.WHITE)
			if _i("mouth") == 4:
				ci.draw_rect(Rect2(m + Vector2(1, -2), Vector2(3.5, 3)), GOLD)
			_line(ci, PackedVector2Array([m + Vector2(-8, -2), m + Vector2(8, -2)]), OUTLINE, 2.0)
		2:  # smirk
			_line(ci, PackedVector2Array([m + Vector2(-6, 0), m + Vector2(0, 1.5), m + Vector2(6, -1), m + Vector2(8, -3)]), OUTLINE, 2.4)
		3:  # always shouting
			_shape(ci, _ellipse(m + Vector2(0, 1), 5.0, 5.5, 14), Color("#7a1f1f"), 2.0)
			ci.draw_colored_polygon(_ellipse(m + Vector2(0, 4), 3.0, 1.8, 10), Color("#ff8a80"))
		5:  # tiny
			_line(ci, PackedVector2Array([m + Vector2(-3, 0), m + Vector2(0, 1.2), m + Vector2(3, 0)]), OUTLINE, 2.2)
		_:  # grin
			_line(ci, _ellipse(m + Vector2(0, -4), 8.0, 6.0, 12, 0.25, PI - 0.25), OUTLINE, 2.6)


func _paint_mouth_open(ci: CanvasItem) -> void:
	var m := _mouth_pos()
	if _override(ci, "mouth", "open", Color.WHITE, m):
		return
	_shape(ci, _ellipse(m + Vector2(0, 1), 7.5, 8.0, 18), Color("#6d1b1b"), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-6, -5), m + Vector2(6, -5), m + Vector2(5, -2), m + Vector2(-5, -2)]), Color.WHITE)
	ci.draw_colored_polygon(_ellipse(m + Vector2(0, 5), 4.5, 2.6, 12), Color("#ff8a80"))
	if _i("mouth") == 4:
		ci.draw_rect(Rect2(m + Vector2(1, -5), Vector2(3, 3)), GOLD)


func _paint_beard(ci: CanvasItem) -> void:
	var col := _hair if _i("hair_style") != 0 or _hair.get_luminance() < 0.8 else _hair.darkened(0.2)
	var c := SKULL
	if _i("facial_hair") > 0 and _override(ci, "facial_hair", AppearanceOptions.FACIAL_HAIR[_i("facial_hair")], col, c + Vector2(FACE_X, 8.0)):
		return
	match _i("facial_hair"):
		1:  # stubble
			var stub := col
			stub.a = 0.33
			var pts := _ellipse(c + Vector2(FACE_X * 0.5, 4), HEAD_R - 1.0, HEAD_R - 2.0, 18, 0.15, PI - 0.15)
			pts.append(c + Vector2(-12, 6))
			ci.draw_colored_polygon(pts, stub)
		4:  # goatee
			_shape(ci, _ellipse(_mouth_pos() + Vector2(0, 9), 5.5, 5.0, 14), col, 1.6)
		5:  # full beard
			var pts := _ellipse(c + Vector2(FACE_X * 0.5, 6), HEAD_R + 1.0, HEAD_R + 3.0, 22, -0.05, PI + 0.05)
			_shape(ci, pts, col, OUTLINE_W)
			# Cut out the mouth area with skin so the mouth reads on top.
			ci.draw_colored_polygon(_ellipse(_mouth_pos() + Vector2(0, -1), 9.0, 5.0, 14), _skin)
		6:  # mutton chops
			for sx: float in [-1.0, 1.0]:
				var x := sx * (HEAD_R - 4.0) + FACE_X * 0.3
				_shape(ci, PackedVector2Array([c + Vector2(x - 4, -6), c + Vector2(x + 4, -6), c + Vector2(x + 5 * -sx + 4, 14), c + Vector2(x - 4, 12)]), col, 1.6)


func _paint_stache(ci: CanvasItem) -> void:
	var col := _hair if _hair.get_luminance() < 0.85 else _hair.darkened(0.15)
	var m := _mouth_pos() + Vector2(0, -6)
	if _override_tex("facial_hair", AppearanceOptions.FACIAL_HAIR[_i("facial_hair")]) != null:
		return  # the PNG (drawn by _paint_beard) includes any moustache
	match _i("facial_hair"):
		2, 4, 5:  # moustache (also part of goatee and full beard)
			var pts := PackedVector2Array([m + Vector2(-9, 2), m + Vector2(-5, -3), m + Vector2(0, -2), m + Vector2(5, -3), m + Vector2(9, 2), m + Vector2(4, 1), m + Vector2(0, 2), m + Vector2(-4, 1)])
			_shape(ci, pts, col, 1.8)
		3:  # handlebar
			var pts := PackedVector2Array([m + Vector2(-8, 0), m + Vector2(-4, -3), m + Vector2(0, -2), m + Vector2(4, -3), m + Vector2(8, 0), m + Vector2(4, 1), m + Vector2(0, 1.5), m + Vector2(-4, 1)])
			_shape(ci, pts, col, 1.8)
			for sx: float in [-1.0, 1.0]:
				_line(ci, PackedVector2Array([m + Vector2(sx * 8, 0), m + Vector2(sx * 12, -1), m + Vector2(sx * 13, -5), m + Vector2(sx * 11, -6)]), col, 2.6)


func _hat_lift() -> float:
	# Big hair pushes hats up.
	match _i("hair_style"):
		5: return 9.0
		10: return 6.0
		9: return 4.0
		3, 7: return 2.0
	return 0.0


func _paint_hair_back(ci: CanvasItem) -> void:
	var c := SKULL
	var col := _hair.darkened(0.12)
	var style := _i("hair_style")
	if _override(ci, "hair_back", AppearanceOptions.HAIR_STYLES[style], _hair, c):
		return
	match style:
		4:  # long
			_shape(ci, PackedVector2Array([c + Vector2(-HEAD_R - 3, -6), c + Vector2(HEAD_R + 3, -6), c + Vector2(HEAD_R + 6, 34), c + Vector2(-HEAD_R - 6, 34)]), col)
		5:  # afro
			_shape(ci, _ellipse(c + Vector2(0, -6), HEAD_R + 13.0, HEAD_R + 12.0, 26), col)
		8:  # ponytail
			_shape(ci, _capsule(c + Vector2(-HEAD_R + 2, -6), c + Vector2(-HEAD_R - 8, 22), 5.5), col)
		12:  # braids
			for k in 5:
				var x := -HEAD_R + 6.0 + k * 10.0
				_shape(ci, _capsule(c + Vector2(x, 4), c + Vector2(x * 1.15, 34), 3.2, 5), col, 1.6)
		3:  # curly volume
			_shape(ci, _ellipse(c + Vector2(0, -4), HEAD_R + 5.0, HEAD_R + 3.0, 22), col)


func _paint_hair_front(ci: CanvasItem) -> void:
	var c := SKULL
	var col := _hair
	var style := _i("hair_style")
	var hat := _i("hat")
	if _override(ci, "hair_front", AppearanceOptions.HAIR_STYLES[style], _hair, c):
		return
	var r := HEAD_R + 1.5
	# Cap shape covering the top of the skull, with an uneven fringe.
	var cap := _ellipse(c, r, r + 1.0, 22, PI + 0.05, TAU - 0.05)
	match style:
		0:  # bald: just a shine
			if hat == 0 or hat == 7:
				_line(ci, _ellipse(c + Vector2(-5, -12), 7.0, 4.0, 8, PI + 0.4, TAU - 0.6), Color(1, 1, 1, 0.55), 2.4)
		1:  # buzz
			var buzz := col
			buzz.a = 0.75
			var pts := _ellipse(c, r - 1.0, r, 20, PI - 0.15, TAU + 0.15)
			ci.draw_colored_polygon(pts, buzz)
		2:  # short with fringe
			cap.append(c + Vector2(r - 3, -6))
			cap.append(c + Vector2(10, -10))
			cap.append(c + Vector2(4, -7))
			cap.append(c + Vector2(-4, -11))
			cap.append(c + Vector2(-12, -7))
			cap.append(c + Vector2(-r + 3, -4))
			_shape(ci, cap, col)
		3:  # curly
			for k in 11:
				var a := PI + 0.1 + (PI - 0.2) * k / 10.0
				_circle(ci, c + Vector2(cos(a) * (r - 1), sin(a) * (r - 1) + 2), 6.5, col, 1.6)
		4:  # long
			cap.append(c + Vector2(r + 1, 18))
			cap.append(c + Vector2(r - 6, 18))
			cap.append(c + Vector2(r - 8, -8))
			cap.append(c + Vector2(-2, -12))
			cap.append(c + Vector2(-r + 8, -8))
			cap.append(c + Vector2(-r + 6, 18))
			cap.append(c + Vector2(-r - 1, 18))
			_shape(ci, cap, col)
		5:  # afro fringe
			for k in 9:
				var a := PI + 0.15 + (PI - 0.3) * k / 8.0
				_circle(ci, c + Vector2(cos(a) * (r + 2), sin(a) * (r + 1) - 4), 8.0, col, 1.4)
		6:  # undercut: shaved sides, swept top
			var buzz := col
			buzz.a = 0.5
			ci.draw_colored_polygon(_ellipse(c, r - 1.0, r, 20, PI - 0.1, TAU + 0.1), buzz)
			_shape(ci, PackedVector2Array([c + Vector2(-r + 4, -12), c + Vector2(-6, -r - 6), c + Vector2(14, -r - 4), c + Vector2(r + 2, -12), c + Vector2(r - 4, -8), c + Vector2(-r + 6, -8)]), col)
		7:  # messy spikes
			var pts := PackedVector2Array()
			for k in 13:
				var a := PI + (PI) * k / 12.0
				var rr := r + (7.0 if k % 2 == 1 else 0.0)
				pts.append(c + Vector2(cos(a) * rr, sin(a) * rr))
			pts.append(c + Vector2(r - 3, -5))
			pts.append(c + Vector2(0, -9))
			pts.append(c + Vector2(-r + 3, -5))
			_shape(ci, pts, col)
		8, 11:  # ponytail / slick back: smooth cap with shine
			cap.append(c + Vector2(r - 2, -6))
			cap.append(c + Vector2(-r + 2, -6))
			_shape(ci, cap, col)
			_line(ci, _ellipse(c, r - 6, r - 6, 10, PI + 0.6, TAU - 0.9), col.lightened(0.35), 2.0)
		9:  # mohawk
			var buzz := col
			buzz.a = 0.45
			ci.draw_colored_polygon(_ellipse(c, r - 1.0, r, 20, PI - 0.1, TAU + 0.1), buzz)
			var pts := PackedVector2Array()
			for k in 7:
				var x := lerpf(-13, 13, k / 6.0)
				var top := -r - (12.0 if k % 2 == 0 else 5.0)
				pts.append(c + Vector2(x, top))
			pts.append(c + Vector2(13, -r + 6))
			pts.append(c + Vector2(-13, -r + 6))
			_shape(ci, pts, col)
		10:  # top bun
			cap.append(c + Vector2(r - 2, -6))
			cap.append(c + Vector2(-r + 2, -6))
			_shape(ci, cap, col)
			_circle(ci, c + Vector2(-2, -r - 7), 9.0, col)
		12:  # braids: cornrow cap
			cap.append(c + Vector2(r - 2, -6))
			cap.append(c + Vector2(-r + 2, -6))
			_shape(ci, cap, col)
			for k in 4:
				var x := -12.0 + k * 8.0
				_line(ci, PackedVector2Array([c + Vector2(x, -6), c + Vector2(x * 0.8, -r + 2)]), col.lightened(0.3), 1.5)


func _paint_glasses(ci: CanvasItem) -> void:
	var eyes := _eye_centers()
	var style := _i("glasses")
	if _override(ci, "glasses", AppearanceOptions.GLASSES[style], Color.WHITE, (eyes[0] + eyes[1]) * 0.5):
		return
	var lens := Color(0.08, 0.08, 0.12, 0.92)
	match style:
		1:  # aviators
			for e in eyes:
				_shape(ci, PackedVector2Array([e + Vector2(-7, -5), e + Vector2(7, -5), e + Vector2(6, 2), e + Vector2(0, 6), e + Vector2(-6, 2)]), lens, 1.6)
				_line(ci, PackedVector2Array([e + Vector2(-7, -5), e + Vector2(7, -5)]), GOLD, 1.8)
				ci.draw_line(e + Vector2(-3, -2), e + Vector2(0, -3), Color(1, 1, 1, 0.6), 1.5)
			ci.draw_line(eyes[0] + Vector2(7, -4), eyes[1] + Vector2(-7, -4), GOLD, 1.8)
		2:  # round shades
			for e in eyes:
				_circle(ci, e, 7.0, lens, 1.8)
				ci.draw_arc(e, 4.5, PI + 0.6, PI + 1.6, 6, Color(1, 1, 1, 0.55), 1.5)
			ci.draw_line(eyes[0] + Vector2(7, 0), eyes[1] + Vector2(-7, 0), OUTLINE, 2.0)
		3:  # star shades
			for e in eyes:
				_shape(ci, _star(e, 9.0, 4.5), Color("#ff4fa3"), 1.6)
				ci.draw_colored_polygon(_ellipse(e, 3.8, 3.8, 10), lens)
			ci.draw_line(eyes[0] + Vector2(6, 0), eyes[1] + Vector2(-6, 0), Color("#ff4fa3"), 2.4)
		4:  # wraparounds
			var a := eyes[0] + Vector2(-9, -5)
			var b := eyes[1] + Vector2(9, -5)
			_shape(ci, PackedVector2Array([a, b, b + Vector2(1, 6), eyes[1] + Vector2(2, 6), (eyes[0] + eyes[1]) * 0.5 + Vector2(0, 3), eyes[0] + Vector2(-2, 6), a + Vector2(-1, 6)]), Color("#ff6d00"), 1.8)
			ci.draw_line(a + Vector2(4, 2), b + Vector2(-4, 2), Color(1, 1, 1, 0.5), 1.6)
		5:  # nerd specs (eyes still visible)
			for e in eyes:
				ci.draw_rect(Rect2(e - Vector2(7, 6), Vector2(14, 12)), Color(0.8, 0.95, 1.0, 0.18))
				ci.draw_rect(Rect2(e - Vector2(7, 6), Vector2(14, 12)), OUTLINE, false, 2.6)
			ci.draw_line(eyes[0] + Vector2(7, -1), eyes[1] + Vector2(-7, -1), OUTLINE, 2.6)


func _paint_hat(ci: CanvasItem) -> void:
	var c := SKULL + Vector2(0, -_hat_lift())
	var r := HEAD_R + 2.0
	var col := _col("hat_color", Color("#e53935"))
	var style := _i("hat")
	if _uniform():
		style = 99
		col = Color("#1c2b4a")
	if style == 0:
		return
	if _override(ci, "hats", "police" if style == 99 else AppearanceOptions.HATS[style], col, c + Vector2(0, -12)):
		return
	var dome := _ellipse(c + Vector2(0, -6), r, r - 3.0, 18, PI, TAU)
	match style:
		1:  # cap
			_shape(ci, _capsule(c + Vector2(4, -8), c + Vector2(r + 12, -8), 3.0, 4), col.darkened(0.15))
			_shape(ci, dome, col)
			ci.draw_circle(c + Vector2(0, -r - 3), 2.0, col.darkened(0.3))
		2:  # backwards cap
			_shape(ci, _capsule(c + Vector2(-r - 8, -9), c + Vector2(-6, -8), 3.0, 4), col.darkened(0.15))
			_shape(ci, dome, col)
			ci.draw_rect(Rect2(c + Vector2(-4, -12), Vector2(8, 4)), col.darkened(0.3))
		3:  # bucket hat
			_shape(ci, PackedVector2Array([c + Vector2(-r - 7, -2), c + Vector2(r + 7, -2), c + Vector2(r - 1, -10), c + Vector2(-r + 1, -10)]), col.darkened(0.12))
			_shape(ci, _ellipse(c + Vector2(0, -10), r - 3.0, r - 6.0, 16, PI, TAU), col)
		4:  # straw hat
			var straw := Color("#e8c170")
			_shape(ci, _ellipse(c + Vector2(0, -8), r + 16.0, 6.0, 22), straw)
			_shape(ci, _ellipse(c + Vector2(0, -10), r - 6.0, r - 8.0, 16, PI, TAU), straw)
			ci.draw_rect(Rect2(c + Vector2(-r + 6, -14), Vector2((r - 6) * 2, 4)), col)
		5:  # sombrero
			var straw2 := Color("#f0c674")
			_shape(ci, _ellipse(c + Vector2(0, -8), r + 30.0, 8.0, 26), straw2)
			_shape(ci, PackedVector2Array([c + Vector2(-14, -10), c + Vector2(14, -10), c + Vector2(8, -42), c + Vector2(-8, -42)]), straw2)
			var zig := PackedVector2Array()
			for k in 9:
				zig.append(c + Vector2(lerpf(-13, 13, k / 8.0), -16.0 - (4.0 if k % 2 == 0 else 0.0)))
			_line(ci, zig, col, 2.6)
		6:  # bandana
			_shape(ci, _ellipse(c + Vector2(0, -4), r, r - 2.0, 18, PI, TAU), col)
			_shape(ci, PackedVector2Array([c + Vector2(-r + 1, -4), c + Vector2(-r - 9, 4), c + Vector2(-r - 4, 8), c + Vector2(-r + 3, 0)]), col.darkened(0.1), 1.6)
			for p: Vector2 in [Vector2(-8, -16), Vector2(6, -18), Vector2(14, -8), Vector2(-16, -8)]:
				ci.draw_circle(c + p, 1.4, Color.WHITE)
		7:  # visor
			_shape(ci, _capsule(c + Vector2(6, -6), c + Vector2(r + 12, -6), 3.0, 4), col)
			ci.draw_line(c + Vector2(-r, -8), c + Vector2(r, -8), col.darkened(0.2), 4.0)
		99:  # police cap
			_shape(ci, _capsule(c + Vector2(2, -6), c + Vector2(r + 8, -6), 3.0, 4), Color("#111111"))
			_shape(ci, PackedVector2Array([c + Vector2(-r + 1, -6), c + Vector2(r - 1, -6), c + Vector2(r + 3, -20), c + Vector2(-r - 3, -20)]), col)
			ci.draw_rect(Rect2(c + Vector2(-r + 1, -10), Vector2((r - 1) * 2, 4)), Color("#f5f5f5"))
			_shape(ci, _star(c + Vector2(2, -15), 4.0, 1.8), GOLD, 1.2)
