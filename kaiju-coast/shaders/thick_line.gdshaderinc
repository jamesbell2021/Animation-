// Shared vertex code for thick lines. Every segment is a strip of two triangles: each vertex holds
// its own end (VERTEX) and the segment's other end (UV.xy, UV2.x), and UV2.y says which side of
// the strip it's on. The strip is widened in screen space so lines keep a constant pixel width
// that scales with resolution.
uniform float width = 1.7;

vec4 thick_line_vertex(mat4 mvp, vec3 vtx, vec2 uv, vec2 uv2, vec2 vp) {
	vec4 p = mvp * vec4(vtx, 1.0);
	vec4 q = mvp * vec4(uv.x, uv.y, uv2.x, 1.0);
	float near_w = 0.05;
	if (q.w < near_w) {
		q = mix(p, q, clamp((p.w - near_w) / max(p.w - q.w, 1e-5), 0.0, 1.0));
	}
	if (p.w < near_w) {
		p = mix(q, p, clamp((q.w - near_w) / max(q.w - p.w, 1e-5), 0.0, 1.0));
	}
	vec2 d = (q.xy / q.w - p.xy / p.w) * vp;
	float l = length(d);
	vec2 dir = l > 1e-4 ? d / l : vec2(1.0, 0.0);
	vec2 n = vec2(-dir.y, dir.x);
	float px = width * vp.y / 720.0;
	vec2 off = (n * uv2.y - dir * 0.5) * px;
	p.xy += off / vp * p.w;
	return p;
}
