shader_type spatial;
// Cheap North Sea: two layered swells, shallow-to-deep colour by distance from
// the island, a broken foam band on the shoreline, and a fresnel sheen.
// In a storm (the global "storm", 0 to 1) the swell heaves, the water darkens,
// whitecaps spread across it and the surf at the cliffs widens and churns.

uniform vec3 deep_color : source_color = vec3(0.03, 0.09, 0.11);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.20, 0.19);
uniform vec3 foam_color : source_color = vec3(0.66, 0.71, 0.70);
uniform float shore_radius = 16.6;
// The holm's shore: a rounded box (Terrain.HOLM_*), its waterline a little past the clifftop.
uniform vec2 holm_c = vec2(48.5, 3.0);
uniform vec2 holm_half = vec2(16.5, 13.5);
uniform float holm_round = 5.0;
uniform float holm_shore = 1.1;
uniform float foam_width = 0.4;
uniform float swell = 0.09;
// 0 by day, 1 at night: faint bioluminescent specks in the swell.
uniform float night_glow = 0.0;
global uniform float storm;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// How far out from the nearest shore (the main island's ring, or the holm's): negative ashore.
float shore_dist(vec2 p) {
	float main_d = length(p) - shore_radius;
	vec2 q = abs(p - holm_c) - (holm_half - vec2(holm_round));
	float holm_d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - holm_round - holm_shore;
	return min(main_d, holm_d);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Swells calm down as they reach the beach.
	float calm = smoothstep(-0.6, 5.4, shore_dist(w.xz)) * 0.7 + 0.3;
	float sp = 1.0 + storm * 0.9;
	float h = sin(w.x * 0.35 + TIME * 0.9 * sp) * 0.6 + sin(w.z * 0.47 - TIME * 1.1 * sp) * 0.4 + sin((w.x + w.z) * 1.1 + TIME * 1.7 * sp) * 0.2;
	// Storm rollers: long swells marching in from the north-west.
	h += sin(w.x * 0.16 - w.z * 0.21 + TIME * 1.3) * storm * 1.6;
	VERTEX.y += h * swell * (1.0 + storm * 5.0) * calm;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float sd = shore_dist(world_pos.xz);
	float depth = smoothstep(0.0, 9.0, sd);
	vec3 col = mix(shallow_color, deep_color, depth) * (1.0 - storm * 0.35);
	// Foam: a band at the shoreline that breathes in and out, broken up by noise.
	// The storm drives it wider and further up and down the rocks.
	float edge = sin(TIME * (0.7 + storm * 1.6) + (world_pos.x + world_pos.z) * 0.35) * (0.25 + storm * 0.9);
	float band = 1.0 - smoothstep(0.0, foam_width * (1.0 + storm * 3.0), abs(sd - edge));
	float speck = noise(world_pos.xz * 2.2 + vec2(TIME * 0.3, -TIME * 0.2));
	float foam = band * smoothstep(0.35, 0.75, speck + band * 0.35);
	// Sparse whitecaps out at sea.
	float caps = smoothstep(0.91 - storm * 0.1, 0.99, noise(world_pos.xz * 0.6 + vec2(TIME * (0.15 + storm * 0.5), TIME * (0.11 + storm * 0.3)))) * depth * (0.5 + storm * 0.15);
	// Streaks of spume blown across the water.
	caps += smoothstep(0.7, 0.95, noise(vec2(world_pos.x * 0.25 + world_pos.z * 0.6, world_pos.z * 2.5) + vec2(TIME * 0.8, 0.0))) * storm * 0.12 * depth;
	col = mix(col, foam_color, clamp(foam + caps, 0.0, 1.0));
	// Small moving ripples: a normal map built from two scrolling noise fields.
	vec2 rp = world_pos.xz * 1.3;
	float e = 0.08;
	float n0 = noise(rp + vec2(TIME * 0.35, TIME * 0.2)) + noise(rp * 2.3 - vec2(TIME * 0.5, -TIME * 0.3)) * 0.5;
	float nx = noise(rp + vec2(e, 0.0) + vec2(TIME * 0.35, TIME * 0.2)) + noise((rp + vec2(e, 0.0)) * 2.3 - vec2(TIME * 0.5, -TIME * 0.3)) * 0.5;
	float nz = noise(rp + vec2(0.0, e) + vec2(TIME * 0.35, TIME * 0.2)) + noise((rp + vec2(0.0, e)) * 2.3 - vec2(TIME * 0.5, -TIME * 0.3)) * 0.5;
	NORMAL_MAP = normalize(vec3((n0 - nx) * 2.2, (n0 - nz) * 2.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = col + fres * 0.06;
	ROUGHNESS = mix(0.12, 0.85, clamp(foam + caps, 0.0, 1.0));
	// Sparse, small, slowly pulsing specks; brightest in the wake of the swell.
	float specks = smoothstep(0.955, 0.99, noise(world_pos.xz * 9.0 + vec2(TIME * 0.12, -TIME * 0.09)));
	specks *= smoothstep(0.3, 0.9, noise(world_pos.xz * 0.35 + vec2(TIME * 0.05, 0.0)));
	specks *= 0.5 + 0.5 * sin(TIME * 1.3 + world_pos.x * 0.9 + world_pos.z * 0.7);
	EMISSION = vec3(0.15, 0.8, 0.7) * specks * night_glow * 0.9;
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
