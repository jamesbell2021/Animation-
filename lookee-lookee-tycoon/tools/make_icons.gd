extends Node
## Renders the app icons and itch.io cover from the real character rig, so they always match
## the game's art. Needs a display (use xvfb-run on a headless Linux box):
##   godot --path . res://tools/make_icons.tscn
## Writes icons/app_icon.png (512), icons/app_icon_192.png, icons/adaptive_foreground.png and
## icons/adaptive_background.png (432, Android adaptive icon layers) and itch/cover.png.


func _ready() -> void:
	_run.call_deferred()


func _render(size: Vector2i, build: Callable, transparent := false) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.msaa_2d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	build.call(vp)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _icon_look() -> Dictionary:
	var a := AppearanceOptions.default_appearance()
	a.shirt = 2
	a.mouth = 4
	return a


func _avatar(parent: Node, pos: Vector2, s: float, shout := false) -> VendorAvatar:
	var av := VendorAvatar.new()
	parent.add_child(av)
	av.set_appearance(_icon_look())
	av.position = pos
	av.scale = Vector2(s, s)
	if shout:
		av.shout(5.0)
	return av


class BeachBg extends Node2D:
	var size := Vector2(512, 512)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y * 0.5), Color("#7fd3f7"))
		draw_rect(Rect2(0, size.y * 0.5, size.x, size.y * 0.2), Color("#1e9bd7"))
		draw_rect(Rect2(0, size.y * 0.7, size.x, size.y * 0.3), Color("#f7d89b"))
		draw_circle(Vector2(size.x * 0.8, size.y * 0.2), size.x * 0.1, Color("#fff3b0"))


func _beach_bg(parent: Node, size: Vector2) -> void:
	var bg := BeachBg.new()
	bg.size = size
	parent.add_child(bg)


func _build_icon(vp: SubViewport) -> void:
	_beach_bg(vp, Vector2(512, 512))
	_avatar(vp, Vector2(256, 760), 6.2)


func _build_fg(vp: SubViewport) -> void:
	_avatar(vp, Vector2(216, 560), 4.0)


func _build_bg(vp: SubViewport) -> void:
	_beach_bg(vp, Vector2(432, 432))


func _build_cover(vp: SubViewport) -> void:
	_beach_bg(vp, Vector2(630, 500))
	_avatar(vp, Vector2(470, 480), 2.9, true)
	vp.add_child(_text("LOOKEE LOOKEE\nTYCOON", 58, UITheme.LEMON, 16, Vector2(24, 24)))
	vp.add_child(_text("Hello chicken nugget!\nVery good very nice!", 30, Color.WHITE, 10, Vector2(28, 330)))


func _text(t: String, size: int, col: Color, outline: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", UITheme.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", UITheme.INK)
	l.add_theme_constant_override("outline_size", outline)
	l.position = pos
	return l


func _run() -> void:
	VendorAvatar.smooth_lines = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://icons"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://itch"))
	var icon := await _render(Vector2i(512, 512), _build_icon)
	icon.save_png(ProjectSettings.globalize_path("res://icons/app_icon.png"))
	var small := icon.duplicate()
	small.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	small.save_png(ProjectSettings.globalize_path("res://icons/app_icon_192.png"))
	# Android adaptive layers: the face inside the central safe zone, on transparency.
	var fg := await _render(Vector2i(432, 432), _build_fg, true)
	fg.save_png(ProjectSettings.globalize_path("res://icons/adaptive_foreground.png"))
	var bgimg := await _render(Vector2i(432, 432), _build_bg)
	bgimg.save_png(ProjectSettings.globalize_path("res://icons/adaptive_background.png"))
	var cover := await _render(Vector2i(630, 500), _build_cover)
	cover.save_png(ProjectSettings.globalize_path("res://itch/cover.png"))
	print("Icons written. Very good very nice!")
	get_tree().quit()
