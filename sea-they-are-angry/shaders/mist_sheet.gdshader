shader_type spatial;
// A sheet of drifting mist: layered value noise moving with the wind, lit by the scene
// (the lamp's beam and the camp's lights show in it), and faded where it meets the rock
// so it never shows a hard line. Atmosphere drives `density` with the phase.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, diffuse_lambert_wrap;

uniform float density = 0.0;
uniform vec3 tint : source_color = vec3(0.72, 0.76, 0.8);
uniform vec2 drift = vec2(0.5, 0.18);
uniform float scale = 0.05;
uniform float soft = 1.4;
uniform float reach = 60.0;
uniform float seed = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz * scale + vec2(seed);
	// Two layers moving at different speeds, so it rolls rather than slides.
	float n = fbm(p + drift * TIME * 0.03);
	n = n * 0.65 + fbm(p * 1.9 - drift.yx * TIME * 0.05 + vec2(4.0)) * 0.35;
	float wisps = smoothstep(0.38, 0.78, n);
	// Soft where the sheet meets the ground or the water.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float behind = clamp((VERTEX.z - view.z) / soft, 0.0, 1.0);
	float edge = 1.0 - smoothstep(reach * 0.7, reach, length(world.xz));
	ALBEDO = tint;
	ROUGHNESS = 1.0;
	ALPHA = clamp(wisps * density * behind * edge, 0.0, 1.0);
}
