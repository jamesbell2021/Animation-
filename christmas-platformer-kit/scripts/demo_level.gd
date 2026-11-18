extends Node2D
## Demo level glue: parallax background, score, gift blocks, and the goal.
## The level itself is painted in the TileMapLayers; open them and paint!

const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

## How far each background layer moves compared with the camera (0 = fixed, 1 = with the world).
@export var parallax_factors := PackedFloat32Array([0.05, 0.2, 0.45])

var score := 0

@onready var player: ElfPlayer = $Player
@onready var camera: Camera2D = $Player/Camera
@onready var ground: TileMapLayer = $Ground
@onready var score_label: Label = $HUD/Score
@onready var message: Label = $HUD/Message
@onready var bg_layers: Array[Node] = $Background.get_children()


func _ready() -> void:
	var used := ground.get_used_rect()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = used.end.x * ground.tile_set.tile_size.x
	camera.limit_bottom = used.end.y * ground.tile_set.tile_size.y
	for p in get_tree().get_nodes_in_group("pickups"):
		p.collected.connect(_on_collected)
	player.block_hit.connect(_on_block_hit)
	player.reached_goal.connect(_on_goal)
	player.died.connect(_on_died)
	_update_score()


func _process(_delta: float) -> void:
	var cam_x := camera.get_screen_center_position().x
	for i in bg_layers.size():
		var spr := bg_layers[i] as Sprite2D
		spr.region_rect.position.x = cam_x * parallax_factors[i]


func _on_collected(_kind: StringName, value: int) -> void:
	score += value
	_update_score()


func _on_block_hit(cell: Vector2i) -> void:
	# A star pops out of the block.
	var star: Pickup = PICKUP_SCENE.instantiate()
	star.kind = "star"
	star.value = 5
	star.position = ground.map_to_local(cell) + Vector2(0, -64)
	star.collected.connect(_on_collected)
	$Pickups.add_child(star)
	star.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(star, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shake(4.0)


func _on_died() -> void:
	_shake(10.0)


func _on_goal() -> void:
	message.text = "Merry Christmas!  Score: %d" % score
	message.visible = true


func _update_score() -> void:
	score_label.text = "Score: %d" % score


func _shake(strength: float) -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, 0.03)
	t.tween_property(camera, "offset", Vector2.ZERO, 0.05)
