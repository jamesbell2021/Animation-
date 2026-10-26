class_name Overlay
extends CanvasLayer
## Base for full-screen menus that sit on top of the game (shop, pause, settings, busted,
## day summary, the creator in edit mode). Handles pausing the game while open, the Android
## back button / Esc (only the top-most overlay reacts), and a dimmed backdrop.

signal closed

static var stack: Array[Overlay] = []

var pause_game := true
var closable_by_back := true
var root: Control


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	layer = 20 + stack.size()
	stack.append(self)
	if pause_game:
		GameManager.set_paused(_reason(), true)
	if not GameManager.back_pressed.is_connected(_on_back):
		GameManager.back_pressed.connect(_on_back)


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.add_child(UITheme.dimmer())
	build()
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.15)


## Override: build the overlay's controls under `root`.
func build() -> void:
	pass


func is_top() -> bool:
	return not stack.is_empty() and stack.back() == self


func _on_back() -> void:
	if is_top() and closable_by_back:
		# Defer so one back press doesn't also reach the overlay underneath.
		close.call_deferred()


func close() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	stack.erase(self)
	if pause_game:
		GameManager.set_paused(_reason(), false)
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	stack.erase(self)
	if pause_game and GameManager.is_paused_by(_reason()):
		GameManager.set_paused(_reason(), false)


func _reason() -> String:
	return "overlay_%d" % get_instance_id()


## A centred card of the given size with a title, returning the VBox to fill.
func card(title_text: String, size := Vector2(900, 600), bg := UITheme.PANEL) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var p := UITheme.panel(bg)
	var vp := root.get_viewport_rect().size
	p.custom_minimum_size = Vector2(minf(size.x, vp.x - 24.0), minf(size.y, vp.y - 24.0))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(UITheme.margin(v, 14))
	if title_text != "":
		var t := UITheme.title(title_text, 40)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
	return v
