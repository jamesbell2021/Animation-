// Night sky: violet zenith, a blood-red glow along the horizon under the moon, twinkling stars
// and the blood moon itself with a glowing rim and craters.
shader_type sky;

uniform vec3 moon_dir = vec3(0.3, 0.27, -0.92);
uniform float moon_size = 0.055;
uniform float flash = 0.0;        // lightning
uniform float storm = 0.0;        // 0..1, clouds the stars and greys the sky

float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 md = normalize(moon_dir);
	float h = d.y;
	vec3 zenith = vec3(0.012, 0.008, 0.03);
	vec3 band = vec3(0.09, 0.016, 0.045);
	float toward = pow(max(dot(normalize(vec3(d.x, 0.0, d.z)), normalize(vec3(md.x, 0.0, md.z))), 0.0), 2.0);
	vec3 col = mix(band + vec3(0.12, 0.0, 0.02) * toward, zenith, smoothstep(-0.02, 0.45, h));
	if (h < 0.0) {
		col = vec3(0.01, 0.008, 0.02);
	}
	// Stars on a direction grid.
	vec3 cell = floor(d * 260.0);
	float s = hash3(cell);
	if (s > 0.9965 && h > 0.02) {
		vec3 c = vec3(1.0);
		if (s > 0.9992) { c = vec3(1.0, 0.45, 0.75); } else if (s > 0.9985) { c = vec3(1.0, 0.8, 0.4); }
		float tw = 0.5 + 0.5 * sin(TIME * (1.0 + s * 3.0) + s * 100.0);
		vec3 f = fract(d * 260.0) - 0.5;
		col += c * (1.0 - smoothstep(0.0, 0.32, length(f))) * (0.6 + tw * 1.2);
	}
	// Blood moon.
	float a = acos(clamp(dot(d, md), -1.0, 1.0));
	float disc = 1.0 - smoothstep(moon_size - 0.002, moon_size, a);
	float rim = exp(-abs(a - moon_size) * 140.0);
	float halo = exp(-a * 7.0);
	vec3 moon = vec3(0.16, 0.025, 0.04);
	vec3 t1 = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
	vec3 t2 = cross(t1, md);
	vec2 q = vec2(dot(d, t1), dot(d, t2)) / moon_size;
	float crater = 0.0;
	crater += exp(-pow((length(q - vec2(-0.3, 0.2)) - 0.22) * 30.0, 2.0));
	crater += exp(-pow((length(q - vec2(0.35, -0.1)) - 0.16) * 30.0, 2.0));
	crater += exp(-pow((length(q - vec2(0.05, -0.45)) - 0.12) * 30.0, 2.0));
	crater += exp(-pow((length(q - vec2(0.22, 0.48)) - 0.09) * 30.0, 2.0));
	col = mix(col, moon + vec3(1.2, 0.08, 0.15) * crater * 0.5, disc);
	col += vec3(2.6, 0.18, 0.28) * rim + vec3(0.5, 0.03, 0.08) * halo;
	col = mix(col, vec3(0.028, 0.022, 0.05) + vec3(0.02, 0.0, 0.02) * toward, storm * 0.6 * smoothstep(-0.05, 0.2, h));
	col += vec3(0.55, 0.5, 0.85) * flash * smoothstep(-0.1, 0.4, h);
	COLOR = col;
}
