class_name BattleView
extends Node3D
## The battle screen. It owns no rules: input becomes command dictionaries for Battle.exec(),
## and the events that come back are played as animation, one after another, before the
## player may act again. Previews (paths, TU ghosts, hit chances) ask the same Battle
## functions the resolution uses, so what the HUD promises is what happens.

signal quit_to_title
signal restart_requested

const STEP_TIME := 0.16
const ENEMY_STEP_TIME := 0.12
const MODE_KEYS := {"snap": "1", "aimed": "2", "burst": "3"}
const SHOT_SOUND := {
	"steam_drill": "drill", "dart_rifle": "dart", "gatling": "gatling",
	"brass_carbine": "shot", "mandibles": "bite", "claws": "bite",
}

var battle: Battle
var board: BoardView
var fx: Fx
var rig: CameraRig
var hud: Hud
var views: Dictionary = {}   # unit id -> UnitView
var selected: Unit
var mode := "move"
var busy := false
var overlay := ""
var auto_seed := 0

var _hover := Vector2i(-1, -1)
var _reach: Dictionary = {}
var _cone: MeshInstance3D
var _tip := ""
var _dead_views: Dictionary = {}


func start(seed_value := 0) -> void:
	auto_seed = seed_value
	battle = Catalog.new_battle(Catalog.LEVELS[0], seed_value)
	_build_world()
	board = BoardView.new()
	add_child(board)
	board.build(battle)
	fx = Fx.new()
	add_child(fx)
	rig = CameraRig.new()
	add_child(rig)
	rig.bounds = AABB(Vector3.ZERO, Vector3((battle.grid.width - 1) * Kit.TILE, 0, (battle.grid.height - 1) * Kit.TILE))
	fx.shake_requested.connect(rig.shake)
	for u in battle.units:
		_add_view(u)
	_apply_spotted(battle.spotted.keys())
	_build_cone()
	hud = Hud.new()
	add_child(hud)
	hud.build_cards(battle.squad())
	hud.action_pressed.connect(_on_action)
	hud.unit_picked.connect(func(id: int) -> void:
		var u := battle.unit(id)
		if u != null and u.alive and not busy:
			select(u))
	hud.end_turn_pressed.connect(end_turn)
	hud.overlay_toggled.connect(_toggle_overlay)
	hud.menu_chosen.connect(_on_menu)
	select(battle.squad()[0])
	# Open looking up the cavern from the lift, toward where the squad is going.
	rig.focus(Kit.world(selected.tile) + Vector3(2.0, 0.0, -6.0), true)
	Audio.ambience(true)
	hud.log_line("[color=#C59B27]The lift settles on the cavern floor.[/color] Somewhere ahead, the survey party's journal.")
	hud.banner("Subterranean: 1888", "Recover the survey journal, then return to the lift.", Kit.BRASS, 1.6)


func _exit_tree() -> void:
	Audio.ambience(false)


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.008, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.52, 0.46)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.04)
	env.fog_density = 0.006
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(0.8, 0.78, 0.72)
	env.volumetric_fog_emission = Color(0, 0, 0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.22
	sun.light_color = Color(0.62, 0.7, 0.9)
	sun.rotation_degrees = Vector3(-64, 35, 0)
	sun.light_volumetric_fog_energy = 0.0
	add_child(sun)


func _add_view(u: Unit) -> UnitView:
	var v := UnitView.create(u)
	add_child(v)
	views[u.id] = v
	if u.crouched:
		v.set_crouched(true, false)
	return v


func _build_cone() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 12.0 * Kit.TILE
	var half := deg_to_rad(45.0)
	var steps := 24
	for k in steps:
		var a0 := -half + 2.0 * half * k / steps
		var a1 := -half + 2.0 * half * (k + 1) / steps
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a1) * r, 0, -cos(a1) * r))
		st.add_vertex(Vector3(sin(a0) * r, 0, -cos(a0) * r))
	var hr := Rules.HEARING_RANGE * Kit.TILE
	for k in 32:
		var a0 := TAU * k / 32.0
		var a1 := TAU * (k + 1) / 32.0
		var inner := hr - 0.12
		st.add_vertex(Vector3(sin(a0) * inner, 0, cos(a0) * inner))
		st.add_vertex(Vector3(sin(a1) * hr, 0, cos(a1) * hr))
		st.add_vertex(Vector3(sin(a0) * hr, 0, cos(a0) * hr))
		st.add_vertex(Vector3(sin(a0) * inner, 0, cos(a0) * inner))
		st.add_vertex(Vector3(sin(a1) * inner, 0, cos(a1) * inner))
		st.add_vertex(Vector3(sin(a1) * hr, 0, cos(a1) * hr))
	_cone = MeshInstance3D.new()
	_cone.mesh = st.commit()
	var m := Kit.unshaded(Color(1.0, 0.85, 0.45, 0.07))
	m.no_depth_test = false
	_cone.material_override = m
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.position.y = 0.05


# --- selection and modes --------------------------------------------------------------------

func select(u: Unit) -> void:
	if selected != null and views.has(selected.id):
		(views[selected.id] as UnitView).set_selected(false)
	selected = u
	mode = "move"
	var v: UnitView = views[u.id]
	v.set_selected(true)
	if _cone.get_parent() != null:
		_cone.get_parent().remove_child(_cone)
	v.add_child(_cone)
	_cone.scale = Vector3.ONE * (u.def.vision_range / 12.0)
	rig.focus(Kit.world(u.tile))
	Audio.play("click", -10)
	_refresh()


func _next_soldier(step := 1) -> void:
	var team := battle.squad()
	if team.is_empty():
		return
	var i := team.find(selected)
	select(team[posmod(i + step, team.size())])


func _set_mode(m: String) -> void:
	mode = "move" if mode == m else m
	Audio.play("click", -12)
	_refresh()


func _refresh() -> void:
	if battle == null or hud == null:
		return
	if selected != null and selected.alive and battle.phase == Battle.Phase.PLAYER:
		_reach = battle.move_reach(selected)
	else:
		_reach = {}
	for id in views:
		if not _dead_views.has(id):
			(views[id] as UnitView).refresh_label()
	hud.refresh(battle, selected, _actions(), _hint(), _objective(), busy)
	_hover = Vector2i(-99, -99)   # force the hover previews to rebuild
	_refresh_info_overlay()


func _objective() -> String:
	if battle.journal_carrier == -1:
		return "Find the survey party's journal (to the north-east), then bring everyone back to the lift. Or wipe out the swarm."
	return "The %s has the journal. Every survivor onto the lift!" % battle.unit(battle.journal_carrier).def.display_name.trim_prefix("The ")


func _hint() -> String:
	if busy:
		return ""
	match mode:
		"move":
			return "Click to move (blue keeps Overwatch, amber spends it) · right-click to face · 1-3 to shoot · Tab: next"
		"snap", "aimed", "burst":
			return "%s: click a spotted creature to fire. Esc to cancel." % _mode_label(mode)
		"mortar":
			return "Mortar flare: click any tile within 12 (no line of sight needed). Esc to cancel."
		"pheromone":
			return "Pheromone grenade: a false trail the swarm will follow. Click a tile within 8."
		"dynamite":
			return "Dynamite: hurts everything within 1.5 tiles, friends too, and blows soft rock open."
		"drill":
			return "Steam-drill: click soft rock or a boulder beside the Engineer to bore through."
		"interact":
			return "Click a door, valve or the journal beside this specialist."
		"patch":
			return "Patch up: click a hurt specialist beside the Engineer (+15 health)."
	return ""


func _mode_label(m: String) -> String:
	if selected != null and selected.has_weapon() and selected.def.weapon.melee:
		return "Strike"
	return {"snap": "Snap shot", "aimed": "Aimed shot", "burst": "Burst"}.get(m, m)


func _actions() -> Array:
	var out: Array = []
	var u := selected
	if u == null or not u.alive:
		return out
	if u.has_weapon():
		var w := u.def.weapon
		for m in ["snap", "aimed", "burst"]:
			if not w.modes.has(m):
				continue
			var cost := battle.shot_cost(u, m)
			var ok := u.tu >= cost and not u.jammed and (w.clip == 0 or u.ammo > 0)
			out.append({"id": m, "key": MODE_KEYS[m], "label": _mode_label(m).replace(" shot", ""), "tu": cost,
				"enabled": ok, "active": mode == m,
				"tip": "%s: %d TU. %s" % [_mode_label(m), cost, {"snap": "Quick, -15% to hit.", "aimed": "+30% to hit.", "burst": "3-5 rounds, -10% each; pins whatever survives."}[m]]})
		if w.clip > 0:
			out.append({"id": "reload", "key": "R", "label": "Reload", "tu": Rules.TU_RELOAD,
				"enabled": u.tu >= Rules.TU_RELOAD and u.spare_clips > 0 and u.ammo < w.clip, "tip": "%d spare clips." % u.spare_clips})
	out.append({"id": "stance", "key": "C", "label": "Stand" if u.crouched else "Crouch", "tu": Rules.TU_STANCE,
		"enabled": u.tu >= Rules.TU_STANCE, "tip": "Crouched: +10% to hit, -10% to be hit, steps cost 2 more."})
	out.append({"id": "hand_flare", "key": "F", "label": "Flare (%d)" % u.hand_flares, "tu": Rules.TU_HAND_FLARE,
		"enabled": u.tu >= Rules.TU_HAND_FLARE and u.hand_flares > 0, "tip": "Light a flare here: radius 3, burns 3 turns."})
	if u.def.mortar_flares > 0:
		out.append({"id": "mortar", "key": "M", "label": "Mortar (%d)" % u.mortar_flares, "tu": Rules.TU_MORTAR,
			"enabled": u.tu >= Rules.TU_MORTAR and u.mortar_flares > 0, "active": mode == "mortar", "tip": "Lob a flare up to 12 tiles: radius 4, 3 turns."})
	if u.def.pheromone_grenades > 0:
		out.append({"id": "pheromone", "key": "G", "label": "Lure (%d)" % u.pheromones, "tu": Rules.TU_THROW,
			"enabled": u.tu >= Rules.TU_THROW and u.pheromones > 0, "active": mode == "pheromone", "tip": "Pheromone grenade: a false trail for the swarm."})
	if u.def.dynamite > 0:
		out.append({"id": "dynamite", "key": "T", "label": "Dynamite (%d)" % u.dynamite, "tu": Rules.TU_THROW,
			"enabled": u.tu >= Rules.TU_THROW and u.dynamite > 0, "active": mode == "dynamite", "tip": "35 damage at the centre, 21 around it. Opens soft rock."})
	if u.def.can_drill:
		out.append({"id": "drill", "key": "B", "label": "Drill rock", "tu": Rules.TU_DRILL,
			"enabled": u.tu >= Rules.TU_DRILL, "active": mode == "drill", "tip": "Bore through adjacent soft rock or a boulder."})
	out.append({"id": "interact", "key": "X", "label": "Use", "tu": Rules.TU_DOOR,
		"enabled": u.tu >= Rules.TU_DOOR, "active": mode == "interact", "tip": "Doors 4 TU, valves 8 TU, the journal 8 TU."})
	if u.def.repair_kit > 0:
		out.append({"id": "patch", "key": "H", "label": "Patch (%d)" % u.repair_kit, "tu": Rules.TU_PATCH_UP,
			"enabled": u.tu >= Rules.TU_PATCH_UP and u.repair_kit > 0, "active": mode == "patch", "tip": "Heal a specialist beside the Engineer by 15."})
	out.append({"id": "repair", "key": "V", "label": "Repair", "tu": Rules.TU_FIELD_REPAIR,
		"enabled": u.tu >= Rules.TU_FIELD_REPAIR and (u.pressure < Rules.PRESSURE_MAX or u.jammed), "tip": "Field Repair: boiler back to 100, clears a jam."})
	out.append({"id": "lamp", "key": "L", "label": "Shutter" if u.lamp_on else "Unshutter", "tu": 0,
		"enabled": true, "tip": "A lit lamp lights 2 tiles round you, and shows the swarm where you are."})
	return out


func _on_action(id: String) -> void:
	if busy or selected == null:
		return
	match id:
		"snap", "aimed", "burst", "mortar", "pheromone", "dynamite", "drill", "interact", "patch":
			_set_mode(id)
		"reload", "stance", "hand_flare", "repair", "lamp":
			_send({"t": id, "u": selected.id})


func end_turn() -> void:
	if busy or battle.phase != Battle.Phase.PLAYER or battle.outcome != "":
		return
	mode = "move"
	_send({"t": "end_turn"})


func _toggle_overlay(id: String) -> void:
	overlay = "" if overlay == id else id
	hud.set_overlay_pressed("light", overlay == "light")
	hud.set_overlay_pressed("swarm", overlay == "swarm")
	_refresh_info_overlay()


func _refresh_info_overlay() -> void:
	match overlay:
		"light":
			board.set_info_overlay(board.light_overlay())
		"swarm":
			board.set_info_overlay(board.pheromone_overlay())
		_:
			board.set_info_overlay({})


func _on_menu(id: String) -> void:
	match id:
		"open":
			hud.show_pause()
		"resume":
			hud.close_modal()
		"help":
			hud.show_help()
		"restart":
			hud.close_modal()
			restart_requested.emit()
		"title":
			hud.close_modal()
			quit_to_title.emit()
		"quit":
			get_tree().quit()


# --- input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if battle == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event as InputEventKey)
		return
	if hud.has_modal() or busy:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var c := _mouse_tile(mb.position)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_click(c)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_face_toward(c)


func _on_key(k: InputEventKey) -> void:
	if k.keycode == KEY_ESCAPE:
		if hud.has_modal():
			hud.close_modal()
		elif mode != "move":
			_set_mode("move")
		elif battle.outcome == "":
			hud.show_pause()
		return
	if hud.has_modal() or busy:
		return
	match k.keycode:
		KEY_1:
			_on_action("snap")
		KEY_2:
			_on_action("aimed")
		KEY_3:
			_on_action("burst")
		KEY_R:
			_on_action("reload")
		KEY_C:
			_on_action("stance")
		KEY_F:
			_on_action("hand_flare")
		KEY_M:
			if selected != null and selected.def.mortar_flares > 0:
				_on_action("mortar")
		KEY_G:
			if selected != null and selected.def.pheromone_grenades > 0:
				_on_action("pheromone")
		KEY_T:
			if selected != null and selected.def.dynamite > 0:
				_on_action("dynamite")
		KEY_B:
			if selected != null and selected.def.can_drill:
				_on_action("drill")
		KEY_X:
			_on_action("interact")
		KEY_H:
			if selected != null and selected.def.repair_kit > 0:
				_on_action("patch")
		KEY_V:
			_on_action("repair")
		KEY_L:
			_on_action("lamp")
		KEY_TAB:
			_next_soldier(-1 if k.shift_pressed else 1)
		KEY_ENTER, KEY_KP_ENTER:
			end_turn()
		KEY_O:
			_toggle_overlay("light")
		KEY_P:
			_toggle_overlay("swarm")
		KEY_SPACE:
			if selected != null:
				rig.focus(Kit.world(selected.tile))


func _mouse_tile(screen: Vector2) -> Vector2i:
	var p = rig.ground_point(screen)
	if p == null:
		return Vector2i(-1, -1)
	return Kit.tile_of(p)


func _click(c: Vector2i) -> void:
	if not battle.grid.in_bounds(c) or battle.phase != Battle.Phase.PLAYER:
		return
	var there := battle.unit_at(c)
	if there != null and there.team == Unit.SQUAD and there != selected and mode != "patch":
		select(there)
		return
	if selected == null or not selected.alive:
		return
	match mode:
		"move":
			if there != null and there.team == Unit.SWARM and battle.spotted.has(there.id):
				hud.toast("Choose a shot first: 1, 2 or 3.")
				return
			if not battle.is_explored(c):
				hud.toast("You can't see there.", true)
				Audio.play("deny")
				return
			_send({"t": "move", "u": selected.id, "to": c})
		"snap", "aimed", "burst":
			if there == null or there.team != Unit.SWARM or not battle.spotted.has(there.id):
				hud.toast("Click a spotted creature.", true)
				return
			_send({"t": "shoot", "u": selected.id, "target": there.id, "mode": mode})
		"mortar":
			mode = "move"
			_send({"t": "mortar", "u": selected.id, "to": c})
		"pheromone", "dynamite":
			var item := mode
			mode = "move"
			_send({"t": "throw", "u": selected.id, "item": item, "to": c})
		"drill":
			mode = "move"
			_send({"t": "drill", "u": selected.id, "to": c})
		"interact":
			var t := battle.grid.get_t(c)
			var cmd := {}
			if t == TacGrid.T.DOOR:
				cmd = {"t": "door", "u": selected.id, "to": c}
			elif t == TacGrid.T.VALVE:
				cmd = {"t": "valve", "u": selected.id, "to": c}
			elif c == battle.journal_tile:
				cmd = {"t": "journal", "u": selected.id}
			if cmd.is_empty():
				hud.toast("Nothing to use there.", true)
				return
			mode = "move"
			_send(cmd)
		"patch":
			if there == null or there.team != Unit.SQUAD:
				hud.toast("Click a specialist beside the Engineer.", true)
				return
			mode = "move"
			_send({"t": "patch", "u": selected.id, "target": there.id})


func _face_toward(c: Vector2i) -> void:
	if selected == null or not selected.alive or not battle.grid.in_bounds(c) or c == selected.tile:
		return
	var dir := Rules.dir_toward(selected.tile, c)
	if dir == selected.facing:
		return
	_send({"t": "face", "u": selected.id, "dir": dir})


# --- hover previews -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if battle == null or hud == null:
		return
	var mouse := get_viewport().get_mouse_position()
	if busy or hud.has_modal() or battle.phase != Battle.Phase.PLAYER:
		if _hover != Vector2i(-1, -1):
			_hover = Vector2i(-1, -1)
			board.hide_cursor()
			board.set_range_overlay({})
			hud.hide_tip()
		return
	var c := _mouse_tile(mouse)
	if c != _hover:
		_hover = c
		_update_hover()
	if _tip != "":
		hud.show_tip(_tip, mouse)


func _update_hover() -> void:
	var c := _hover
	var u := selected
	var tiles := {}
	var tip := ""
	var cost := 0
	var cursor := Color(1, 0.85, 0.4, 0.9)
	var g := battle.grid
	if u == null or not u.alive or not g.in_bounds(c):
		board.hide_cursor()
		board.set_range_overlay({})
		hud.hide_tip()
		_tip = ""
		return
	var there := battle.unit_at(c)
	var enemy: Unit = there if there != null and there.team == Unit.SWARM and battle.spotted.has(there.id) else null
	match mode:
		"move":
			var keep := Rules.overwatch_threshold(u.max_tu)
			var costs: PackedInt32Array = _reach.get("cost", PackedInt32Array())
			for i in costs.size():
				var k := costs[i]
				if k > 0 and k <= u.tu and battle.explored[i] == 1 and g.occupant[i] == -1:
					tiles[i] = Color(0.3, 0.75, 1.0, 0.2) if u.tu - k >= keep else Color(1.0, 0.68, 0.2, 0.2)
			if enemy != null:
				tip = _enemy_tip(u, enemy)
				cursor = Kit.DANGER
			elif there != null and there.team == Unit.SQUAD:
				tip = "[b]%s[/b]  %d / %d HP · %d TU" % [there.def.display_name, there.hp, there.def.max_hp, there.tu]
			elif battle.is_explored(c) and g.walkable(c):
				var k := g.reach_cost(_reach, c)
				if k <= u.tu:
					cost = k
					for step in g.path_to(_reach, c):
						var i := g.idx(step)
						tiles[i] = Color(0.5, 0.9, 1.0, 0.5) if u.tu - g.reach_cost(_reach, step) >= keep else Color(1.0, 0.75, 0.3, 0.5)
					var left := u.tu - k
					tip = "Move  [b]%d TU[/b]  ->  %d left\n%s\n%s" % [k, left,
						"[color=#7fd0ff]Overwatch kept[/color]" if left >= keep else "[color=#ffb347]No Overwatch this turn[/color]",
						_light_text(c)]
				else:
					cursor = Color(0.8, 0.3, 0.25, 0.8)
					tip = "Out of reach this turn\n" + _light_text(c)
			elif battle.is_explored(c):
				tip = _terrain_tip(c)
		"snap", "aimed", "burst":
			for id in battle.spotted:
				var e := battle.unit(id)
				var p := battle.shot_preview(u, e, mode)
				tiles[g.idx(e.tile)] = Color(1.0, 0.3, 0.2, 0.18 + 0.4 * float(p["chance"]) / 100.0) if p["ok"] else Color(0.5, 0.5, 0.5, 0.2)
			if enemy != null:
				var p := battle.shot_preview(u, enemy, mode)
				cost = int(p["tu"])
				cursor = Kit.DANGER
				tip = _shot_tip(u, enemy, mode, p)
			else:
				tip = "Pick a spotted creature."
		"mortar":
			for i in g.terrain.size():
				var t := g.cell(i)
				if battle.explored[i] == 1 and g.walkable(t) and Rules.dist(u.tile, t) <= Rules.MORTAR_RANGE:
					tiles[i] = Color(1.0, 0.5, 0.35, 0.1)
			if Rules.dist(u.tile, c) <= Rules.MORTAR_RANGE:
				cost = Rules.TU_MORTAR
				_radius_tiles(tiles, c, Rules.MORTAR_FLARE_RADIUS, Color(1.0, 0.65, 0.45, 0.35))
				tip = "Mortar flare  [b]%d TU[/b]\nLights 4 tiles round for 3 turns" % cost
			else:
				cursor = Color(0.8, 0.3, 0.25, 0.8)
				tip = "Beyond the mortar's 12 tiles"
		"pheromone", "dynamite":
			var ok := Rules.dist(u.tile, c) <= Rules.THROW_RANGE and (c == u.tile or g.has_los(u.tile, c))
			if ok:
				cost = Rules.TU_THROW
				if mode == "dynamite":
					_radius_tiles(tiles, c, Rules.DYNAMITE_RADIUS, Color(1.0, 0.35, 0.15, 0.4))
					tip = "Dynamite  [b]%d TU[/b]\n%d damage at the centre, %d around it. Friends too." % [cost, Rules.DYNAMITE_DAMAGE, roundi(Rules.DYNAMITE_DAMAGE * Rules.DYNAMITE_EDGE)]
				else:
					_radius_tiles(tiles, c, Rules.PHEROMONE_DENSITY_RADIUS, Color(0.4, 1.0, 0.25, 0.3))
					tip = "Pheromone lure  [b]%d TU[/b]\nCreatures within 15 tiles follow it next turn" % cost
			else:
				cursor = Color(0.8, 0.3, 0.25, 0.8)
				tip = "Too far, or no clear throw"
		"drill":
			for d in Rules.DIRS:
				var t := u.tile + d
				var tt := g.get_t(t)
				if tt == TacGrid.T.SOFT_ROCK or tt == TacGrid.T.BOULDER:
					tiles[g.idx(t)] = Color(1.0, 0.6, 0.2, 0.45)
			if tiles.has(g.idx(c)):
				cost = Rules.TU_DRILL
				tip = "Bore through  [b]%d TU[/b]" % cost
		"interact":
			for d in Rules.DIRS + [Vector2i.ZERO]:
				var t: Vector2i = u.tile + d
				if g.get_t(t) == TacGrid.T.DOOR or g.get_t(t) == TacGrid.T.VALVE or t == battle.journal_tile:
					tiles[g.idx(t)] = Color(1.0, 0.85, 0.4, 0.45)
			if tiles.has(g.idx(c)):
				if g.get_t(c) == TacGrid.T.DOOR:
					cost = Rules.TU_DOOR
					tip = "%s the door  [b]%d TU[/b]" % ["Close" if g.door_open[g.idx(c)] == 1 else "Open", cost]
				elif g.get_t(c) == TacGrid.T.VALVE:
					cost = Rules.TU_VALVE
					tip = "Turn the valve  [b]%d TU[/b]\n%s" % [cost, "Shuts off the steam" if g.steam.count(1) > 0 else "Lets the steam run again"]
				else:
					cost = Rules.TU_JOURNAL
					tip = "Take the journal  [b]%d TU[/b]" % cost
		"patch":
			for s in battle.squad():
				if Rules.chebyshev(u.tile, s.tile) <= 1 and s.hp < s.def.max_hp:
					tiles[g.idx(s.tile)] = Color(0.4, 1.0, 0.5, 0.4)
			if there != null and tiles.has(g.idx(c)):
				cost = Rules.TU_PATCH_UP
				tip = "Patch up %s  [b]%d TU[/b]  (+%d)" % [there.def.display_name, cost, mini(Rules.PATCH_UP_HEAL, there.def.max_hp - there.hp)]
	board.set_range_overlay(tiles)
	board.show_cursor(c, cursor)
	hud.set_preview_cost(u, cost)
	_tip = tip
	if tip == "":
		hud.hide_tip()


func _radius_tiles(tiles: Dictionary, at: Vector2i, r: float, colour: Color) -> void:
	var n := ceili(r)
	for oy in range(-n, n + 1):
		for ox in range(-n, n + 1):
			var t := at + Vector2i(ox, oy)
			if battle.grid.in_bounds(t) and Vector2(ox, oy).length() <= r:
				tiles[battle.grid.idx(t)] = colour


func _light_text(c: Vector2i) -> String:
	var l := battle.grid.light_at(c)
	var b := Rules.band(l)
	var col: String = {Rules.Band.PITCH: "#7f9cff", Rules.Band.DIM: "#ffb347", Rules.Band.BRIGHT: "#fff6c8"}[b]
	var steam := " · steam" if battle.grid.steam[battle.grid.idx(c)] == 1 else ""
	return "[color=%s]%s (%.2f)[/color]%s" % [col, Rules.band_name(b), l, steam]


func _terrain_tip(c: Vector2i) -> String:
	match battle.grid.get_t(c):
		TacGrid.T.SOFT_ROCK:
			return "Soft rock: the Engineer's drill or dynamite will open it"
		TacGrid.T.BOULDER:
			return "Boulder: cover from shots across it"
		TacGrid.T.VENT:
			return "Steam vent: its steam blocks sight. A valve nearby shuts it."
		TacGrid.T.WALL:
			return "Solid rock"
	return ""


func _enemy_tip(u: Unit, e: Unit) -> String:
	var lines: Array[String] = ["[b][color=#9dff7a]%s[/color][/b]  %d / %d HP" % [e.def.display_name, e.hp, e.def.max_hp]]
	if u.has_weapon():
		for m in u.def.weapon.modes:
			var p := battle.shot_preview(u, e, m)
			if p["ok"]:
				lines.append("%s %s  [b]%d%%[/b]  (%d TU)" % [MODE_KEYS[m], _mode_label(m), p["chance"], p["tu"]])
			else:
				lines.append("%s %s  [color=#a08a7a]%s[/color]" % [MODE_KEYS[m], _mode_label(m), p["reason"]])
	return "\n".join(lines)


func _shot_tip(u: Unit, e: Unit, m: String, p: Dictionary) -> String:
	var lines: Array[String] = ["[b]%s -> %s[/b]" % [_mode_label(m), e.def.display_name]]
	if not p["ok"]:
		lines.append("[color=#ff8a70]%s[/color]" % p["reason"])
		return "\n".join(lines)
	for part in p["parts"]:
		var v: int = part[1]
		lines.append("%s  [color=%s]%s%d[/color]" % [part[0], "#9be38f" if v >= 0 else "#ff8a70", "+" if v >= 0 else "", v])
	lines.append("[b]Hit chance %d%%[/b]   ·   %d TU" % [p["chance"], p["tu"]])
	if m == "burst":
		lines.append("3-5 rounds, each rolled. Pins the target.")
	if u.def.weapon.poison_turns > 0:
		lines.append("Poisons: %d a turn for %d turns" % [u.def.weapon.poison_damage, u.def.weapon.poison_turns])
	var jam := Rules.jam_chance(u.pressure)
	if jam > 0:
		lines.append("[color=#ff8a70]Low pressure: %d%% chance to jam[/color]" % jam)
	return "\n".join(lines)


# --- sending commands and playing events ----------------------------------------------------

func _send(cmd: Dictionary) -> void:
	if busy:
		return
	var events := battle.exec(cmd)
	await play(events)


func play(events: Array[Dictionary]) -> void:
	busy = true
	board.hide_cursor()
	board.set_range_overlay({})
	hud.hide_tip()
	_tip = ""
	hud.refresh(battle, selected, _actions(), "", _objective(), true)
	for e in events:
		await _play_event(e)
	busy = false
	if battle.outcome != "":
		Audio.play("bell")
		hud.show_end(battle.outcome, battle)
		_refresh()
		return
	if selected == null or not selected.alive:
		var team := battle.squad()
		if not team.is_empty():
			select(team[0])
			return
	_refresh()


func _wait(t: float) -> void:
	if t > 0.0:
		await get_tree().create_timer(t).timeout


func _seen(e: Dictionary, id: int) -> bool:
	var u := battle.unit(id)
	if u == null:
		return false
	return u.team == Unit.SQUAD or (e.get("spotted", []) as Array).has(id)


func _apply_spotted(ids: Array) -> void:
	for id in views:
		var u := battle.unit(id)
		if u.team == Unit.SWARM and not _dead_views.has(id):
			(views[id] as UnitView).visible = ids.has(id)


func _name(id: int) -> String:
	var u := battle.unit(id)
	return u.def.display_name.trim_prefix("The ") if u != null else "?"


func _play_event(e: Dictionary) -> void:
	if e.has("vis"):
		board.apply_vision(e["vis"], e["exp"])
	if e.has("light"):
		board.apply_light(e["light"])
	if e.has("spotted"):
		_apply_spotted(e["spotted"])
	var id := int(e.get("u", -1))
	var v: UnitView = views.get(id)
	var u := battle.unit(id)
	match e["type"]:
		"refused":
			hud.toast(e["reason"], true)
			Audio.play("deny")
		"move":
			if _seen(e, id):
				var dur := STEP_TIME if u.team == Unit.SQUAD else ENEMY_STEP_TIME
				v.step_to(e["to"], e["facing"], dur)
				rig.focus(Kit.world(e["to"]))
				Audio.play("step", -12 if u.team == Unit.SQUAD else -16)
				await _wait(dur)
			else:
				v.snap_to(e["to"], e["facing"])
		"door":
			board.set_door(e["tile"], e["open"])
			if battle.is_visible(e["tile"]) or _seen(e, id):
				Audio.play("clank", -4)
				await _wait(0.22)
		"face":
			v.face(e["facing"])
			await _wait(0.12)
		"stance":
			v.set_crouched(e["crouched"])
			Audio.play("step", -8)
			await _wait(0.15)
		"aim":
			v.face(e["facing"], 0.1)
			if e["reaction"]:
				fx.float_text(v.global_position + Vector3(0, 2.6, 0), "REACTION!", Color(1.0, 0.75, 0.3), 60)
				Audio.play("click")
				rig.focus(views[e["target"]].global_position)
				await _wait(0.3)
			else:
				await _wait(0.1)
		"shot":
			await _play_shot(e, v, u)
		"hurt":
			var tv: UnitView = views.get(id)
			if tv != null and (tv.visible or u.team == Unit.SQUAD):
				tv.flash()
				fx.float_text(tv.global_position + Vector3(0, 2.0, 0), "-%d" % e["dmg"], Color(1.0, 0.35, 0.25), 64)
				Audio.play("hit", -4)
				if u.team == Unit.SQUAD:
					rig.shake(0.3)
				await _wait(0.06)
		"death":
			_dead_views[id] = true
			v.visible = true if u.team == Unit.SQUAD or battle.is_visible(e["tile"]) else v.visible
			v.die()
			Audio.play("death", -2)
			if u.team == Unit.SQUAD:
				rig.shake(0.5)
				hud.log_line("[color=#ff7a60]%s has fallen.[/color]" % u.def.display_name)
				fx.float_text(v.global_position + Vector3(0, 2.4, 0), "FALLEN", Kit.DANGER, 72)
				await _wait(0.6)
			else:
				hud.log_line("%s killed." % u.def.display_name)
				fx.puff(v.global_position + Vector3(0, 0.6, 0), Color(0.4, 0.9, 0.3), 12, 1.0)
				await _wait(0.3)
		"wake":
			if _seen(e, id):
				fx.float_text(v.global_position + Vector3(0, 1.8, 0), "!", Kit.SWARM_GREEN, 90)
				Audio.play("chitter", -6)
				hud.log_line("[color=#9dff7a]A %s stirs.[/color]" % u.def.display_name.to_lower())
				await _wait(0.2)
		"jam":
			fx.puff(v.global_position + Vector3(0, 1.4, 0), Color(0.9, 0.9, 0.95), 14, 1.0)
			fx.float_text(v.global_position + Vector3(0, 2.4, 0), "JAMMED!", Color(1, 0.6, 0.3), 60)
			Audio.play("hiss")
			hud.log_line("[color=#ffb347]%s's weapon jams![/color] Field Repair (V) to clear it." % _name(id))
			await _wait(0.5)
		"click":
			fx.float_text(v.global_position + Vector3(0, 2.2, 0), "click", Kit.DIM_INK, 44)
			Audio.play("click")
		"pinned":
			if v.visible:
				fx.float_text(v.global_position + Vector3(0, 2.2, 0), "PINNED", Color(1, 0.8, 0.4), 52)
			hud.log_line("%s is pinned: half TU next turn." % _name(id))
		"poisoned":
			if v.visible:
				fx.float_text(v.global_position + Vector3(0, 2.6, 0), "POISONED", Color(0.5, 1.0, 0.3), 48)
		"poison":
			if v.visible:
				fx.puff(v.global_position + Vector3(0, 0.8, 0), Color(0.5, 1.0, 0.3), 6, 0.6)
		"reload":
			Audio.play("clank", -8)
			fx.float_text(v.global_position + Vector3(0, 2.2, 0), "Reloaded", Kit.INK, 44)
			await _wait(0.25)
		"repair":
			fx.puff(v.global_position + Vector3(0, 1.4, 0.3), Color(0.9, 0.9, 0.95), 16, 1.1)
			Audio.play("hiss")
			fx.float_text(v.global_position + Vector3(0, 2.3, 0), "Pressure 100", Kit.COPPER, 48)
			await _wait(0.4)
		"patch":
			var tv: UnitView = views[e["target"]]
			fx.float_text(tv.global_position + Vector3(0, 2.2, 0), "+%d" % e["healed"], Color(0.5, 1.0, 0.5), 60)
			Audio.play("hiss", -8)
			await _wait(0.3)
		"flare":
			var to := Kit.world(e["tile"], 0.3)
			Audio.play("flare", -2)
			if e["mortar"]:
				Audio.play("shot", -10)
				rig.focus(to)
				await fx.lob(v.muzzle.global_position, to, Color(1.0, 0.5, 0.35), 0.8, 7.0)
			else:
				await fx.lob(v.global_position + Vector3(0, 1.3, 0), to, Color(1.0, 0.5, 0.35), 0.3, 0.8)
			board.sync_flares()
			hud.log_line("A flare sputters alight.")
			await _wait(0.2)
		"light":
			board.sync_flares()
		"throw":
			var to := Kit.world(e["tile"], 0.3)
			var col := Color(0.5, 1.0, 0.3) if e["item"] == "pheromone" else Color(0.7, 0.25, 0.15)
			rig.focus(to)
			await fx.lob(v.global_position + Vector3(0, 1.4, 0), to, col, 0.55, 3.0)
			if e["item"] == "pheromone":
				fx.puff(to, Color(0.5, 1.0, 0.3), 18, 1.6)
				Audio.play("hiss", -4)
				hud.log_line("[color=#9dff7a]The lure bursts: a false trail for the swarm.[/color]")
		"explosion":
			fx.blast(Kit.world(e["tile"]))
			Audio.play("blast")
			board.terrain_changed()
			await _wait(0.5)
		"drill":
			v.face(Rules.dir_toward(u.tile, e["tile"]), 0.1)
			v.lunge()
			Audio.play("drill")
			var at := Kit.world(e["tile"], 1.0)
			fx.sparks(at, Color(1.0, 0.7, 0.35), 34, 6.0)
			fx.puff(at, Color(0.45, 0.4, 0.35), 16, 1.6)
			await _wait(0.35)
			board.terrain_changed()
			hud.log_line("The drill bites through the rock.")
			await _wait(0.2)
		"valve":
			board.turn_valve(e["tile"])
			board.set_vents(e["vents"], e["on"])
			Audio.play("clank", -4)
			Audio.play("hiss", -2)
			hud.log_line("Valve turned: the steam %s." % ("rises again" if e["on"] else "thins away"))
			await _wait(0.5)
		"journal":
			board.remove_journal()
			Audio.play("bell")
			hud.log_line("[color=#C59B27]%s takes the survey journal.[/color]" % _name(id))
			await hud.banner("Journal Recovered", "Every survivor onto the lift.", Kit.BRASS, 0.9)
		"journal_dropped":
			board.place_journal(e["tile"])
			hud.log_line("[color=#ffb347]The journal falls to the cavern floor.[/color]")
		"lamp":
			v.set_lamp(e["on"])
			Audio.play("click", -6)
		"pheromone":
			if overlay == "swarm":
				board.set_info_overlay(board.pheromone_overlay())
			if not e["lure"] and battle.is_visible(e["tile"]):
				fx.puff(Kit.world(e["tile"], 0.5), Color(0.5, 1.0, 0.3), 6, 0.8)
		"reaction":
			hud.log_line("%s watches %s: %.0f vs %.0f, %s" % [_name(id), _name(int(e["target"])),
				e["score"], e["against"], "[color=#ffb347]fires![/color]" if e["fires"] else "too slow"])
		"contact":
			fx.float_text(v.global_position + Vector3(0, 2.6, 0), "CONTACT!", Color(1, 0.7, 0.3), 64)
			Audio.play("chitter", -4)
			hud.log_line("[color=#ffb347]%s: contact![/color] Movement stopped." % _name(id))
			await _wait(0.4)
		"overwatch":
			for wid in e["units"]:
				(views[wid] as UnitView).refresh_label()
			if not (e["units"] as Array).is_empty():
				var names := PackedStringArray()
				for wid in e["units"]:
					names.append(_name(wid))
				hud.log_line("On Overwatch: %s." % ", ".join(names))
		"phase":
			if e["phase"] == "enemy":
				hud.refresh(battle, selected, [], "", _objective(), true)
				await hud.banner("The Swarm Stirs", "", Kit.SWARM_GREEN, 0.35)
			else:
				for vid in views:
					if not _dead_views.has(vid):
						(views[vid] as UnitView).refresh_label()
				board.show_pings(e["pings"])
				if not (e["pings"] as Array).is_empty():
					Audio.play("ping")
					hud.log_line("[color=#ffb347]Seismograph: %d tremors beyond sight.[/color]" % (e["pings"] as Array).size())
				if selected != null and selected.alive:
					rig.focus(Kit.world(selected.tile))
				await hud.banner("Turn %d" % e["turn"], "Your squad", Kit.BRASS, 0.35)
		"spawn":
			var nv := _add_view(u)
			nv.visible = _seen(e, id)
			if nv.visible:
				fx.puff(nv.global_position + Vector3(0, 0.5, 0), Color(0.4, 1.0, 0.3), 14, 1.2)
				Audio.play("chitter")
				hud.log_line("[color=#9dff7a]The hive births a crawler.[/color]")
				await _wait(0.3)


func _play_shot(e: Dictionary, v: UnitView, u: Unit) -> void:
	var tv: UnitView = views[e["target"]]
	var w := u.def.weapon
	var to := tv.global_position + Vector3(0, 0.6 if tv.unit.team == Unit.SWARM else 1.1, 0)
	var from := v.muzzle.global_position
	if not e["hit"]:
		var side := (to - from).cross(Vector3.UP).normalized()
		to += side * randf_range(-1.2, 1.2) + Vector3(0, randf_range(-0.3, 0.6), 0)
		to = from + (to - from) * 1.25
	var visible_shot := v.visible or tv.visible
	if e["melee"]:
		v.lunge()
		if visible_shot:
			fx.sparks(to, Color(1.0, 0.75, 0.4) if u.team == Unit.SQUAD else Color(0.6, 1.0, 0.4), 12, 3.0)
	else:
		fx.tracer(from, to, w.tracer_color)
		fx.flash_light(from, w.tracer_color, 5.0, 6.0)
		v.recoil()
		if e["round"] == 0:
			fx.puff(v.global_position + Vector3(0, 1.5, 0.3), Color(0.9, 0.9, 0.95), 5, 0.5)
	Audio.play(SHOT_SOUND.get(String(w.id), "shot"), -2 if visible_shot else -14)
	if not e["hit"] and visible_shot:
		fx.float_text(to, "miss", Kit.DIM_INK, 40)
	if e["round"] == 0 or not e["hit"]:
		var verb := "strikes" if e["melee"] else ("fires" if e["rounds"] == 1 else "rakes")
		if e["round"] == 0:
			hud.log_line("%s %s at %s (%d%%): %s" % [_name(u.id), verb, _name(int(e["target"])), e["chance"], "hit" if e["hit"] else "miss"])
	await _wait(0.08 if e["rounds"] > 1 else 0.24)
