shader_type canvas_item;
// A rendered frame redrawn as a pencil sketch on off-white paper: the keeper's log.
// Used by tools/make_story_stills.gd on a full-rect ColorRect in a SubViewport.
//
// The frame's levels are stretched first (lo, hi, gamma come from its histogram), so a
// night scene comes out as a heavily hatched drawing with its lights left as bare
// paper. Outlines are an edge detector at two scales (a firm line round big shapes, a
// faint one for detail). Tone is hatching: strokes at 45 degrees for mid-tones, crossed
// for darks, none for lights. The drawing thins out to bare paper toward the margins.

uniform sampler2D frame : filter_linear_mipmap, repeat_disable;
// The picture's size in pixels.
uniform vec2 out_px = vec2(1200.0, 760.0);
// Scales UV about the middle so a frame of another shape fills the picture uncropped.
uniform vec2 crop = vec2(1.0, 1.0);
// Levels: a tone curve through five points of the frame's histogram (the tool works
// them out), so a dark frame is stretched and lifted and its tones pulled apart.
uniform float curve_in[5];
uniform float curve_out[5];
// Changes every stroke (one per still, so no two pages share their hatching).
uniform float seed = 0.0;
// How heavy the outlines and the hatching are.
uniform float line_weight = 1.0;
uniform float hatch_weight = 1.0;
// How far the lines wander, in pixels.
uniform float wobble = 2.2;
// Where the drawing gives out toward the margins (0.5 early, 1 at the very edge).
uniform float reach = 0.86;
uniform vec3 paper : source_color = vec3(0.945, 0.925, 0.87);
uniform vec3 graphite : source_color = vec3(0.17, 0.17, 0.19);
// A faint warm wash where the frame was brightest (lamplight). 0 for none.
uniform float wash = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

// The frame's brightness at a pixel, levels stretched: 0 black to 1 white.
float light_at(vec2 px, float lod) {
	vec2 uv = (px / out_px - 0.5) * crop + 0.5;
	vec3 c = textureLod(frame, uv, lod).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	if (l <= curve_in[0]) {
		return curve_out[0];
	}
	for (int i = 1; i < 5; i++) {
		if (l <= curve_in[i]) {
			float t = (l - curve_in[i - 1]) / max(curve_in[i] - curve_in[i - 1], 0.0005);
			return mix(curve_out[i - 1], curve_out[i], t);
		}
	}
	return curve_out[4];
}

// Sobel edge strength with taps `r` pixels apart.
float edge_at(vec2 px, float r, float lod) {
	float tl = light_at(px + vec2(-r, -r), lod);
	float tc = light_at(px + vec2(0.0, -r), lod);
	float tr = light_at(px + vec2(r, -r), lod);
	float ml = light_at(px + vec2(-r, 0.0), lod);
	float mr = light_at(px + vec2(r, 0.0), lod);
	float bl = light_at(px + vec2(-r, r), lod);
	float bc = light_at(px + vec2(0.0, r), lod);
	float br = light_at(px + vec2(r, r), lod);
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	return length(vec2(gx, gy));
}

// How the hand wanders: a slow drift plus a quicker tremor, in pixels.
vec2 wander(vec2 px, float k) {
	vec2 slow = vec2(vnoise(px * 0.011 + seed + k), vnoise(px * 0.011 + 31.0 + seed + k)) - 0.5;
	vec2 quick = vec2(vnoise(px * 0.07 + 7.0 + k), vnoise(px * 0.07 + 53.0 + k)) - 0.5;
	return slow * 2.0 * wobble + quick * 0.6 * wobble;
}

// The outline at a pixel: a firm line where big shapes meet, a faint one on detail.
float outline(vec2 px) {
	float fine = edge_at(px, 0.9, 0.6);
	float broad = edge_at(px, 1.3, 1.1);
	float faint = smoothstep(0.24, 0.9, fine) * 0.6;
	float firm = smoothstep(0.40, 0.80, broad);
	return max(faint, firm);
}

// One set of pencil strokes along a row: each its own length and pressure, thinning
// at both ends. `shift` slides the set along so two sets can overlap.
float strokes(float along, float row, float f, float rj, float amount, float k, float shift) {
	float seg_len = mix(90.0, 210.0, rj);
	float s = along / seg_len + rj * 17.0 + shift;
	float seg = floor(s);
	float sf = fract(s);
	float sh = hash21(vec2(seg, row * 1.7 + k + seed + shift));
	float taper = smoothstep(0.0, 0.05, sf) * (1.0 - smoothstep(0.80 + sh * 0.15, 1.0, sf));
	float press = mix(0.55, 1.0, hash21(vec2(seg + 3.0, row + k + shift)));
	// The lightest tones get a few whole rows; more rows, then every stroke, as it darkens.
	float need = mix(rj, sh, 0.35) * 0.6;
	float on = smoothstep(need, need + 0.2, amount);
	// Each stroke sits a little off its row.
	float off = (sh - 0.5) * 0.22;
	float width = mix(0.11, 0.21, amount);
	float line = 1.0 - smoothstep(width * 0.45, width, abs(f - off));
	return line * taper * on * press;
}

// One layer of hatching: rows of strokes `gap` pixels apart along `ang`, bowed and
// unevenly spaced as a hand lays them, coming in a few at a time as `amount` (0 to 1)
// rises.
float hatch(vec2 px, float ang, float gap, float amount, float k) {
	vec2 d = vec2(cos(ang), sin(ang));
	vec2 n = vec2(-d.y, d.x);
	float along = dot(px, d);
	float across = dot(px, n);
	// The hand's angle drifts from patch to patch, and each row wavers.
	across += (fbm(px * 0.0035 + seed + k * 7.0) - 0.5) * 70.0;
	across += (vnoise(vec2(along * 0.03, across * 0.25) + k) - 0.5) * gap * 0.3;
	float row = floor(across / gap);
	float f = fract(across / gap) - 0.5;
	float rj = hash21(vec2(row, k + seed));
	float a = strokes(along, row, f, rj, amount, k, 0.0);
	float b = strokes(along, row, f, rj, amount, k, 0.47);
	return max(a, b);
}

void fragment() {
	vec2 px = UV * out_px;
	vec2 w = wander(px, 0.0);
	vec2 pw = px + w;

	// How much of the drawing is here: all of it in the middle, none at the margins,
	// with a ragged boundary. Lines carry on a little past where the shading stops.
	vec2 c = (UV - 0.5) * 2.0;
	float d = pow(pow(abs(c.x), 3.0) + pow(abs(c.y), 3.0), 1.0 / 3.0);
	d += (fbm(px * 0.0045 + seed) - 0.5) * 0.42;
	float shade_here = 1.0 - smoothstep(reach - 0.22, reach + 0.08, d);
	float line_here = 1.0 - smoothstep(reach - 0.04, reach + 0.2, d);

	// Outlines, drawn twice with the hand in a slightly different place: the second,
	// lighter pass is the construction line a quick sketch leaves beside the true one.
	float press = mix(0.62, 1.0, vnoise(px * 0.013 + seed));
	float ln = outline(pw) * press;
	float ln2 = outline(px + wander(px, 40.0) * 1.3 + vec2(1.5, -1.0)) * 0.35;
	float lines = max(ln, ln2) * line_weight * line_here;

	// Tone, from a slightly soft copy of the frame so the hatching follows masses
	// rather than every pixel.
	float soft = light_at(pw, 2.0) * 0.6 + light_at(pw, 3.5) * 0.4;
	// Set against its surroundings a little, so a pale wall still shows in a dark mass.
	soft = clamp(soft + (soft - light_at(pw, 5.5)) * 0.6, 0.0, 1.0);
	float dark = (1.0 - soft) * shade_here;
	dark += (vnoise(px * 0.02 + seed) - 0.5) * 0.08;
	float a45 = -0.785;
	float h1 = hatch(px, a45, 7.0, smoothstep(0.20, 0.50, dark), 1.0);
	float h2 = hatch(px, a45 + 0.14, 5.0, smoothstep(0.42, 0.70, dark), 2.0);
	float h3 = hatch(px, a45 + 1.571, 6.0, smoothstep(0.58, 0.84, dark), 3.0);
	float h4 = hatch(px, a45 + 1.1, 4.0, smoothstep(0.78, 0.97, dark), 4.0);
	float hatching = 1.0 - (1.0 - h1 * 0.55) * (1.0 - h2 * 0.6) * (1.0 - h3 * 0.65) * (1.0 - h4 * 0.75);
	hatching *= hatch_weight;
	// A little rubbed-in tone under the strokes in the darks.
	float rubbed = smoothstep(0.45, 1.0, dark) * 0.2 * hatch_weight;

	// The paper's tooth breaks every mark up.
	float tooth = vnoise(px * 0.9) * 0.6 + vnoise(px * 2.3 + 11.0) * 0.4;
	float g = 1.0 - (1.0 - lines) * (1.0 - hatching) * (1.0 - rubbed);
	g *= mix(0.62, 1.0, tooth);
	g = clamp(g, 0.0, 0.93);

	// Paper: grain, a few fibres, and the optional warm wash.
	vec3 page = paper;
	page -= (fbm(px * 0.35) - 0.5) * 0.035;
	page -= smoothstep(0.80, 1.0, vnoise(vec2(px.x * 0.02, px.y * 0.6))) * 0.012;
	float bright = smoothstep(0.75, 1.0, light_at(pw, 3.0)) * shade_here;
	page = mix(page, page * vec3(1.0, 0.95, 0.80), bright * wash);

	COLOR = vec4(mix(page, graphite, g), 1.0);
}
