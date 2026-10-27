// The shore and the city ground: dark, with faint contour lines and the street grid.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 base : source_color = vec3(0.012, 0.010, 0.024);

float coast_z(float x) { return 6.0 * sin(x * 0.013) + 4.0 * sin(x * 0.037 + 1.0); }

float line_at(float x, float width) {
	float d = abs(fract(x + 0.5) - 0.5);
	float w = fwidth(x) * width;
	return 1.0 - smoothstep(0.0, w, d);
}

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float off = wpos.z - coast_z(wpos.x);
	if (off < 0.0) {
		discard;
	}
	vec3 col = base;
	// Sand between the waterline and the seawall.
	col += vec3(0.06, 0.045, 0.02) * smoothstep(16.0, 15.0, off);
	// Contours inland.
	float contour = line_at(sqrt(max(off - 16.0, 0.0)) / 3.3, 1.0) * step(16.0, off);
	col += vec3(0.16, 0.12, 0.42) * contour * 0.5;
	// Streets in the city blocks.
	float city = step(abs(wpos.x), 380.0) * step(70.0, wpos.z) * step(wpos.z, 345.0);
	float sx = line_at((wpos.x + 16.0) / 32.0, 1.4);
	float sz = line_at((wpos.z - 67.0) / 34.0, 1.4);
	col += vec3(0.5, 0.35, 0.1) * max(sx, sz) * city * 0.35;
	ALBEDO = col;
}
