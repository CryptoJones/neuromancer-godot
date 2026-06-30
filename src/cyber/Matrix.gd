extends RefCounted
## Matrix — cyberspace database data + ICE-combat math. Pure logic; the player
## state is passed in (the GameState autoload in-game, a plain instance in tests).

const DB_PATH := "res://data/cyberspace/databases.json"
const ART_DIR := "res://assets/cyberspace/"

var databases: Array = []

func load_data() -> void:
	databases = _load(DB_PATH).get("databases", [])

func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}

func db(id: String) -> Dictionary:
	for d in databases:
		if d.get("id", "") == id:
			return d
	return {}

func art(name: String) -> String:
	return ART_DIR + name + ".png"

## Your attack power per turn vs ICE = base deck + ICE-Breaking skill + loaded software.
func player_attack(state) -> int:
	var atk := 40
	atk += int(state.skills.get("ICE Breaking", 0)) * 20
	for sid in state.software:
		atk += int(state.software[sid].get("rating", 0)) * 10
	return atk

## ICE bite-back per turn: stronger ICE hurts more; an AI-guarded core doubles it.
func ice_bite(d: Dictionary) -> int:
	var bite := int(max(5, int(d.get("ice", 0)) / 8.0))
	if d.has("ai"):
		bite *= 2
	return bite

func is_cracked(state, id: String) -> bool:
	return state.story_flags.get("cracked_" + id, false)
