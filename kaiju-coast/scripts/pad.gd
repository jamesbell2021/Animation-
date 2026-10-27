class_name Pad
extends RefCounted
## A gun emplacement: a ring on the seawall, behind it, or on a sea fort out in the bay.

var index: int = 0
var pos: Vector3 = Vector3.ZERO
var fort: bool = false
var turret: Turret = null


func _init(i: int, p: Vector3, is_fort: bool) -> void:
	index = i
	pos = p
	fort = is_fort
