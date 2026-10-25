class_name BeachBackdrop
extends Node2D
## The beach itself, seen from the promenade looking out to sea: sky and headlands on the
## horizon, the sea with rolling foam, wet and dry sand, and the promenade tiles at the bottom.
## Static layers are drawn once; only the waves (a separate child) animate. Colours come from
## the beach's entry in BeachDB, so every Costa resort looks a little different.

const WORLD_W := 3200.0
const HORIZON_Y := 110.0
const SHORE_Y := 300.0
const PROM_Y := 790.0
const WORLD_H := 900.0

var beach_id := "benidorm"
var show_ship := false:
	set(v):
		show_ship = v
		if _ship:
			_ship.visible = v
var _waves: Node2D
var _ship: Node2D
var _t := 0.0


func _ready() -> void:
	z_index = -20
	_waves = Node2D.new()
	_waves.z_index = 1
	_waves.draw.connect(_draw_waves)
	add_child(_waves)
	_ship = Node2D.new()
	_ship.draw.connect(_draw_ship)
	_ship.visible = show_ship
	add_child(_ship)


func setup(id: String) -> void:
	beach_id = id
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	# Waves at ~20 FPS are plenty and save phone batteries.
	if int(_t * 20.0) != int((_t - delta) * 20.0):
		_waves.queue_redraw()
	if _ship.visible:
		_ship.position.x = fmod(_t * 12.0, WORLD_W + 600.0) - 300.0


func _draw() -> void:
	var b := BeachDB.get_beach(beach_id)
	var sky: Color = b.sky
	var sea: Color = b.sea
	var sand: Color = b.sand
	var prom: Color = b.prom
	# Sky (a few bands for a cheap gradient) and the sun.
	for i in 6:
		var f := float(i) / 6.0
		draw_rect(Rect2(0, HORIZON_Y * f - 200.0 * (1.0 - f) * 0.0, WORLD_W, HORIZON_Y / 6.0 + 1.0), sky.lightened(0.35 * f))
	draw_rect(Rect2(0, -400, WORLD_W, 400), sky)
	draw_circle(Vector2(WORLD_W * 0.72, 40), 46, Color(1, 0.95, 0.7, 0.35))
	draw_circle(Vector2(WORLD_W * 0.72, 40), 32, Color("#fff3b0"))
	# Fluffy clouds.
	for c: Vector2 in [Vector2(300, 35), Vector2(1100, 55), Vector2(1900, 28), Vector2(2650, 60)]:
		for k in 4:
			draw_circle(c + Vector2(k * 22 - 33, sin(k * 1.7) * 6.0), 18 + (k % 2) * 6, Color(1, 1, 1, 0.9))
	# Headlands on the horizon.
	var hill := sea.darkened(0.35).lerp(Color("#5d8a5a"), 0.4)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, HORIZON_Y), Vector2(120, HORIZON_Y - 46), Vector2(330, HORIZON_Y - 30), Vector2(520, HORIZON_Y)]), hill)
	draw_colored_polygon(PackedVector2Array([Vector2(2500, HORIZON_Y), Vector2(2700, HORIZON_Y - 26), Vector2(2950, HORIZON_Y - 52), Vector2(3210, HORIZON_Y - 20), Vector2(3210, HORIZON_Y)]), hill)
	# Sea: deeper towards the horizon.
	for i in 8:
		var f := float(i) / 8.0
		var y0 := lerpf(HORIZON_Y, SHORE_Y, f)
		draw_rect(Rect2(0, y0, WORLD_W, (SHORE_Y - HORIZON_Y) / 8.0 + 1.0), sea.darkened(0.25 * (1.0 - f)).lightened(0.12 * f))
	# Wet sand strip and dry sand.
	draw_rect(Rect2(0, SHORE_Y, WORLD_W, 40), sand.darkened(0.12))
	draw_rect(Rect2(0, SHORE_Y + 40, WORLD_W, PROM_Y - SHORE_Y - 40), sand)
	# Sand texture: deterministic speckles, shells and footprints.
	var rng := RandomNumberGenerator.new()
	rng.seed = beach_id.hash()
	for i in 500:
		var p := Vector2(rng.randf() * WORLD_W, rng.randf_range(SHORE_Y + 45, PROM_Y - 6))
		draw_circle(p, rng.randf_range(1.0, 2.4), sand.darkened(rng.randf_range(0.05, 0.14)))
	for i in 24:
		var p := Vector2(rng.randf() * WORLD_W, rng.randf_range(SHORE_Y + 50, PROM_Y - 30))
		draw_circle(p, 3.5, Color("#fff1e6"))
		draw_arc(p, 3.5, PI, TAU, 6, sand.darkened(0.3), 1.0)
	# Promenade: sea wall edge, tiles, and the road beyond.
	draw_rect(Rect2(0, PROM_Y - 8, WORLD_W, 12), Color("#c9b49a"))
	draw_rect(Rect2(0, PROM_Y + 4, WORLD_W, WORLD_H - PROM_Y), prom)
	for x in range(0, int(WORLD_W), 64):
		draw_line(Vector2(x, PROM_Y + 4), Vector2(x - 20, WORLD_H), prom.darkened(0.08), 2.0)
	for y: float in [PROM_Y + 40, PROM_Y + 80]:
		draw_line(Vector2(0, y), Vector2(WORLD_W, y), prom.darkened(0.08), 2.0)
	# Wavy mosaic pattern like the famous promenades.
	var wave_col := prom.darkened(0.22)
	var pts := PackedVector2Array()
	for x in range(0, int(WORLD_W) + 20, 20):
		pts.append(Vector2(x, PROM_Y + 60 + sin(x * 0.03) * 10.0))
	draw_polyline(pts, wave_col, 6.0)
	draw_rect(Rect2(0, WORLD_H - 8, WORLD_W, 400), Color("#5b5b66"))


func _draw_waves() -> void:
	var b := BeachDB.get_beach(beach_id)
	var sea: Color = b.sea
	var t := _t
	# Rolling wave lines across the sea.
	for row in 6:
		var y := lerpf(HORIZON_Y + 18.0, SHORE_Y - 30.0, row / 5.0)
		var col := sea.lightened(0.3 + row * 0.05)
		col.a = 0.55
		var pts := PackedVector2Array()
		var off := t * (14.0 + row * 6.0) + row * 90.0
		for x in range(0, int(WORLD_W) + 60, 60):
			pts.append(Vector2(x - fmod(off, 60.0), y + sin((x + off) * 0.02 + row) * (2.0 + row)))
		_waves.draw_polyline(pts, col, 2.0 + row * 0.4)
	# Foam line washing up and down the sand.
	var wash := sin(t * 0.9) * 10.0
	var foam := PackedVector2Array()
	var wet := PackedVector2Array()
	for x in range(0, int(WORLD_W) + 40, 40):
		var y := SHORE_Y + 6.0 + wash + sin(x * 0.013 + t * 1.3) * 6.0
		foam.append(Vector2(x, y))
	wet.append(Vector2(0, SHORE_Y - 20))
	wet.append_array(foam)
	wet.append(Vector2(WORLD_W + 40, SHORE_Y - 20))
	var shallow := sea.lightened(0.35)
	shallow.a = 0.8
	_waves.draw_colored_polygon(wet, shallow)
	_waves.draw_polyline(foam, Color(1, 1, 1, 0.95), 5.0)


func _draw_ship() -> void:
	# A cruise ship crawling along the horizon during the Cruise Ship event.
	var y := HORIZON_Y - 4.0
	_ship.draw_colored_polygon(PackedVector2Array([Vector2(-120, y - 20), Vector2(120, y - 20), Vector2(100, y), Vector2(-110, y)]), Color("#f5f5f5"))
	_ship.draw_rect(Rect2(-100, y - 38, 170, 18), Color("#ffffff"))
	_ship.draw_rect(Rect2(-80, y - 52, 120, 14), Color("#eeeeee"))
	_ship.draw_rect(Rect2(10, y - 72, 18, 22), Color("#e53935"))
	for i in 12:
		_ship.draw_circle(Vector2(-95 + i * 15, y - 29), 2.5, Color("#1e88e5"))
	_ship.draw_line(Vector2(-120, y - 8), Vector2(115, y - 8), Color("#1565c0"), 4.0)
