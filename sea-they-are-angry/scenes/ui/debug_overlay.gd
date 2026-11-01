extends CanvasLayer
## The developer's overlay, in debug builds only (never in an exported release): F10
## shows the numbers behind a run, and the F keys bend it for testing and balancing.
##   F5 skip to the next phase · F6 +10 lamp fuel · F7 +5 of everything in the store
##   F8 the lighthouse takes 50 · F9 the Eel now · F11 the sea angrier by 1

var main: Node
var _panel: PanelContainer
var _text: Label
var _t := 0.0

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(20, 220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 15)
	_text.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_panel.add_child(_text)

static func allowed() -> bool:
	return OS.is_debug_build()

func _unhandled_input(ev: InputEvent) -> void:
	if not allowed() or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var handled := true
	match ev.keycode:
		KEY_F10:
			_panel.visible = not _panel.visible
		KEY_F5:
			if Run.active and not Net.is_client():
				Cycle._enter((Cycle.phase + 1) % 4)
		KEY_F6:
			if Run.active and main != null:
				main.lighthouse.lamp.fuel = minf(Lamp.FUEL_MAX, main.lighthouse.lamp.fuel + 10.0)
		KEY_F7:
			for k in ["driftwood", "scrap", "seaweed", "bio", "food", "diesel", "seeds", "notes", "arrows", "shells", "bombs"]:
				Stock.add(k, 5)
		KEY_F8:
			if Run.active and main != null:
				main.lighthouse.take_damage(50)
		KEY_F11:
			Anger.add(1)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	_text.text = report()

## The numbers, as the overlay shows them.
func report() -> String:
	var lines: Array[String] = []
	lines.append("DEBUG  ·  %d fps" % Engine.get_frames_per_second())
	lines.append("Night %d  ·  %s  %.0f s left  ·  %s sea" % [Run.night, Cycle.phase_name(), Cycle.time_left, Difficulty.name()])
	lines.append("Anger %d / %d  ·  weather %s, storm %.2f" % [Anger.value, Anger.MAX, Weather.tonight_name(), Weather.storm_now])
	if main != null:
		var lamp: Lamp = main.lighthouse.lamp
		lines.append("Lamp %s  fuel %.1f  burn %.2f/s  ·  lighthouse %d / %d" % [Lamp.State.keys()[lamp.state], lamp.fuel, lamp.burn_rate(), main.lighthouse.hp, main.lighthouse.max_hp])
		lines.append("Creatures %d  ·  spawn queue %d  ·  keepers %d (people %d)" % [get_tree().get_nodes_in_group("enemies").size(), main.spawner.queue_size(), Players.count(), Players.humans()])
		if main.camp != null:
			lines.append("Camp: generator %.0f fuel %s  ·  turbine %d  ·  lights %.1f" % [main.camp.generator.fuel, "running" if main.camp.generator.running else "off", main.camp.turbine.hp if main.camp.turbine != null else 0, main.camp.lights_level])
	lines.append("Boat in %d nights  ·  salvage lying %d" % [Rescue.nights_left(), get_tree().get_nodes_in_group("salvage").size()])
	lines.append("F5 next phase · F6 +10 fuel · F7 +5 everything · F8 hit the lighthouse · F9 the Eel · F11 angrier")
	return "\n".join(lines)
