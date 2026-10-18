extends Node
## Score, lives, campaign progress and high scores. Progress persists in user://tripod_attack.cfg.

const SAVE_PATH := "user://tripod_attack.cfg"

var score := 0
var lives := 4
var sector_idx := 0
var wave := 0
var endless := false
var stats := {"saved": 0, "lost": 0, "destroyed": 0, "dodged": 0}
var cleared: Array = []
var campaign_done := false
var high_campaign := 0
var high_endless := 0
var lost_sector := -1
var clear_bonus := 0


func _ready() -> void:
	load_save()


func reset_stats() -> void:
	stats = {"saved": 0, "lost": 0, "destroyed": 0, "dodged": 0}


func load_save() -> void:
	cleared = []
	for i in 10:
		cleared.append(false)
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		var c: Array = cf.get_value("campaign", "cleared", cleared)
		if c.size() == 10:
			cleared = c
		campaign_done = cf.get_value("campaign", "done", false)
		high_campaign = cf.get_value("scores", "campaign", 0)
		high_endless = cf.get_value("scores", "endless", 0)


func persist() -> void:
	var cf := ConfigFile.new()
	cf.set_value("campaign", "cleared", cleared)
	cf.set_value("campaign", "done", campaign_done)
	cf.set_value("scores", "campaign", high_campaign)
	cf.set_value("scores", "endless", high_endless)
	cf.save(SAVE_PATH)


func reset_campaign() -> void:
	for i in 10:
		cleared[i] = false
	persist()


func next_sector_idx() -> int:
	for i in 10:
		if not cleared[i]:
			return i
	return 9


func all_cleared() -> bool:
	return cleared.all(func(c): return c)


func cleared_count() -> int:
	return cleared.filter(func(c): return c).size()


func has_progress() -> bool:
	return cleared.any(func(c): return c) and not campaign_done
