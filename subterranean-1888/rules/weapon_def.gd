class_name WeaponDef
extends Resource
## A weapon's numbers, kept as a .tres in data/weapons so balance can be changed in the
## Inspector without touching code (Godot's equivalent of a Unity ScriptableObject).

@export var id: StringName
@export var display_name := ""
@export var damage := 20
## Before modifiers; see Rules for the rest of the hit formula.
@export var accuracy := 60
## Tiles before range falloff starts. Melee weapons reach adjacent tiles only.
@export var optimal_range := 10
@export var melee := false
## Rounds a clip; 0 means it never needs ammunition.
@export var clip := 8
@export var spare_clips := 2
@export var weight := 5.0
## Boiler pressure each round costs (see Rules.JAM_BELOW).
@export var pressure_per_shot := 5
@export var modes: PackedStringArray = PackedStringArray(["snap", "aimed"])
@export var burst_min := 3
@export var burst_max := 5
## When above 0, every attack costs this many TU instead of a share of Max TU.
@export var flat_tu := 0
@export var poison_turns := 0
@export var poison_damage := 0
@export var tracer_color := Color(1.0, 0.8, 0.45)
