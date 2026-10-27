// The solid inside of every building, kaiju, gun and airship: near-black with a hint of the part's
// neon colour (vertex colour) and a fresnel rim so silhouettes read against the night.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 base : source_color = vec3(0.010, 0.012, 0.028);
uniform float tint_amount = 0.07;
uniform float rim_amount = 0.22;
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash = 0.0;

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	vec3 c = base + COLOR.rgb * tint * (tint_amount + rim * rim_amount);
	ALBEDO = mix(c, vec3(0.9, 0.5, 0.6), clamp(flash, 0.0, 1.0) * 0.3);
}
