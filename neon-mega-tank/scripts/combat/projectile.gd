class_name Projectile
extends Node3D
## Shells, bullets and rockets. Moves with a ray cast per physics step; anything with
## take_damage() can be hit. Player bullets can also shoot enemy rockets out of the air.

const KINDS := {
	"shell": {"damage": 45.0, "radius": 3.2, "blast": 38.0, "range": 46.0, "size": Vector3(0.4, 0.4, 1.6), "energy": 5.0},
	"bullet": {"damage": 6.0, "radius": 0.0, "blast": 0.0, "range": 30.0, "size": Vector3(0.14, 0.14, 1.1), "energy": 4.0},
	"rocket": {"damage": 3.0, "radius": 2.3, "blast": 7.0, "range": 40.0, "size": Vector3(0.3, 0.3, 1.0), "energy": 4.0},
	"enemy_bullet": {"damage": 0.6, "radius": 0.0, "blast": 0.0, "range": 28.0, "size": Vector3(0.12, 0.12, 0.7), "energy": 4.0},
	"enemy_shell": {"damage": 5.0, "radius": 2.6, "blast": 7.0, "range": 42.0, "size": Vector3(0.35, 0.35, 1.3), "energy": 4.5},
}
const FLIGHT_HEIGHT := 0.7

var kind := "bullet"
var team := 0
var velocity := Vector3.ZERO
var color := Color.WHITE
var damage := 5.0
var blast_radius := 0.0
var blast_damage := 0.0
var range_left := 30.0
var dead := false


func setup(projectile_kind: String, projectile_team: int, vel: Vector3, tint: Color) -> void:
	kind = projectile_kind
	team = projectile_team
	velocity = vel
	color = tint
	var stats: Dictionary = KINDS[kind]
	damage = stats["damage"]
	blast_radius = stats["radius"]
	blast_damage = stats["blast"]
	range_left = stats["range"]
	G.neon_box(self, stats["size"], Vector3.ZERO, color, stats["energy"])
	if kind == "rocket":
		add_to_group("rockets")
	if kind in ["shell", "rocket", "enemy_shell"]:
		_add_trail()


func _add_trail() -> void:
	var trail := CPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.mesh = G.box_mesh(Vector3.ONE * 0.18)
	trail.material_override = G.additive_material
	trail.spread = 180.0
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.2
	trail.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	trail.color_ramp = ramp
	add_child(trail)


func _physics_process(delta: float) -> void:
	if dead:
		return
	var from := global_position
	var to := from + velocity * delta
	to.y = lerpf(from.y, FLIGHT_HEIGHT, minf(1.0, delta * 8.0))
	if team == G.Team.PLAYER and kind == "bullet" and _hits_rocket(from, to):
		return
	var mask := G.LAYER_TERRAIN | (G.LAYER_ENEMY if team == G.Team.PLAYER else G.LAYER_PLAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, to, mask))
	if not hit.is_empty():
		_impact(hit["position"], hit["collider"])
		return
	global_position = to
	range_left -= velocity.length() * delta
	if range_left <= 0.0:
		_impact(to, null)


func _hits_rocket(from: Vector3, to: Vector3) -> bool:
	for r in get_tree().get_nodes_in_group("rockets"):
		var rocket: Projectile = r
		var rp := rocket.global_position
		var cp := Geometry3D.get_closest_point_to_segment(rp, from, to)
		if Vector2(cp.x - rp.x, cp.z - rp.z).length() < 0.8:
			rocket.shoot_down()
			dead = true
			queue_free()
			return true
	return false


func shoot_down() -> void:
	if dead:
		return
	dead = true
	G.sparks(global_position, color, 14, 7.0)
	G.ring(global_position, color, 1.5, 0.3, global_position.y)
	G.add_score(15)
	G.sfx("hit", 0.0, 0.7)
	queue_free()


func _impact(pos: Vector3, collider: Object) -> void:
	dead = true
	if collider and collider.has_method("take_damage"):
		collider.take_damage(damage, pos, team)
	if blast_radius > 0.0:
		G.explode(pos, blast_radius, blast_damage, team, color.lerp(Color(1, 0.55, 0.15), 0.5))
	else:
		G.sparks(pos, color, 4, 4.0, 0.25, 0.1)
		if collider:
			G.sfx("hit", -14.0)
	queue_free()
