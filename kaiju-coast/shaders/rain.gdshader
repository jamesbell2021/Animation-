// Rain: a fixed cloud of streaks that falls and wraps round a box centred on the camera, so it
// costs one draw call and no CPU work. Each streak is a thick-line segment (see
// thick_line.gdshaderinc); both of its ends are shifted by the same amount, worked out from the
// segment's midpoint. COLOR.a is the streak's speed factor and COLOR.b its random threshold
// against `intensity`, so lighter rain shows fewer streaks.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform;

#include "res://shaders/thick_line.gdshaderinc"

uniform vec3 box = vec3(360.0, 260.0, 360.0);
uniform vec3 cam = vec3(0.0);
uniform float fall = 0.0;          // metres fallen so far (accumulated on the CPU)
uniform vec2 wind = vec2(0.0);     // sideways drift per metre fallen
uniform float intensity = 0.0;
uniform float flash = 0.0;
uniform vec3 tint : source_color = vec3(0.45, 0.55, 0.8);

varying float vis;

void vertex() {
	vec3 a = VERTEX;
	vec3 b = vec3(UV.x, UV.y, UV2.x);
	vec3 mid = (a + b) * 0.5;
	vec3 m = mid + vec3(wind.x, -1.0, wind.y) * fall * COLOR.a;
	vec3 lo = cam - box * 0.5;
	vec3 w = lo + mod(m - lo, box);
	vec3 shift = w - mid;
	a += shift;
	b += shift;
	vec3 rel = abs(w - cam) / box;
	float edge = 1.0 - smoothstep(0.32, 0.5, max(max(rel.x, rel.z), rel.y));
	vis = intensity * edge * step(COLOR.b, intensity) * step(0.0, w.y);
	POSITION = thick_line_vertex(PROJECTION_MATRIX * VIEW_MATRIX, a, b.xy, vec2(b.z, UV2.y), VIEWPORT_SIZE);
}

void fragment() {
	ALBEDO = tint * (0.55 + flash * 2.0) * vis;
}
