extends Node
## Dev-only visual tour: boots the real Game scene with the actual renderer,
## drives it through each M1 state, and saves an upscaled screenshot of every
## step to user://. Run windowed:
##   godot --path . res://tests/Tour.tscn
## Not part of the shipped game; used to eyeball the slice and for the README.

const GameScene := preload("res://scenes/Boot.tscn")
const SCALE := 4

var _game: Control


func _ready() -> void:
	_game = GameScene.instantiate()
	add_child(_game)
	_run()


func _run() -> void:
	await _settle()
	await _shot("01_title")

	_game._go_name()
	await _shot("02_name")

	_game._start_new_game("CASE")
	await _shot("03_chatsubo")

	_game._go_dialog("ratz")
	await _shot("04_ratz_dialog")

	_game._end_dialog()
	_game._try_move("south")          # Chatsubo -> Ninsei Street
	await _shot("05_street")

	_game._try_move("west")           # Street -> Ninsei West
	await _shot("06_ninsei_west")

	_game._try_move("south")          # Ninsei West -> Body Shop
	await _shot("07_bodyshop")

	_game._go_explore()
	GameState.current_room = "gentleman_loser"
	_game._refresh_room()
	await _shot("08_gentleman_loser")

	print("TOUR: DONE")
	get_tree().quit()


func _settle() -> void:
	for i in 8:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var path := "user://%s.png" % shot_name
	img.save_png(path)
	print("SHOT %s -> %s" % [shot_name, ProjectSettings.globalize_path(path)])
	await get_tree().process_frame
