extends RefCounted
## SaveSystem — single-slot JSON save/load of GameState to user://save.json.

const SAVE_PATH := "user://save.json"

## Serialize GameState.to_dict() to disk. Returns true on success.
static func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot open %s for write" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	return true

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Load user://save.json back into GameState. Returns true on success.
static func load_game() -> bool:
	if not has_save():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: corrupt save file")
		return false
	GameState.from_dict(parsed)
	return true
