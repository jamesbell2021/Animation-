// Expanding shockwave ring for explosions and muzzle flashes.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float energy = 4.0;
uniform float progress = 0.0;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float ring_r = mix(0.15, 0.95, progress);
	float w = mix(0.22, 0.03, progress);
	float ring = 1.0 - smoothstep(0.0, w, abs(r - ring_r));
	float core = (1.0 - smoothstep(0.0, 0.55, r)) * (1.0 - progress) * 1.5;
	float a = clamp((ring + core) * (1.0 - progress), 0.0, 1.0);
	ALBEDO = color.rgb * energy;
	ALPHA = a;
}
