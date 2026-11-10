shader_type spatial;
// Fire: soft, turbulent flame tongues that glow in a dark, realistically lit scene (it
// replaced the old coarse pixel fire). Value noise rising through the flame warps its
// shape into licking tongues and eats it away towards the tip; a colour ramp by heat runs
// from yellow-white at the core and base through orange to deep red at the tips, with a
// thin dark smoke where the tongues break up. Unshaded and nearly additive, so it glows
// (the hottest parts go over 1.0 for the glow to bloom) without piling up into a white
// blob where flames overlap. Every edge fades out, and the flame fades where it meets the
// ground (proximity fade), so neither the quad nor a line on the paving shows. Three shapes:
//   mode 0: a flame standing up from its base (burning creatures, the fire pools), turned
//           to face the camera about the vertical and leaned back a little, so it stays
//           upright on screen;
//   mode 1: the flamer's jet, laid along the node's Y axis from the nozzle and turned
//           about that axis to face the camera, rushing outward;
//   mode 2: a rolling billow (GPU particles), facing the camera, burning down to smoke as
//           it ages.
// No pixel grid any more: `pixels` is still accepted but unused.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform int mode = 0;
// Unused: the old pixel fire's grid. Still accepted so callers needn't change.
uniform vec2 pixels = vec2(14.0, 22.0);
uniform float speed = 1.0;
uniform float brightness = 1.0;
// The jet's length so far (0 to 1): it shoots out when lit and dies back when stopped.
uniform float reach = 1.0;
// How far (metres) the flame fades out before it meets the ground or a wall.
uniform float soft_reach = 0.25;
uniform vec3 smoke_colour : source_color = vec3(0.025, 0.022, 0.02);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// Per thing burning: a seed so no two flames match, and how far it has died down.
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;

varying float age;
varying float pseed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Three octaves, rotated between them so the grid of the value noise never lines up.
float fbm(vec2 p) {
	const mat2 R = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = vnoise(p) * 0.5;
	p = R * p * 2.03 + vec2(3.1, 1.7);
	v += vnoise(p) * 0.3;
	p = R * p * 2.01 + vec2(5.3, 8.9);
	v += vnoise(p) * 0.2;
	return v;
}

void vertex() {
	age = 0.0;
	pseed = 0.0;
	if (mode == 1) {
		// Along the node's Y (the jet's line), turned about it to face the camera.
		vec3 axis = MODEL_MATRIX[1].xyz;
		vec3 centre = MODEL_MATRIX[3].xyz;
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - centre);
		vec3 side = normalize(cross(normalize(axis), to_cam)) * length(MODEL_MATRIX[0].xyz);
		vec3 facing = normalize(cross(side, axis));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(axis, 0.0), vec4(facing, 0.0), vec4(centre, 1.0));
	} else if (mode == 2) {
		// A particle, square to the camera, keeping its size.
		mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		age = INSTANCE_CUSTOM.y;
		pseed = float(INSTANCE_ID) * 7.31;
	} else {
		// Upright, turned about the vertical to face the camera, and leaned back from its
		// foot by half the camera's pitch: it still stands upright on screen, but seen from
		// the game's high camera it isn't squashed short.
		vec3 up = normalize(mix(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[1].xyz, 0.5));
		vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
		vec3 back = normalize(cross(right, up));
		float wide = length(MODEL_MATRIX[0].xyz);
		float tall = length(MODEL_MATRIX[1].xyz);
		vec3 foot = MODEL_MATRIX[3].xyz - vec3(0.0, tall * 0.5, 0.0);
		// Brought towards the camera along the line of sight (so it stays where it was on
		// screen) until it stands clear of the middle by four tenths of its width, so a
		// burning creature's flames lick up its front and aren't half hidden in its body.
		vec3 eye = normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
		vec3 at = foot + up * tall * 0.5 + eye * wide * 0.4 / max(length(eye.xz), 0.4);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * wide, 0.0), vec4(up * tall, 0.0), vec4(back, 0.0), vec4(at, 1.0));
	}
}

// Colour by heat (0 to 1): deep red at the tips, orange, yellow, yellow-white at the core.
// Hotter is brighter too, so the cool tips sink into the dark.
vec3 ramp(float h) {
	vec3 c = mix(vec3(0.3, 0.025, 0.01), vec3(0.8, 0.12, 0.02), smoothstep(0.0, 0.3, h));
	c = mix(c, vec3(1.0, 0.36, 0.05), smoothstep(0.25, 0.55, h));
	c = mix(c, vec3(1.0, 0.62, 0.16), smoothstep(0.5, 0.8, h));
	c = mix(c, vec3(1.0, 0.8, 0.46), smoothstep(0.8, 1.0, h));
	return c * mix(0.7, 1.35, h * h);
}

void fragment() {
	float sd = seed * 17.31 + pseed + float(mode) * 3.7;
	float t = TIME * speed;
	float u = UV.x - 0.5;
	float v = 1.0 - UV.y;
	float heat = 0.0;
	float smoke = 0.0;
	if (mode == 1) {
		// The jet: v from the nozzle (0) out to its end (1), fanning out and tearing into
		// tongues, the fire rushing outward along it.
		float along = v / max(reach, 0.05);
		float c1 = smoothstep(0.22, 0.78, fbm(vec2(u * 3.0 + sd, along * 4.0 - t * 5.5)));
		float c2 = smoothstep(0.22, 0.78, fbm(vec2(u * 7.0 - sd, along * 10.0 - t * 9.0)));
		float x = u + (c1 - 0.5) * 0.3 * along;
		float halfw = mix(0.06, 0.42, pow(clamp(along, 0.0, 1.0), 0.65));
		float body = clamp(1.0 - abs(x) / halfw, 0.0, 1.0);
		heat = body * 1.2 - along * 0.5;
		heat -= (1.0 - c2) * (0.1 + along * 0.6);
		heat -= (1.0 - c1) * 0.3 * along;
		heat *= smoothstep(1.0, 0.75, along + (c2 - 0.5) * 0.25);
		// It rolls into smoke at its end.
		smoke = smoothstep(0.5, 0.85, along) * smoothstep(1.0, 0.85, along) * clamp(1.0 - abs(x) / (halfw * 1.1), 0.0, 1.0) * c1;
		heat *= smoothstep(0.0, 0.04, along);
	} else if (mode == 2) {
		// A billow: a ragged ball of fire cooling into smoke as it ages.
		vec2 p = vec2(u, v - 0.5) * 2.0;
		float n1 = fbm(p * 1.2 + vec2(sd, sd * 0.7 - t * 2.0));
		float n2 = fbm(p * 2.4 + vec2(-sd, -t * 3.0));
		float r = length(p + (vec2(n1, n2) - 0.5) * 0.8);
		float puff = clamp(1.0 - r, 0.0, 1.0) * smoothstep(1.0, 0.75, length(p));
		float c2 = smoothstep(0.22, 0.78, n2);
		heat = puff * 1.5 * (1.0 - age * 1.1) - (1.0 - c2) * 0.4 - age * 0.15;
		smoke = smoothstep(0.0, 0.5, puff) * smoothstep(0.3, 0.75, age) * (1.0 - age) * n1 * 1.6;
	} else {
		// A flame standing on its base: a wide, hot foot narrowing to licking tongues.
		float n1 = fbm(vec2(u * 3.0 + sd, v * 2.2 - t * 2.2));
		float c1 = smoothstep(0.2, 0.8, n1);
		float c2 = smoothstep(0.2, 0.8, fbm(vec2(u * 6.0 - sd, v * 5.0 - t * 3.8)));
		// Licking and swaying more the higher it goes.
		float x = u + (c1 - 0.5) * 0.45 * v + sin(t * 1.3 + sd + v * 3.0) * 0.04 * v;
		float vy = v + (c2 - 0.5) * 0.08;
		float halfw = 0.46 * pow(clamp(1.0 - vy, 0.0, 1.0), 0.45);
		float body = clamp(1.0 - pow(abs(x) / max(halfw, 0.001), 1.6), 0.0, 1.0);
		heat = body * 1.25 - vy * 0.5;
		heat -= (1.0 - c2) * (0.12 + vy * 0.75);
		heat -= (1.0 - c1) * 0.3 * vy;
		// A thin smoke rising off the tongues.
		float sx = u + (n1 - 0.5) * 0.35;
		smoke = smoothstep(0.4, 0.8, v) * smoothstep(1.0, 0.8, v) * clamp(1.0 - abs(sx) / 0.32, 0.0, 1.0) * (1.0 - c2);
		// Fade into the ground at a ragged bottom edge.
		heat *= smoothstep(0.0, 0.17, v + (c2 - 0.5) * 0.08);
	}
	heat *= fade;
	smoke *= fade;
	// Every edge of the quad fades to nothing.
	float edge = smoothstep(0.5, 0.42, abs(u)) * smoothstep(0.0, 0.05, v) * smoothstep(1.0, 0.94, v);
	// Soft where it meets the ground or a wall.
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	behind.xyz /= behind.w;
	float soft = clamp((VERTEX.z - behind.z) / soft_reach, 0.0, 1.0);
	if (mode == 0) {
		// A standing flame only meets the ground low down: higher up, what's just behind
		// it is the creature it's burning on, which mustn't fade it.
		soft = mix(soft, 1.0, smoothstep(0.12, 0.3, v));
	}
	edge *= soft;
	float h = clamp(heat, 0.0, 1.0);
	float flame = smoothstep(0.0, 0.25, heat) * edge;
	// A dark, thin smoke where the flame isn't.
	float sm = smoke * (1.0 - flame) * 0.55 * edge;
	// The flame covers what's behind it only a little (so flames over flames don't pile
	// up into a white blob) and its light is divided by that cover, so the blend comes
	// out nearly additive: the fire adds light. Done in blend_mix rather than additive or
	// premultiplied blending because Godot mixes the fog into ALBEDO before blending: this
	// way the fog dims the fire with distance and adds nothing where there's no flame.
	float cover = clamp(flame * 0.45 + sm, 0.0, 1.0);
	ALBEDO = (ramp(h) * brightness * flame + smoke_colour * sm) / max(cover, 0.001);
	ALPHA = cover;
}
