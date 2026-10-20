shader_type spatial;
// The island's ground: four tiling layers (grass, dirt, shingle, rock) blended by
// weights painted per vertex (Terrain.build_mesh). The colour comes from the painted
// vertex colours, the detail from the textures (each divided by its mean colour, so
// the palette stays as painted), and the relief from their normal maps. Grass, dirt
// and shingle are projected from above; rock is projected from all three sides
// (triplanar), so the cliffs aren't smeared.
// UV.x = rock, UV.y = shingle, UV2.x = dirt, UV2.y = wet (near the sea).

render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shingle_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shingle_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 grass_mean = vec3(0.04, 0.07, 0.01);
uniform vec3 dirt_mean = vec3(0.06, 0.035, 0.017);
uniform vec3 shingle_mean = vec3(0.13, 0.11, 0.075);
uniform vec3 rock_mean = vec3(0.07, 0.068, 0.06);
// Metres per tile.
uniform float grass_tile = 2.0;
uniform float dirt_tile = 2.0;
uniform float shingle_tile = 1.5;
uniform float rock_tile = 4.0;
uniform float detail = 0.8;          // how far the textures' own colour varies the paint
uniform float bump = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tn(sampler2D s, vec2 uv) {
	// X and Y only: Godot may keep a normal map as two channels. Z is rebuilt.
	vec2 xy = texture(s, uv).xy * 2.0 - 1.0;
	float z = sqrt(max(0.0, 1.0 - dot(xy, xy)));
	return vec3(xy * bump, z);
}

// A tangent-space normal projected from above, onto the surface (whiteout blend).
vec3 top_normal(vec3 t, vec3 n) {
	return normalize(vec3(t.x + n.x, abs(t.z) * n.y, -t.y + n.z));
}

void fragment() {
	vec3 n = normalize(wnrm);
	float w_rock = clamp(UV.x, 0.0, 1.0);
	float w_shingle = clamp(UV.y, 0.0, 1.0) * (1.0 - w_rock);
	float w_dirt = clamp(UV2.x, 0.0, 1.0) * (1.0 - w_rock) * (1.0 - w_shingle);
	float w_grass = max(0.0, 1.0 - w_rock - w_shingle - w_dirt);

	vec2 top = wpos.xz;
	vec3 ga = texture(grass_albedo, top / grass_tile).rgb / grass_mean;
	vec3 da = texture(dirt_albedo, top / dirt_tile).rgb / dirt_mean;
	vec3 sa = texture(shingle_albedo, top / shingle_tile).rgb / shingle_mean;
	vec3 gn = top_normal(tn(grass_normal, top / grass_tile), n);
	vec3 dn = top_normal(tn(dirt_normal, top / dirt_tile), n);
	vec3 sn = top_normal(tn(shingle_normal, top / shingle_tile), n);

	// Rock from three sides.
	vec3 bw = pow(abs(n), vec3(6.0));
	bw /= (bw.x + bw.y + bw.z);
	vec2 ux = wpos.zy / rock_tile;
	vec2 uy = wpos.xz / rock_tile;
	vec2 uz = wpos.xy / rock_tile;
	vec3 ra = (texture(rock_albedo, ux).rgb * bw.x + texture(rock_albedo, uy).rgb * bw.y + texture(rock_albedo, uz).rgb * bw.z) / rock_mean;
	vec3 tx = tn(rock_normal, ux);
	vec3 ty = tn(rock_normal, uy);
	vec3 tz = tn(rock_normal, uz);
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 rn = normalize(tx.zyx * bw.x + ty.xzy * bw.y + tz.xyz * bw.z);

	vec3 det = ga * w_grass + da * w_dirt + sa * w_shingle + ra * w_rock;
	det = mix(vec3(1.0), det, detail);
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = clamp(paint * det, vec3(0.0), vec3(1.0));

	vec3 nw = normalize(gn * w_grass + dn * w_dirt + sn * w_shingle + rn * w_rock + n * 0.001);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float wet = clamp(UV2.y, 0.0, 1.0);
	ROUGHNESS = mix(0.92 - 0.1 * w_shingle, 0.35, wet);
	SPECULAR = mix(0.3, 0.6, wet);
}
