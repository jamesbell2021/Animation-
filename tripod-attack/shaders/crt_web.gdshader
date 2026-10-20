// The phosphor tube for the browser build. WebGL cannot build the screen texture's mipmaps that
// crt.gdshader blurs for its glow, so this version gathers the glow from three close rings of
// direct samples (kept within a few pixels so thin lines do not get ghost copies). Same curve,
// scanlines, vignette and flash.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float curve = 0.035;
uniform float glow = 1.8;
uniform float glow_radius = 1.0;
uniform float scanlines = 0.22;
uniform float vignette = 0.5;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	vec2 uv = 0.5 + c * (1.0 + curve * dot(c, c));
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = texture(screen_tex, uv).rgb;
		vec2 px = SCREEN_PIXEL_SIZE * glow_radius;
		vec3 g = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 d = vec2(cos(a), sin(a));
			vec2 e = vec2(cos(a + 0.3927), sin(a + 0.3927));
			g += texture(screen_tex, uv + d * px * 1.5).rgb * 0.45;
			g += texture(screen_tex, uv + e * px * 3.2).rgb * 0.35;
			g += texture(screen_tex, uv + d * px * 5.5).rgb * 0.20;
		}
		col += g / 8.0 * glow;
		float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
		col *= 1.0 - scanlines * (1.0 - line);
		float v = smoothstep(0.9, 0.3, length(c * vec2(1.0, 1.2)));
		col *= mix(1.0 - vignette, 1.0, v);
		col = mix(col, flash_color.rgb, clamp(flash, 0.0, 0.8));
		COLOR = vec4(col, 1.0);
	}
}
