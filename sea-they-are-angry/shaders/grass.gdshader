shader_type spatial;
render_mode cull_disabled;
// Valheim-style grass tufts: vertex-coloured blades that sway in a gusting wind.
// Normals point up so the field shades as one soft surface, not as cards.
// In a storm (the global "storm", 0 to 1) the grass leans hard downwind, thrashes,
// and gusts sweep across the island in bands.

uniform float sway = 0.18;
uniform float gust_speed = 1.6;
global uniform float storm;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bend = VERTEX.y * VERTEX.y * 3.0;
	float speed = gust_speed * (1.0 + storm * 1.8);
	float amp = sway * (1.0 + storm * 2.4);
	float gust = sin(TIME * speed + w.x * 0.45 + w.z * 0.3) * 0.7 + sin(TIME * 2.9 * (1.0 + storm) + w.x * 1.7 - w.z * 1.1) * 0.3;
	// A band of gust rolling across the island from the west.
	float sweep = smoothstep(0.35, 1.0, sin(TIME * 0.7 - w.x * 0.09 + w.z * 0.04)) * storm;
	float lean = storm * 0.3 + sweep * 0.55;
	VERTEX.x += (gust * amp + lean) * bend;
	VERTEX.z += (gust * amp * 0.5 + lean * 0.35) * bend;
	VERTEX.y -= lean * bend * 0.25;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	// Vertex colours are sRGB; convert to linear like a vertex_color_is_srgb material.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
