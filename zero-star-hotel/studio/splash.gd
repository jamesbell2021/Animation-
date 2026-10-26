extends CanvasLayer
## 3BL_Indie studio splash, shared by every 3BL_Indie game (keep the copies identical).
## Registered as the first autoload: covers the screen at launch, then fades away to
## reveal the game. Any key, click, tap or gamepad button skips it.
## Headless runs (tests, CI) and the --no-splash command-line flag skip it entirely.

const STUDIO := "3BL"
const SUFFIX := "_Indie"
const TAGLINE := "presents"
const FADE_IN := 0.7
const HOLD := 2.0
const FADE_OUT := 0.7
const BG := Color(0.02, 0.02, 0.03)
const INK := Color(0.95, 0.93, 0.9)
const ACCENT := Color(1.0, 0.66, 0.22)
const DIM := Color(0.62, 0.6, 0.58)

const SETTLE_FRAMES := 3
const MAX_STEP := 0.1

var _root: Control
var _content: Control
var _bars: Array[ColorRect] = []
var _bar_x: Array[float] = []
var _tagline: Label
var _frames := 0
var _t := 0.0
var _out_t := -1.0
var _out_len := FADE_OUT

func _ready() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.has("--no-splash"):
		queue_free()
		return
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_content.modulate.a = 0.0

# The timeline runs on clamped frame steps, and only once the game has settled, so a
# long first frame (a big scene being built underneath) can't skip the splash.
func _process(delta: float) -> void:
	if _frames < SETTLE_FRAMES:
		_frames += 1
		if _frames == SETTLE_FRAMES:
			_play_sting()
		return
	var step := minf(delta, MAX_STEP)
	if _out_t >= 0.0:
		_out_t += step
		_root.modulate.a = 1.0 - clampf(_out_t / _out_len, 0.0, 1.0)
		if _out_t >= _out_len:
			queue_free()
		return
	_t += step
	_content.modulate.a = clampf(_t / FADE_IN, 0.0, 1.0)
	for i in _bars.size():
		var p := clampf((_t - 0.15 - 0.12 * float(i)) / 0.55, 0.0, 1.0)
		_bars[i].position.x = _bar_x[i] - 160.0 * (1.0 - _back_out(p))
	_tagline.modulate.a = clampf((_t - FADE_IN - 0.4) / 0.6, 0.0, 1.0)
	if _t >= FADE_IN + HOLD:
		_leave()

static func _back_out(p: float) -> float:
	var c1 := 1.70158
	var q := p - 1.0
	return 1.0 + (c1 + 1.0) * q * q * q + c1 * q * q

func _font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Montserrat", "Inter", "Helvetica Neue", "Arial", "Liberation Sans", "DejaVu Sans", "sans-serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f

func _label(text: String, size: int, color: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	column.add_child(row)
	# The mark: three stacked bars, for the three Bells.
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(96, 120)
	row.add_child(mark)
	var widths := [92.0, 70.0, 92.0]
	for i in 3:
		var bar := ColorRect.new()
		bar.color = ACCENT if i != 1 else INK
		bar.size = Vector2(widths[i], 22)
		bar.position = Vector2(96.0 - widths[i], 14.0 + float(i) * 36.0)
		mark.add_child(bar)
		_bars.append(bar)
		_bar_x.append(bar.position.x)
	var word := HBoxContainer.new()
	word.add_theme_constant_override("separation", 0)
	row.add_child(word)
	var studio := _label(STUDIO, 132, INK, 800)
	word.add_child(studio)
	var suffix := _label(SUFFIX, 132, ACCENT, 300)
	word.add_child(suffix)
	_tagline = _label(TAGLINE, 30, DIM, 400)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.modulate.a = 0.0
	column.add_child(_tagline)

func _input(event: InputEvent) -> void:
	if _root == null:
		return
	get_viewport().set_input_as_handled()
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_leave(0.25)

func _leave(duration: float = FADE_OUT) -> void:
	if _out_t >= 0.0:
		return
	_out_len = duration
	_out_t = 0.0

# A soft, warm chord as the mark appears. Synthesised, so no audio file is needed.
func _play_sting() -> void:
	var rate := 22050
	var seconds := 2.2
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes := [110.0, 164.81, 220.0, 277.18, 329.63]
	for i in n:
		var t := float(i) / float(rate)
		var env := minf(1.0, t / 0.05) * exp(-t * 1.6)
		var v := 0.0
		for k in notes.size():
			var f: float = notes[k]
			var start := 0.06 * float(k)
			if t >= start:
				v += sin(TAU * f * (t - start)) * (0.32 - 0.04 * float(k)) + sin(TAU * f * 2.0 * (t - start)) * 0.05
		data.encode_s16(i * 2, int(clampf(v * env * 0.5, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	var p := AudioStreamPlayer.new()
	p.stream = wav
	p.volume_db = -8.0
	add_child(p)
	p.play()
