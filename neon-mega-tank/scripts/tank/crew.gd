class_name Crew
extends Node3D
## One player. Walks around the tank deck, boards stations with INTERACT, and patches breaches
## by holding ACTION next to them.

const SPEED := 4.5

var index := 0
var input: PlayerInput
var color := Color.WHITE
var tank: MegaTank
var station: MegaTank.Station = null
var deck_pos := Vector2.ZERO
var fixing := false

var _body: Node3D
var _legs: Array[MeshInstance3D] = []
var _walk := 0.0


func setup(player_index: int, player_input: PlayerInput, owner_tank: MegaTank) -> void:
	index = player_index
	input = player_input
	tank = owner_tank
	color = G.PLAYER_COLORS[player_index]


func _ready() -> void:
	scale = Vector3.ONE * 1.35
	_body = Node3D.new()
	add_child(_body)
	G.neon_box(_body, Vector3(0.5, 0.5, 0.34), Vector3(0, 0.55, 0), color, 4.5, false, true)
	G.neon_box(_body, Vector3(0.36, 0.32, 0.36), Vector3(0, 0.98, 0), color, 4.5, false, true)
	G.neon_box(_body, Vector3(0.28, 0.08, 0.06), Vector3(0, 1.0, -0.19), Color.WHITE, 5.0, false, true)
	G.neon_box(_body, Vector3(0.3, 0.4, 0.14), Vector3(0, 0.6, 0.24), color.darkened(0.3), 2.0, false, true)
	for side in [-1.0, 1.0]:
		var leg := G.neon_box(_body, Vector3(0.16, 0.32, 0.16), Vector3(side * 0.13, 0.16, 0), color, 4.0, false, true)
		_legs.append(leg)
	G.neon_box(self, Vector3(0.9, 0.02, 0.9), Vector3(0, 0.02, 0), color, 2.0, false, true)
	var label := Label3D.new()
	label.text = "P%d" % (index + 1)
	label.font = G.ui_font
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.position = Vector3(0, 1.75, 0)
	add_child(label)


func status_text() -> String:
	if tank.dead:
		return "BAILED OUT"
	if station != null:
		return station.title + (" [JAMMED]" if station.jammed else "")
	if fixing:
		return "PATCHING BREACH"
	return "ON DECK"


func _process(delta: float) -> void:
	fixing = false
	if tank.dead:
		return
	if input.interact_pressed and G.main.state != Main.State.GAMEOVER:
		if station:
			tank.leave(self)
		else:
			var st := tank.nearest_free_station(deck_pos)
			if st:
				tank.occupy(st, self)
	var moving := false
	if station == null:
		var local := tank.global_basis.inverse() * G.main.stick_to_world(input.move)
		var mv := Vector2(local.x, local.z)
		if mv.length() > 0.15:
			moving = true
			deck_pos += mv.limit_length(1.0) * SPEED * delta
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-mv.x, -mv.y), minf(1.0, delta * 14.0))
		deck_pos = tank.clamp_deck(deck_pos)
		if input.action_held:
			fixing = tank.fix_breach_near(deck_pos, delta)
	else:
		deck_pos = station.pos
		var look := station.look - station.pos
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-look.x, -look.y), minf(1.0, delta * 14.0))
	position = Vector3(deck_pos.x, MegaTank.DECK_Y, deck_pos.y)
	if moving:
		_walk += delta * 13.0
	elif fixing:
		_walk += delta * 25.0
	else:
		_walk = lerpf(_walk, roundf(_walk / PI) * PI, minf(1.0, delta * 10.0))
	_body.position.y = absf(sin(_walk)) * 0.1
	_legs[0].rotation.x = sin(_walk) * 0.6
	_legs[1].rotation.x = -sin(_walk) * 0.6
