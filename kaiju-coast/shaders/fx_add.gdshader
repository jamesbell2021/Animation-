// Sparks, blood, smoke rings, beams and tracers: additive, so fading is done by darkening the
// vertex colour on the CPU. Depth-tested (hidden behind solids) but never writes depth.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float energy = 2.6;

void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
