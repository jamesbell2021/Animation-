class_name Difficulty
## The three difficulty settings. NORMAL is the game as first tuned; VETERAN and MASSACRE
## multiply the machines' speed, armour and rate of fire, cut the warning, and start with fewer
## lives. Every setting has the random gap before the beam, the double sweep and leg hardening.

const NAMES := ["NORMAL", "VETERAN", "MASSACRE"]
const TABLE := [
	{"lives": 4, "max_lives": 6, "reload": 1.05, "speed": 1.0, "leg_hp": 0, "cooldown": 1.0, "siren": 1.0, "count": 0, "gap": 1.0,
	 "big_from": 2, "extra_life_every": 3, "harden": 4.0, "double_from_sector": 3, "double_from_wave": 6, "pause": [0.3, 1.0]},
	{"lives": 3, "max_lives": 5, "reload": 1.25, "speed": 1.2, "leg_hp": 1, "cooldown": 0.8, "siren": 0.85, "count": 1, "gap": 0.85,
	 "big_from": 1, "extra_life_every": 4, "harden": 3.0, "double_from_sector": 2, "double_from_wave": 4, "pause": [0.3, 1.2]},
	{"lives": 3, "max_lives": 4, "reload": 1.4, "speed": 1.4, "leg_hp": 1, "cooldown": 0.65, "siren": 0.7, "count": 1, "gap": 0.7,
	 "big_from": 0, "extra_life_every": 5, "harden": 2.5, "double_from_sector": 1, "double_from_wave": 3, "pause": [0.2, 1.4]}
]


static func get_setting(level: int) -> Dictionary:
	return TABLE[clampi(level, 0, TABLE.size() - 1)]


static func name_of(level: int) -> String:
	return NAMES[clampi(level, 0, NAMES.size() - 1)]
