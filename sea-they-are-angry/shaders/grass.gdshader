shader_type spatial;
render_mode cull_disabled;
// Valheim-style grass tufts: vertex-coloured blades that sway in a gusting wind.
// Normals point up so the field shades as one soft surface, not as cards.

uniform float sway = 0.18;
uniform float gust_speed = 1.6;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bend = VERTEX.y * VERTEX.y * 3.0;
	float gust = sin(TIME * gust_speed + w.x * 0.45 + w.z * 0.3) * 0.7 + sin(TIME * 2.9 + w.x * 1.7 - w.z * 1.1) * 0.3;
	VERTEX.x += gust * sway * bend;
	VERTEX.z += gust * sway * bend * 0.5;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	// Vertex colours are sRGB; convert to linear like a vertex_color_is_srgb material.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
