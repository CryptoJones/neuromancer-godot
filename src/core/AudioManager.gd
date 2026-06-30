extends Node
## Crossfading background-music director (autoload).
##
## Holds two AudioStreamPlayers and fades between them whenever the area changes,
## so jacking into cyberspace or walking into the Body Shop swaps the score without
## a hard cut. Tracks are seamless, bar-aligned .ogg loops under assets/audio/music/.
##
## Loaded at runtime via AudioStreamOggVorbis.load_from_file (same no-import-pipeline
## approach the rest of the game uses for art), so a clean source checkout just works.

const MUSIC_DIR := "res://assets/audio/music/"
const FADE := 1.2          # crossfade seconds
const MUSIC_DB := -8.0     # nominal playback level

var enabled := true
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current := ""
var _cache := {}


func _ready() -> void:
	_a = _make_player()
	_b = _make_player()
	_active = _a


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = -80.0
	add_child(p)
	return p


func _load(track: String) -> AudioStream:
	if _cache.has(track):
		return _cache[track]
	var path := MUSIC_DIR + track + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	else:
		stream = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_cache[track] = stream
	return stream


## Crossfade to `track` (a filename stem under MUSIC_DIR). No-op if it's already
## playing, so calling this every room refresh is cheap and stable.
func play(track: String) -> void:
	if not enabled or track == "" or track == _current:
		return
	var stream := _load(track)
	if stream == null:
		return
	_current = track
	var prev := _active
	var next := _b if _active == _a else _a
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	_active = next
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(next, "volume_db", MUSIC_DB, FADE)
	tw.tween_property(prev, "volume_db", -80.0, FADE)
	tw.set_parallel(false)
	tw.tween_callback(prev.stop)


func stop() -> void:
	_current = ""
	var tw := create_tween()
	tw.tween_property(_active, "volume_db", -80.0, FADE)
	tw.tween_callback(_active.stop)


## Pick the right area track for a room dictionary (from World.room()).
func for_room(r: Dictionary) -> String:
	if r.get("organbank", false):
		return "body_shop"
	if r.has("shop"):
		return "shops_pax"
	return "streets"
