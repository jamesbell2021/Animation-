class_name EscapeHelm
extends Node3D
## The Mary Ann's wheel, on the after face of her wheelhouse (the Escape, docs/ESCAPE.md),
## and Dod Wiseman, her skipper, who stays with his boat.
##
## Whoever works the wheel steers her across the channel: a person walks up and presses
## Use, steers with their own move keys (left and right, or up and down the screen), and
## presses Use again to let go. A helper keeper can take it too (KeeperAI's "helm"
## role), and gives it up to a person who wants it, as with the lamp. While nobody has it,
## Dod steers, not as well as a keeper who can see what is coming. The Escape asks
## `steer` each frame (-1 to port, up the screen; 1 to starboard, down it).

signal changed(who: Node)

## How long Dod and a helper take to see a thing coming and act on it, how far ahead they
## look (m), and how far off their aim is: the Escape's autopilot reads these.
const DOD := {"look": 15.0, "react": 1.0, "err": 1.0, "name": "Dod Wiseman"}
const HELPER := {"look": 21.0, "react": 0.6, "err": 0.6, "name": ""}
const LOOK := {"label": Color(1.0, 0.9, 0.5)}
const FACE_BOW := -PI * 0.5

## The keeper at the wheel (a Player), or null: Dod has it.
var helmsman: Player = null
## -1 to 1: how hard over she is being put this frame.
var steer := 0.0
## Set by the Escape: the autopilot's steer for Dod or a helper.
var autopilot: Callable
var dod: Node3D
var _dod_rig: CharacterRig
var _taken_frame := -1
var _wheel: Node3D
var _spin := 0.0

func _ready() -> void:
	add_to_group("interactable")
	position = EscapeMap.WHEEL
	_build_wheel()
	_build_dod()

func _build_wheel() -> void:
	_wheel = Node3D.new()
	add_child(_wheel)
	var wood := Look.wood(Color(0.5, 0.34, 0.2), 0.6)
	var brass := Look.flat_mat(Color(0.85, 0.66, 0.22), 0.4)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.42
	tm.rings = 16
	tm.ring_segments = 6
	rim.mesh = tm
	rim.material_override = wood
	rim.rotation.z = PI * 0.5
	_wheel.add_child(rim)
	for i in 4:
		var spoke := Geo.box(_wheel, Vector3(0.04, 1.05, 0.04), Color.WHITE, Vector3.ZERO)
		spoke.material_override = wood
		spoke.rotation.x = PI * 0.25 * float(i)
	var hub := Geo.cyl(_wheel, 0.07, 0.12, Color.WHITE, Vector3.ZERO)
	hub.rotation.z = PI * 0.5
	hub.material_override = brass
	# Its pedestal down to the deck.
	var post := Geo.box(self, Vector3(0.14, 1.0, 0.18), Color.WHITE, Vector3(0.06, -0.5, 0.0))
	post.material_override = wood

func _build_dod() -> void:
	dod = Node3D.new()
	dod.name = "Dod"
	add_child(dod)
	dod.top_level = true
	_dod_rig = CharacterRig.create(Players.MODELS[1])
	if _dod_rig != null:
		dod.add_child(_dod_rig)
		_dod_rig.scale = Vector3.ONE * Player.MODEL_SCALE
		Outfits.dress(_dod_rig, "wiseman")
	var label := Label3D.new()
	label.text = "Dod Wiseman"
	label.font_size = 30
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.9, 0.5, 0.85)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.7)
	label.position = Vector3(0.0, 2.0, 0.0)
	var f := Fonts.title()
	if f != null:
		label.font = f
	dod.add_child(label)
	_place_dod(true)

## Who is steering, for the HUD and the messages.
func who() -> String:
	if helmsman != null and is_instance_valid(helmsman):
		return helmsman.keeper_name()
	return "Dod Wiseman"

func held_by_person() -> bool:
	return helmsman != null and is_instance_valid(helmsman) and not helmsman.ai

# ---- a keeper at the wheel ----

func surface_distance(p: Vector3) -> float:
	return Geo.flat_dist(p, EscapeMap.HELM_STAND)

func interact_prompt() -> String:
	return "[E] Take the wheel"

func prompt_for(k: Node) -> String:
	if k == helmsman:
		return "Steering: %s · [E] let go of the wheel" % steer_keys(k)
	if held_by_person():
		return ""
	if helmsman != null:
		return "[E] Take the wheel from %s" % helmsman.keeper_name()
	return "[E] Take the wheel from Dod"

## The keys a keeper steers with, in words.
static func steer_keys(k: Node) -> String:
	var idx := int(k.get("idx"))
	var d: int = Players.devices[idx] if idx < Players.devices.size() else Players.KEYBOARD_MOUSE
	if d == Players.KEYBOARD_MOUSE:
		return "%s %s (or %s %s)" % [Settings.key_name("move_left"), Settings.key_name("move_right"), Settings.key_name("move_up"), Settings.key_name("move_down")]
	if d == Players.KEYBOARD_ARROWS:
		return "the arrow keys"
	return "the left stick"

func interact(k: Node) -> bool:
	if not (k is Player):
		return false
	take(k as Player)
	return true

## Take the wheel (from Dod, or from a helper, who stands aside for a person).
func take(k: Player) -> void:
	if k == helmsman or k.downed:
		return
	if helmsman != null and is_instance_valid(helmsman):
		if not helmsman.ai and k.ai:
			return
		var was := helmsman
		release(was)
		if not k.ai:
			Events.message.emit("%s hands you the wheel." % was.keeper_name())
	elif not k.ai:
		Events.message.emit("\"She's yours,\" says Dod, and stands off.")
	helmsman = k
	k.in_menu = true
	k.arsenal.cease()
	_taken_frame = Engine.get_physics_frames()
	if not k.ai:
		Events.message.emit("At the wheel: %s to steer, [E] to let go." % steer_keys(k))
	changed.emit(k)

## Let go of the wheel: Dod has her again.
func release(k: Player = null) -> void:
	if k == null:
		k = helmsman
	if k == null or k != helmsman:
		return
	if is_instance_valid(k):
		k.in_menu = false
	helmsman = null
	changed.emit(null)

func _physics_process(delta: float) -> void:
	var k := helmsman
	if k != null and (not is_instance_valid(k) or k.downed or k.hp <= 0 or k.is_staggering() or k.is_prone() or not Run.active):
		release(k)
		k = null
	var want := 0.0
	if k != null:
		k.velocity = Vector3.ZERO
		k.global_position = k.global_position.lerp(EscapeMap.HELM_STAND + Vector3(0.0, 0.02, 0.0), 1.0 - exp(-delta * 12.0))
		k.facing = FACE_BOW
		k.rotation.y = FACE_BOW
		if k.ai:
			want = float(autopilot.call(HELPER)) if autopilot.is_valid() else 0.0
		else:
			var idx := k.idx
			var v := Input.get_vector(Players.action(idx, "move_left"), Players.action(idx, "move_right"), Players.action(idx, "move_up"), Players.action(idx, "move_down"))
			want = clampf(v.x + v.y, -1.0, 1.0)
			if Engine.get_physics_frames() > _taken_frame + 1 and (Input.is_action_just_pressed(Players.action(idx, "interact")) or Input.is_action_just_pressed(Players.action(idx, "operate"))):
				release(k)
	else:
		want = float(autopilot.call(DOD)) if autopilot.is_valid() else 0.0
	steer = want
	_spin = lerpf(_spin, -steer * 1.6, 1.0 - exp(-delta * 4.0))
	_wheel.rotation.x = _spin
	_place_dod(false, delta)

# Dod at the wheel when nobody else is; stood off by the stern rail when someone is.
func _place_dod(snap: bool, delta: float = 0.0) -> void:
	if dod == null:
		return
	var steering := helmsman == null
	var at := EscapeMap.HELM_STAND if steering else Vector3(EscapeMap.WALK_STERN + 0.1, EscapeMap.DECK_Y, -1.15)
	dod.global_position = at if snap else dod.global_position.lerp(at, 1.0 - exp(-delta * 3.0))
	dod.rotation.y = FACE_BOW if steering else 0.6
	if _dod_rig == null:
		return
	var moving := 0.0 if snap else dod.global_position.distance_to(at) / maxf(delta, 0.001) * 0.2
	_dod_rig.locomote(clampf(moving, 0.0, 2.0))
	var w := 1.0 if steering else 0.0
	_dod_rig.layer("upper_arm.L", Vector3(-1.05 * w, 0.0, -0.15 * w))
	_dod_rig.layer("upper_arm.R", Vector3(-1.05 * w, 0.0, 0.15 * w))
	_dod_rig.layer("forearm.L", Vector3(-0.5 * w, 0.0, 0.0))
	_dod_rig.layer("forearm.R", Vector3(-0.5 * w, 0.0, 0.0))
