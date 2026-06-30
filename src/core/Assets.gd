extends Node
## Assets — runtime loader for extracted, git-ignored game assets (autoload).
##
## The PNGs under res://assets/ are regenerated per-user by tools/extract_dat and
## are NOT part of Godot's import pipeline. We therefore load them straight off
## disk at runtime instead of referencing imported res:// textures. Anything that
## is missing degrades gracefully (returns null) so the game still boots.

const HD_BG_DIR := "res://assets/backgrounds_hd/"   # owned, committed art (M4 swap)
const BG_DIR := "res://assets/backgrounds/"          # extracted EGA originals (gitignored)
const SPRITE_DIR := "res://assets/sprites/"
const TEXT_PATH := "res://assets/text/game_text.json"

var _tex_cache: Dictionary = {}      # path -> Texture2D (or null sentinel)
var _text_data: Dictionary = {}      # parsed game_text.json
var _text_loaded := false

## Load a PNG off disk into a Texture2D. Returns null (and warns) if missing.
func load_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_warning("Assets: cannot load image '%s' (err %d)" % [path, err])
		_tex_cache[path] = null
		return null
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex

## Background for a room's bg id. Prefer the owned, modern HD plate
## (assets/backgrounds_hd/R1.png, 1344x768); fall back to the extracted EGA
## original (assets/backgrounds/R1_PIC.png, 304x112) when no HD art exists.
func background(bg_id: String) -> Texture2D:
	if bg_id == "":
		return null
	var hd_path := HD_BG_DIR + bg_id + ".png"
	if _tex_cache.has(hd_path):
		if _tex_cache[hd_path] != null:
			return _tex_cache[hd_path]
	elif FileAccess.file_exists(hd_path):
		var hd := load_texture(hd_path)
		if hd != null:
			return hd
	return load_texture(BG_DIR + bg_id + "_PIC.png")

## Sprite/title image by name, e.g. sprite("TITLE") -> TITLE_IMH.png.
func sprite(name: String) -> Texture2D:
	return load_texture(SPRITE_DIR + name + "_IMH.png")

func _ensure_text() -> void:
	if _text_loaded:
		return
	_text_loaded = true
	if not FileAccess.file_exists(TEXT_PATH):
		push_warning("Assets: %s not found; room prose unavailable" % TEXT_PATH)
		return
	var raw := FileAccess.get_file_as_string(TEXT_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		_text_data = parsed
	else:
		push_warning("Assets: could not parse %s" % TEXT_PATH)

## Return the descriptive prose for a text key like "R1.BIH".
## The extracted lists carry decode-noise tokens (short all-caps gibberish) plus
## the real prose. The room's rich description is the longest real sentence, so
## we return that. Returns "" when the key is absent or only noise.
func room_prose(text_key: String) -> String:
	_ensure_text()
	if not _text_data.has(text_key):
		return ""
	var best := ""
	for s in _text_data[text_key]:
		if typeof(s) != TYPE_STRING:
			continue
		# Skip short decode-noise tokens (e.g. "FZZ_", "sFsZw").
		if s.length() < 30:
			continue
		if s.length() > best.length():
			best = s
	return best
