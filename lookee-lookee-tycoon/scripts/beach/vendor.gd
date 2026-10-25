class_name Vendor
extends Walker
## The player's Lookee Lookee vendor. Wears whatever the Character Creator says (the avatar
## follows CharacterData live). Walks where you tap, sets up and packs the stall, shouts
## "Hello chicken nugget!", pitches to tourists from the bag, and legs it from the police.

signal state_changed(state: int)
signal shouted

enum State { IDLE, WALKING, SETUP, PACKING, PITCHING, RUNNING, CAUGHT }

const WALK_SPEED := 120.0
const RUN_SPEED := 185.0
const SETUP_TIME := 0.6

var state: State = State.IDLE
var stall: Stall
var shout_cooldown := 0.0
var _timer := 0.0
var _pitch_target: Node2D


func _ready() -> void:
	setup_avatar({}, false, true)
	speed = WALK_SPEED


func set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)


func is_at_stall() -> bool:
	return stall != null and stall.is_open() and state in [State.IDLE, State.PACKING] \
		and position.distance_to(stall.vendor_spot()) < 60.0


func is_busy() -> bool:
	return state in [State.SETUP, State.PACKING, State.CAUGHT]


func _process(delta: float) -> void:
	shout_cooldown = maxf(shout_cooldown - delta, 0.0)
	var mult := Upgrades.move_speed_mult()
	match state:
		State.WALKING:
			if step_move(delta, WALK_SPEED * mult):
				set_state(State.IDLE)
		State.RUNNING:
			step_move(delta, RUN_SPEED * mult)
		State.PITCHING:
			if _pitch_target == null or not is_instance_valid(_pitch_target) or not _pitch_target.visible:
				set_state(State.IDLE)
				stop()
			else:
				target = _pitch_target.position + Vector2(-50.0 if _pitch_target.position.x > position.x else 50.0, 4.0)
				moving = true
				if step_move(delta, WALK_SPEED * mult) or position.distance_to(target) < 8.0:
					stop()
					face(_pitch_target.position)
					var t := _pitch_target
					_pitch_target = null
					set_state(State.IDLE)
					beach.vendor_pitch(t)
		State.SETUP:
			_timer -= delta
			if _timer <= 0.0:
				_finish_setup()
		State.PACKING:
			_timer -= delta
			var total := Upgrades.pack_time()
			stall.set_pack_progress(1.0 - _timer / maxf(total, 0.01))
			if _timer <= 0.0:
				stall.close()
				beach.fx.puff(stall.position + Vector2(0, -10), 10)
				AudioManager.play_sfx("pack")
				set_state(State.IDLE)
				say(Lines.pick(Lines.PACK), "normal", 1.6)
				GameManager.tutorial_event("pack")
		State.CAUGHT:
			pass


# --- Commands from the player ---------------------------------------------------------------

func command_walk(p: Vector2) -> void:
	if is_busy():
		return
	_pitch_target = null
	walk_to(beach.clamp_to_land(p), state == State.RUNNING)
	if state != State.RUNNING:
		set_state(State.WALKING)


func command_pitch(tourist: Node2D) -> void:
	if is_busy() or state == State.RUNNING:
		return
	if Economy.total_stock() <= 0:
		say(Lines.pick(Lines.NO_STOCK), "bad")
		return
	_pitch_target = tourist
	set_state(State.PITCHING)


func command_return_to_stall() -> void:
	if stall and stall.is_open() and not is_busy() and state != State.RUNNING:
		walk_to(stall.vendor_spot())
		set_state(State.WALKING)


## SET UP / PACK UP button.
func command_toggle_stall() -> void:
	if state in [State.SETUP, State.CAUGHT, State.RUNNING]:
		return
	if state == State.PACKING:
		return
	if stall.is_open():
		if position.distance_to(stall.vendor_spot()) > 70.0:
			# Too far away: run back first. Packing starts when you tap again.
			command_return_to_stall()
			say("Coming, coming! Very good very nice!", "normal", 1.4)
			return
		stop()
		stall.begin_packing()
		_timer = Upgrades.pack_time()
		set_state(State.PACKING)
		avatar.present(_timer)
	else:
		if not beach.can_set_up_at(position):
			say("Not here, chicken nugget! On the sand!", "bad")
			AudioManager.play_sfx("error")
			return
		if Economy.total_stock() <= 0:
			say(Lines.pick(Lines.NO_STOCK), "bad")
			AudioManager.play_sfx("error")
			return
		stop()
		_timer = SETUP_TIME
		set_state(State.SETUP)
		avatar.present(SETUP_TIME)


func _finish_setup() -> void:
	# The stall goes in front of the vendor; the vendor stands behind it.
	stall.open_at(position + Vector2(0, 30), Upgrades.stall_tier())
	AudioManager.play_sfx("setup")
	set_state(State.IDLE)
	say(Lines.pick(Lines.SETUP), "shout", 1.8)
	GameManager.tutorial_event("setup")


func command_shout() -> bool:
	if shout_cooldown > 0.0 or state == State.CAUGHT:
		return false
	shout_cooldown = Upgrades.shout_cooldown()
	avatar.shout(1.3)
	say(Lines.pick(Lines.SHOUT), "shout", 1.8)
	AudioManager.say("hello")
	AudioManager.play_sfx("shout", 0.1, -8.0)
	Economy.lifetime.shouts += 1
	var tier_noise := 0.25 * Upgrades.stall_tier() + 0.3 * Upgrades.level("megaphone")
	HeatSystem.add(1.0 + tier_noise, "shout")
	beach.broadcast_shout(position, Upgrades.shout_radius(), 1.0, self)
	shouted.emit()
	GameManager.tutorial_event("shout")
	return true


func start_running() -> void:
	_pitch_target = null
	set_state(State.RUNNING)
	running = true
	moving = false


func stop_running() -> void:
	running = false
	stop()
	set_state(State.IDLE)


func get_caught() -> void:
	stop()
	set_state(State.CAUGHT)
	avatar.set_pose(VendorAvatar.Pose.IDLE)


func release() -> void:
	set_state(State.IDLE)
