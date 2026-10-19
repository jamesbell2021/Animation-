class_name MobileSettings
extends RefCounted
## Runtime quality tiers for phones and desktops. Call apply() after the
## course (and its DirectionalLight3D) has been built.

enum Tier { LOW, MEDIUM, HIGH }


static func detect() -> Tier:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return Tier.LOW if OS.get_processor_count() <= 4 else Tier.MEDIUM
	return Tier.HIGH


static func tier_name(tier: int) -> String:
	match tier:
		Tier.LOW: return "Low"
		Tier.MEDIUM: return "Medium"
		Tier.HIGH: return "High"
	return "Unknown"


## [param root] is searched for DirectionalLight3D nodes to adjust shadows.
static func apply(tier: Tier, viewport: Viewport, root: Node) -> void:
	if viewport == null:
		push_error("MobileSettings.apply: viewport is null.")
		return
	if OS.has_feature("web"):
		# Browsers: leave the renderer alone (changing it stops the 3D drawing in WebGL).
		_configure_lights(root, false, 45.0)
		print("MobileSettings: browser defaults")
		return
	match tier:
		Tier.LOW:
			viewport.scaling_3d_scale = 0.7
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			_configure_lights(root, false, 30.0)
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		Tier.MEDIUM:
			viewport.scaling_3d_scale = 0.85
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			_configure_lights(root, true, 45.0)
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		Tier.HIGH:
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_2X
			_configure_lights(root, true, 90.0)
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	Engine.max_fps = 60
	if OS.has_feature("mobile") or OS.has_feature("android"):
		DisplayServer.screen_set_keep_on(true)
	print("MobileSettings: quality tier %s" % tier_name(tier))


static func _configure_lights(root: Node, shadows: bool, max_distance: float) -> void:
	if root == null:
		return
	for light in root.find_children("*", "DirectionalLight3D", true, false):
		var sun := light as DirectionalLight3D
		sun.shadow_enabled = shadows
		sun.directional_shadow_max_distance = max_distance
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if max_distance <= 45.0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
