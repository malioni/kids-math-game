extends GutTest

## AudioManager plays to Godot's silent driver in tests, so behaviour is checked through its
## signals, its buses and its players' settings.


func before_each() -> void:
	SaveFixture.clear()
	AudioManager.set_music_enabled(true)
	AudioManager.set_effects_enabled(true)


func after_each() -> void:
	SaveFixture.clear()
	AudioManager.set_music_enabled(true)
	AudioManager.set_effects_enabled(true)


func _bus_muted(bus: String) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))


func test_audio_manager_every_expected_sound_loads() -> void:
	var sounds: Array[String] = AudioManager.expected_sounds()
	assert_eq(sounds.size(), 4 + 3 * GameRegistry.get_worlds().size() + 1)
	for sound in ["win", "lose", "complete", "tap", "forest/place", "sky/remove", "menu/ambience"]:
		assert_has(sounds, sound)
	for world in GameRegistry.get_worlds():
		assert_has(sounds, "%s/ambience" % world["id"])
	for sound in sounds:
		var path: String = "res://assets/audio/%s.wav" % sound
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		assert_true(load(path) is AudioStream, "%s loads" % path)


func test_audio_manager_play_sfx_reports_the_sound() -> void:
	watch_signals(AudioManager)
	AudioManager.play_sfx("win")
	assert_signal_emitted_with_parameters(AudioManager, "sfx_played", ["win"])


func test_audio_manager_unknown_sounds_stay_silent() -> void:
	watch_signals(AudioManager)
	AudioManager.play_sfx("no/such_sound")
	AudioManager.play_music("no/such_loop")
	assert_signal_not_emitted(AudioManager, "sfx_played")
	assert_signal_not_emitted(AudioManager, "music_changed")


func test_audio_manager_unknown_music_keeps_the_current_loop() -> void:
	AudioManager.play_music("forest/ambience")
	AudioManager.play_music("no/such_loop")
	assert_eq(AudioManager.current_music(), "forest/ambience")


# Review focus: a child tapping bags quickly hears every one.
func test_audio_manager_many_quick_effects_all_play() -> void:
	watch_signals(AudioManager)
	for i in 10:
		AudioManager.play_sfx("tap")
	assert_signal_emit_count(AudioManager, "sfx_played", 10)


# Review focus: quick effects use different players, so none cuts off another.
func test_audio_manager_quick_effects_use_different_players() -> void:
	for player: AudioStreamPlayer in AudioManager._effect_players:
		player.stop()
	var count := 4
	for i in count:
		AudioManager.play_sfx("tap")
	var playing := 0
	for player: AudioStreamPlayer in AudioManager._effect_players:
		if player.playing:
			playing += 1
	assert_eq(playing, count, "each quick effect has its own player")


func test_audio_manager_same_music_does_not_restart() -> void:
	AudioManager.play_music("forest/ambience")
	watch_signals(AudioManager)
	AudioManager.play_music("forest/ambience")
	assert_signal_not_emitted(AudioManager, "music_changed")
	AudioManager.play_music("sky/ambience")
	assert_signal_emitted_with_parameters(AudioManager, "music_changed", ["sky/ambience"])
	assert_eq(AudioManager.current_music(), "sky/ambience")


# Review focus: the background loop keeps going past the end of its file.
func test_audio_manager_music_loops() -> void:
	AudioManager.play_music("picnic/ambience")
	var stream: AudioStreamWAV = AudioManager._stream("picnic/ambience")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_gt(stream.loop_end, 0)


# Review focus: switching loops again mid-crossfade ends with only the last one audible.
func test_audio_manager_quick_music_switches_end_on_the_last_loop() -> void:
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	AudioManager.play_music("market/ambience")
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	await wait_seconds(0.8)
	assert_eq(AudioManager.current_music(), AudioManager.MENU_MUSIC)
	var menu_stream: AudioStream = AudioManager._stream(AudioManager.MENU_MUSIC)
	for player: AudioStreamPlayer in AudioManager._music_players:
		if player.stream == menu_stream and player.playing:
			assert_almost_eq(player.volume_db, AudioManager._MUSIC_DB, 0.5)
		else:
			assert_true(
				not player.playing or player.volume_db <= AudioManager._SILENT_DB + 0.5,
				"the other loop is silent"
			)


func test_audio_manager_music_toggle_mutes_its_bus_and_is_saved() -> void:
	AudioManager.set_music_enabled(false)
	assert_true(_bus_muted("Music"))
	assert_false(_bus_muted("Effects"))
	SaveManager.reload()
	assert_false(AudioManager.is_music_enabled())
	AudioManager.set_music_enabled(true)
	assert_false(_bus_muted("Music"))


func test_audio_manager_effects_toggle_mutes_its_bus_and_is_saved() -> void:
	AudioManager.set_effects_enabled(false)
	assert_true(_bus_muted("Effects"))
	assert_false(_bus_muted("Music"))
	SaveManager.reload()
	assert_false(AudioManager.is_effects_enabled())
	AudioManager.set_effects_enabled(true)
	assert_false(_bus_muted("Effects"))


# Review focus: sound turned off last time means the game starts silent.
func test_audio_manager_saved_off_settings_mute_at_startup() -> void:
	SaveManager.save_music_enabled(false)
	SaveManager.save_effects_enabled(false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Effects"), false)
	AudioManager.apply_saved_settings()
	assert_true(_bus_muted("Music"))
	assert_true(_bus_muted("Effects"))
