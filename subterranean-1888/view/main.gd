extends Node
## The root: title screen <-> battle. Pass `-- --battle` (or `--seed N`) on the command line
## to skip the title, which the smoke test and screenshots use.

var _title: TitleScreen
var _battle: BattleView
var _seed := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seed")
	if i >= 0 and i + 1 < args.size():
		_seed = int(args[i + 1])
	if args.has("--battle"):
		start_battle()
	else:
		show_title()


func show_title() -> void:
	_clear()
	_title = TitleScreen.new()
	add_child(_title)
	_title.begin.connect(start_battle)


func start_battle() -> void:
	_clear()
	_battle = BattleView.new()
	add_child(_battle)
	_battle.quit_to_title.connect(show_title.call_deferred)
	_battle.restart_requested.connect(start_battle.call_deferred)
	_battle.start(_seed)


func battle_view() -> BattleView:
	return _battle


func _clear() -> void:
	if _title != null:
		_title.queue_free()
		_title = null
	if _battle != null:
		_battle.queue_free()
		_battle = null
