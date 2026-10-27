// The airship's searchlight: additive cone fading along its length (UV.y) and at the edges.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.85, 0.9, 1.0);
uniform float strength = 0.16;

void fragment() {
	float along = 1.0 - UV.y;
	float rim = pow(abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = tint * strength * (0.25 + along) * rim;
}
