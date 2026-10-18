// The phosphor tube: glow from blurred mips of the screen, a slight barrel curve, scanlines,
// a vignette and the white/red flash the game triggers on explosions and hits.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float curve = 0.035;
uniform float glow = 1.1;
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
		vec3 g = textureLod(screen_tex, uv, 2.0).rgb * 0.7 + textureLod(screen_tex, uv, 3.5).rgb * 0.9;
		col += g * glow;
		float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
		col *= 1.0 - scanlines * (1.0 - line);
		float v = smoothstep(0.9, 0.3, length(c * vec2(1.0, 1.2)));
		col *= mix(1.0 - vignette, 1.0, v);
		col = mix(col, flash_color.rgb, clamp(flash, 0.0, 0.8));
		COLOR = vec4(col, 1.0);
	}
}
