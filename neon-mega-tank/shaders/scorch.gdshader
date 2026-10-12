// Crater mark left on the ground after an explosion.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 rim : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float fade = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float jag = 0.85 + 0.08 * sin(ang * 7.0) + 0.05 * sin(ang * 13.0);
	float disc = 1.0 - smoothstep(jag - 0.08, jag, r);
	float edge = smoothstep(jag - 0.2, jag - 0.08, r) * disc;
	ALBEDO = rim.rgb * edge * 1.6;
	ALPHA = disc * fade * 0.9;
}
