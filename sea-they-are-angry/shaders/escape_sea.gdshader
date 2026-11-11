shader_type spatial;
// The open sea of the Escape (scenes/escape/): the Mary Ann stays at the origin and the
// world goes past her, so the sea's pattern is shifted by `scroll` (how far she has come,
// and how far across) while the mesh stays put. A heavy swell, whitecaps, her wake, a
// wash of foam along her sides, and the waterline cut out inside her hull. Adapted from
// sea.gdshader (the islands' sea), without the shores.

uniform vec3 deep_color : source_color = vec3(0.02, 0.05, 0.068);
uniform vec3 shallow_color : source_color = vec3(0.04, 0.1, 0.11);
uniform vec3 foam_color : source_color = vec3(0.66, 0.71, 0.70);
uniform vec2 scroll = vec2(0.0);
// Her waterline, in the mesh's own space (she lies along X): half length, half beam.
uniform vec2 boat_half = vec2(6.9, 2.0);
uniform float boat_x = 0.25;
uniform float swell = 0.22;
uniform float speed = 4.5;
uniform float night_glow = 1.0;
global uniform float storm;

varying vec3 world_pos;
varying vec3 sea_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float waves(vec2 w) {
	float sp = 1.0 + storm * 0.9;
	float h = sin(w.x * 0.35 + TIME * 0.9 * sp) * 0.6 + sin(w.y * 0.47 - TIME * 1.1 * sp) * 0.4 + sin((w.x + w.y) * 1.1 + TIME * 1.7 * sp) * 0.2;
	// Long rollers from the north-west, crossing her course.
	h += sin(w.x * 0.16 - w.y * 0.21 + TIME * 1.3) * (0.6 + storm * 1.2);
	return h;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 s = w.xz + scroll;
	// Flattened right against her, so the hull doesn't plough through a wave's crest.
	vec2 q = vec2(w.x - boat_x, w.z);
	float near = smoothstep(0.0, 3.0, length(max(abs(q) - boat_half, vec2(0.0))));
	VERTEX.y += waves(s) * swell * (0.45 + 0.55 * near);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	sea_pos = vec3(s.x, world_pos.y, s.y);
}

void fragment() {
	vec2 q = vec2(world_pos.x - boat_x, world_pos.z);
	float u = q.x / boat_half.x;
	// Inside her planking at the waterline: her hull's shape, a pointed bow.
	float bow = clamp((u - 0.35) / 0.65, 0.0, 1.0);
	if (abs(u) < 1.0 && abs(q.y) < boat_half.y * (1.0 - bow * bow) * 0.96) {
		discard;
	}
	vec2 p = sea_pos.xz;
	vec3 col = mix(shallow_color, deep_color, 0.7) * (1.0 - storm * 0.3);
	// Whitecaps, stretched along the wind and broken into lace.
	vec2 cp = vec2(p.x * 0.32 + p.y * 0.1, p.y * 0.85) + vec2(TIME * (0.15 + storm * 0.5), TIME * (0.11 + storm * 0.3));
	float lace = smoothstep(0.35, 0.8, noise(p * 3.1 + vec2(TIME * 0.4, 0.0)) * 0.6 + noise(p * 7.3 - vec2(0.0, TIME * 0.5)) * 0.4);
	float body = noise(cp) * 0.65 + noise(cp * 2.3 + vec2(5.2, 1.3)) * 0.35;
	float caps = smoothstep(0.7 - storm * 0.1, 0.95, body) * lace * (0.12 + storm * 0.3);
	// Her wash: a band of churned foam close along her sides, and the wake spreading
	// astern (to -X) in a V, broken up and fading.
	float side = max(abs(q.y) - boat_half.y * (1.0 - bow * bow), 0.0);
	float along = clamp((q.x + boat_half.x) / (boat_half.x * 2.0), 0.0, 1.0);
	float speck = noise(p * 2.4 + vec2(TIME * 0.6, -TIME * 0.3));
	float wash = (1.0 - smoothstep(0.0, 0.5 + along * 0.5, side)) * step(-boat_half.x - 0.5, q.x) * step(q.x, boat_half.x + 0.6);
	wash *= smoothstep(0.35, 0.8, speck + 0.15);
	float behind = -(q.x + boat_half.x);
	float spread = behind * 0.42 + boat_half.y;
	float vee = 1.0 - smoothstep(0.0, 1.4 + behind * 0.08, abs(abs(q.y) - spread));
	float trail = (1.0 - smoothstep(0.0, boat_half.y + behind * 0.12, abs(q.y))) * 0.8;
	float wake = max(vee, trail) * step(0.0, behind) * (1.0 - smoothstep(4.0, 26.0, behind));
	wake *= smoothstep(0.35, 0.75, noise(p * 1.7 + vec2(TIME * 0.3, 0.0)) + 0.2) * clamp(speed / 4.5, 0.0, 1.0);
	float foam = clamp(caps + wash * 0.55 + wake * 0.5, 0.0, 1.0);
	col = mix(col, foam_color, foam);
	// Small moving ripples: a normal map built from two scrolling noise fields.
	vec2 rp = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 1.3;
	float e = 0.08;
	float n0 = noise(rp + vec2(TIME * 0.35, TIME * 0.2)) + noise(rp * 2.3 - vec2(TIME * 0.5, -TIME * 0.3)) * 0.5;
	float nx = noise(rp + vec2(e, 0.0) + vec2(TIME * 0.35, TIME * 0.2)) + noise((rp + vec2(e, 0.0)) * 2.3 - vec2(TIME * 0.5, -TIME * 0.3)) * 0.5;
	float nz = noise(rp + vec2(0.0, e) + vec2(TIME * 0.35, TIME * 0.2)) + noise((rp + vec2(0.0, e)) * 2.3 - vec2(TIME * 0.5, -TIME * 0.3)) * 0.5;
	NORMAL_MAP = normalize(vec3((n0 - nx) * 2.2, (n0 - nz) * 2.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = col + fres * 0.03;
	ROUGHNESS = mix(0.3, 0.9, foam);
	// The sea's own faint glow at night: sparse, slowly pulsing specks, and her wash
	// lit up a little where it churns.
	float specks = smoothstep(0.955, 0.99, noise(p * 9.0 + vec2(TIME * 0.12, -TIME * 0.09)));
	specks *= smoothstep(0.3, 0.9, noise(p * 0.35 + vec2(TIME * 0.05, 0.0)));
	specks *= 0.5 + 0.5 * sin(TIME * 1.3 + p.x * 0.9 + p.y * 0.7);
	EMISSION = vec3(0.15, 0.8, 0.7) * (specks * 0.9 + (wash + wake) * 0.06) * night_glow;
	SPECULAR = 0.35;
	METALLIC = 0.0;
}
