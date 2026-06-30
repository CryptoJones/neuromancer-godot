extends RefCounted
## DialogEngine — data-driven branching conversation runner.
##
## Loads a node graph from JSON ({ "start": id, "nodes": { id: {text, options[]} } })
## and walks it option by option. Pure logic, no display — the UI reads current_*
## and calls choose(). Reusable for any NPC in later milestones.

var npc_name: String = ""
var _nodes: Dictionary = {}
var _current: String = ""

## Load a dialog file like "res://data/npcs/ratz.json". Returns true on success.
func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("DialogEngine: missing dialog file '%s'" % path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("nodes"):
		push_warning("DialogEngine: bad dialog file '%s'" % path)
		return false
	npc_name = parsed.get("name", "")
	_nodes = parsed["nodes"]
	_current = parsed.get("start", "")
	return _nodes.has(_current)

func current_id() -> String:
	return _current

func current_text() -> String:
	if _nodes.has(_current):
		return _nodes[_current].get("text", "")
	return ""

## Available options at the current node: an Array of { "text", "next" }.
func current_options() -> Array:
	if _nodes.has(_current):
		return _nodes[_current].get("options", [])
	return []

## Item id this node grants the player (e.g. Shin returning your deck), or "".
func current_grant() -> String:
	if _nodes.has(_current):
		return _nodes[_current].get("grant", "")
	return ""

## True when the current node has no options (conversation can end here).
func is_terminal() -> bool:
	return current_options().is_empty()

## Pick option `index`; advances to its "next" node. Returns false if invalid.
func choose(index: int) -> bool:
	var opts := current_options()
	if index < 0 or index >= opts.size():
		return false
	var nxt: String = opts[index].get("next", "")
	if not _nodes.has(nxt):
		return false
	_current = nxt
	return true
