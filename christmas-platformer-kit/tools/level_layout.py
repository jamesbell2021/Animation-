"""Composes the demo level as ASCII (written to tools/demo_level.txt), which the
Godot builder turns into painted TileMapLayers. Edit here, re-run, rebuild."""
from pathlib import Path
W, H = 96, 14
g = [["."] * W for _ in range(H)]
def rect(ch, x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch
def put(ch, x, y): g[y][x] = ch
def row(ch, x0, x1, y): rect(ch, x0, y, x1, y)

# --- Section 1: start, gentle steps, a gift block
rect("S", 0, 10, 15, 13)
rect("S", 11, 9, 15, 9)
put("P", 3, 9)
put("?", 7, 6)
row("*", 11, 14, 7)
# spike pit
rect("S", 16, 12, 18, 13); row("^", 16, 18, 11)
rect("S", 19, 10, 30, 13)
rect("S", 22, 8, 24, 9)
put("X", 27, 9); put("X", 28, 9); put("X", 28, 8)
row("p", 20, 23, 6); row("*", 20, 23, 5)
# --- Section 2: ice lake (slippery terrain) with a spring up to candy platforms
rect("I", 31, 10, 44, 13)
put("J", 38, 9)
row("c", 32, 38, 3); row("o", 33, 37, 2)
row("v", 41, 44, 6); rect("G", 40, 4, 45, 5)  # gingerbread overhang with icicles under it
rect("S", 45, 9, 50, 13)
rect("S", 48, 7, 50, 8)
# ladder up to a brick tower
for y in range(4, 10): put("H", 51, y)
rect("S", 51, 10, 52, 13)
rect("B", 52, 4, 56, 9); put("h", 54, 3)
# --- Section 3: freezing water with ice slabs and crumbling ice
rect("S", 53, 10, 56, 13)
rect("=", 57, 11, 70, 12); row("~", 57, 70, 10); rect("S", 57, 13, 70, 13)
row("i", 59, 61, 8); put("K", 64, 8); put("K", 65, 8); row("i", 67, 69, 7)
row("f", 59, 61, 7); put("b", 68, 6)
# --- Section 4: gingerbread village run to the North Pole
rect("G", 71, 10, 95, 13)
rect("G", 76, 8, 79, 9)
row("p", 81, 84, 7); row("d", 81, 84, 6)
put("?", 86, 6)
row("^", 88, 89, 9)
put("N", 92, 9)
rows = ["".join(r) for r in g]
Path(__file__).with_name("demo_level.txt").write_text("\n".join(rows) + "\n")
print("\n".join(rows))
