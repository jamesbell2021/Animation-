// Arcade CRT pass: slight barrel curve, chromatic fringe, scanlines and vignette.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float curve = 0.05;
uniform float aberration = 0.0012;
uniform float scanlines = 0.16;
uniform float vignette = 0.45;

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	vec2 uv = 0.5 + c * (1.0 + curve * dot(c, c));
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col;
		col.r = texture(screen_tex, uv + vec2(aberration, 0.0)).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - vec2(aberration, 0.0)).b;
		float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
		col *= 1.0 - scanlines * (1.0 - line);
		float v = smoothstep(0.85, 0.3, length(c * vec2(1.0, 1.15)));
		col *= mix(1.0 - vignette, 1.0, v);
		COLOR = vec4(col, 1.0);
	}
}
