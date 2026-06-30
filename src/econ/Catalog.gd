extends RefCounted
## Catalog — items/shops data + buy/sell/organ economy logic.
##
## Pure logic with NO autoload dependency: every mutating/query call takes the
## `state` object (the GameState autoload in-game, or a plain GameState instance
## in the headless smoke test). Call load_data() once, then buy()/sell()/etc.

const ITEMS_PATH := "res://data/items.json"
const SHOPS_PATH := "res://data/shops.json"

# The Body Shop trade: organs for credits, paid in constitution. Iconic, grim.
const ORGANS := [
	{ "id": "kidney",      "name": "a kidney",      "price": 1000, "con": 15 },
	{ "id": "lung",        "name": "a lung",        "price": 1800, "con": 25 },
	{ "id": "heart_valve", "name": "a heart valve", "price": 3000, "con": 40 },
]
const CON_FLOOR := 10   # never let an organ sale drop you below this (it'd kill you)

var items: Dictionary = {}
var shops: Dictionary = {}

func load_data() -> void:
	items = _load(ITEMS_PATH).get("items", {})
	shops = _load(SHOPS_PATH).get("shops", {})

func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Catalog: missing %s" % path)
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}

func item(id: String) -> Dictionary:
	return items.get(id, {})

func item_name(id: String) -> String:
	return item(id).get("name", id)

func shop(id: String) -> Dictionary:
	return shops.get(id, {})

func price(id: String) -> int:
	return int(item(id).get("price", 0))

## Already owned? Skills land in state.skills, software in .software, the
## rest (hardware/misc) in .inventory.
func owned(state, id: String) -> bool:
	var it := item(id)
	match it.get("type", ""):
		"skill": return state.skills.has(it.get("skill", id))
		"software": return state.software.has(id)
		_: return state.inventory.has(id)

func can_buy(state, id: String) -> bool:
	return not item(id).is_empty() and not owned(state, id) and state.credits >= price(id)

## Buy: deduct credits and grant the item. Returns true on success.
func buy(state, id: String) -> bool:
	if not can_buy(state, id):
		return false
	state.credits -= price(id)
	var it := item(id)
	match it.get("type", ""):
		"skill":
			var s: String = it.get("skill", id)
			state.skills[s] = max(int(state.skills.get(s, 0)), int(it.get("rating", 1)))
		"software":
			state.software[id] = { "rating": int(it.get("rating", 1)) }
		_:
			if not state.inventory.has(id):
				state.inventory.append(id)
	return true

## Resale is half list price (fences don't pay retail).
func sell_value(id: String) -> int:
	return int(price(id) / 2.0)

## Only tangible inventory (hardware/misc) is sellable; learned skills aren't.
func can_sell(state, id: String) -> bool:
	return state.inventory.has(id)

func sell(state, id: String) -> bool:
	if not can_sell(state, id):
		return false
	state.inventory.erase(id)
	state.credits += sell_value(id)
	return true

func can_sell_organ(state, organ: Dictionary) -> bool:
	return state.constitution - int(organ.get("con", 0)) >= CON_FLOOR

func sell_organ(state, organ: Dictionary) -> bool:
	if not can_sell_organ(state, organ):
		return false
	state.constitution -= int(organ.get("con", 0))
	state.credits += int(organ.get("price", 0))
	state.story_flags["sold_" + str(organ.get("id", ""))] = true
	return true
