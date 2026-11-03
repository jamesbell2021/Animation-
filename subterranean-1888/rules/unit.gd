class_name Unit
extends RefCounted
## One unit's state in a battle. Plain data: the Battle changes it, the view reads it.

const SQUAD := 0
const SWARM := 1

var id := -1
var def: UnitDef
var team := SQUAD
var tile := Vector2i.ZERO
var facing := 0
var hp := 1
var max_tu := 0
var tu := 0
var crouched := false
var ammo := 0
var spare_clips := 0
var pressure := Rules.PRESSURE_MAX
var jammed := false
var overwatch := false
## Suppressed: the next turn starts at half TU, and no reaction fire until then.
var pinned := false
var poison_turns := 0
var poison_damage := 0
var dormant := false
var lamp_on := true
var moved_this_phase := false
var marked_this_phase := false
var hand_flares := 0
var mortar_flares := 0
var pheromones := 0
var dynamite := 0
var repair_kit := 0
var alive: bool:
	get:
		return hp > 0


static func create(unit_id: int, unit_def: UnitDef, unit_team: int, at: Vector2i) -> Unit:
	var u := Unit.new()
	u.id = unit_id
	u.def = unit_def
	u.team = unit_team
	u.tile = at
	u.hp = unit_def.max_hp
	u.max_tu = unit_def.max_tu()
	u.tu = u.max_tu
	if unit_def.weapon != null:
		u.ammo = unit_def.weapon.clip
		u.spare_clips = unit_def.weapon.spare_clips
	u.hand_flares = unit_def.hand_flares
	u.mortar_flares = unit_def.mortar_flares
	u.pheromones = unit_def.pheromone_grenades
	u.dynamite = unit_def.dynamite
	u.repair_kit = unit_def.repair_kit
	u.lamp_on = unit_def.glow <= 0.0 and not unit_def.is_enemy
	return u


func label() -> String:
	return def.display_name


func has_weapon() -> bool:
	return def.weapon != null
