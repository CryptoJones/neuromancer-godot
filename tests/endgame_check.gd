extends Node
## Headless win-path check (no screenshots, so it won't hang the renderer): boot the
## real game, hand CASE a deck, mark the Gold AI cracked, run the final core, hammer the
## Neuromancer AI, and assert the game reaches the victory state.
##   godot --headless --audio-driver Dummy --path . res://tests/EndgameCheck.tscn

const GameScene := preload("res://scenes/Boot.tscn")
var _game: Control


func _ready() -> void:
	_game = GameScene.instantiate()
	add_child(_game)
	_run()


func _run() -> void:
	for i in 8:
		await get_tree().process_frame
	_game._start_new_game("CASE")
	GameState.inventory.append("uxb")              # a deck to jack in with
	GameState.constitution = 2000
	GameState.story_flags["cracked_bank_berne"] = true   # Gold AI down -> final core unlocks
	_game._go_matrix()
	await get_tree().process_frame
	_game._enter_endgame("neuromancer_core")       # first contact -> Cyberspace Beach
	await get_tree().process_frame
	_game._open_final_battle()
	for i in 80:
		if GameState.story_flags.get("game_won", false):
			break
		_game._combat_attack()
		await get_tree().process_frame
	var won: bool = GameState.story_flags.get("game_won", false)
	print("ENDGAME_CHECK: game_won=%s  final_con=%d" % [str(won), GameState.constitution])
	print("ENDGAME_CHECK: " + ("PASS" if won else "FAIL"))
	get_tree().quit(0 if won else 1)
