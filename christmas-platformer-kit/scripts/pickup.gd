class_name Pickup
extends Area2D
## A collectable. One scene serves every item: pick the animation in the Inspector.
## The bob/spin is baked into the sprite sheet, so no tween is needed while idle.

signal collected(kind: StringName, value: int)

@export_enum("star", "present", "candy_cane", "bauble", "cookie", "bell", "heart", "snowflake")
var kind: String = "star"
@export var value := 1

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.play(kind)
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count(kind)  # desync neighbours
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is ElfPlayer:
		return
	collected.emit(StringName(kind), value)
	set_deferred("monitoring", false)
	# Juice: pop up and play the sparkle burst, then free.
	sprite.play("sparkle")
	var t := create_tween().set_parallel()
	t.tween_property(sprite, "position:y", -24.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.3)
	sprite.animation_finished.connect(queue_free)
