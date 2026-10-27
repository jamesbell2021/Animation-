// The bay: rolling swell drawn as a glowing vector grid. The same three waves are evaluated in
// GDScript (World.wave_h) so splashes, blood slicks and the kaiju wade at the right height.
// Surf bands roll in on the beach, the city's neon shimmers near the shore and the blood moon
// glints off the wave faces.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.006, 0.010, 0.024);
uniform vec3 line_color : source_color = vec3(0.10, 0.45, 0.70);
uniform vec3 crest_color : source_color = vec3(0.35, 0.9, 1.0);
uniform vec3 moon_dir = vec3(0.3, 0.27, -0.92);
uniform float t = 0.0;
uniform float flat_far = 0.0;   // 1 on the far horizon plane: no waves, and discard inside the near plane
uniform vec4 near_rect = vec4(-1600.0, -1700.0, 1600.0, 0.0);

varying vec3 wpos;
varying vec3 wnorm;
varying float wh;

float coast_z(float x) { return 6.0 * sin(x * 0.013) + 4.0 * sin(x * 0.037 + 1.0); }

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = 0.0;
	vec2 g = vec2(0.0);
	if (flat_far < 0.5) {
		float a1 = p.x * 0.019 + t * 1.1;
		float a2 = p.z * 0.027 - t * 1.4;
		float a3 = (p.x + p.z) * 0.05 + t * 2.1;
		h = 1.3 * sin(a1) + 1.1 * sin(a2) + 0.6 * sin(a3);
		g.x = 1.3 * 0.019 * cos(a1) + 0.6 * 0.05 * cos(a3);
		g.y = 1.1 * 0.027 * cos(a2) + 0.6 * 0.05 * cos(a3);
	}
	VERTEX.y += h;
	wpos = p + vec3(0.0, h, 0.0);
	wh = h;
	wnorm = normalize(vec3(-g.x * 2.5, 1.0, -g.y * 2.5));
}

float line_at(float x, float width) {
	float d = abs(fract(x + 0.5) - 0.5);
	float w = fwidth(x) * width;
	return 1.0 - smoothstep(0.0, w, d);
}

void fragment() {
	vec2 xz = wpos.xz;
	if (flat_far > 0.5 && xz.x > near_rect.x && xz.x < near_rect.z && xz.y > near_rect.y && xz.y < near_rect.w) {
		discard;
	}
	float cz = coast_z(xz.x);
	if (xz.y > cz) {
		discard;
	}
	float dist = length(xz - vec2(0.0, 200.0));
	float fade = clamp(1.0 - dist / 2600.0, 0.0, 1.0);
	float crest = clamp(wh / 3.0 * 0.5 + 0.5, 0.0, 1.0);
	float grid = max(line_at(xz.x / 60.0, 1.1), line_at(xz.y / 45.0, 1.1));
	float contour = line_at(wh * 1.3, 1.0) * 0.4;
	vec3 col = deep_color;
	col += line_color * (grid * (0.45 + crest * 0.9) + contour) * fade;
	col += crest_color * smoothstep(0.82, 0.98, crest) * grid * 1.4 * fade;
	// Surf bands rolling in to the beach.
	float off = cz - xz.y;
	float surf = line_at(off / 9.0 + t * 0.35, 2.2) * smoothstep(42.0, 2.0, off);
	col += vec3(0.6, 1.0, 1.0) * surf * 1.3;
	col += vec3(0.5, 0.95, 1.0) * smoothstep(3.0, 0.0, off) * 1.5;
	// City neon shimmering near the shore.
	float near = smoothstep(180.0, 10.0, off);
	float s = sin(xz.x * 0.9 + t * 1.3 + sin(xz.y * 0.07) * 3.0) * sin(xz.y * 0.35 - t * 0.6 + wh * 2.0);
	s = pow(max(s, 0.0), 24.0);
	vec3 neon = mix(vec3(1.0, 0.25, 0.65), vec3(1.0, 0.75, 0.25), 0.5 + 0.5 * sin(xz.x * 0.013));
	col += neon * s * near * 0.5;
	// Blood moon glinting off the wave faces.
	vec3 v = normalize(wpos - CAMERA_POSITION_WORLD);
	vec3 r = reflect(v, normalize(wnorm));
	float m = dot(r, normalize(moon_dir));
	col += vec3(1.4, 0.05, 0.1) * smoothstep(0.9965, 0.9995, m) * (0.5 + crest) * fade;
	ALBEDO = col;
}
