extends Node
## Headless check: entering room 1337 renders the hand-drawn plate SHARP (linear
## filter, texture present) while normal rooms stay pixel-crushed (nearest).
##   godot --headless --audio-driver Dummy --path . res://tests/VoidCheck.tscn

const GameScene := preload("res://scenes/Boot.tscn")
var _game: Control

func _ready() -> void:
	_game = GameScene.instantiate()
	add_child(_game)
	_run()

func _run() -> void:
	for i in 8:
		await get_tree().process_frame
	AudioManager.enabled = false   # the dummy audio driver makes the void playlist spin; not what we're testing
	_game._start_new_game("CASE")
	await get_tree().process_frame
	# a normal room: pixelated (nearest)
	var normal_nearest: bool = _game._bg_rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	# fall into 1337: the hand-drawn plate, rendered sharp (linear) with a texture
	GameState.current_room = "1337"
	_game._refresh_room()
	await get_tree().process_frame
	var void_linear: bool = _game._bg_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR
	var void_has_tex: bool = _game._bg_rect.texture != null
	# leaving 1337 restores pixelation
	GameState.current_room = "R1"
	_game._refresh_room()
	await get_tree().process_frame
	var restored: bool = _game._bg_rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	var ok: bool = normal_nearest and void_linear and void_has_tex and restored
	print("VOIDCHECK normal_nearest=%s void_linear=%s void_tex=%s restored=%s" % [
		str(normal_nearest), str(void_linear), str(void_has_tex), str(restored)])
	print("VOIDCHECK: " + ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
