class_name Tourist
extends Walker
## A holidaymaker. Pooled: TouristPool activates and recycles them instead of creating and
## freeing nodes. Each has a type (Sunburnt Brits, Stag Party, Pensioners...), a mood and a
## budget. They pick a spot, sunbathe, swim or wander, and when "Hello chicken nugget!" gets
## their interest high enough they come and shop.

enum State { INACTIVE, ARRIVING, SUNBATHE, SWIM, WANDER, GO_STALL, BROWSE, GO_VENDOR, LISTEN, HAGGLE, RETURNING, LEAVING }

var state: State = State.INACTIVE
var type_id := "brits"
var mood := "happy"
var budget := 15.0
var interest := 0.0
var spot := Vector2.ZERO
var stay_time := 90.0
var stall: Stall
var slot := -1
var bought := 0
var towel: BeachProp
var is_child := false

var _timer := 0.0
var _chat_timer := 0.0
var _rng := RandomNumberGenerator.new()


func activate(b: Node, t_id: String, look: Dictionary, from: Vector2, to_spot: Vector2, child := false) -> void:
	beach = b
	type_id = t_id
	is_child = child
	_rng.randomize()
	mood = TouristTypes.roll_mood(type_id, _rng)
	if float(look.get("sunburn", 0.0)) > 0.6:
		mood = "sunburnt"
	var t := TouristTypes.get_type(type_id)
	var wealth := float(BeachDB.get_beach(GameManager.current_beach).wealth)
	budget = float(t.budget) * wealth * _rng.randf_range(0.7, 1.3) * RandomEvents.mult("budget")
	if child:
		budget *= 0.5
	speed = float(t.speed) * _rng.randf_range(0.85, 1.15)
	stay_time = _rng.randf_range(70.0, 150.0)
	interest = 0.0
	bought = 0
	stall = null
	slot = -1
	position = from
	spot = to_spot
	setup_avatar(look, true)
	avatar.hold_item("")
	avatar.set_pose(VendorAvatar.Pose.IDLE)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_chat_timer = _rng.randf_range(4.0, 20.0)
	walk_to(spot)
	state = State.ARRIVING
	if towel:
		towel.visible = false


func deactivate() -> void:
	_leave_stall()
	state = State.INACTIVE
	visible = false
	hide_bubble()
	process_mode = Node.PROCESS_MODE_DISABLED
	if towel:
		towel.visible = false


func is_active() -> bool:
	return state != State.INACTIVE


func mood_buy() -> float:
	return float(TouristTypes.MOODS[mood].buy)


func can_be_pitched() -> bool:
	return state in [State.ARRIVING, State.SUNBATHE, State.WANDER, State.RETURNING, State.GO_VENDOR]


func _process(delta: float) -> void:
	_timer -= delta
	stay_time -= delta
	_chat_timer -= delta
	if _chat_timer <= 0.0 and state in [State.SUNBATHE, State.WANDER]:
		_chat_timer = _rng.randf_range(15.0, 35.0)
		if _rng.randf() < 0.5 and beach.is_on_screen(position):
			say(Lines.pick(TouristTypes.get_type(type_id).lines, _rng), "normal", 2.0)
	if stay_time <= 0.0 and state in [State.SUNBATHE, State.WANDER, State.SWIM]:
		leave()
	match state:
		State.ARRIVING:
			if step_move(delta):
				_settle()
		State.SUNBATHE:
			if _timer <= 0.0:
				_choose_activity()
		State.SWIM:
			if moving:
				if step_move(delta):
					avatar.set_pose(VendorAvatar.Pose.SWIM)
					_timer = _rng.randf_range(8.0, 18.0)
			elif _timer <= 0.0:
				avatar.set_pose(VendorAvatar.Pose.IDLE)
				_return_to_spot()
		State.WANDER:
			if step_move(delta) and _timer <= 0.0:
				_return_to_spot()
			elif not moving and _timer > 0.0:
				pass
		State.GO_STALL:
			if stall == null or not stall.is_open():
				_give_up("?")
			elif step_move(delta):
				state = State.BROWSE
				face(stall.position)
				_timer = _rng.randf_range(1.3, 2.4) * Upgrades.browse_time_mult()
		State.BROWSE:
			if stall == null or not stall.is_open():
				_give_up("?")
			elif _timer <= 0.0:
				beach.resolve_purchase(self, stall)
		State.GO_VENDOR:
			var v: Node2D = beach.vendor
			target = v.position + Vector2(40.0 if position.x > v.position.x else -40.0, 6.0)
			moving = true
			if step_move(delta) or position.distance_to(target) < 10.0:
				stop()
				face(v.position)
				state = State.LISTEN
				_timer = 0.6
			elif _timer <= -8.0:
				_give_up("...")
		State.LISTEN:
			if _timer <= 0.0:
				state = State.HAGGLE  # placeholder while the beach decides
				beach.resolve_bag_purchase(self)
		State.HAGGLE:
			if _timer <= -8.0:
				finish_shopping(false)
		State.RETURNING:
			if step_move(delta):
				_settle()
		State.LEAVING:
			if step_move(delta):
				beach.tourists.recycle(self)


func _settle() -> void:
	state = State.SUNBATHE
	_timer = _rng.randf_range(6.0, 16.0)
	var t := TouristTypes.get_type(type_id)
	if not is_child and _rng.randf() < float(t.sunbathe):
		if towel == null:
			towel = BeachProp.make("towel", spot, _bright(), Color.WHITE)
			beach.ground.add_child(towel)
		towel.position = spot + Vector2(0, -4)
		towel.color = _bright()
		towel.queue_redraw()
		towel.visible = true
		avatar.set_pose(VendorAvatar.Pose.LIE)
		avatar.hold_item("")
	else:
		avatar.set_pose(VendorAvatar.Pose.IDLE)


func _choose_activity() -> void:
	var t := TouristTypes.get_type(type_id)
	var r := _rng.randf()
	if r < float(t.swim) and not RandomEvents.is_active("rain"):
		state = State.SWIM
		avatar.set_pose(VendorAvatar.Pose.IDLE)
		walk_to(beach.random_sea_point(position.x))
	elif r < float(t.swim) + 0.3:
		state = State.WANDER
		avatar.set_pose(VendorAvatar.Pose.IDLE)
		walk_to(beach.random_sand_point(position.x, 300.0))
		_timer = _rng.randf_range(3.0, 7.0)
	else:
		_timer = _rng.randf_range(6.0, 14.0)


func _return_to_spot() -> void:
	state = State.RETURNING
	avatar.set_pose(VendorAvatar.Pose.IDLE)
	walk_to(spot)


func leave() -> void:
	_leave_stall()
	state = State.LEAVING
	avatar.set_pose(VendorAvatar.Pose.IDLE)
	if towel:
		towel.visible = false
	walk_to(beach.exit_point(position))


# --- Reacting to vendors --------------------------------------------------------------------

## Someone shouted "Hello chicken nugget!". strength 1.0 = the player.
func hear_shout(from: Vector2, radius: float, strength: float, _source: Node) -> void:
	if not state in [State.SUNBATHE, State.WANDER, State.ARRIVING, State.RETURNING, State.SWIM]:
		return
	var d := position.distance_to(from)
	if d > radius:
		return
	var t := TouristTypes.get_type(type_id)
	var m: Dictionary = TouristTypes.MOODS[mood]
	var falloff := 1.0 - d / radius * 0.5
	var gain := strength * float(t.ears) * float(m.ears) * falloff * _rng.randf_range(0.6, 1.15) * RandomEvents.mult("ears")
	if state == State.SWIM:
		gain *= 0.4
	interest += gain
	# Grumpy people near a loud vendor might complain to the police.
	if _rng.randf() < float(t.complain) * float(m.complain) * falloff:
		say(Lines.pick(Lines.TOURIST_COMPLAIN, _rng), "bad", 2.0)
		HeatSystem.add(5.0, "complaint")
		interest = 0.0
		return
	if interest >= 1.0:
		interest = 0.0
		go_shopping(from)
	elif gain > 0.3 and beach.is_on_screen(position):
		say("?", "think", 0.9)


## Walk past an open stall: sometimes curiosity wins.
func notice_stall(s: Stall) -> void:
	if state in [State.WANDER, State.ARRIVING, State.RETURNING] and bought < 2 and _rng.randf() < 0.5:
		_go_to_stall(s)


func go_shopping(near: Vector2) -> void:
	if bought >= 3:
		return
	var s: Stall = beach.best_stall_for(self, near)
	if s:
		_go_to_stall(s)
	elif beach.vendor_can_sell_from_bag(position):
		_lie_up()
		state = State.GO_VENDOR
		_timer = 0.0
		say("Ooh, what you got?", "normal", 1.4)
	else:
		say("?", "think", 1.0)


func _go_to_stall(s: Stall) -> void:
	var i := s.request_slot(self)
	if i < 0:
		return
	_lie_up()
	stall = s
	slot = i
	state = State.GO_STALL
	walk_to(s.slot_position(i))
	if towel:
		towel.visible = true


func _lie_up() -> void:
	if avatar.pose == VendorAvatar.Pose.LIE or avatar.pose == VendorAvatar.Pose.SWIM:
		avatar.set_pose(VendorAvatar.Pose.IDLE)


## Called by the stall when it closes in our face.
func stall_closed() -> void:
	if state in [State.GO_STALL, State.BROWSE, State.HAGGLE]:
		stall = null
		_give_up("Huh?")


## The vendor walked over and started pitching.
func listen_pitch() -> void:
	_lie_up()
	stop()
	state = State.LISTEN
	_timer = 0.9


func start_haggle() -> void:
	state = State.HAGGLE
	_timer = 0.0


func finish_shopping(did_buy: bool, item_id := "") -> void:
	_leave_stall()
	if did_buy:
		bought += 1
		avatar.hold_item(item_id)
		if _rng.randf() < 0.4:
			mood = "happy"
	interest = 0.0
	if stay_time < 10.0:
		leave()
	else:
		_return_to_spot()


func _give_up(text: String) -> void:
	_leave_stall()
	if beach.is_on_screen(position):
		say(text, "think", 1.0)
	_return_to_spot()


func _leave_stall() -> void:
	if stall and is_instance_valid(stall):
		stall.release_slot(self)
	stall = null
	slot = -1


func _bright() -> Color:
	return AppearanceOptions.CLOTH_PALETTE[_rng.randi() % AppearanceOptions.CLOTH_PALETTE.size()]
