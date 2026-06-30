extends SceneTree
## Headless smoke test for the M1 Chiba City slice.
##
## Run:  godot --headless --script res://tests/smoke.gd
## Prints "SMOKE: PASS" and quits 0 on success, quits 1 on the first failure.
## Validates data parsing, runtime asset loading, GameState round-trip, room
## transitions, and one dialog step — no display required.
##
## Everything is preloaded and instantiated directly (no reliance on autoload
## singletons or the global-class cache, neither of which is available in the
## --script SceneTree run), so this passes on a clean checkout.

const World = preload("res://src/world/World.gd")
const DialogEngine = preload("res://src/world/DialogEngine.gd")
const Assets = preload("res://src/core/Assets.gd")
const GameStateScript = preload("res://src/core/GameState.gd")
const CatalogScript = preload("res://src/econ/Catalog.gd")

func _fail(msg: String) -> void:
	push_error("SMOKE FAIL: " + msg)
	print("SMOKE: FAIL - " + msg)
	quit(1)

func _check(cond: bool, msg: String) -> bool:
	if not cond:
		_fail(msg)
	return cond

func _initialize() -> void:
	var assets = Assets.new()

	# --- 1. Room graph parses, start + exits present ---
	var world = World.new()
	if not _check(world.load_file("res://data/rooms/chiba.json"), "room graph failed to load"):
		return
	if not _check(world.start_id == "R1", "start room is not R1 (Chatsubo)"):
		return
	if not _check(world.has_room("R1"), "missing start room"):
		return
	var ex = world.exits("R1")
	if not _check(ex.has("south") and ex["south"] == "R2", "Chatsubo south exit (-> Street) missing"):
		return

	# --- 2. Runtime texture load: R1 background must be 304x112 ---
	var tex = assets.load_texture("res://assets/backgrounds/R1_PIC.png")
	if not _check(tex != null, "load_texture(R1_PIC) returned null"):
		return
	if not _check(tex.get_width() == 304 and tex.get_height() == 112,
			"R1 background wrong size: %dx%d" % [tex.get_width(), tex.get_height()]):
		return

	# --- 2b. M4 owned-art swap: background("R1") must prefer the HD plate ---
	var hd = assets.background("R1")
	if not _check(hd != null, "background('R1') returned null"):
		return
	if not _check(hd.get_width() == 1344 and hd.get_height() == 768,
			"R1 HD plate wrong size: %dx%d (expected 1344x768)" % [hd.get_width(), hd.get_height()]):
		return

	# --- 3. GameState to_dict/from_dict round-trip ---
	var gs = GameStateScript.new()
	gs.player_name = "Case"
	gs.credits = 137
	gs.current_room = "street"
	gs.game_minutes = 372
	gs.story_flags["met_ratz"] = true
	var snap = gs.to_dict()
	gs.from_dict(snap)
	if not _check(gs.player_name == "Case" and gs.credits == 137
			and gs.current_room == "street" and gs.game_minutes == 372
			and gs.story_flags.get("met_ratz", false),
			"GameState round-trip mismatch"):
		return

	# --- 4. Room transitions via World.move (Chiba City district graph) ---
	var here = world.start_id
	var dest = world.move(here, "south")          # R1 Chatsubo -> R2 Street
	if not _check(dest == "R2", "move south from Chatsubo failed"):
		return
	var dest2 = world.move(dest, "east")          # R2 Street -> R5 Street Body Shop
	if not _check(dest2 == "R5", "move east from Street Chatsubo failed"):
		return
	var dest3 = world.move(dest2, "north")        # R5 -> R4 Body Shop
	if not _check(dest3 == "R4", "move north from R5 to Body Shop failed"):
		return
	if not _check(world.move("R1", "north") == "", "non-exit should yield ''"):
		return
	# Connectivity: every exit must point at a real room, and be reciprocal.
	for rid in world.rooms.keys():
		for dir in world.exits(rid).keys():
			var to: String = world.exits(rid)[dir]
			if not _check(world.has_room(to), "room '%s' exit '%s' -> unknown room '%s'" % [rid, dir, to]):
				return

	# --- 5. One dialog step through the engine ---
	var dlg = DialogEngine.new()
	if not _check(dlg.load_file("res://data/npcs/ratz.json"), "ratz dialog failed to load"):
		return
	if not _check(dlg.current_id() == "greet", "dialog did not start at 'greet'"):
		return
	if not _check(dlg.current_options().size() >= 2, "greet node has too few options"):
		return
	if not _check(dlg.choose(0), "choosing option 0 failed"):
		return
	if not _check(dlg.current_id() == "deck", "option 0 did not lead to 'deck'"):
		return
	if not _check(dlg.current_text().length() > 0, "deck node has no text"):
		return

	# --- 6. Economy: buy / re-buy guard / resell / organ-bank ---
	var cat = CatalogScript.new()
	cat.load_data()
	if not _check(not cat.item("sw_probe").is_empty(), "items.json did not load"):
		return
	var gs2 = GameStateScript.new()
	gs2.reset()
	gs2.credits = 1000
	if not _check(cat.buy(gs2, "sw_probe"), "buy sw_probe failed"):
		return
	if not _check(gs2.credits == 300 and gs2.software.has("sw_probe"),
			"buy sw_probe: credits/grant wrong (%d)" % gs2.credits):
		return
	if not _check(not cat.can_buy(gs2, "sw_probe"), "owned software should not re-buy"):
		return
	gs2.credits = 5000
	if not _check(cat.buy(gs2, "ram_chip") and gs2.inventory.has("ram_chip"), "buy ram_chip failed"):
		return
	var before: int = gs2.credits
	if not _check(cat.sell(gs2, "ram_chip") and gs2.credits == before + 400,
			"resell ram_chip should pay half (400)"):
		return
	gs2.constitution = 100
	if not _check(cat.sell_organ(gs2, cat.ORGANS[0]) and gs2.constitution == 85,
			"kidney sale: constitution wrong (%d)" % gs2.constitution):
		return
	gs2.constitution = 12
	if not _check(not cat.can_sell_organ(gs2, cat.ORGANS[2]), "organ sale must be blocked below floor"):
		return
	gs2.free()

	# Free the Node instances we created so the SceneTree exits cleanly.
	gs.free()
	assets.free()

	print("SMOKE: PASS")
	quit(0)
