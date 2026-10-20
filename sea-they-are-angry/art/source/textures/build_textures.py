"""Builds the game's tiling surface textures: a colour map and a normal map for each.

    python3 art/source/textures/build_textures.py [out_dir]     (default art/textures)

Everything is generated from periodic noise and wrapped Voronoi cells, so every
texture tiles seamlessly. Heights are built first; the normal maps come from them
(OpenGL convention, +Y up, as Godot expects), and the colour maps are painted from
the same cells so the light and the paint agree.

    grass    meadow turf: clumps and blades                         2 m a tile
    dirt     worn earth with pebbles                                2 m
    shingle  rounded beach pebbles in sand                          1.5 m
    rock     cliff rock: strata, cracks, lichen                     4 m
    slate    roof slates: courses of overlapping slates             1 m (5 courses)
    harl     whitewashed roughcast render on stone                  1 m
    rubble   rubble stonework with lime mortar                      1.5 m
    planks   weathered vertical boards                              1 m (6 boards)

terrain.json records each ground layer's mean colour: the terrain shader takes its
colour from the painted vertex colours and its detail from these textures, divided by
their mean so the overall colour stays what the island was painted.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

N = 512
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "textures")
RNG = np.random.default_rng(7)
YY, XX = np.mgrid[0:N, 0:N] / N          # 0..1, rows (v) then columns (u)


def fbm(beta=2.0, seed=0, lo=1.0):
    """Periodic fractal noise from filtered white noise: -1..1 roughly, tiles exactly.
    beta sets the falloff (higher is smoother); lo cuts frequencies below lo."""
    r = np.random.default_rng(seed)
    white = r.standard_normal((N, N))
    f = np.fft.fftfreq(N) * N
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1.0
    amp = 1.0 / k ** (beta / 2.0)
    amp[k < lo] = 0.0
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    return out / (np.abs(out).max() + 1e-9)


def stretched(sx, sy, seed, beta=2.0):
    """Noise squashed along one axis (grain, blades): sample a finer field."""
    r = np.random.default_rng(seed)
    white = r.standard_normal((N, N))
    f = np.fft.fftfreq(N) * N
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt((fx * sx) ** 2 + (fy * sy) ** 2)
    k[0, 0] = 1.0
    out = np.real(np.fft.ifft2(np.fft.fft2(white) / k ** (beta / 2.0)))
    return out / (np.abs(out).max() + 1e-9)


def voronoi(n_points, seed, jitter=1.0, aspect=(1.0, 1.0), warp=None):
    """Wrapped Voronoi on the unit tile: F1, F2 distances and the nearest cell's id.
    Points come from a jittered grid so the cells are even."""
    r = np.random.default_rng(seed)
    g = int(np.ceil(np.sqrt(n_points)))
    pts = []
    for j in range(g):
        for i in range(g):
            pts.append(((i + 0.5 + (r.random() - 0.5) * jitter) / g, (j + 0.5 + (r.random() - 0.5) * jitter) / g))
    pts = np.array(pts) % 1.0
    f1 = np.full((N, N), 9.0)
    f2 = np.full((N, N), 9.0)
    cid = np.zeros((N, N), dtype=np.int32)
    ax, ay = aspect
    U, V = (XX, YY) if warp is None else (XX + warp[0], YY + warp[1])
    for idx, (px, py) in enumerate(pts):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                dx = (U - (px + ox)) * ax
                dy = (V - (py + oy)) * ay
                d = np.sqrt(dx * dx + dy * dy)
                closer = d < f1
                f2 = np.where(closer, f1, np.minimum(f2, d))
                cid = np.where(closer, idx, cid)
                f1 = np.where(closer, d, f1)
    return f1, f2, cid, len(pts)


def cell_rand(cid, n, seed):
    r = np.random.default_rng(seed)
    return r.random(n)[cid]


def normal_map(h, strength):
    """Normals from a periodic height field (height in tile widths x strength)."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * N * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * N * strength
    # Rows run down the image; OpenGL's +Y (green) points up it.
    nx, ny, nz = -dx, dy, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], axis=-1)
    return ((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)


def ramp(t, *stops):
    """Colour along a ramp of (position, (r, g, b)) stops, t in 0..1, linear in sRGB."""
    t = np.clip(t, 0.0, 1.0)
    out = np.zeros(t.shape + (3,))
    pos = [s[0] for s in stops]
    cols = [np.array(s[1], dtype=float) for s in stops]
    for i in range(len(stops) - 1):
        a, b = pos[i], pos[i + 1]
        m = (t >= a) & (t <= b)
        k = ((t - a) / max(b - a, 1e-6))[..., None]
        out = np.where(m[..., None], cols[i] * (1 - k) + cols[i + 1] * k, out)
    out = np.where((t < pos[0])[..., None], cols[0], out)
    out = np.where((t > pos[-1])[..., None], cols[-1], out)
    return out


def save(name, albedo, height, strength):
    os.makedirs(OUT, exist_ok=True)
    a = (np.clip(albedo, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(a, "RGB").save(os.path.join(OUT, f"{name}_albedo.png"), optimize=True)
    Image.fromarray(normal_map(height, strength), "RGB").save(os.path.join(OUT, f"{name}_normal.png"), optimize=True)
    mean = a.reshape(-1, 3).mean(axis=0) / 255.0
    print(f"TEXTURE {name}: mean colour {mean.round(3).tolist()}")
    return mean.tolist()


def shade(albedo, height, k=0.35):
    """Bake a little of the relief into the paint (cavities darker), like hand-painted textures."""
    h = (height - height.min()) / (np.ptp(height) + 1e-9)
    return albedo * (1.0 - k + k * h)[..., None]


# ---------------------------------------------------------------- ground

def grass():
    clumps = fbm(2.6, 1)
    blades = stretched(1.0, 5.0, 2, 1.2) * 0.6 + stretched(5.0, 1.0, 3, 1.2) * 0.4
    fine = fbm(0.8, 4)
    h = clumps * 0.5 + blades * 0.35 + fine * 0.15
    t = 0.5 + clumps * 0.35 + blades * 0.2
    col = ramp(t, (0.0, (0.16, 0.24, 0.09)), (0.5, (0.27, 0.36, 0.13)), (0.85, (0.40, 0.45, 0.19)), (1.0, (0.52, 0.52, 0.27)))
    dry = fbm(3.0, 5) > 0.45
    col = np.where(dry[..., None], col * 0.6 + np.array([0.45, 0.40, 0.22]) * 0.4, col)
    return save("grass", shade(col, h, 0.3), h, 0.012)


def dirt():
    base = fbm(2.4, 11)
    f1, f2, cid, n = voronoi(400, 12)
    stones = (cell_rand(cid, n, 13) > 0.8) & (f1 < 0.01)
    dome = np.where(stones, np.sqrt(np.clip(1 - (f1 / 0.012) ** 2, 0, 1)), 0.0)
    crack = np.clip(1.0 - (f2 - f1) / 0.004, 0, 1) * (fbm(2.0, 14) > 0.2)
    h = base * 0.4 + fbm(1.0, 15) * 0.15 + dome * 0.6 - crack * 0.2
    col = ramp(0.5 + base * 0.4, (0.0, (0.22, 0.16, 0.10)), (0.5, (0.33, 0.25, 0.16)), (1.0, (0.45, 0.36, 0.24)))
    col = np.where(stones[..., None], ramp(cell_rand(cid, n, 16), (0.0, (0.30, 0.27, 0.23)), (1.0, (0.44, 0.40, 0.34))) * (0.75 + 0.25 * dome[..., None]), col)
    return save("dirt", shade(col, h, 0.25), h, 0.02)


def shingle():
    f1, f2, cid, n = voronoi(900, 21, jitter=0.9)
    size = 0.5 * (f1 + f2) * 0.0 + 0.016
    r = cell_rand(cid, n, 22)
    rad = 0.012 + r * 0.008
    dome = np.sqrt(np.clip(1 - (f1 / rad) ** 2, 0, 1))
    edge = np.clip((f2 - f1) / 0.004, 0, 1)
    peb = dome * edge
    h = peb * (0.7 + 0.3 * r) + fbm(0.6, 23) * 0.05
    tone = cell_rand(cid, n, 24)
    pcol = ramp(tone, (0.0, (0.33, 0.32, 0.30)), (0.4, (0.52, 0.49, 0.44)), (0.75, (0.66, 0.60, 0.50)), (1.0, (0.45, 0.38, 0.30)))
    sand = ramp(0.5 + fbm(1.5, 25) * 0.5, (0.0, (0.48, 0.43, 0.33)), (1.0, (0.62, 0.56, 0.43)))
    k = np.clip(peb * 3.0, 0, 1)[..., None]
    col = sand * (1 - k) + pcol * (0.8 + 0.2 * dome[..., None]) * k
    return save("shingle", shade(col, h, 0.35), h, 0.03)


def rock():
    warp = fbm(3.0, 31) * 0.08
    strata = np.sin((YY + warp) * 2 * np.pi * 7) * 0.5 + np.sin((YY + warp * 1.7) * 2 * np.pi * 19) * 0.25
    # Blocks broken along the bedding: wide, warped cells, thin irregular cracks.
    f1, f2, cid, n = voronoi(16, 32, aspect=(0.6, 1.8), warp=(fbm(2.6, 38) * 0.06, fbm(2.6, 39) * 0.03))
    cracks = np.clip(1.0 - (f2 - f1) / 0.005, 0, 1) * (0.5 + 0.5 * (fbm(2.0, 40) > -0.3))
    blocks = cell_rand(cid, n, 33)
    base = fbm(2.2, 34)
    h = base * 0.5 + strata * 0.25 + blocks * 0.15 - cracks * 0.4 + fbm(0.9, 35) * 0.1
    col = ramp(0.5 + base * 0.35 + blocks * 0.12 + strata * 0.08 - 0.06, (0.0, (0.20, 0.20, 0.20)), (0.5, (0.36, 0.35, 0.33)), (1.0, (0.52, 0.50, 0.46)))
    col = col * (1.0 - cracks[..., None] * 0.45)
    lichen = (fbm(2.0, 36) > 0.35) & (fbm(1.0, 37) > -0.1)
    col = np.where(lichen[..., None], col * 0.5 + np.array([0.52, 0.52, 0.36]) * 0.5, col)
    return save("rock", shade(col, h, 0.3), h, 0.03)


# ---------------------------------------------------------------- buildings

def slate():
    courses = 5                     # a course every 20 cm
    per_row = 3                     # slates about 33 cm wide
    row = np.floor(YY * courses)
    t = YY * courses - row          # 0 at the top of a course, 1 at its exposed bottom edge
    shift = (row % 2) * 0.5 / per_row
    u = (XX + shift) % 1.0
    col_i = np.floor(u * per_row)
    s = u * per_row - col_i
    sid = (row * 7 + col_i * 13).astype(int) % 997
    rnd = np.random.default_rng(41).random(997)
    rnd2 = np.random.default_rng(42).random(997)
    tilt = (rnd[sid] - 0.5) * 0.15
    # Each slate thickens toward its lower edge (it lies over the course below), with a
    # dark joint between neighbours and a shadowed lip.
    h = t * 0.6 + tilt * (s - 0.5) + fbm(1.2, 43) * 0.05
    joint = np.clip(1.0 - np.minimum(s, 1 - s) / 0.02, 0, 1)
    lip = np.clip((t - 0.93) / 0.07, 0, 1)
    h = h - joint * 0.25 - lip * 0.6
    chip = (rnd2[sid] > 0.85) & (t > 0.8) & (np.abs(s - rnd[sid]) < 0.12)
    h = np.where(chip, h - 0.2, h)
    tone = rnd[sid]
    col = ramp(tone, (0.0, (0.17, 0.19, 0.22)), (0.5, (0.24, 0.26, 0.30)), (0.8, (0.28, 0.27, 0.31)), (1.0, (0.33, 0.33, 0.35)))
    col = col * (0.85 + 0.2 * fbm(1.4, 44)[..., None] * 0.5 + 0.1)
    col = col * (1.0 - joint[..., None] * 0.6) * (1.0 - lip[..., None] * 0.5)
    moss = (fbm(2.6, 45) > 0.55) & (t > 0.5)
    col = np.where(moss[..., None], col * 0.4 + np.array([0.33, 0.38, 0.16]) * 0.6, col)
    return save("slate", col, h, 0.02)


def harl():
    # Roughcast lime render, whitewashed: fine pebbly lumps over faintly showing stones.
    lumps = fbm(0.4, 51)
    f1, f2, cid, n = voronoi(30, 52, aspect=(1.0, 1.5))
    stones = np.clip((f2 - f1) / 0.03, 0, 1)
    h = lumps * 0.35 + stones * 0.12 + fbm(2.5, 53) * 0.1
    grime = fbm(3.0, 54)
    col = ramp(0.6 + grime * 0.3 + lumps * 0.1, (0.0, (0.66, 0.65, 0.61)), (0.6, (0.88, 0.87, 0.83)), (1.0, (0.96, 0.95, 0.92)))
    streak = stretched(6.0, 1.0, 55, 1.5)
    col = col * (1.0 - np.clip(streak - 0.4, 0, 1)[..., None] * 0.25)
    return save("harl", col, h, 0.012)


def rubble():
    f1, f2, cid, n = voronoi(36, 61, jitter=0.8, aspect=(0.75, 1.0))
    mortar = np.clip(1.0 - (f2 - f1) / 0.025, 0, 1)
    face = cell_rand(cid, n, 62)
    dome = np.clip((f2 - f1) / 0.08, 0, 1) ** 0.5
    h = dome * 0.6 + fbm(1.0, 63) * 0.12 + face * 0.1 - mortar * 0.3
    col = ramp(face * 0.8 + fbm(2.0, 64) * 0.2, (0.0, (0.30, 0.29, 0.27)), (0.5, (0.44, 0.42, 0.38)), (1.0, (0.56, 0.52, 0.45)))
    lime = np.array([0.62, 0.60, 0.55])
    col = col * (1 - mortar[..., None]) + lime * mortar[..., None] * (0.85 + 0.15 * fbm(0.8, 65)[..., None])
    return save("rubble", shade(col, h, 0.3), h, 0.025)


def planks():
    boards = 6
    b = np.floor(XX * boards)
    s = XX * boards - b
    rnd = np.random.default_rng(71).random(boards)
    grain = stretched(1.0, 12.0, 72, 1.6) * 0.6 + stretched(1.0, 30.0, 73, 1.2) * 0.4
    gap = np.clip(1.0 - np.minimum(s, 1 - s) / 0.03, 0, 1)
    knots = (fbm(3.4, 74) > 0.7)
    h = grain * 0.25 + rnd[b.astype(int)][...] * 0.1 - gap * 0.6 + np.where(knots, -0.1, 0.0)
    tone = 0.5 + grain * 0.3 + (rnd[b.astype(int)] - 0.5) * 0.4
    col = ramp(tone, (0.0, (0.28, 0.24, 0.20)), (0.5, (0.45, 0.40, 0.34)), (1.0, (0.60, 0.56, 0.49)))
    col = col * (1.0 - gap[..., None] * 0.7)
    nails = np.zeros_like(h)
    for row_y in (0.12, 0.62):
        d = np.sqrt(((s - 0.5) / boards) ** 2 + (YY - row_y) ** 2)
        nails = np.maximum(nails, np.clip(1 - d / 0.004, 0, 1))
    col = col * (1 - nails[..., None]) + np.array([0.20, 0.14, 0.10]) * nails[..., None]
    return save("planks", col, h, 0.02)


if __name__ == "__main__":
    means = {"grass": grass(), "dirt": dirt(), "shingle": shingle(), "rock": rock()}
    for f in (slate, harl, rubble, planks):
        f()
    with open(os.path.join(OUT, "terrain.json"), "w") as fh:
        json.dump(means, fh, indent=1)
    print("WROTE", os.path.abspath(OUT))
