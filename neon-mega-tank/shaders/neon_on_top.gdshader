// Same neon look, drawn over everything (used for the crew so the turret never hides them).
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

#define ON_TOP
#include "res://shaders/neon_common.gdshaderinc"
