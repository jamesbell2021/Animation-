shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Soft lamp beam: bright at the lantern, fading along its length and toward its
// silhouette edges, so it reads as light in fog rather than a solid cone.

uniform vec3 beam_color : source_color = vec3(1.0, 0.78, 0.45);
uniform float intensity = 0.35;
// In a storm, rain shows falling through the beam: sparse bright dashes.
global uniform float storm;

varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// CylinderMesh UV.y runs 0 at the top cap (the apex, at the lantern) to 1 at the base.
	float along = 1.0 - smoothstep(0.0, 1.0, UV.y);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.0, 0.6, facing);
	ALBEDO = beam_color;
	vec2 cell = floor(vec2(wp.x + wp.y * 0.18, wp.z) * 6.0);
	float h = hash(cell);
	float drop = fract(wp.y * 0.45 + TIME * 3.4 + h * 13.0);
	float rain = step(0.82, h) * smoothstep(0.0, 0.03, drop) * (1.0 - smoothstep(0.03, 0.2, drop));
	ALPHA = intensity * along * edge * (along + rain * storm * 2.5);
}
