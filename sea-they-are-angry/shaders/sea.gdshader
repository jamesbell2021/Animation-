shader_type spatial;
// Cheap North Sea: two layered swells, shallow-to-deep colour by distance from
// the island, a broken foam band on the shoreline, and a fresnel sheen.

uniform vec3 deep_color : source_color = vec3(0.03, 0.09, 0.11);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.20, 0.19);
uniform vec3 foam_color : source_color = vec3(0.66, 0.71, 0.70);
uniform float shore_radius = 13.2;
uniform float foam_width = 0.4;
uniform float swell = 0.09;

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

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float r = length(w.xz);
	// Swells calm down as they reach the beach.
	float calm = smoothstep(12.5, 18.0, r) * 0.7 + 0.3;
	float h = sin(w.x * 0.35 + TIME * 0.9) * 0.6 + sin(w.z * 0.47 - TIME * 1.1) * 0.4 + sin((w.x + w.z) * 1.1 + TIME * 1.7) * 0.2;
	VERTEX.y += h * swell * calm;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(world_pos.xz);
	float depth = smoothstep(shore_radius, shore_radius + 9.0, r);
	vec3 col = mix(shallow_color, deep_color, depth);
	// Foam: a band at the shoreline that breathes in and out, broken up by noise.
	float edge = shore_radius + sin(TIME * 0.7 + atan(world_pos.z, world_pos.x) * 3.0) * 0.25;
	float band = 1.0 - smoothstep(0.0, foam_width, abs(r - edge));
	float speck = noise(world_pos.xz * 2.2 + vec2(TIME * 0.3, -TIME * 0.2));
	float foam = band * smoothstep(0.35, 0.75, speck + band * 0.35);
	// Sparse whitecaps out at sea.
	float caps = smoothstep(0.91, 0.98, noise(world_pos.xz * 0.6 + vec2(TIME * 0.15, TIME * 0.11))) * depth * 0.5;
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
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
