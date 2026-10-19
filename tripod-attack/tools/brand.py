"""The 3BL_Indie lockup, from the studio website's SVG: three pixel figures above the 3BL_INDIE
wordmark. Figures and 3BL in orange, _INDIE in cyan. Drawn as filled rectangles at any scale.
"""
from PIL import Image, ImageDraw, ImageFilter

ORANGE = (255, 140, 43)
CYAN = (31, 200, 218)

# (x, y, w, h) on a 21 x 11 grid
FIGS = [(1, 2, 3, 2), (0, 4, 5, 2), (1, 6, 3, 2), (1, 8, 1, 2), (3, 8, 1, 2), (0, 10, 2, 1), (3, 10, 2, 1),
        (9, 0, 3, 2), (7, 2, 7, 4), (8, 6, 5, 1), (8, 7, 2, 3), (11, 7, 2, 3), (7, 10, 3, 1), (11, 10, 3, 1),
        (17, 2, 3, 2), (16, 4, 5, 2), (17, 6, 3, 2), (17, 8, 1, 2), (19, 8, 1, 2), (16, 10, 2, 1), (19, 10, 2, 1)]
# "3BL" on a 56 x 7 grid (x 0..19), then "_INDIE" in cyan (x 21..56)
LETTERS_ORANGE = [(0, 0, 5, 1), (4, 1, 1, 5), (1, 3, 3, 1), (0, 6, 5, 1),
                  (7, 0, 1, 7), (7, 0, 4, 1), (10, 1, 2, 2), (7, 3, 4, 1), (10, 4, 2, 2), (7, 6, 4, 1),
                  (14, 0, 1, 7), (14, 6, 5, 1)]
LETTERS_CYAN = [(21, 6, 4, 1),
                (27, 0, 3, 1), (28, 1, 1, 5), (27, 6, 3, 1),
                (32, 0, 1, 7), (36, 0, 1, 7), (33, 1, 1, 2), (34, 3, 1, 1), (35, 4, 1, 2),
                (39, 0, 1, 7), (39, 0, 4, 1), (42, 1, 2, 5), (39, 6, 4, 1),
                (46, 0, 3, 1), (47, 1, 1, 5), (46, 6, 3, 1),
                (51, 0, 1, 7), (51, 0, 5, 1), (51, 3, 4, 1), (51, 6, 5, 1)]


def _rects(d, rects, ox, oy, px, colour):
    for x, y, w, h in rects:
        d.rectangle([ox + x * px, oy + y * px, ox + (x + w) * px - 1, oy + (y + h) * px - 1], fill=colour)


def lockup_size(px, gap=None):
    """Width and height of the lockup at `px` pixels per grid cell."""
    gap = px * 2 if gap is None else gap
    return 56 * px, 11 * px + gap + 7 * px


def draw_lockup(img, cx, cy, px, glow=True, gap=None, wordmark=True):
    """Draws the lockup centred at (cx, cy) on an RGBA image. `px` is the pixel size of one cell."""
    gap = px * 2 if gap is None else gap
    w, h = lockup_size(px, gap)
    if not wordmark:
        w, h = 21 * px, 11 * px
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    top = cy - h / 2
    fx = cx - 21 * px / 2
    _rects(d, FIGS, fx, top, px, ORANGE + (255,))
    if wordmark:
        lx = cx - 56 * px / 2
        ly = top + 11 * px + gap
        _rects(d, LETTERS_ORANGE, lx, ly, px, ORANGE + (255,))
        _rects(d, LETTERS_CYAN, lx, ly, px, CYAN + (255,))
    if glow:
        g = layer.filter(ImageFilter.GaussianBlur(max(2, px * 1.2)))
        a = g.split()[3].point(lambda v: min(255, int(v * 1.2)))
        g.putalpha(a)
        img.alpha_composite(g)
    img.alpha_composite(layer)
    return w, h
