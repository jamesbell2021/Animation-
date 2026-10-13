// Neon look for MultiMesh-rendered terrain (the whole city in a few draw calls).
shader_type spatial;
render_mode unshaded, cull_back;

#define MULTI
#include "res://shaders/neon_common.gdshaderinc"
