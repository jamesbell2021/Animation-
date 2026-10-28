class_name Crew
extends Node3D
## One crew member, controlled by a player or by the AI (BotInput). Walks around the tank deck,
## boards stations with INTERACT, and patches breaches by holding ACTION next to them.

const SPEED := 4.5

var index := 0
var input: PlayerInput
var color := Color.WHITE
var tank: MegaTank
var station: MegaTank.Station = null
var deck_pos := Vector2.ZERO
var fixing := false
## LAN client: mirrors the host's snapshots instead of reading input.
var puppet := false
var _net_yaw := 0.0

var _body: Node3D
var _legs: Array[MeshInstance3D] = []
var _walk := 0.0
var _label: Label3D


func setup(player_index: int, player_input: PlayerInput, owner_tank: MegaTank) -> void:
	index = player_index
	tank = owner_tank
	color = G.PLAYER_COLORS[player_index]
	set_input(player_input)


func is_bot() -> bool:
	return input is BotInput


## Hands this crew member to a player or to the AI, mid-game if needed.
func set_input(new_input: PlayerInput) -> void:
	input = new_input
	if input is BotInput:
		(input as BotInput).crew = self
	if _label:
		_label.text = _label_text()


func _label_text() -> String:
	var tag := " AI" if is_bot() else ""
	if Net.is_client() and input and input.device == Net.my_device():
		tag = G.t(" YOU")
	return "P%d%s" % [index + 1, tag]


func net_state() -> Array:
	return [input.device, deck_pos, _body.rotation.y, station.id if station else "", fixing]


func apply_net(s: Array) -> void:
	deck_pos = s[1]
	_net_yaw = s[2]
	fixing = s[4]
	var id: String = s[3]
	var want: MegaTank.Station = tank.stations.get(id) if id != "" else null
	if want != station:
		if station and station.occupant == self:
			station.occupant = null
		station = want
		if station:
			station.occupant = self


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
	_label = label
	label.text = _label_text()
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
		return G.t("BAILED OUT")
	if station != null:
		if station.jammed:
			return G.t("%s [JAMMED]") % G.t(station.title)
		if station.id == "repair":
			if tank.shield_up:
				return G.t("REPAIR - SHIELD UP")
			if tank.combo >= 2:
				return G.t("REPAIR  COMBO x%d") % tank.combo
		return G.t(station.title)
	if fixing:
		return G.t("PATCHING BREACH")
	return G.t("ON DECK")


func _process(delta: float) -> void:
	if puppet:
		_puppet_update(delta)
		return
	fixing = false
	if tank.dead:
		return
	if input.interact_pressed and G.main.state != Main.State.GAMEOVER:
		if station:
			tank.leave(self)
		else:
			# Players may bump an AI crew member off the station they want.
			var st := tank.nearest_free_station(deck_pos, 1.1, not is_bot())
			if st:
				if st.occupant:
					tank.leave(st.occupant)
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


func _puppet_update(delta: float) -> void:
	var target := Vector3(deck_pos.x, MegaTank.DECK_Y, deck_pos.y)
	var moved := position.distance_to(target)
	position = position.lerp(target, minf(1.0, delta * 14.0))
	_body.rotation.y = lerp_angle(_body.rotation.y, _net_yaw, minf(1.0, delta * 14.0))
	if moved > 0.02 or fixing:
		_walk += delta * (25.0 if fixing else 13.0)
	_body.position.y = absf(sin(_walk)) * 0.1
	_legs[0].rotation.x = sin(_walk) * 0.6
	_legs[1].rotation.x = -sin(_walk) * 0.6
