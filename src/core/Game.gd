extends Control
## Game — the Chiba City real-world adventure loop (M1 vertical slice).
##
## The Boot scene is just an empty Control named "Main" with this script; every
## widget (framed view window, HUD, dialog panel, exit buttons) is built here in
## code at the 320x200 base resolution. Flow:
##   TITLE -> NAME -> EXPLORE <-> DIALOG, with F5/F9 save/load in EXPLORE.

enum State { TITLE, NAME, EXPLORE, DIALOG, MENU }

# Preloaded (not class_name globals) so the game runs without a prebuilt
# .godot global-class cache — i.e. on a fresh checkout before any editor open.
const World = preload("res://src/world/World.gd")
const DialogEngine = preload("res://src/world/DialogEngine.gd")
const SaveSystem = preload("res://src/core/SaveSystem.gd")
const Catalog = preload("res://src/econ/Catalog.gd")

const ROOMS_PATH := "res://data/rooms/chiba.json"
const NPC_DIR := "res://data/npcs/"
const VIEW_W := 304
const VIEW_H := 124   # taller frame: the owned HD plates are ~16:9, not the EGA letterbox
const MINUTES_PER_MOVE := 3
const BG_PIXEL_W := 320   # downscale width: keeps the plates chunky/retro while text stays crisp

var _state: int = State.TITLE
var _world: World
var _dialog: DialogEngine
var _pix_cache: Dictionary = {}      # bg_id -> downscaled (pixelated) Texture2D

# Layers
var _title_layer: Control
var _name_layer: Control
var _explore_layer: Control
var _dialog_layer: Control
var _menu_layer: Control

# Menu (shop / inventory / organ bank) widgets
var _menu_title: Label
var _menu_info: Label
var _menu_list: VBoxContainer
var _catalog                          # Catalog instance (items/shops + economy)

# Explore widgets
var _bg_rect: TextureRect
var _bg_placeholder: ColorRect
var _room_name_lbl: Label
var _desc_lbl: Label
var _status_lbl: Label
var _button_bar: HBoxContainer

# Dialog widgets
var _dialog_text: Label
var _dialog_options: VBoxContainer

var _name_edit: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_theme()
	_world = World.new()
	if not _world.load_file(ROOMS_PATH):
		push_error("Game: failed to load room graph %s" % ROOMS_PATH)
	_catalog = Catalog.new()
	_catalog.load_data()
	_build_title_layer()
	_build_name_layer()
	_build_explore_layer()
	_build_dialog_layer()
	_build_menu_layer()
	_go_title()


## DOS-terminal font (VT323, OFL), rendered as MSDF so glyphs stay razor-crisp at
## ANY window scale. canvas_items stretch scales the 2D up by the window factor;
## on a non-integer factor (e.g. a Chromebook fullscreen) an ordinary rasterised
## pixel font smears into blur, but MSDF glyphs are resolution-independent — the
## shader evaluates them at the final pixel size, so they're sharp everywhere.
## Cascades to all child controls.
func _apply_theme() -> void:
	var f := FontFile.new()
	if f.load_dynamic_font("res://fonts/VT323-Regular.ttf") != OK:
		push_warning("Game: VT323 font not found; using default font")
		return
	f.multichannel_signed_distance_field = true
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NONE
	var th := Theme.new()
	th.default_font = f
	# Scale the whole UI's fonts up a notch now that they render crisp — easier to
	# read on a phone/Chromebook without reflowing the 320x200 layout.
	th.default_font_size = 8
	theme = th


# ---------------------------------------------------------------- layer builders

func _full_control(name: String) -> Control:
	var c := Control.new()
	c.name = name
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _small(node: Control, size: int) -> void:
	node.add_theme_font_size_override("font_size", size)

func _build_title_layer() -> void:
	_title_layer = _full_control("Title")
	var tex := Assets.sprite("TITLE")
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2.ZERO
		tr.size = Vector2(320, 200)
		_title_layer.add_child(tr)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.04, 0.02, 0.08)
		bg.size = Vector2(320, 200)
		_title_layer.add_child(bg)
		var t := Label.new()
		t.text = "N E U R O M A N C E R"
		t.position = Vector2(0, 80)
		t.size = Vector2(320, 20)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_small(t, 14)
		_title_layer.add_child(t)
	var prompt := Label.new()
	prompt.text = "press any key"
	prompt.position = Vector2(0, 184)
	prompt.size = Vector2(320, 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_small(prompt, 8)
	_title_layer.add_child(prompt)

func _build_name_layer() -> void:
	_name_layer = _full_control("NameEntry")
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04)
	bg.size = Vector2(320, 200)
	_name_layer.add_child(bg)
	var lbl := Label.new()
	lbl.text = "Jack in, cowboy.\nWhat do they call you?"
	lbl.position = Vector2(20, 70)
	lbl.size = Vector2(280, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_small(lbl, 10)
	_name_layer.add_child(lbl)
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(80, 110)
	_name_edit.size = Vector2(160, 16)
	_name_edit.placeholder_text = "Case"
	_name_edit.max_length = 16
	_small(_name_edit, 9)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_layer.add_child(_name_edit)

func _build_explore_layer() -> void:
	_explore_layer = _full_control("Explore")
	_explore_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	var screen := ColorRect.new()
	screen.color = Color(0.02, 0.02, 0.04)
	screen.size = Vector2(320, 200)
	_explore_layer.add_child(screen)
	# Framed view window.
	var frame := ColorRect.new()
	frame.color = Color(0.35, 0.30, 0.20)
	frame.position = Vector2(6, 4)
	frame.size = Vector2(VIEW_W + 4, VIEW_H + 4)
	_explore_layer.add_child(frame)
	_bg_placeholder = ColorRect.new()
	_bg_placeholder.color = Color(0.10, 0.10, 0.16)
	_bg_placeholder.position = Vector2(8, 6)
	_bg_placeholder.size = Vector2(VIEW_W, VIEW_H)
	_explore_layer.add_child(_bg_placeholder)
	_bg_rect = TextureRect.new()
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# COVERED keeps the plate's aspect (no squish) and fills the frame; clip the
	# overflow so the wide HD art never bleeds past the window into the HUD.
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.clip_contents = true
	# NEAREST so the downscaled plate blows back up into chunky retro pixels
	# (canvas_items mode otherwise linear-filters it into a soft blur).
	_bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg_rect.position = Vector2(8, 6)
	_bg_rect.size = Vector2(VIEW_W, VIEW_H)
	_explore_layer.add_child(_bg_rect)
	# Room name.
	_room_name_lbl = Label.new()
	_room_name_lbl.position = Vector2(8, 132)
	_room_name_lbl.size = Vector2(VIEW_W, 10)
	_room_name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_small(_room_name_lbl, 9)
	_explore_layer.add_child(_room_name_lbl)
	# Description.
	_desc_lbl = Label.new()
	_desc_lbl.position = Vector2(8, 143)
	_desc_lbl.size = Vector2(VIEW_W, 31)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.85))
	_small(_desc_lbl, 7)
	_explore_layer.add_child(_desc_lbl)
	# Button bar (exits + actions).
	_button_bar = HBoxContainer.new()
	_button_bar.position = Vector2(8, 175)
	_button_bar.size = Vector2(VIEW_W, 12)
	_button_bar.add_theme_constant_override("separation", 3)
	_explore_layer.add_child(_button_bar)
	# Status HUD.
	var status_bg := ColorRect.new()
	status_bg.color = Color(0.06, 0.07, 0.10)
	status_bg.position = Vector2(0, 189)
	status_bg.size = Vector2(320, 11)
	_explore_layer.add_child(status_bg)
	_status_lbl = Label.new()
	_status_lbl.position = Vector2(4, 190)
	_status_lbl.size = Vector2(312, 10)
	_status_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	_small(_status_lbl, 7)
	_explore_layer.add_child(_status_lbl)

func _build_dialog_layer() -> void:
	_dialog_layer = _full_control("Dialog")
	_dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	# Opaque text box below the framed scene (keeps the room art visible up top,
	# the way the original lays out conversations). An explicit StyleBoxFlat makes
	# it solid so the explore layer behind it never bleeds through.
	var panel := Panel.new()
	panel.position = Vector2(4, 118)
	panel.size = Vector2(312, 82)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09)
	sb.border_color = Color(0.35, 0.30, 0.20)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	_dialog_layer.add_child(panel)
	_dialog_text = Label.new()
	_dialog_text.position = Vector2(6, 4)
	_dialog_text.size = Vector2(300, 42)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.add_theme_color_override("font_color", Color(0.85, 0.90, 0.85))
	_small(_dialog_text, 7)
	panel.add_child(_dialog_text)
	_dialog_options = VBoxContainer.new()
	_dialog_options.position = Vector2(6, 48)
	_dialog_options.size = Vector2(300, 30)
	_dialog_options.add_theme_constant_override("separation", 1)
	panel.add_child(_dialog_options)

func _build_menu_layer() -> void:
	# One reusable full-screen list panel for shops, the organ bank, and inventory.
	_menu_layer = _full_control("Menu")
	_menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.07)
	sb.border_color = Color(0.35, 0.30, 0.20)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	_menu_layer.add_child(panel)
	_menu_title = Label.new()
	_menu_title.position = Vector2(8, 5)
	_menu_title.size = Vector2(304, 12)
	_menu_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_small(_menu_title, 10)
	panel.add_child(_menu_title)
	_menu_info = Label.new()
	_menu_info.position = Vector2(8, 18)
	_menu_info.size = Vector2(304, 10)
	_menu_info.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	_small(_menu_info, 7)
	panel.add_child(_menu_info)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 30)
	scroll.size = Vector2(306, 166)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_menu_list = VBoxContainer.new()
	_menu_list.custom_minimum_size = Vector2(300, 0)
	_menu_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_menu_list)


# ---------------------------------------------------------------- menu (shop/inv)

func _menu_begin(title: String, info: String) -> void:
	_state = State.MENU
	_show_only(_menu_layer)
	_menu_title.text = title
	_menu_info.text = info
	for c in _menu_list.get_children():
		c.queue_free()

func _menu_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(298, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.78, 0.83, 0.85))
	_small(l, 7)
	_menu_list.add_child(l)

func _menu_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(298, 0)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_small(b, 7)
	if cb.is_valid():
		b.pressed.connect(cb)
	else:
		b.disabled = true
	_menu_list.add_child(b)

func _open_shop(shop_id: String, info: String) -> void:
	var shop: Dictionary = _catalog.shop(shop_id)
	_menu_begin(shop.get("name", "Shop"),
		info if info != "" else "Credits: %d" % GameState.credits)
	_menu_label("— FOR SALE —")
	for iid in shop.get("stock", []):
		var nm: String = _catalog.item_name(iid)
		var pr: int = _catalog.price(iid)
		if _catalog.owned(GameState, iid):
			_menu_button("[owned] %s" % nm, Callable())
		elif _catalog.can_buy(GameState, iid):
			_menu_button("Buy: %s — %d cr  · %s" % [nm, pr, _catalog.item(iid).get("desc", "")],
				_buy.bind(shop_id, iid))
		else:
			_menu_button("(need %d cr) %s" % [pr, nm], Callable())
	if shop.get("buys", false) and not GameState.inventory.is_empty():
		_menu_label("— SELL (half price) —")
		for iid in GameState.inventory:
			_menu_button("Sell: %s — +%d cr" % [_catalog.item_name(iid), _catalog.sell_value(iid)],
				_sell.bind(shop_id, iid))
	_menu_button("« Back to the street", _go_explore)

func _buy(shop_id: String, iid: String) -> void:
	var nm: String = _catalog.item_name(iid)
	if _catalog.buy(GameState, iid):
		_open_shop(shop_id, "Bought %s.  Credits: %d" % [nm, GameState.credits])
	else:
		_open_shop(shop_id, "Can't afford %s." % nm)

func _sell(shop_id: String, iid: String) -> void:
	var nm: String = _catalog.item_name(iid)
	if _catalog.sell(GameState, iid):
		_open_shop(shop_id, "Sold %s.  Credits: %d" % [nm, GameState.credits])
	else:
		_open_shop(shop_id, "Can't sell that here.")

func _open_organbank(info: String) -> void:
	_menu_begin("The Body Shop",
		info if info != "" else "Credits: %d    Constitution: %d" % [GameState.credits, GameState.constitution])
	_menu_label("The surgeon's smile never wavers. \"We buy what you can spare — and sell it back, for a price.\"")
	for part in _catalog.parts:
		if _catalog.part_sold(GameState, part):
			if _catalog.can_buyback_part(GameState, part):
				_menu_button("Buy back %s — %d cr  (+%d CON)" % [part.get("name"), part.get("buy"), part.get("con")],
					_buyback_part.bind(part))
			else:
				_menu_button("(need %d cr) buy back %s" % [part.get("buy"), part.get("name")], Callable())
		else:
			_menu_button("Sell %s — +%d cr  (−%d CON)" % [part.get("name"), part.get("sell"), part.get("con")],
				_sell_part.bind(part))
	_menu_button("« Back to the street", _go_explore)

func _sell_part(part: Dictionary) -> void:
	if _catalog.sell_part(GameState, part):
		_open_organbank("Sold %s.  Credits: %d   CON: %d" % [part.get("name"), GameState.credits, GameState.constitution])
	else:
		_open_organbank("")

func _buyback_part(part: Dictionary) -> void:
	if _catalog.buyback_part(GameState, part):
		_open_organbank("Bought back %s.  Credits: %d   CON: %d" % [part.get("name"), GameState.credits, GameState.constitution])
	else:
		_open_organbank("Can't afford to buy that back.")

func _open_inventory() -> void:
	_menu_begin("%s — Gear" % GameState.player_name,
		"Credits: %d    HP: %d    CON: %d" % [GameState.credits, GameState.health, GameState.constitution])
	_menu_label("— HARDWARE / ITEMS —")
	if GameState.inventory.is_empty():
		_menu_label("   (nothing yet)")
	else:
		for iid in GameState.inventory:
			_menu_label("   " + _catalog.item_name(iid))
	_menu_label("— SOFTWARE —")
	if GameState.software.is_empty():
		_menu_label("   (none)")
	else:
		for sid in GameState.software:
			_menu_label("   %s  (rating %d)" % [_catalog.item_name(sid), int(GameState.software[sid].get("rating", 1))])
	_menu_label("— SKILLS —")
	if GameState.skills.is_empty():
		_menu_label("   (none)")
	else:
		for sk in GameState.skills:
			_menu_label("   %s  L%d" % [sk, int(GameState.skills[sk])])
	_menu_button("« Back", _go_explore)


# ---------------------------------------------------------------- PAX terminal

func _open_pax() -> void:
	var hh := int(GameState.game_minutes / 60.0) % 24
	var mm := GameState.game_minutes % 60
	_menu_begin("PAX — Public Access System",
		"Logged in: %s        %02d:%02d" % [GameState.player_name, hh, mm])
	_menu_button("Read the news", _open_pax_news)
	_menu_button("Read the message base", _open_pax_messages)
	_menu_button("« Log off", _go_explore)

func _open_pax_news() -> void:
	_menu_begin("PAX — Night City News", "")
	var news := Assets.text_list("NEWS.BIH")
	if news.is_empty():
		_menu_label("(news feed unavailable — run the extractor on your original game files)")
	for s in news:
		_menu_label(str(s))
	_menu_button("« Back to PAX", _open_pax)

func _open_pax_messages() -> void:
	_menu_begin("PAX — Message Base", "")
	var raw := Assets.text_list("PAXBBS.BIH")
	if raw.is_empty():
		_menu_label("(message base unavailable)")
	# Group the flat strings into messages, a new one starting at each "TO:".
	var block := ""
	for s in raw:
		var line := str(s)
		if line.begins_with("TO:") and block != "":
			_menu_label(block)
			block = line
		elif block == "":
			block = line
		else:
			block += "\n" + line
	if block != "":
		_menu_label(block)
	_menu_button("« Back to PAX", _open_pax)


# ---------------------------------------------------------------- state switches

func _show_only(active: Control) -> void:
	for layer in [_title_layer, _name_layer, _explore_layer, _dialog_layer, _menu_layer]:
		layer.visible = (layer == active)

func _go_title() -> void:
	_state = State.TITLE
	_show_only(_title_layer)

func _go_name() -> void:
	_state = State.NAME
	_show_only(_name_layer)
	_name_edit.text = ""
	_name_edit.grab_focus()

func _start_new_game(player_name: String) -> void:
	GameState.reset()
	GameState.player_name = player_name
	GameState.credits = 100
	GameState.health = 100
	GameState.constitution = 2000   # CONSTITUTION_MAX
	GameState.game_minutes = 360   # 06:00
	GameState.current_room = _world.start_id
	_go_explore()

func _go_explore() -> void:
	_state = State.EXPLORE
	_show_only(_explore_layer)
	_refresh_room()

func _go_dialog(npc_id: String) -> void:
	_dialog = DialogEngine.new()
	if not _dialog.load_file(NPC_DIR + npc_id + ".json"):
		return
	_state = State.DIALOG
	_explore_layer.visible = true   # keep room behind the panel
	_dialog_layer.visible = true
	_title_layer.visible = false
	_name_layer.visible = false
	_refresh_dialog()


# ---------------------------------------------------------------- explore render

func _refresh_room() -> void:
	var id := GameState.current_room
	var r := _world.room(id)
	_room_name_lbl.text = r.get("name", id)
	# Background — deliberately downscaled to low-res (nearest) so the plate reads
	# as chunky retro pixels when canvas_items stretch scales it up, while the
	# text/UI render crisp at native resolution.
	var tex := _pixelated_bg(r.get("bg", ""))
	_bg_rect.texture = tex
	_bg_rect.visible = tex != null
	_bg_placeholder.visible = tex == null
	# Description: prefer the room's extracted prose, fall back to authored desc.
	var prose := ""
	if r.has("text_key"):
		prose = Assets.room_prose(r["text_key"])
	if prose == "":
		prose = r.get("desc", "")
	_desc_lbl.text = prose
	_rebuild_buttons(r)
	_refresh_status()

## Downscale a room's HD plate to BG_PIXEL_W (nearest-neighbour) and cache it, so
## the canvas_items stretch blows it back up into chunky retro pixels. The owned
## 1344x768 art stays on disk untouched; only the on-screen plate is pixelated.
func _pixelated_bg(bg_id: String) -> Texture2D:
	if bg_id == "":
		return null
	if _pix_cache.has(bg_id):
		return _pix_cache[bg_id]
	var src := Assets.background(bg_id)
	if src == null:
		_pix_cache[bg_id] = null
		return null
	var img := src.get_image()
	var h := int(round(float(BG_PIXEL_W) * img.get_height() / img.get_width()))
	img.resize(BG_PIXEL_W, max(1, h), Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_pix_cache[bg_id] = tex
	return tex

func _rebuild_buttons(r: Dictionary) -> void:
	for c in _button_bar.get_children():
		c.queue_free()
	# Exit buttons.
	var dir_abbr := { "north": "N", "south": "S", "east": "E", "west": "W" }
	for dir in r.get("exits", {}).keys():
		var dest: String = r["exits"][dir]
		var b := Button.new()
		b.text = dir_abbr.get(dir, dir)
		b.tooltip_text = "Go %s to %s" % [dir, _world.room(dest).get("name", dest)]
		_small(b, 7)
		b.pressed.connect(_try_move.bind(dir))
		_button_bar.add_child(b)
	# Talk actions for NPCs in the room.
	for npc in r.get("npcs", []):
		var b := Button.new()
		b.text = "Talk"
		_small(b, 7)
		b.pressed.connect(_go_dialog.bind(npc))
		_button_bar.add_child(b)
	# Shop / organ bank, when the room offers them.
	if r.has("shop"):
		var shopb := Button.new()
		shopb.text = "Shop"
		_small(shopb, 7)
		shopb.pressed.connect(_open_shop.bind(String(r["shop"]), ""))
		_button_bar.add_child(shopb)
	if r.get("organbank", false):
		var orgb := Button.new()
		orgb.text = "Organs"
		_small(orgb, 7)
		orgb.pressed.connect(_open_organbank.bind(""))
		_button_bar.add_child(orgb)
	# PAX terminal, in rooms with a booth.
	if r.get("pax", false):
		var paxb := Button.new()
		paxb.text = "PAX"
		_small(paxb, 7)
		paxb.pressed.connect(_open_pax)
		_button_bar.add_child(paxb)
	# Inventory (always available).
	var invb := Button.new()
	invb.text = "Items"
	_small(invb, 7)
	invb.pressed.connect(_open_inventory)
	_button_bar.add_child(invb)
	# Save / Load.
	var sb := Button.new()
	sb.text = "Save"
	_small(sb, 7)
	sb.pressed.connect(_do_save)
	_button_bar.add_child(sb)
	var lb := Button.new()
	lb.text = "Load"
	_small(lb, 7)
	lb.pressed.connect(_do_load)
	_button_bar.add_child(lb)

func _refresh_status() -> void:
	var hh := int(GameState.game_minutes / 60.0) % 24
	var mm := GameState.game_minutes % 60
	var loc: String = _world.room(GameState.current_room).get("name", GameState.current_room)
	_status_lbl.text = "%s   CR %d   CON %d   %s   %02d:%02d" % [
		GameState.player_name, GameState.credits, GameState.constitution, loc, hh, mm]


# ---------------------------------------------------------------- actions

func _try_move(direction: String) -> void:
	if _state != State.EXPLORE:
		return
	var dest := _world.move(GameState.current_room, direction)
	if dest == "":
		return
	GameState.current_room = dest
	GameState.game_minutes += MINUTES_PER_MOVE
	_refresh_room()

func _do_save() -> void:
	SaveSystem.save_game()

func _do_load() -> void:
	if SaveSystem.load_game():
		_go_explore()


# ---------------------------------------------------------------- dialog render

func _refresh_dialog() -> void:
	_dialog_text.text = _dialog.current_text()
	for c in _dialog_options.get_children():
		c.queue_free()
	var opts := _dialog.current_options()
	for i in opts.size():
		var b := Button.new()
		b.text = "> " + str(opts[i].get("text", ""))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_small(b, 7)
		b.pressed.connect(_on_dialog_option.bind(i))
		_dialog_options.add_child(b)
	if _dialog.is_terminal():
		var b := Button.new()
		b.text = "(end conversation)"
		_small(b, 7)
		b.pressed.connect(_end_dialog)
		_dialog_options.add_child(b)

func _on_dialog_option(index: int) -> void:
	if _dialog.choose(index):
		_refresh_dialog()

func _end_dialog() -> void:
	_go_explore()


# ---------------------------------------------------------------- input

func _on_name_submitted(text: String) -> void:
	var n := text.strip_edges()
	if n == "":
		n = "Case"
	_start_new_game(n)

func _unhandled_input(event: InputEvent) -> void:
	match _state:
		State.TITLE:
			if (event is InputEventKey and event.pressed) \
					or (event is InputEventMouseButton and event.pressed):
				_go_name()
				get_viewport().set_input_as_handled()
		State.EXPLORE:
			if event is InputEventKey and event.pressed and not event.echo:
				_handle_explore_key(event.keycode)
		State.MENU:
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				_go_explore()
				get_viewport().set_input_as_handled()

func _handle_explore_key(keycode: int) -> void:
	match keycode:
		KEY_UP, KEY_W:
			_try_move("north")
		KEY_DOWN, KEY_S:
			_try_move("south")
		KEY_LEFT, KEY_A:
			_try_move("west")
		KEY_RIGHT, KEY_D:
			_try_move("east")
		KEY_I:
			_open_inventory()
		KEY_F5:
			_do_save()
		KEY_F9:
			_do_load()
