extends Overlay
## Tap a room: see its state and who's staying, and sort it out. Open a boarded-up room,
## upgrade it, or send the manager to clean, repair or squash cockroaches personally.

var world: Node
var room := 0


func build() -> void:
	var r: Dictionary = Hotel.rooms[room]
	var title := "Room %s" % Hotel.room_label(room)
	var v := card(title, Vector2(760, 0))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	v.add_child(info)
	if not Hotel.floor_unlocked(Hotel.floor_of(room)):
		_line(info, "This floor is closed (the asbestos is... resting).", UITheme.DANGER)
		_line(info, "Open it under UPGRADES > Building > Open Another Floor.")
		_buttons(v, [])
		return
	if not r.open:
		_line(info, "Boarded up. Smells of the previous owner.")
		_line(info, "Opening it costs %s: one more room to fill every night." % Lines.money(Hotel.open_cost()))
		var reason := Hotel.can_open(room)
		_buttons(v, [["OPEN ROOM\n%s" % Lines.money(Hotel.open_cost()), UITheme.LIME, _open, reason]])
		return
	var q := int(r.quality)
	_line(info, "Quality: %s. %s" % [Hotel.QUALITY_NAMES[q], Hotel.QUALITY_DESC[q]])
	_line(info, "Price: %s per guest, per night" % Lines.money(Hotel.room_rate(room)))
	var dirt := float(r.dirt)
	_line(info, "Cleanliness: %s" % ("Spotless" if dirt < 20.0 else ("Bit grubby" if dirt < 50.0 else ("Minging" if dirt < 80.0 else "Biohazard"))), UITheme.DANGER if dirt >= 50.0 else UITheme.INK)
	if int(r.roaches) > 0:
		_line(info, "Cockroaches: %d (tap them in the room to squash!)" % int(r.roaches), UITheme.DANGER)
	if int(r.damage) > 0:
		_line(info, "Damage: %s (repair: %s)" % [["", "a broken lamp", "a smashed telly", "fully trashed"][int(r.damage)], Lines.money(Hotel.repair_cost(room))], UITheme.DANGER)
	var g := Hotel.group(int(r.group))
	if not g.is_empty():
		var mood := float(g.happiness)
		var face := "Delighted" if mood >= 80.0 else ("Happy" if mood >= 60.0 else ("Meh" if mood >= 40.0 else ("Grumpy" if mood >= 20.0 else "FURIOUS")))
		_line(info, "Guests: %s x%d, %d night(s) left. Mood: %s (%d%%)" % [GuestTypes.get_type(g.type).name, int(g.size), int(g.nights), face, int(mood)], UITheme.SEA_DARK)
	else:
		_line(info, "Empty tonight.")
	var actions := []
	if q < 3:
		actions.append(["UPGRADE to %s\n%s" % [Hotel.QUALITY_NAMES[q + 1], Lines.money(Hotel.quality_cost(room))], UITheme.TERRACOTTA, _upgrade,
			"" if Economy.can_afford(Hotel.quality_cost(room)) else "Not enough cash"])
	if dirt > 20.0 or int(r.roaches) > 0:
		actions.append(["Clean it\nyourself", UITheme.SEA, _clean, ""])
	if int(r.damage) > 0:
		actions.append(["Repair\n%s" % Lines.money(Hotel.repair_cost(room)), UITheme.LEMON, _repair, ""])
	_buttons(v, actions)


func _line(parent: Control, text: String, col := UITheme.INK) -> void:
	var l := UITheme.label(text, 20, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)


func _buttons(v: VBoxContainer, actions: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for a in actions:
		var b := UITheme.button(str(a[0]), a[1], Vector2(190, 80), 18)
		b.disabled = str(a[3]) != ""
		if b.disabled:
			b.text += "\n(%s)" % a[3]
			b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(a[2])
		h.add_child(b)
	var close_btn := UITheme.button("Close", UITheme.SEA, Vector2(130, 80), 22)
	close_btn.pressed.connect(close)
	h.add_child(close_btn)


func _open() -> void:
	if Hotel.open_room(room):
		AudioManager.play_sfx("upgrade")
		GameManager.notify("Room %s is open for business! (Mind the smell.)" % Hotel.room_label(room), "good")
	close()


func _upgrade() -> void:
	if Hotel.upgrade_room(room):
		AudioManager.play_sfx("upgrade")
		GameManager.notify("Room %s is now %s!" % [Hotel.room_label(room), Hotel.QUALITY_NAMES[int(Hotel.rooms[room].quality)]], "good")
	close()


func _clean() -> void:
	world.manager_clean(room)
	close()


func _repair() -> void:
	world.manager_repair(room)
	close()
