extends Node
## GameState — canonical, save-serializable world state (autoload singleton).
##
## Every room, shop, and cyberspace site reads/writes through this node so that
## saving the game is a single serialization point. Fields are intentionally
## minimal at M0 and will grow with each milestone.

# --- Player ---
var player_name: String = ""
var credits: int = 0
var constitution: int = 2000         # original scale: CONSTITUTION_MAX = 2000
var health: int = 100

# --- Inventory & skills (filled in M1/M2) ---
var inventory: Array[String] = []
var skills: Dictionary = {}          # skill_name -> level (int)
var software: Dictionary = {}        # warez_name -> { "rating": int }
var sold_parts: Array = []           # body-part ids sold to the Body Shop organ bank

# --- World ---
var current_room: String = ""
var story_flags: Dictionary = {}     # flag_name -> bool/int
var game_minutes: int = 0            # in-world clock (M1)

func reset() -> void:
	player_name = ""
	credits = 0
	constitution = 2000
	health = 100
	inventory.clear()
	skills.clear()
	software.clear()
	sold_parts.clear()
	current_room = ""
	story_flags.clear()
	game_minutes = 0

## Serialize to a plain Dictionary for SaveSystem (added in M1).
func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"credits": credits,
		"constitution": constitution,
		"health": health,
		"inventory": inventory.duplicate(),
		"skills": skills.duplicate(true),
		"software": software.duplicate(true),
		"sold_parts": sold_parts.duplicate(),
		"current_room": current_room,
		"story_flags": story_flags.duplicate(true),
		"game_minutes": game_minutes,
	}

func from_dict(d: Dictionary) -> void:
	reset()
	for key in d:
		if not (key in self):
			continue
		var cur = get(key)
		if cur is Array:
			# set() can't put an untyped JSON array into a typed field like
			# inventory: Array[String]; .assign() coerces the elements instead.
			(cur as Array).assign(d[key] if d[key] is Array else [])
		else:
			set(key, d[key])
