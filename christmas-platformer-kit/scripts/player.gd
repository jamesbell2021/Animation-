class_name ElfPlayer
extends CharacterBody2D
## Test player for the Christmas tile kit.
##
## Shows how tile *custom data* can drive gameplay: the player asks the TileMapLayer
## "what tile is under my feet / above my head?" and reacts to its data
## (slippery, bounce, climbable, crumble, hit_block, goal). Hazards use a second
## physics layer instead, so spikes hurt only where the spikes are drawn.

signal died
signal reached_goal
signal block_hit(cell: Vector2i)

@export var ground: TileMapLayer
@export var back_decor: TileMapLayer

@export_group("Run")
@export var run_speed := 360.0
@export var accel := 2800.0
@export var friction := 3200.0
@export var ice_accel := 650.0   ## on slippery tiles you take longer to speed up...
@export var ice_friction := 220.0  ## ...and much longer to stop
@export var air_accel := 1800.0

@export_group("Jump")
@export var jump_velocity := -820.0
@export var gravity := 2200.0
@export var fall_gravity_mult := 1.35  ## heavier on the way down: snappier arcs
@export var jump_cut := 0.45           ## let go early for a short hop
@export var max_fall := 1300.0
@export var coyote_time := 0.10
@export var jump_buffer := 0.12

@export_group("Climb")
@export var climb_speed := 230.0

const PLATFORMS_SOURCE := 4
const USED_BLOCK := Vector2i(7, 2)
const CRUMBLE_DELAY := 0.45
const CRUMBLE_RESPAWN := 3.0
const FEET := 29.0  ## distance from origin to the bottom of the collision box

var _coyote := 0.0
var _buffer := 0.0
var _climbing := false
var _dead := false
var _won := false
var _was_on_floor := true
var _spawn := Vector2.ZERO
var _crumbling := {}  ## Vector2i -> seconds stood on it

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	_spawn = global_position
	_ensure_input_actions()
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)


func _physics_process(delta: float) -> void:
	if _dead or _won:
		return
	var move_x := Input.get_axis("move_left", "move_right")
	var move_y := Input.get_axis("move_up", "move_down")

	var feet_data := _data_at(ground, global_position + Vector2(0, FEET + 4))
	var body_data := _data_at(ground, global_position)
	var on_ladder := _flag(body_data, "climbable") or _flag(_data_at(ground, global_position + Vector2(0, FEET - 2)), "climbable")

	# --- Ladders: grab with up/down, let go by jumping or walking off.
	if on_ladder and absf(move_y) > 0.1:
		_climbing = true
	if not on_ladder:
		_climbing = false

	if _climbing:
		velocity = Vector2(move_x * climb_speed * 0.6, move_y * climb_speed)
		_play("climb", velocity.length() > 1.0)  # freeze on the rungs when still
		if Input.is_action_just_pressed("jump"):
			_climbing = false
			velocity.y = jump_velocity * 0.8
		move_and_slide()
		return

	# --- Timers that make jumping feel fair.
	_coyote = coyote_time if is_on_floor() else maxf(_coyote - delta, 0.0)
	_buffer = jump_buffer if Input.is_action_just_pressed("jump") else maxf(_buffer - delta, 0.0)

	# --- Horizontal: slippery tiles swap in low accel/friction.
	var slippery := is_on_floor() and _flag(feet_data, "slippery")
	var target := move_x * run_speed
	var rate: float
	if not is_on_floor():
		rate = air_accel
	elif slippery:
		rate = ice_accel if absf(move_x) > 0.0 else ice_friction
	else:
		rate = accel if absf(move_x) > 0.0 else friction
	velocity.x = move_toward(velocity.x, target, rate * delta)

	# --- Vertical.
	var g := gravity * (fall_gravity_mult if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall)
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		_stretch(Vector2(0.8, 1.2))
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	var rising := velocity.y < 0.0
	move_and_slide()

	# --- Tile reactions after moving.
	if is_on_floor():
		feet_data = _data_at(ground, global_position + Vector2(0, FEET + 4))
		var bounce := _number(feet_data, "bounce")
		if bounce > 0.0:
			velocity.y = jump_velocity * bounce
			_stretch(Vector2(0.7, 1.3))
		_tick_crumble(delta)
		if not _was_on_floor:
			_stretch(Vector2(1.25, 0.8))  # landing squash
	if rising and is_on_ceiling():
		_try_hit_block()
	if _flag(_data_at(back_decor, global_position), "goal"):
		_won = true
		_play("idle")
		reached_goal.emit()
	_was_on_floor = is_on_floor()

	# --- Animation.
	if absf(velocity.x) > 5.0:
		sprite.flip_h = velocity.x < 0.0
	if not is_on_floor():
		_play("jump" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > 20.0:
		_play("run")
	else:
		_play("idle")


# ------------------------------------------------------------------ tile helpers
func _data_at(layer: TileMapLayer, world_pos: Vector2) -> TileData:
	if layer == null:
		return null
	return layer.get_cell_tile_data(layer.local_to_map(layer.to_local(world_pos)))


func _flag(data: TileData, layer_name: String) -> bool:
	return data != null and data.get_custom_data(layer_name) == true


func _number(data: TileData, layer_name: String) -> float:
	return 0.0 if data == null else float(data.get_custom_data(layer_name))


func _tick_crumble(delta: float) -> void:
	var cell := ground.local_to_map(ground.to_local(global_position + Vector2(0, FEET + 4)))
	if not _flag(ground.get_cell_tile_data(cell), "crumble"):
		return
	_crumbling[cell] = _crumbling.get(cell, 0.0) + delta
	if _crumbling[cell] < CRUMBLE_DELAY:
		return
	_crumbling.erase(cell)
	var source := ground.get_cell_source_id(cell)
	var coords := ground.get_cell_atlas_coords(cell)
	ground.erase_cell(cell)
	# Put it back later so the route never becomes impossible.
	get_tree().create_timer(CRUMBLE_RESPAWN).timeout.connect(func(): ground.set_cell(cell, source, coords))


func _try_hit_block() -> void:
	var cell := ground.local_to_map(ground.to_local(global_position + Vector2(0, -FEET - 6)))
	if _flag(ground.get_cell_tile_data(cell), "hit_block"):
		ground.set_cell(cell, PLATFORMS_SOURCE, USED_BLOCK)
		block_hit.emit(cell)


# ------------------------------------------------------------------ hurt & respawn
func _on_hurtbox_body_entered(_body: Node2D) -> void:
	# Only the hazard physics layer (layer 2) is in the hurtbox's mask.
	if _dead or _won:
		return
	_dead = true
	died.emit()
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 0.0), 0.35)
	t.tween_callback(_respawn)


func _respawn() -> void:
	global_position = _spawn
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	_dead = false


func set_checkpoint(pos: Vector2) -> void:
	_spawn = pos


# ------------------------------------------------------------------ feel
func _play(anim: StringName, playing := true) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
	if not playing:
		sprite.pause()
	elif not sprite.is_playing():
		sprite.play()


func _stretch(amount: Vector2) -> void:
	sprite.scale = amount
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ensure_input_actions() -> void:
	# Added in code so the kit works without editing Project Settings.
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE, KEY_Z, KEY_K],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var pad := {"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
		"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN, "jump": JOY_BUTTON_A}
	for action in pad:
		if not InputMap.action_get_events(action).filter(func(e): return e is InputEventJoypadButton).is_empty():
			continue
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)
