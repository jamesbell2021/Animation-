class_name ResearchDesk
extends Node3D
## A desk in the camp's mess, under a lamp, with the internees' papers spread on it.
## Work out a project here (Research): paid for from the store and the notes found about
## the camp, one at a time, done by dawn. Nothing is worked out in a wrecked mess.

## The mess hut it stands in.
var building: Structure

func _ready() -> void:
	add_to_group("interactable")
	var wood := Look.wood(Color(0.36, 0.27, 0.19), 0.7)
	var top := Geo.box(self, Vector3(1.1, 0.06, 0.6), Color.WHITE, Vector3(0.0, 0.76, 0.0))
	top.material_override = wood
	for sx in [-0.5, 0.5]:
		for sz in [-0.25, 0.25]:
			Geo.box(self, Vector3(0.05, 0.75, 0.05), Color.WHITE, Vector3(sx, 0.37, sz)).material_override = wood
	var paper := Look.flat_mat(Color(0.86, 0.82, 0.7), 0.9)
	for i in 4:
		var sheet := Geo.box(self, Vector3(0.21, 0.004, 0.29), Color.WHITE, Vector3(-0.3 + 0.2 * float(i), 0.795 + 0.002 * float(i), 0.04 * float(i % 2)))
		sheet.material_override = paper
		sheet.rotation.y = 0.3 * float(i - 2)

## Whether work can go on here: the mess is standing.
func usable() -> bool:
	return building == null or not building.is_destroyed()

func interact_prompt() -> String:
	if not usable():
		return "The mess is wrecked: mend the hut to work at the desk"
	if Research.busy():
		return "[E] Research: working out %s tonight" % Research.title(Run.researching)
	return "[E] Research at the desk (the internees' notes: %d)" % Stock.get_amount("notes")

func interact(player: Node) -> bool:
	if not (player is Player) or not usable():
		return false
	ChoiceMenu.open(player, "Research", menu_rows)
	return true

func menu_rows() -> Array:
	var rows := []
	for id in Research.PROJECTS:
		var pr: Dictionary = Research.PROJECTS[id]
		if Research.has(id):
			rows.append({"text": "%s: done" % pr["name"], "enabled": false, "do": func() -> void: pass})
		elif Run.researching == id:
			rows.append({"text": "%s: working on it, done by dawn" % pr["name"], "enabled": false, "do": func() -> void: pass})
		else:
			rows.append({"text": "%s (%s): %s" % [pr["name"], Stock.cost_str(pr["cost"]), pr["blurb"]],
				"enabled": Research.can_start(id), "do": Research.start.bind(id)})
	return rows
