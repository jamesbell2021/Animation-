shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
// Pixel fire: flame drawn in coarse square pixels with a hard-stepped palette (white
// heat, yellow, orange, red, ember red, then nothing), its shape licked and torn by
// fast-scrolling noise, in the old demoscene and Doom-fire way. Three shapes:
//   mode 0: a flame standing up from its base (burning creatures, the fire pools),
//           turned to face the camera about its upright;
//   mode 1: the flamer's jet, laid along the node's Y axis from the nozzle and turned
//           about that axis to face the camera, rushing outward;
//   mode 2: a rolling billow (GPU particles), facing the camera, burning down as it ages.
// Bright enough that the glow makes it roar.

uniform int mode = 0;
// How many fire pixels across, and along.
uniform vec2 pixels = vec2(14.0, 22.0);
uniform float speed = 2.2;
uniform float brightness = 1.35;
// The jet's length so far (0 to 1): it shoots out when lit and dies back when stopped.
uniform float reach = 1.0;
// Per thing burning: a seed so no two flames match, and how far it has died down.
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;

varying float age;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.3 - 3.1) * 0.15;
}

void vertex() {
	age = 0.0;
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
	} else {
		// Upright, turned about the vertical to face the camera.
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 back = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
	}
}

// The palette, a step at a time from the edge of the flame to its heart.
vec3 palette(float h, out float a) {
	a = 1.0;
	if (h < 0.2) { a = 0.0; return vec3(0.0); }
	if (h < 0.3) return vec3(0.38, 0.05, 0.02);
	if (h < 0.42) return vec3(0.78, 0.12, 0.03);
	if (h < 0.55) return vec3(1.0, 0.36, 0.04);
	if (h < 0.68) return vec3(1.0, 0.6, 0.1);
	if (h < 0.8) return vec3(1.0, 0.82, 0.28);
	if (h < 0.95) return vec3(1.0, 0.93, 0.5);
	return vec3(1.0, 1.0, 0.85);
}

void fragment() {
	float sd = seed * 17.31 + float(mode) * 3.7;
	// Snap to the fire's pixel grid, and jitter whole rows sideways a frame at a time,
	// like the old fire did.
	vec2 px = pixels;
	vec2 cell = floor(UV * px);
	float tick = floor(TIME * 18.0);
	cell.x += floor((hash(vec2(cell.y, tick + sd)) - 0.5) * 1.6);
	vec2 q = (cell + 0.5) / px;
	float u = q.x;
	float v = 1.0 - q.y;
	float t = TIME * speed + sd;
	float side = abs(u - 0.5) * 2.0;
	float heat = 0.0;
	if (mode == 1) {
		// The jet: v from the nozzle (0) out to its end (1), fanning out and tearing into
		// tongues, the fire rushing outward along it.
		float along = v / max(reach, 0.05);
		if (along > 1.0) discard;
		float width = mix(0.16, 1.0, pow(along, 0.6));
		float turb = fbm(vec2(u * 5.0 + sd, along * 7.0 - t * 3.2));
		float tear = fbm(vec2(u * 3.0 - sd, along * 3.5 - t * 2.1));
		heat = (1.0 - smoothstep(0.0, width, side + (turb - 0.5) * 0.5)) * (1.25 - along * 0.75);
		heat += (turb - 0.5) * 0.55;
		heat -= smoothstep(0.55, 1.0, along) * (0.35 + tear * 0.6);
		heat *= smoothstep(0.0, 0.06, along) * 0.6 + 0.4;
	} else {
		// A flame standing on its base (mode 0) or a billow (mode 2): hottest low and in the
		// middle, its tongues flickering upward.
		float turb = fbm(vec2(u * 4.0 + sd, v * 4.5 - t * 2.4));
		float lick = fbm(vec2(u * 2.0 - sd, v * 2.0 - t * 1.3));
		float width = mix(0.95, 0.15, v);
		if (mode == 2) {
			width = 0.8 * (1.0 - abs(v - 0.45) * 1.1);
		}
		heat = (1.0 - smoothstep(0.0, width, side + (turb - 0.5) * 0.6)) * (1.3 - v * 1.1);
		heat += (turb - 0.5) * 0.6 + (lick - 0.5) * 0.3;
		if (mode == 2) {
			heat *= 1.0 - age * 0.85;
			heat -= age * 0.25;
		}
	}
	heat *= fade;
	float a;
	vec3 col = palette(heat, a);
	if (a < 0.5) discard;
	// The hottest steps glow hardest.
	ALBEDO = col * brightness * mix(0.85, 1.25, smoothstep(0.5, 1.0, heat));
}
