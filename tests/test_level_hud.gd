extends GutTest

const SCENE := preload("res://scenes/ui/level_hud.tscn")
const ROW := "Root/Pause/Panel/Margin/Row/"

var hud: LevelHud


func before_each() -> void:
	SaveFixture.clear()
	hud = SCENE.instantiate()
	add_child(hud)
	hud.show_level("forest", 4)


func after_each() -> void:
	hud.queue_free()
	AudioManager.set_music_enabled(true)
	AudioManager.set_effects_enabled(true)
	SaveFixture.clear()


func _assert_tap_size(control: Control) -> void:
	assert_true(
		control.size.x >= 100 and control.size.y >= 100, "%s is %s" % [control.name, control.size]
	)


func _badge_text() -> String:
	return (
		hud.get_node("Root/LevelBadge/Row/LevelLabel").text
		+ hud.get_node("Root/LevelBadge/Row/CountLabel").text
	)


func test_level_hud_badge_on_easy_counts_to_10() -> void:
	assert_eq(_badge_text(), "5/10")


func test_level_hud_badge_on_hard_shows_real_number_out_of_20() -> void:
	GameRegistry.set_difficulty("hard")
	hud.show_level("forest", 13)
	assert_eq(_badge_text(), "14/20")


func test_level_hud_badge_in_shuffle_shows_place_in_round() -> void:
	GameRegistry.set_shuffle(true)
	SaveManager.save_shuffle_round_played(5)
	SaveManager.set_progress(SaveManager.progress_key("sky", "easy", true), 4)
	hud.show_level("sky", 3)
	assert_eq(_badge_text(), "6/10")


func test_level_hud_badge_shows_world_icon() -> void:
	var icon: Texture2D = hud.get_node("Root/LevelBadge/Row/WorldIcon").texture
	assert_eq(icon.resource_path, GameRegistry.get_world("forest")["icon"])


func test_level_hud_badge_shows_shuffle_icon_only_while_shuffling() -> void:
	var icon: TextureRect = hud.get_node("Root/LevelBadge/ShuffleIcon")
	assert_false(icon.visible)
	GameRegistry.set_shuffle(true)
	hud.show_level("sky", 2)
	assert_true(icon.visible)
	GameRegistry.set_shuffle(false)
	hud.show_level("sky", 2)
	assert_false(icon.visible)


func test_level_hud_pause_hidden_on_start() -> void:
	assert_false(hud.is_pause_open())


func test_level_hud_badge_press_opens_pause() -> void:
	hud.get_node("Root/LevelBadge").pressed.emit()
	assert_true(hud.is_pause_open())


func test_level_hud_pause_has_home_replay_music_effects_close() -> void:
	var names: Array = hud.get_node(ROW).get_children().map(func(n: Node) -> String: return n.name)
	assert_eq(names, ["HomeButton", "ReplayButton", "MusicButton", "EffectsButton", "CloseButton"])


func test_level_hud_pause_has_no_level_buttons_or_world_strip() -> void:
	assert_eq(hud.find_children("*", "WorldCarousel", true, false).size(), 0)
	assert_null(hud.get_node_or_null("Root/Picker"))
	for child in hud.get_node(ROW).get_children():
		assert_false(child is Button and child.text != "", "%s has no text" % child.name)


func test_level_hud_replay_emits_replay_requested_and_closes() -> void:
	hud.open_pause()
	watch_signals(hud)
	hud.get_replay_button().pressed.emit()
	assert_signal_emitted(hud, "replay_requested")
	assert_false(hud.is_pause_open())


func test_level_hud_pause_home_emits_home_requested_and_closes() -> void:
	hud.open_pause()
	watch_signals(hud)
	hud.get_home_buttons()[0].pressed.emit()
	assert_signal_emitted(hud, "home_requested")
	assert_false(hud.is_pause_open())


func test_level_hud_close_button_closes_pause() -> void:
	hud.open_pause()
	watch_signals(hud)
	hud.get_close_button().pressed.emit()
	assert_false(hud.is_pause_open())
	assert_signal_not_emitted(hud, "replay_requested")
	assert_signal_not_emitted(hud, "home_requested")


func test_level_hud_backdrop_tap_closes_pause() -> void:
	hud.open_pause()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	hud.get_node("Root/Pause/Backdrop").gui_input.emit(event)
	assert_false(hud.is_pause_open())


func test_level_hud_world_complete_shows_restart() -> void:
	hud.show_world_complete()
	assert_true(hud.is_world_complete_shown())
	watch_signals(hud)
	hud.get_restart_button().pressed.emit()
	assert_signal_emitted(hud, "restart_requested")
	assert_false(hud.is_world_complete_shown())


func test_level_hud_world_complete_restart_label_shows_first_level_of_difficulty() -> void:
	var label: Label = hud.get_node("Root/Complete/Choices/RestartButton/OneLabel")
	hud.show_world_complete()
	assert_eq(label.text, "1")
	GameRegistry.set_difficulty("hard")
	hud.show_world_complete()
	assert_eq(label.text, "11")
	assert_true(label.visible)


func test_level_hud_world_complete_in_shuffle_hides_restart_label() -> void:
	GameRegistry.set_shuffle(true)
	hud.show_world_complete()
	assert_false(hud.get_node("Root/Complete/Choices/RestartButton/OneLabel").visible)


func test_level_hud_world_complete_on_easy_shows_next_difficulty_button() -> void:
	hud.show_world_complete()
	var button: TextureButton = hud.get_next_difficulty_button()
	assert_true(button.visible)
	assert_eq(button.texture_normal.resource_path, "res://assets/sprites/ui/icon_hard.svg")


func test_level_hud_world_complete_on_hard_hides_next_difficulty_button() -> void:
	GameRegistry.set_difficulty("hard")
	hud.show_world_complete()
	assert_false(hud.get_next_difficulty_button().visible)


func test_level_hud_world_complete_in_shuffle_hides_next_difficulty_button() -> void:
	GameRegistry.set_shuffle(true)
	hud.show_world_complete()
	assert_false(hud.get_next_difficulty_button().visible)


func test_level_hud_next_difficulty_button_emits_next_difficulty_requested() -> void:
	hud.show_world_complete()
	watch_signals(hud)
	hud.get_next_difficulty_button().pressed.emit()
	assert_signal_emitted(hud, "next_difficulty_requested")
	assert_false(hud.is_world_complete_shown())


func test_level_hud_next_difficulty_label_shows_next_difficultys_first_level() -> void:
	hud.show_world_complete()
	var label: Label = hud.get_next_difficulty_button().get_node("FirstLabel")
	assert_eq(label.text, str(LevelLoader.get_difficulty_range("hard").x + 1))


func test_level_hud_world_complete_has_no_world_strip() -> void:
	hud.show_world_complete()
	assert_eq(hud.get_node("Root/Complete").find_children("*", "WorldCarousel").size(), 0)


func test_level_hud_show_level_closes_overlays() -> void:
	hud.show_world_complete()
	hud.show_level("forest", 0)
	assert_false(hud.is_world_complete_shown())
	hud.open_pause()
	hud.show_level("forest", 0)
	assert_false(hud.is_pause_open())
	assert_eq(hud.get_node("Root/LevelBadge/Row/LevelLabel").text, "1")


func test_level_hud_world_complete_home_button_emits_home_requested() -> void:
	hud.show_world_complete()
	watch_signals(hud)
	hud.get_home_buttons()[1].pressed.emit()
	assert_signal_emitted(hud, "home_requested")
	assert_false(hud.is_world_complete_shown())


func test_level_hud_buttons_meet_minimum_tap_size() -> void:
	hud.open_pause()
	await wait_process_frames(2)
	for child in hud.get_node(ROW).get_children():
		_assert_tap_size(child)
	hud.show_world_complete()
	await wait_process_frames(2)
	_assert_tap_size(hud.get_home_buttons()[1])
	_assert_tap_size(hud.get_restart_button())
	_assert_tap_size(hud.get_next_difficulty_button())


func test_level_hud_badge_tap_plays_tap() -> void:
	watch_signals(AudioManager)
	hud.get_node("Root/LevelBadge").pressed.emit()
	assert_signal_emitted_with_parameters(AudioManager, "sfx_played", ["tap"])


func test_level_hud_pause_and_complete_buttons_play_tap() -> void:
	var buttons: Array[BaseButton] = [
		hud.get_replay_button(),
		hud.get_close_button(),
		hud.get_restart_button(),
		hud.get_next_difficulty_button(),
	]
	buttons.append_array(hud.get_home_buttons())
	for button in buttons:
		watch_signals(AudioManager)
		button.pressed.emit()
		assert_signal_emitted_with_parameters(AudioManager, "sfx_played", ["tap"])


func test_level_hud_music_button_toggles_and_shows_it() -> void:
	hud.open_pause()
	var music: Button = hud.get_sound_buttons()[0]
	assert_eq(music.icon.resource_path, "res://assets/sprites/ui/icon_music_on.svg")
	music.pressed.emit()
	assert_false(AudioManager.is_music_enabled())
	assert_true(AudioManager.is_effects_enabled())
	assert_eq(music.icon.resource_path, "res://assets/sprites/ui/icon_music_off.svg")
	assert_true(hud.is_pause_open(), "a sound toggle keeps the pause panel open")
	music.pressed.emit()
	assert_true(AudioManager.is_music_enabled())


func test_level_hud_effects_button_toggles_and_shows_it() -> void:
	hud.open_pause()
	var effects: Button = hud.get_sound_buttons()[1]
	effects.pressed.emit()
	assert_false(AudioManager.is_effects_enabled())
	assert_true(AudioManager.is_music_enabled())
	assert_eq(effects.icon.resource_path, "res://assets/sprites/ui/icon_effects_off.svg")


func test_level_hud_sound_buttons_show_saved_settings_when_opened() -> void:
	AudioManager.set_music_enabled(false)
	hud.open_pause()
	assert_eq(
		hud.get_sound_buttons()[0].icon.resource_path, "res://assets/sprites/ui/icon_music_off.svg"
	)
