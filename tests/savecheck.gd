extends Node
## Integration test for SaveSystem multi-slot saves + slug sanitization, run against the
## real GameState autoload. Records existing slugs first and only deletes what it creates,
## so it never disturbs a player's real saves.
##   godot --headless --audio-driver Dummy --path . res://tests/SaveCheck.tscn

const SaveSystem = preload("res://src/core/SaveSystem.gd")

var _fail := ""

func _ck(cond: bool, msg: String) -> void:
	if not cond and _fail == "":
		_fail = msg

func _ready() -> void:
	# Snapshot pre-existing slugs so we only clean up our own.
	var before := {}
	for s in SaveSystem.list_saves():
		before[str(s["slug"])] = true

	GameState.reset()
	GameState.player_name = "TESTCASE"
	GameState.credits = 4242
	GameState.constitution = 1500
	GameState.current_room = "R1"
	GameState.inventory.assign(["uxb", "hikigaeru"])

	_ck(SaveSystem.save_as("ZZ Alpha Save"), "save_as Alpha failed")
	GameState.credits = 9999
	_ck(SaveSystem.save_as("ZZ Beta Save"), "save_as Beta failed")

	# Both named slots show up in the listing.
	var names := {}
	for s in SaveSystem.list_saves():
		names[str(s["name"])] = str(s["slug"])
	_ck(names.has("ZZ Alpha Save") and names.has("ZZ Beta Save"), "named saves not listed")

	# Loading Alpha restores inventory (typed-array!) + credits + room.
	GameState.reset()
	_ck(SaveSystem.load_slug(str(names.get("ZZ Alpha Save", "zz_alpha_save"))), "load Alpha failed")
	_ck(GameState.inventory.size() == 2 and GameState.inventory.has("uxb"), "inventory not restored on load")
	_ck(GameState.credits == 4242, "credits not restored on load (got %d)" % GameState.credits)
	_ck(GameState.current_room == "R1", "room not restored on load")

	# Slug sanitization: a path-traversal / junk name must collapse to a safe slug
	# that stays inside the saves dir (no '/', no '..').
	_ck(SaveSystem.save_as("../../../etc/evil $#@! name"), "save_as with junk name failed")
	var traversal_safe := true
	for s in SaveSystem.list_saves():
		var sl := str(s["slug"])
		if sl.contains("/") or sl.contains("\\") or sl.contains(".."):
			traversal_safe = false
	_ck(traversal_safe, "slug sanitization let a path-traversal name through")

	# load of a missing slot is a graceful false, not a crash.
	_ck(not SaveSystem.load_slug("does_not_exist_zzz"), "load of missing slot should return false")

	# Clean up: delete every slug we added this run.
	for s in SaveSystem.list_saves():
		var sl := str(s["slug"])
		if not before.has(sl):
			SaveSystem.delete_slug(sl)

	if _fail == "":
		print("SAVECHECK: PASS")
		get_tree().quit(0)
	else:
		print("SAVECHECK: FAIL - " + _fail)
		get_tree().quit(1)
