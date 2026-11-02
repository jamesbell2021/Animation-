shader_type spatial;
// A keeper seen through whatever hides them (a hut's roof, the tower, a wall), in their
// own colour: drawn over everything, but only where the scene is nearer the camera than
// the keeper, strongest at the silhouette's edge. Multiplayer only (Player.set_outline);
// playing alone, the buildings are cut away instead (Interior).
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	// Hidden: something nearer the camera than this point of the keeper (by a margin, so
	// a keeper's own arm across their chest doesn't count).
	float hidden = step(VERTEX.z + 0.25, v.z);
	float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = color.rgb;
	ALPHA = hidden * (0.2 + 0.75 * pow(rim, 1.4));
}
