// Unshaded vertex-coloured lines and glow solids pushed above 1.0 so the WorldEnvironment glow
// blooms them. `tint` recolours a whole mesh, `flash` whites it out on a hit, `pulse` > 0 makes it
// throb (charging breath, eyes).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float energy = 2.4;
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash = 0.0;
uniform float pulse = 0.0;
uniform float pulse_speed = 6.0;

void fragment() {
	float p = 1.0 + pulse * sin(TIME * pulse_speed);
	vec3 c = COLOR.rgb * tint * energy * p;
	ALBEDO = mix(c, vec3(energy * 1.3), clamp(flash, 0.0, 1.0) * 0.8);
}
