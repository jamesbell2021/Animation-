// Full-screen pass: scanlines, slight chromatic aberration, vignette, a red pulse when the city is
// being hurt and a white flash for big moments.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float aberration : hint_range(0.0, 0.01) = 0.0011;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.16;
uniform float vignette : hint_range(0.0, 2.0) = 0.85;
uniform float hurt = 0.0;
uniform float flash = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = dot(c, c);
	vec2 off = c * aberration * (1.0 + d * 6.0);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	float scan = sin(FRAGCOORD.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scan;
	col *= 1.0 - d * vignette;
	float edge = smoothstep(0.08, 0.5, d);
	col = mix(col, vec3(1.0, 0.0, 0.12), edge * hurt * (0.45 + 0.15 * sin(TIME * 8.0)));
	col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
