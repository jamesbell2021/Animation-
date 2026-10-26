class_name PetrolBomb
extends Node3D
## A bottle of bio with a burning kelp rag, thrown in an arc. It smashes where it lands:
## a burst of fire that sets everything near it alight, and a pool that burns on.
## Into the sea, it's only a hiss and a puff of steam.

const FLIGHT_TIME := 0.75
const ARC := 2.6
const BLAST_R := 2.2
const BLAST_DMG := 20
const BLAST_BURN := 4.0

var thrower: Node
var from := Vector3.ZERO
var to := Vector3.ZERO
var _t := 0.0

func _ready() -> void:
	global_position = from
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.3, 0.55, 0.3, 0.7)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var body := Geo.cyl(self, 0.07, 0.24, Color.WHITE, Vector3.ZERO)
	body.material_override = glass
	Look.glint(self, Vector3(0.0, 0.18, 0.0), Color(1.0, 0.55, 0.2), 0.35)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 1.5
	l.omni_range = 3.0
	add_child(l)

func _physics_process(delta: float) -> void:
	_t += delta / FLIGHT_TIME
	var k := minf(_t, 1.0)
	global_position = from.lerp(to, k) + Vector3(0.0, ARC * 4.0 * k * (1.0 - k), 0.0)
	rotation.x += delta * 14.0
	if _t >= 1.0:
		_smash()

func _smash() -> void:
	var parent := get_parent()
	if to.y <= Terrain.SEA_LEVEL + 0.05 and Terrain.height_at(to.x, to.z) < Terrain.SEA_LEVEL:
		FX.steam(parent, to + Vector3(0.0, 0.2, 0.0))
		Audio.sfx("sizzle", to, 0.0, 0.1)
		queue_free()
		return
	Audio.sfx("glass", to, 0.0, 0.1)
	Audio.sfx("ignite", to, 2.0, 0.1)
	FX.emitter(parent, to + Vector3(0.0, 0.3, 0.0), FX._puff_mesh_ref(), Color(1.0, 0.5, 0.15, 0.95), 30, 0.7, Vector3.UP, 80.0, 2.0, 5.0, -1.0, 0.6, 1.6, true, true, 5.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if Arsenal._live(e) and Geo.flat_dist(e.global_position, to) <= BLAST_R and absf(e.global_position.y - to.y) < 1.5:
			var dir: Vector3 = e.global_position - to
			dir.y = 0.0
			e.set_alight(BLAST_BURN)
			Arsenal.strike(e, BLAST_DMG, dir.normalized() if dir.length() > 0.01 else Vector3.ZERO, thrower, "bomb")
	var pool := FirePool.new()
	pool.thrower = thrower
	parent.add_child(pool)
	pool.global_position = to
	queue_free()
