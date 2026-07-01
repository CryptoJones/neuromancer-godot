extends Node
## Dev-only: boot the game, drop into room 1337, and screenshot the current
## render of the hand-drawn void plate (to eyeball how much of the drawing shows).
##   godot --path . res://tests/VoidShot.tscn

const GameScene := preload("res://scenes/Boot.tscn")
const SCALE := 4
var _game: Control

func _ready() -> void:
	_game = GameScene.instantiate()
	add_child(_game)
	_run()

func _run() -> void:
	for i in 12:
		await get_tree().process_frame
	_game._start_new_game("CASE")
	await get_tree().process_frame
	GameState.current_room = "1337"
	_game._refresh_room()
	for i in 24:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var path := "user://void_shot.png"
	img.save_png(path)
	print("VOIDSHOT -> %s" % ProjectSettings.globalize_path(path))
	await get_tree().process_frame
	get_tree().quit()
