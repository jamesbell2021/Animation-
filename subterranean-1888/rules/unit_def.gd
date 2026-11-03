class_name UnitDef
extends Resource
## A class of unit (a specialist or a creature), kept as a .tres in data/units.

@export var id: StringName
@export var display_name := ""
@export var role := ""
@export var is_enemy := false
@export var max_hp := 40
## Max TU before the load penalty (see Rules.max_tu).
@export var base_tu := 50
@export var strength := 50
## Reaction stat when watching (on Overwatch).
@export var perception := 50
## Reaction stat when moving through someone's cone.
@export var agility := 50
@export var armour := 0
## Extra armour against blows from inside this unit's own vision cone (the boilerplate shield).
@export var frontal_armour := 0
@export var vision_range := 12.0
@export var vision_half_angle := 45.0
@export var weapon: WeaponDef
## Everything carried apart from the weapon, in kg.
@export var gear_weight := 0.0
@export var gear: PackedStringArray = PackedStringArray()
@export var hand_flares := 0
@export var mortar_flares := 0
@export var pheromone_grenades := 0
@export var dynamite := 0
@export var repair_kit := 0
@export var can_drill := false
@export var seismograph := false
## Swarm only: prefer attack tiles outside the target's vision cone (GDD 6.2.3).
@export var flanker := false
## Never moves (the hive).
@export var stationary := false
## Bioluminescence: the unit lights its own tile and a little around it.
@export var glow := 0.0
@export var colour := Color(0.77, 0.61, 0.15)


func load_kg() -> float:
	return gear_weight + (weapon.weight if weapon != null else 0.0)


func max_tu() -> int:
	return Rules.max_tu(base_tu, strength, load_kg())
