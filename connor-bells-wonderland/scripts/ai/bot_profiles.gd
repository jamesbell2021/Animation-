class_name BotProfiles
extends RefCounted
## Personalities and difficulty settings for AI contestants.
## Profiles are plain Dictionaries so they are easy to send over the network later.

enum Difficulty { EASY, MEDIUM, HARD }
enum Personality { STEADY, RECKLESS, GREEDY, CLUMSY }

const NAMES: Array[String] = ["Paddy", "Bridget", "Seamus", "Roisin", "Finn", "Aoife", "Declan", "Niamh", "Cormac", "Saoirse"]
const HAT_COLOURS: Array[Color] = [
	Color(0.1, 0.6, 0.2), Color(0.8, 0.1, 0.2), Color(0.2, 0.3, 0.9),
	Color(0.9, 0.6, 0.1), Color(0.5, 0.2, 0.7), Color(0.1, 0.1, 0.1),
]


## Builds the profile for bot number [param index] (0-based).
static func make(index: int, difficulty: Difficulty = Difficulty.MEDIUM, personality: int = -1) -> Dictionary:
	var profile := _base(difficulty)
	var p: int = personality if personality >= 0 else index % Personality.size()
	match p:
		Personality.STEADY:
			profile["weave"] *= 0.5
			profile["steer_noise"] *= 0.6
			profile["coin_greed"] = 0.0
		Personality.RECKLESS:
			profile["speed"] = minf(float(profile["speed"]) + 0.08, 1.0)
			profile["jump_delay"] *= 0.3
			profile["patience"] = 0.0
			profile["weave"] *= 1.5
		Personality.GREEDY:
			profile["coin_greed"] = 5.0
			profile["speed"] = maxf(float(profile["speed"]) - 0.03, 0.6)
		Personality.CLUMSY:
			profile["steer_noise"] *= 2.0
			profile["jump_delay"] *= 1.8
			profile["weave"] *= 2.0
			profile["stuck_time"] = 2.5
	profile["personality"] = p
	profile["difficulty"] = difficulty
	profile["name"] = NAMES[index % NAMES.size()]
	profile["colour"] = CourseBuilder.rainbow(index + 1)
	profile["hat_colour"] = HAT_COLOURS[index % HAT_COLOURS.size()]
	return profile


static func personality_name(personality: int) -> String:
	match personality:
		Personality.STEADY: return "Steady"
		Personality.RECKLESS: return "Reckless"
		Personality.GREEDY: return "Greedy"
		Personality.CLUMSY: return "Clumsy"
	return "Unknown"


static func difficulty_name(difficulty: int) -> String:
	match difficulty:
		Difficulty.EASY: return "Easy"
		Difficulty.MEDIUM: return "Medium"
		Difficulty.HARD: return "Hard"
	return "Unknown"


## speed: fraction of full move speed. steer_noise: random heading wobble (radians).
## jump_delay: seconds of hesitation before a jump. weave: lateral sway amplitude.
## coin_greed: detour radius for coins (0 = ignore). patience: 1 = waits for moving
## platforms, 0 = walks off edges. stuck_time: seconds without progress before un-sticking.
## item_delay: seconds a bot holds an item before it starts looking for a chance to use it.
static func _base(difficulty: Difficulty) -> Dictionary:
	match difficulty:
		Difficulty.EASY:
			return {"speed": 0.78, "steer_noise": 0.35, "jump_delay": 0.25, "weave": 0.3, "coin_greed": 3.0, "patience": 0.7, "stuck_time": 1.8, "item_delay": 2.5}
		Difficulty.HARD:
			return {"speed": 1.0, "steer_noise": 0.06, "jump_delay": 0.03, "weave": 0.05, "coin_greed": 2.0, "patience": 1.0, "stuck_time": 1.2, "item_delay": 0.5}
		_:
			return {"speed": 0.9, "steer_noise": 0.18, "jump_delay": 0.12, "weave": 0.15, "coin_greed": 3.0, "patience": 0.9, "stuck_time": 1.5, "item_delay": 1.2}
