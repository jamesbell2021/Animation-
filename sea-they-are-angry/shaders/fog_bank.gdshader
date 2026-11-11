shader_type spatial;
// The fog bank: a glowing wall of fog that lies on the sea round the islands, lit from
// within. It keeps `gap` metres off each shore, pushes tongues up the beaches where
// something is about to land, floods over low ground when `flood` rises, and is held off
// wherever a light burns (`holes`). Drawn as a few stacked sheets (FogBank), so from the
// keepers' camera it has depth: the low sheet is the brightest, and what stands in it
// shows dark against the glow.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float density = 0.0;
uniform float layer = 0.0;          // 0 the sheet on the water, 1 the highest
uniform vec3 glow : source_color = vec3(0.50, 0.86, 0.80);
uniform vec3 deep : source_color = vec3(0.10, 0.22, 0.26);
uniform float brightness = 1.0;
uniform float gap = 60.0;
uniform float flood = 0.0;
uniform vec2 drift = vec2(0.5, 0.18);
// The Escape: the world goes past a boat that stays put, so the billows are shifted by
// this (how far she has come) while the shores and holes stay where they are.
uniform vec2 scroll = vec2(0.0);
uniform float soft = 1.2;
uniform vec4 isles[3];              // centre x, z, half extents x, z
uniform float isle_yaw[3];
uniform vec4 tongues[4];            // x, z, radius, strength
uniform vec4 holes[16];             // x, z, radius, strength
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world;

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
		p = p * 2.03 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float t = TIME;
	// The bank's body: slow billows, and a faster, finer layer that makes it roll.
	float big = fbm((p + scroll) * 0.045 + drift * t * 0.02 + vec2(layer * 13.0));
	float fine = fbm((p + scroll) * 0.16 - drift.yx * t * 0.05 + vec2(layer * 5.0, 2.0));
	float body = big * 0.7 + fine * 0.3;
	// Off every shore by `gap` metres, the edge torn by the billows.
	float off = 1.0;
	for (int i = 0; i < 3; i++) {
		vec2 q = p - isles[i].xy;
		float c = cos(-isle_yaw[i]);
		float s = sin(-isle_yaw[i]);
		q = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
		float e = length(q / max(isles[i].zw, vec2(0.1)));
		float metres = (e - 1.0) * min(isles[i].z, isles[i].w);
		float edge = gap + (big - 0.5) * 16.0 + (fine - 0.5) * 5.0 - flood * (gap + 30.0);
		off *= smoothstep(edge, edge + 9.0, metres);
	}
	float m = off;
	// Tongues up the beaches.
	for (int i = 0; i < 4; i++) {
		float d = distance(p, tongues[i].xy);
		float r = tongues[i].z * (0.75 + 0.5 * big);
		m = max(m, tongues[i].w * (1.0 - smoothstep(r * 0.45, r, d)));
	}
	// Held off by lights.
	for (int i = 0; i < 16; i++) {
		float d = distance(p, holes[i].xy);
		float r = holes[i].z * (0.85 + 0.3 * fine);
		m *= 1.0 - holes[i].w * (1.0 - smoothstep(r * 0.6, r, d));
	}
	float wisps = smoothstep(0.30, 0.62, body);
	// The higher sheets are thinner and more broken.
	float thin = mix(1.0, 0.42, layer);
	float a = m * mix(0.55 + 0.45 * wisps, wisps, layer) * thin;
	// Soft where it meets the ground and the water.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float behind = clamp((VERTEX.z - view.z) / soft, 0.0, 1.0);
	// Lit from within: the thick of it glows, slowly breathing.
	float pulse = 0.9 + 0.1 * sin(t * 0.55 + big * 6.0);
	// The shoreward edge of the bank is its brightest part (the light is behind it), so
	// whatever wades out of it is a dark shape on a bright ground.
	float rim = m * (1.0 - m) * 4.0;
	float lit = smoothstep(0.22, 0.72, body) * pulse + rim * 0.25;
	vec3 col = mix(deep, glow, clamp(lit, 0.0, 1.0)) * brightness * mix(1.0, 0.8, layer);
	col += glow * rim * 0.10 * (1.0 - layer);
	ALBEDO = col;
	ALPHA = clamp(a * density * behind, 0.0, 1.0);
}
