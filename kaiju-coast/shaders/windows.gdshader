// Lit windows, signs and ad screens: unshaded quads whose vertex colour is the light colour and
// whose vertex ALPHA is a per-quad random seed. Each window switches on and off on its own slow
// clock and a few flicker. Adapted from Rust & Iron.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float energy = 1.7;
uniform float lit_fraction : hint_range(0.0, 1.0) = 0.62;
uniform float rate = 0.06;
uniform float flicker = 0.08;
uniform bool always_on = false;
uniform bool chase = false;
uniform float chase_speed = 0.7;

float hash(float n) { return fract(sin(n) * 43758.5453123); }

void fragment() {
	float seed = COLOR.a * 97.0;
	float on = 1.0;
	if (chase) {
		on = 0.18 + 0.82 * step(fract(COLOR.a - TIME * chase_speed), 0.22);
	} else if (!always_on) {
		float epoch = floor(TIME * rate + seed * 13.0);
		on = step(1.0 - lit_fraction, hash(seed + epoch * 1.7));
	}
	if (hash(seed * 3.1) < flicker) {
		float f = hash(floor(TIME * 18.0) + seed);
		on *= f > 0.35 ? 1.0 : 0.12;
	}
	ALBEDO = COLOR.rgb * energy * on;
}
