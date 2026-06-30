extends Node
## Crossfading background-music director (autoload).
##
## Holds two AudioStreamPlayers and fades between them whenever the area changes,
## so jacking into cyberspace or walking into the Body Shop swaps the score without
## a hard cut. Tracks are seamless, bar-aligned .ogg loops under assets/audio/music/.
## Also drives a playlist mode (the whole soundtrack back-to-back, looping) for the
## hidden room 1337.
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
# Playlist mode (hidden room): play a list of tracks in order, advancing on finish.
var _playlist: Array = []
var _pl_idx := 0
var _pl_active := false


func _ready() -> void:
	_a = _make_player()
	_b = _make_player()
	_active = _a
	_a.finished.connect(_on_finished.bind(_a))
	_b.finished.connect(_on_finished.bind(_b))


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = -80.0
	add_child(p)
	return p


func _load(track: String, loop_it := true) -> AudioStream:
	var key := "%s|%d" % [track, int(loop_it)]
	if _cache.has(key):
		return _cache[key]
	var path := MUSIC_DIR + track + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	else:
		stream = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
	if stream is AudioStreamOggVorbis:
		stream.loop = loop_it
	_cache[key] = stream
	return stream


func _crossfade_to(stream: AudioStream) -> void:
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


## Crossfade to a single looping `track`. No-op if it's already playing, so calling
## this every room refresh is cheap and stable. Leaving playlist mode if it was on.
func play(track: String) -> void:
	_pl_active = false
	if not enabled or track == "" or track == _current:
		return
	var stream := _load(track, true)
	if stream == null:
		return
	_current = track
	_crossfade_to(stream)


## Play a whole list of tracks back-to-back, looping the list forever (hidden room).
func play_playlist(tracks: Array) -> void:
	if not enabled or tracks.is_empty():
		return
	if _pl_active and _playlist == tracks:
		return   # already running this playlist — don't restart it
	_playlist = tracks.duplicate()
	_pl_idx = 0
	_pl_active = true
	_current = "__playlist__"
	_play_playlist_track()


func _play_playlist_track() -> void:
	var stream := _load(str(_playlist[_pl_idx]), false)   # non-looping so `finished` fires
	if stream == null:
		return
	_crossfade_to(stream)


func _on_finished(which: AudioStreamPlayer) -> void:
	if not _pl_active or which != _active:
		return
	_pl_idx = (_pl_idx + 1) % _playlist.size()
	_play_playlist_track()


## Skip forward/back in the playlist (wraps around). No-op outside playlist mode.
func next_track() -> void:
	if not _pl_active or _playlist.is_empty():
		return
	_pl_idx = (_pl_idx + 1) % _playlist.size()
	_play_playlist_track()


func prev_track() -> void:
	if not _pl_active or _playlist.is_empty():
		return
	_pl_idx = (_pl_idx - 1 + _playlist.size()) % _playlist.size()
	_play_playlist_track()


func current_track() -> String:
	if not _pl_active or _playlist.is_empty():
		return ""
	return str(_playlist[_pl_idx])


func stop() -> void:
	_pl_active = false
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
