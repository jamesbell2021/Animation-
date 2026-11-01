// Energy shield around the mega tank: a glowing rim, a scrolling hex lattice and a ripple
// that runs out from wherever it was hit. Additive, so it never hides the crew underneath.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float strength = 1.0;
// 1 right after a hit, fading to 0.
uniform float hit = 0.0;
// Direction of the last hit in the tank's local space (y ignored).
uniform vec3 hit_dir = vec3(0.0, 0.0, -1.0);
// Shield charge 0..1: the lattice thins out as it runs low.
uniform float charge = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hex_lines(vec2 p) {
	// Distance to the nearest edge of a hex grid, 0 on the lines.
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
}

void fragment() {
	// Only the upper half of the sphere shows (it sits over the deck like a dome).
	if (local_pos.y < -0.2) {
		discard;
	}
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	vec2 uv = vec2(atan(local_pos.x, local_pos.z) * 3.2, local_pos.y * 5.0 + TIME * 0.6);
	float hex = 1.0 - smoothstep(0.0, 0.06, hex_lines(uv * 1.6));
	float lattice = hex * (0.08 + 0.16 * charge);
	vec3 flat_dir = normalize(vec3(local_pos.x, 0.0, local_pos.z) + vec3(0.0001));
	float facing_hit = clamp(dot(flat_dir, normalize(hit_dir)), -1.0, 1.0);
	float ring_pos = 1.0 - hit;
	float ripple = hit * (1.0 - smoothstep(0.0, 0.25, abs(acos(facing_hit) / 3.14159 - ring_pos * 0.9)));
	float spot = hit * smoothstep(0.75, 1.0, facing_hit) * 0.5;
	float a = (rim * 0.55 + lattice + ripple * 0.6 + spot) * strength;
	ALBEDO = mix(color.rgb, vec3(1.0), clamp(ripple * 0.5 + spot * 0.3, 0.0, 1.0)) * 1.1;
	ALPHA = clamp(a, 0.0, 0.85);
}
