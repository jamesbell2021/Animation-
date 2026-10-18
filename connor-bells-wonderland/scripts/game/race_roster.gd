class_name RaceRoster
extends RefCounted
## Builds the ordered list of contestants for a race. Humans come first in
## peer-id order, then bots. The same input produces the same roster on every
## peer, so node names and spawn slots match across the network.


## Each entry: {"name", "colour", "hat", "peer_id" (0 = bot), "bot", "profile"}.
static func build(net: Node, settings: Dictionary, fallback_name: String, fallback_colour: Color, max_contestants: int) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	var used: Dictionary = {}
	var green := Color(0.1, 0.6, 0.2)
	if net != null and bool(net.get("is_multiplayer_session")):
		for id in net.get_sorted_peer_ids():
			var entry: Dictionary = net.players[id]
			roster.append({
				"name": _unique(str(entry.get("name", "Player")), used),
				"colour": entry.get("colour", fallback_colour),
				"hat": green,
				"peer_id": int(id),
				"bot": false,
				"profile": {},
			})
	else:
		var local_name := fallback_name
		var local_colour := fallback_colour
		if net != null:
			local_name = str(net.get("local_name"))
			local_colour = net.get("local_colour")
		roster.append({
			"name": _unique(local_name, used),
			"colour": local_colour,
			"hat": green,
			"peer_id": 1,
			"bot": false,
			"profile": {},
		})
	var bots := clampi(int(settings.get("bots", 0)), 0, max_contestants - roster.size())
	var difficulty := clampi(int(settings.get("difficulty", BotProfiles.Difficulty.MEDIUM)), 0, 2)
	for i in range(bots):
		var profile := BotProfiles.make(i, difficulty as BotProfiles.Difficulty)
		roster.append({
			"name": _unique(str(profile.get("name", "Bot")), used),
			"colour": profile.get("colour", Color.WHITE),
			"hat": profile.get("hat_colour", green),
			"peer_id": 0,
			"bot": true,
			"profile": profile,
		})
	return roster


static func _unique(raw_name: String, used: Dictionary) -> String:
	var base := raw_name.strip_edges().validate_node_name()
	if base.is_empty():
		base = "Player"
	var candidate := base
	var n := 2
	while used.has(candidate):
		candidate = "%s %d" % [base, n]
		n += 1
	used[candidate] = true
	return candidate
