extends Control
## The title's LAN screen: host a game, or join one found on the LAN (or by address),
## wait in the lobby, and (the host) start it. Each machine plays one keeper on a screen
## of its own; the computer's helpers make up three. See Net.

signal closed

const GOLD := Color(1.0, 0.78, 0.42)
const PALE := Color(0.9, 0.92, 0.95)
const DIM := Color(0.7, 0.75, 0.8)

var _box: VBoxContainer
var _name: LineEdit
var _addr: LineEdit
var _status: Label
var _list: VBoxContainer
var _view := "menu"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.88)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_box = VBoxContainer.new()
	_box.position = Vector2(90, 120)
	_box.custom_minimum_size = Vector2(620, 0)
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	Net.lobby_changed.connect(_show)
	Net.hosts_changed.connect(_show)
	Net.failed.connect(_on_failed)
	Net.left.connect(_on_failed)
	_show()

func _exit_tree() -> void:
	Net.browse(false)

func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	return l

func _button(text: String, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_font_size_override("font_size", 28)
	Fonts.use_title(b)
	b.add_theme_color_override("font_color", PALE)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
		cb.call())
	(parent if parent != null else _box).add_child(b)
	return b

func _field(text: String, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.add_theme_font_size_override("font_size", 22)
	e.custom_minimum_size = Vector2(420, 40)
	_box.add_child(e)
	return e

func _player_name() -> String:
	var n := _name.text.strip_edges() if _name != null else ""
	return n if n != "" else Net.my_name

func _show() -> void:
	if Net.started:
		return
	_clear()
	var t := _label("Play on the LAN", 52, GOLD)
	Fonts.use_title(t)
	if not Net.online():
		_view = "menu" if _view == "lobby" else _view
	if Net.online() and not Net.lobby.is_empty():
		_view = "lobby"
	match _view:
		"menu":
			_label("Every keeper on a screen of their own: one person to each machine, the computer's helpers making up three.", 18, DIM)
			_label("Your name", 18, DIM)
			_name = _field(Net.my_name, "Your name")
			_button("Host a game", _on_host)
			_button("Join a game", func() -> void:
				Net.my_name = _player_name()
				_view = "join"
				Net.browse(true)
				_show())
			_button("Back", _on_back)
		"join":
			_label("Games on the LAN:", 20, PALE)
			if Net.found_hosts.is_empty():
				_label("Looking… (a host's game shows here when it's open)", 18, DIM)
			for ip in Net.found_hosts:
				var h: Dictionary = Net.found_hosts[ip]
				_button("%s's game  (%d of %d)  ·  %s" % [h["name"], h["players"], Players.MAX, ip], _join.bind(ip))
			_label("Or the host's address:", 18, DIM)
			_addr = _field("", "192.168.1.20")
			_button("Join that address", func() -> void: _join(_addr.text.strip_edges()))
			_button("Back", func() -> void:
				Net.browse(false)
				_view = "menu"
				_show())
		"connecting":
			_label("Connecting…", 22, PALE)
			_button("Cancel", _on_cancel)
		"lobby":
			var who := "Your game" if Net.is_host() else "In the lobby"
			_label(who, 26, PALE)
			for e in Net.lobby:
				_label("  %s  —  keeper %d: %s" % [e["name"], int(e["slot"]) + 1, Players.NAMES[int(e["slot"]) % Players.NAMES.size()]], 22, GOLD if int(e["slot"]) == Net.my_slot else PALE)
			_label("The computer keeps the other %d." % (Players.MAX - Net.lobby.size()), 18, DIM)
			if Net.is_host():
				_label("The sea: %s. Others join from their own Play on the LAN screen." % Difficulty.NAMES[Run.next_difficulty], 18, DIM)
				_button("Start a new run", func() -> void: Net.start_game(false))
				var save := SaveSys.load_run()
				if not save.is_empty():
					_button("Continue (night %d)" % int(save.get("night", 1)), func() -> void: Net.start_game(true))
			else:
				_label("Waiting for the host to start…", 20, DIM)
			_button("Leave", _on_cancel)
	_status = _label("", 18, Color(1.0, 0.55, 0.45))
	var first := _first_button()
	if first != null:
		first.grab_focus.call_deferred()

func _first_button() -> Button:
	for c in _box.get_children():
		if c is Button:
			return c
	return null

func _on_host() -> void:
	var err := Net.host(_player_name())
	if err != "":
		_show()
		_status.text = err
		return
	_view = "lobby"
	_show()

func _join(address: String) -> void:
	if address == "":
		return
	Net.browse(false)
	var err := Net.join(address, Net.my_name)
	if err != "":
		_status.text = err
		return
	_view = "connecting"
	_show()

func _on_cancel() -> void:
	Net.leave()
	_view = "menu"
	_show()

func _on_failed(reason: String) -> void:
	_view = "menu"
	_show()
	_status.text = reason

func _on_back() -> void:
	Net.leave()
	closed.emit()
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		if _view == "menu":
			_on_back()
		else:
			_on_cancel()
		get_viewport().set_input_as_handled()
