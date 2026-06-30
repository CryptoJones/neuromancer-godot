extends RefCounted
## Catalog — items/shops data + buy/sell/organ economy logic.
##
## Pure logic with NO autoload dependency: every mutating/query call takes the
## `state` object (the GameState autoload in-game, or a plain GameState instance
## in the headless smoke test). Call load_data() once, then buy()/sell()/etc.

const ITEMS_PATH := "res://data/items.json"
const SHOPS_PATH := "res://data/shops.json"
const PARTS_PATH := "res://data/bodyparts.json"   # real Body Shop organ table (from the original)

var items: Dictionary = {}
var shops: Dictionary = {}
var parts: Array = []         # body parts: {id, name, sell, buy, con}

func load_data() -> void:
	items = _load(ITEMS_PATH).get("items", {})
	shops = _load(SHOPS_PATH).get("shops", {})
	parts = _load(PARTS_PATH).get("parts", [])

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

# --- Body Shop organ bank (the original's grim trade) ---------------------------
# Sell a part: gain its sell price, lose its constitution toll, mark it sold.
# Buy it back later: pay the (higher) buy price, restore the constitution.

func part_sold(state, part: Dictionary) -> bool:
	return state.sold_parts.has(part.get("id", ""))

func can_sell_part(state, part: Dictionary) -> bool:
	return not part_sold(state, part)

func sell_part(state, part: Dictionary) -> bool:
	if not can_sell_part(state, part):
		return false
	state.credits += int(part.get("sell", 0))
	state.constitution -= int(part.get("con", 0))
	state.sold_parts.append(part.get("id", ""))
	return true

func can_buyback_part(state, part: Dictionary) -> bool:
	return part_sold(state, part) and state.credits >= int(part.get("buy", 0))

func buyback_part(state, part: Dictionary) -> bool:
	if not can_buyback_part(state, part):
		return false
	state.credits -= int(part.get("buy", 0))
	state.constitution += int(part.get("con", 0))
	state.sold_parts.erase(part.get("id", ""))
	return true
