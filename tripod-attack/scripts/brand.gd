class_name Brand
## The 3BL_Indie lockup from the studio website: three pixel figures above the 3BL_INDIE
## wordmark, drawn as rectangles so it stays crisp at any size.

const ORANGE := Color("ff8c2b")
const CYAN := Color("1fc8da")
const FIGS := [[1, 2, 3, 2], [0, 4, 5, 2], [1, 6, 3, 2], [1, 8, 1, 2], [3, 8, 1, 2], [0, 10, 2, 1], [3, 10, 2, 1],
	[9, 0, 3, 2], [7, 2, 7, 4], [8, 6, 5, 1], [8, 7, 2, 3], [11, 7, 2, 3], [7, 10, 3, 1], [11, 10, 3, 1],
	[17, 2, 3, 2], [16, 4, 5, 2], [17, 6, 3, 2], [17, 8, 1, 2], [19, 8, 1, 2], [16, 10, 2, 1], [19, 10, 2, 1]]
const LETTERS_ORANGE := [[0, 0, 5, 1], [4, 1, 1, 5], [1, 3, 3, 1], [0, 6, 5, 1],
	[7, 0, 1, 7], [7, 0, 4, 1], [10, 1, 2, 2], [7, 3, 4, 1], [10, 4, 2, 2], [7, 6, 4, 1],
	[14, 0, 1, 7], [14, 6, 5, 1]]
const LETTERS_CYAN := [[21, 6, 4, 1],
	[27, 0, 3, 1], [28, 1, 1, 5], [27, 6, 3, 1],
	[32, 0, 1, 7], [36, 0, 1, 7], [33, 1, 1, 2], [34, 3, 1, 1], [35, 4, 1, 2],
	[39, 0, 1, 7], [39, 0, 4, 1], [42, 1, 2, 5], [39, 6, 4, 1],
	[46, 0, 3, 1], [47, 1, 1, 5], [46, 6, 3, 1],
	[51, 0, 1, 7], [51, 0, 5, 1], [51, 3, 4, 1], [51, 6, 5, 1]]


static func _rects(c: CanvasItem, rects: Array, origin: Vector2, px: float, col: Color) -> void:
	for r in rects:
		c.draw_rect(Rect2(origin + Vector2(r[0], r[1]) * px, Vector2(r[2], r[3]) * px), col)


## Draws the lockup with its top-left at `pos`; `px` is the size of one grid cell. Returns its size.
static func draw(c: CanvasItem, pos: Vector2, px: float, alpha := 1.0) -> Vector2:
	var o := Color(ORANGE, alpha)
	var cy := Color(CYAN, alpha)
	_rects(c, FIGS, pos + Vector2((56 - 21) * px / 2.0, 0), px, o)
	var ly := pos + Vector2(0, 13.0 * px)
	_rects(c, LETTERS_ORANGE, ly, px, o)
	_rects(c, LETTERS_CYAN, ly, px, cy)
	return Vector2(56.0 * px, 20.0 * px)
