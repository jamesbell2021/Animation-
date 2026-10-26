extends Node
## Renders the app icons and a store cover from the real character rig, so they always match
## the game's art. Needs a display (use xvfb-run on a headless Linux box):
##   godot --path . res://tools/make_icons.tscn
## Writes icons/app_icon.png (512), icons/app_icon_192.png, icons/adaptive_foreground.png and
## icons/adaptive_background.png (432, Android adaptive icon layers) and store/cover.png.


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


func _manager_look() -> Dictionary:
	var a := AppearanceOptions.default_appearance()
	a.shirt = 2
	a.shirt_color = "e2673f"
	a.mouth = 4
	a.chain = 1
	a.badge = "MANAGER"
	return a


func _avatar(parent: Node, pos: Vector2, s: float, shout := false) -> VendorAvatar:
	var av := VendorAvatar.new()
	parent.add_child(av)
	av.set_appearance(_manager_look())
	av.position = pos
	av.scale = Vector2(s, s)
	if shout:
		av.shout(5.0)
	return av


## A grubby little hotel at sunset with an empty row of stars over the door.
class HotelBg extends Node2D:
	var size := Vector2(512, 512)
	var building := true

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("#ff9e5e"))
		draw_rect(Rect2(0, 0, s.x, s.y * 0.35), Color("#8e6bb3"))
		draw_circle(Vector2(s.x * 0.2, s.y * 0.62), s.x * 0.12, Color("#ffd166"))
		draw_rect(Rect2(0, s.y * 0.72, s.x, s.y * 0.28), Color("#e8c98a"))
		if not building:
			return
		var r := Rect2(s.x * 0.08, s.y * 0.2, s.x * 0.84, s.y * 0.55)
		draw_rect(r, Color("#d9b48f"))
		draw_rect(r, UITheme.INK, false, s.x * 0.012)
		for f in 2:
			for k in 3:
				var w := Rect2(r.position.x + 18 + k * (r.size.x - 36) / 3.0, r.position.y + 70 + f * 92, (r.size.x - 36) / 3.0 - 18, 62)
				draw_rect(w, Color("#ffe08a") if (f + k) % 2 == 0 else Color("#3b3f5c"))
				draw_rect(w, UITheme.INK, false, 4.0)
		for k in 3:
			var c := Vector2(s.x * 0.5 + (k - 1) * s.x * 0.15, r.position.y + 36)
			var pts := VendorAvatar._star(c, s.x * 0.06, s.x * 0.027)
			draw_colored_polygon(pts, Color(0.45, 0.4, 0.38))
			pts.append(pts[0])
			draw_polyline(pts, UITheme.INK, 3.0, true)


func _bg(parent: Node, size: Vector2, building := true) -> void:
	var bg := HotelBg.new()
	bg.size = size
	bg.building = building
	parent.add_child(bg)


func _build_icon(vp: SubViewport) -> void:
	_bg(vp, Vector2(512, 512))
	_avatar(vp, Vector2(256, 690), 3.6)


func _build_fg(vp: SubViewport) -> void:
	_avatar(vp, Vector2(216, 560), 3.6)


func _build_bg(vp: SubViewport) -> void:
	_bg(vp, Vector2(432, 432))


func _build_cover(vp: SubViewport) -> void:
	_bg(vp, Vector2(630, 500), false)
	_avatar(vp, Vector2(480, 480), 2.8, true)
	vp.add_child(_text("ZERO STAR\nHOTEL", 70, UITheme.LEMON, 16, Vector2(24, 24)))
	vp.add_child(_text("Lads. Cockroaches.\nLounger wars.\nCan you get 3 stars?", 28, Color.WHITE, 10, Vector2(28, 300)))


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://store"))
	var icon := await _render(Vector2i(512, 512), _build_icon)
	icon.save_png(ProjectSettings.globalize_path("res://icons/app_icon.png"))
	var small := icon.duplicate()
	small.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	small.save_png(ProjectSettings.globalize_path("res://icons/app_icon_192.png"))
	var fg := await _render(Vector2i(432, 432), _build_fg, true)
	fg.save_png(ProjectSettings.globalize_path("res://icons/adaptive_foreground.png"))
	var bgimg := await _render(Vector2i(432, 432), _build_bg)
	bgimg.save_png(ProjectSettings.globalize_path("res://icons/adaptive_background.png"))
	var cover := await _render(Vector2i(630, 500), _build_cover)
	cover.save_png(ProjectSettings.globalize_path("res://store/cover.png"))
	print("Icons written.")
	get_tree().quit()
