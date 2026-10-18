shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Soft lamp beam: bright at the lantern, fading along its length and toward its
// silhouette edges, so it reads as light in fog rather than a solid cone.

uniform vec3 beam_color : source_color = vec3(1.0, 0.78, 0.45);
uniform float intensity = 0.35;

void fragment() {
	// CylinderMesh UV.y runs 0 at the top cap (the apex, at the lantern) to 1 at the base.
	float along = 1.0 - smoothstep(0.0, 1.0, UV.y);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.0, 0.6, facing);
	ALBEDO = beam_color;
	ALPHA = intensity * along * along * edge;
}
