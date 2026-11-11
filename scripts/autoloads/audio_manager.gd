extends Node

## Plays sound effects and background loops by name. A name maps to a file in assets/audio/:
## "win" is win.wav, "forest/place" is forest/place.wav. Effects play on the Effects bus and
## loops on the Music bus, and a grown-up can turn each off in the level picker; the choice is
## saved. A missing sound warns once and stays silent, so a sound problem never stops the game;
## a test checks every expected sound exists.
##
## Mechanics never call this. WorldBase, the main menu and the level HUD do, in response to
## signals. If another system (adaptive difficulty, a parent view) comes to need the same
## moments, add a game-events autoload that WorldBase reports to and have this listen to it,
## rather than adding more direct calls.

## Emitted when an effect starts.
signal sfx_played(sound: String)
## Emitted when a different background loop starts.
signal music_changed(sound: String)

## Sounds every world shares.
const SHARED_SOUNDS: Array[String] = ["win", "lose", "complete", "tap"]
## Sounds each world needs under its id, e.g. "forest/place".
const WORLD_SOUNDS: Array[String] = ["ambience", "place", "remove"]
## The main menu's background loop.
const MENU_MUSIC := "menu/ambience"

const _AUDIO_DIR := "res://assets/audio/"
const _MUSIC_BUS := &"Music"
const _EFFECTS_BUS := &"Effects"
const _EFFECT_PLAYERS := 6
const _CROSSFADE := 0.5
const _MUSIC_DB := -10.0
const _SILENT_DB := -60.0

var _streams := {}
var _warned := {}
var _effect_players: Array[AudioStreamPlayer] = []
var _next_effect: int = 0
# The loop playing now is _music_players[0]; the other fades out or waits.
var _music_players: Array[AudioStreamPlayer] = []
var _music: String = ""
var _fade: Tween


func _ready() -> void:
	for i in _EFFECT_PLAYERS:
		_effect_players.append(_add_player(_EFFECTS_BUS))
	for i in 2:
		_music_players.append(_add_player(_MUSIC_BUS))
	apply_saved_settings()


## Plays a sound effect by name. Players are taken in turn, so quick sounds overlap rather than cut
## each other off. An unknown name stays silent.
func play_sfx(sound: String) -> void:
	var stream: AudioStream = _stream(sound)
	if stream == null:
		return
	var player: AudioStreamPlayer = _effect_players[_next_effect]
	_next_effect = (_next_effect + 1) % _effect_players.size()
	player.stream = stream
	player.play()
	sfx_played.emit(sound)


## Crossfades to the named background loop. Asking for the loop already playing does nothing, and an
## unknown name leaves the current loop playing.
func play_music(sound: String) -> void:
	if sound == _music:
		return
	var stream: AudioStream = _stream(sound)
	if stream == null:
		return
	_set_looping(stream)
	_music = sound
	var outgoing: AudioStreamPlayer = _music_players[0]
	var incoming: AudioStreamPlayer = _music_players[1]
	_music_players = [incoming, outgoing]
	if _fade:
		_fade.kill()
	incoming.stream = stream
	incoming.volume_db = _SILENT_DB
	incoming.play()
	_fade = create_tween().set_parallel()
	_fade.tween_property(incoming, "volume_db", _MUSIC_DB, _CROSSFADE)
	_fade.tween_property(outgoing, "volume_db", _SILENT_DB, _CROSSFADE)
	_fade.chain().tween_callback(outgoing.stop)
	music_changed.emit(sound)


## Returns the name of the background loop playing, or "" if none.
func current_music() -> String:
	return _music


## Returns every sound name the game expects to find: the shared sounds, each registered world's
## WORLD_SOUNDS, and the menu's loop.
func expected_sounds() -> Array[String]:
	var sounds: Array[String] = SHARED_SOUNDS.duplicate()
	for world in GameRegistry.get_worlds():
		for sound in WORLD_SOUNDS:
			sounds.append("%s/%s" % [world["id"], sound])
	sounds.append(MENU_MUSIC)
	return sounds


## Turns background sound on or off, and saves the choice.
func set_music_enabled(enabled: bool) -> void:
	SaveManager.save_music_enabled(enabled)
	_mute_bus(_MUSIC_BUS, not enabled)


## Returns true while background sound is on.
func is_music_enabled() -> bool:
	return SaveManager.load_music_enabled()


## Turns sound effects on or off, and saves the choice.
func set_effects_enabled(enabled: bool) -> void:
	SaveManager.save_effects_enabled(enabled)
	_mute_bus(_EFFECTS_BUS, not enabled)


## Returns true while sound effects are on.
func is_effects_enabled() -> bool:
	return SaveManager.load_effects_enabled()


## Mutes or unmutes each bus to match the saved settings. Runs at startup, so sound turned off last
## time is off before anything plays.
func apply_saved_settings() -> void:
	_mute_bus(_MUSIC_BUS, not SaveManager.load_music_enabled())
	_mute_bus(_EFFECTS_BUS, not SaveManager.load_effects_enabled())


func _add_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _mute_bus(bus: StringName, mute: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), mute)


func _stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path: String = _AUDIO_DIR + sound + ".wav"
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream == null:
		if not _warned.has(sound):
			_warned[sound] = true
			push_warning("AudioManager: no sound at %s" % path)
		return null
	_streams[sound] = stream
	return stream


# Generated .wav files carry no loop points, so a loop is set to repeat when it is first played.
func _set_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
