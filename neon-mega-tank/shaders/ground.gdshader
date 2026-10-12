// Neon street grid: faint ground grid, glowing road edges and dashed centre lines.
shader_type spatial;
render_mode unshaded;

uniform vec4 grid_color : source_color = vec4(0.1, 0.3, 1.0, 1.0);
uniform vec4 road_color : source_color = vec4(0.15, 0.55, 1.0, 1.0);
uniform vec4 border_color : source_color = vec4(1.0, 0.2, 0.6, 1.0);
uniform float period = 24.0;
uniform float road = 8.0;
uniform float half_size = 72.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float aa_line(float dist, float fw, float px) {
	return 1.0 - smoothstep(px * fw, (px + 1.0) * fw, dist);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 fw = fwidth(p);
	vec3 col = vec3(0.004, 0.006, 0.018);
	float inside = step(abs(p.x), half_size) * step(abs(p.y), half_size);

	vec2 g = abs(fract(p / 4.0 - 0.5) - 0.5) * 4.0;
	float grid = max(aa_line(g.x, fw.x, 0.6), aa_line(g.y, fw.y, 0.6));
	col += grid_color.rgb * grid * 0.09 * inside;

	vec2 lp = mod(p + period * 0.5, period) - period * 0.5;
	float road_x = step(abs(lp.x), road * 0.5);
	float road_z = step(abs(lp.y), road * 0.5);
	vec2 e = abs(abs(lp) - road * 0.5);
	float edge_x = aa_line(e.x, fw.x, 1.0) * (1.0 - road_z);
	float edge_z = aa_line(e.y, fw.y, 1.0) * (1.0 - road_x);
	col += road_color.rgb * (edge_x + edge_z) * 1.6 * inside;

	float dash_x = aa_line(abs(lp.x), fw.x, 0.8) * step(0.5, fract(p.y / 4.0)) * (1.0 - road_z);
	float dash_z = aa_line(abs(lp.y), fw.y, 0.8) * step(0.5, fract(p.x / 4.0)) * (1.0 - road_x);
	col += road_color.rgb * (dash_x + dash_z) * 0.7 * inside;
	col += vec3(0.006, 0.012, 0.035) * max(road_x, road_z) * inside;

	vec2 b = abs(abs(p) - half_size);
	float border = max(aa_line(b.x, fw.x, 1.5) * step(abs(p.y), half_size),
			aa_line(b.y, fw.y, 1.5) * step(abs(p.x), half_size));
	col += border_color.rgb * border * 3.0;
	ALBEDO = col;
}
