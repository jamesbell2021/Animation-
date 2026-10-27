// Spark, blood and smoke-ring lines: thick, additive, depth-tested but never writing depth.
// Fading is done by darkening the vertex colour on the CPU.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

#include "res://shaders/thick_line.gdshaderinc"

uniform float energy = 2.6;

void vertex() {
	POSITION = thick_line_vertex(PROJECTION_MATRIX * MODELVIEW_MATRIX, VERTEX, UV, UV2, VIEWPORT_SIZE);
}

void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
