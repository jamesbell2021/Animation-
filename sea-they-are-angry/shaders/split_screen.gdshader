shader_type canvas_item;
// The split screen (CameraDirector): each pixel belongs to the view whose anchor is
// nearest (a Voronoi split). The first view is the main camera's, already drawn below,
// so its pixels are left clear; the others come from their SubViewports. A dark line
// runs along the seams, fading in as the split opens.

uniform sampler2D view1 : source_color, filter_linear;
uniform sampler2D view2 : source_color, filter_linear;
uniform int count = 1;
uniform vec2 size = vec2(1920.0, 1080.0);
uniform vec2 anchor0;
uniform vec2 anchor1;
uniform vec2 anchor2;
uniform float line_px = 2.5;
uniform float line_alpha = 1.0;

void fragment() {
	vec2 p = UV * size;
	vec2 a[3] = vec2[3](anchor0, anchor1, anchor2);
	int best = 0;
	int second = 0;
	float bd = 1e20;
	float sd = 1e20;
	for (int i = 0; i < 3; i++) {
		if (i >= count) {
			break;
		}
		float d = dot(p - a[i], p - a[i]);
		if (d < bd) {
			sd = bd;
			second = best;
			bd = d;
			best = i;
		} else if (d < sd) {
			sd = d;
			second = i;
		}
	}
	vec4 col = vec4(0.0);
	if (best == 1) {
		col = vec4(texture(view1, UV).rgb, 1.0);
	} else if (best == 2) {
		col = vec4(texture(view2, UV).rgb, 1.0);
	}
	if (count > 1) {
		// Distance to the seam between this pixel's view and the next nearest.
		float edge = (sd - bd) / (2.0 * max(length(a[second] - a[best]), 1.0));
		float line = (1.0 - smoothstep(line_px - 1.0, line_px + 1.0, edge)) * line_alpha;
		col = mix(col, vec4(0.03, 0.035, 0.045, 1.0), line);
	}
	COLOR = col;
}
