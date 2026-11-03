class_name HowToPlay
extends RefCounted
## The rules in the players' words, shared by the title screen and the pause menu.

const TEXT := """[font_size=30][color=#C59B27]Her Majesty's Royal Subterranean Expedition[/color][/font_size]
A survey party went down the shaft in '87 and never came up. Find their [b]journal[/b], then bring every surviving specialist back to [b]the lift[/b]. Or kill every creature in the cavern, the hive included.

[color=#C59B27][b]Time Units[/b][/color]
Each specialist has a pool of TU each turn. A step costs 4 (6 diagonally, 2 more crouched), turning costs 1 for each 45°, and shots cost a share of the pool: snap 25%, aimed 50%, burst 60%. The bar shows what the action under the mouse would cost, in red.

[color=#C59B27][b]Overwatch[/b][/color]
End a turn with a third of the TU bar unspent (the bright tick) and the specialist watches. When a creature walks into the cone, the watcher and the creature each score [i]reaction stat × share of TU left[/i]; the higher acts first. Creatures lose TU as they walk, so the deeper they come, the likelier the shot.

[color=#C59B27][b]Light[/b][/color]
Each specialist sees a 90° cone (and anything within 2 tiles). In pitch black nothing past 2 tiles can be targeted. Workers glow and give themselves away; crawlers don't. Davy lamps (L) light the way but show the swarm where you are. Flares (F, or the Engineer's mortar, M) burn for three turns. Steam blocks sight: shut the valve.

[color=#C59B27][b]The swarm[/b][/color]
A creature that sees you marks the spot with pheromone, and every creature within 15 tiles follows the strongest trail on the next turns. The Naturalist's pheromone grenade (G) lays a false trail. Crawlers circle round to strike from outside your cone: watch your backs. Firing is loud and wakes sleepers.

[color=#C59B27][b]Steam pressure[/b][/color]
Every shot draws on the boiler. Below 30 pressure a weapon may jam; Field Repair (V) restores it.

[color=#C59B27][b]Controls[/b][/color]
Left-click: select a specialist, move, or carry out the chosen action.  Right-click: face that way.
1 / 2 / 3 snap, aimed, burst.  R reload.  C crouch.  F hand flare.  M mortar flare.  G pheromone.  T dynamite.  B drill.  X doors, valves, the journal.  H patch up.  V field repair.  L lamp.
Tab next specialist.  Enter end turn.  Esc cancel / menu.
Camera: WASD or arrows, middle-drag, Q / E to turn, wheel to zoom.  O light map.  P swarm sense (pheromone)."""


static func panel(on_close: Callable) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(980, 760)
	p.position = Vector2(-490, -380)
	shade.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = TEXT
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_font_size_override("bold_font_size", 17)
	rt.add_theme_font_size_override("italics_font_size", 17)
	v.add_child(rt)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		shade.queue_free()
		on_close.call())
	v.add_child(back)
	back.call_deferred("grab_focus")
	return shade
