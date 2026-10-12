// Shared neon look: near-black faces with glowing, pixel-constant edges.
// Relies on BoxMesh UVs, where every face covers one cell of a 3x2 atlas.

global uniform vec3 tank_pos;

instance uniform vec4 line_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
instance uniform float energy = 2.5;
instance uniform float flash = 0.0;
instance uniform float windows = 0.0;
instance uniform float fadeable = 0.0;

uniform float line_px = 1.3;
uniform float fill_amount = 0.08;

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 f = fract(UV * vec2(3.0, 2.0));
	vec2 fw = max(fwidth(f), vec2(1e-5));
	vec2 d = min(f, 1.0 - f) / fw;
	float line = 1.0 - smoothstep(line_px - 0.5, line_px + 0.5, min(d.x, d.y));

	// Optional window outline on the side faces of buildings.
	vec2 q = (abs(f - vec2(0.5, 0.42)) - vec2(0.2, 0.16)) / fw;
	float win = 1.0 - smoothstep(line_px - 0.5, line_px + 0.5, abs(max(q.x, q.y)));
	float side = 1.0 - step(0.5, abs(world_normal.y));
	line = max(line, 0.7 * win * side * step(0.5, windows));

	float shade = 0.55 + 0.45 * clamp(dot(world_normal, normalize(vec3(0.3, 1.0, 0.5))), 0.0, 1.0);
	vec3 col = mix(line_color.rgb * fill_amount * shade, line_color.rgb * energy, line);
	col += vec3(1.0, 0.92, 0.85) * flash * 2.0;

	// Terrain between the camera and the mega tank turns into pure wireframe.
	if (fadeable > 0.5) {
		vec3 fwd = -INV_VIEW_MATRIX[2].xyz;
		vec3 rel = world_pos - (tank_pos + vec3(0.0, 1.2, 0.0));
		float along = dot(rel, fwd);
		float perp = length(rel - along * fwd);
		if (along < 0.0 && perp < 7.5) {
			if (line < 0.3) {
				discard;
			}
			col *= 0.45;
		}
	}
	ALBEDO = col;
#ifdef ON_TOP
	ALPHA = 1.0;
#endif
}
