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
	_game._try_move("south")          # R1 Chatsubo -> R2 Street Chatsubo
	await _shot("05_street_chatsubo")

	_game._try_move("east")           # R2 -> R5 Street Body Shop
	await _shot("06_street_bodyshop")

	_game._go_explore()
	GameState.current_room = "R4"     # Body Shop interior
	_game._refresh_room()
	await _shot("07_body_shop")

	GameState.current_room = "R8"     # Gentleman Loser
	_game._refresh_room()
	await _shot("08_gentleman_loser")

	GameState.credits = 60000          # so the decks read as buyable in the shot
	GameState.current_room = "R40"     # Crazy Edo's — real deck shop
	_game._refresh_room()
	_game._open_shop("edos", "")
	await _shot("09_crazy_edos")

	_game._open_inventory()
	await _shot("10_inventory")

	_game._go_explore()
	GameState.current_room = "R4"     # Body Shop — real organ bank
	_game._refresh_room()
	_game._open_organbank("")
	await _shot("10_body_shop")

	_game._go_explore()
	GameState.current_room = "R1"     # Chatsubo PAX booth
	_game._refresh_room()
	_game._open_pax_news()            # the real NEWS.BIH feed
	await _shot("11_pax_news")
	_game._open_pax_messages()
	await _shot("12_pax_messages")

	# Cyberspace: jack in, fly the matrix, break a weak fortress's ICE.
	_game._go_explore()
	GameState.inventory.append("uxb")     # give CASE a deck
	GameState.current_room = "R1"
	_game._refresh_room()
	_game._go_matrix()
	await _shot("13_matrix")
	_game._approach_db("free_matrix")
	await _shot("14_ice_combat")
	_game._combat_attack()                # Free Matrix ICE 60 vs attack 40
	_game._combat_attack()                # -> ICE shattered, you're in
	await _shot("15_db_cracked")

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
