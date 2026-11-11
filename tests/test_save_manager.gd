extends GutTest


func before_each() -> void:
	SaveFixture.clear()


func after_each() -> void:
	SaveFixture.clear()


func test_load_progress_returns_1_when_no_save_file() -> void:
	assert_eq(SaveManager.load_progress("forest"), 1)


func test_load_progress_returns_1_for_unknown_world() -> void:
	SaveManager.save_progress("forest", 3)
	assert_eq(SaveManager.load_progress("other"), 1)


func test_save_and_load_progress_roundtrip() -> void:
	SaveManager.save_progress("forest", 3)
	assert_eq(SaveManager.load_progress("forest"), 3)


func test_save_progress_updates_to_higher_value() -> void:
	SaveManager.save_progress("forest", 3)
	SaveManager.save_progress("forest", 5)
	assert_eq(SaveManager.load_progress("forest"), 5)


func test_save_progress_does_not_overwrite_with_lower_value() -> void:
	SaveManager.save_progress("forest", 5)
	SaveManager.save_progress("forest", 3)
	assert_eq(SaveManager.load_progress("forest"), 5)


func test_load_progress_returns_default_on_corrupt_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "forest", "not_an_int")
	cfg.save(SaveManager.save_path)
	SaveManager.reload()
	assert_eq(SaveManager.load_progress("forest"), 1)


func test_save_progress_replaces_a_corrupt_value() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "forest", "not_an_int")
	cfg.save(SaveManager.save_path)
	SaveManager.reload()
	SaveManager.save_progress("forest", 3)
	assert_eq(SaveManager.load_progress("forest"), 3)


func test_every_kind_of_save_is_still_there_after_a_restart() -> void:
	SaveManager.save_progress("forest:easy", 3)
	SaveManager.save_last_world("sky")
	SaveManager.save_difficulty("hard")
	SaveManager.save_play_mode("shuffle")
	SaveManager.reload()
	assert_eq(SaveManager.load_progress("forest:easy"), 3)
	assert_eq(SaveManager.load_last_world(), "sky")
	assert_eq(SaveManager.load_difficulty(), "hard")
	assert_eq(SaveManager.load_play_mode(), "shuffle")


func test_set_and_reset_progress_are_still_there_after_a_restart() -> void:
	SaveManager.set_progress("forest:easy", 5)
	SaveManager.set_progress("sky:easy", 5)
	SaveManager.reset_progress("sky:easy")
	SaveManager.reload()
	assert_eq(SaveManager.load_progress("forest:easy"), 5)
	assert_eq(SaveManager.load_progress("sky:easy"), 1)


func test_reload_of_an_unreadable_file_starts_empty() -> void:
	SaveManager.save_progress("forest", 3)
	var file := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	file.store_string("this is not [a config file")
	file.close()
	SaveManager.reload()
	assert_eq(SaveManager.load_progress("forest"), 1)


func test_save_progress_preserves_other_worlds() -> void:
	SaveManager.save_progress("forest", 3)
	SaveManager.save_progress("garden", 2)
	assert_eq(SaveManager.load_progress("forest"), 3)
	assert_eq(SaveManager.load_progress("garden"), 2)


func test_reset_progress_unconditionally_resets_to_1() -> void:
	SaveManager.save_progress("forest", 10)
	SaveManager.reset_progress("forest")
	assert_eq(SaveManager.load_progress("forest"), 1)


func test_reset_progress_works_on_missing_file() -> void:
	SaveManager.reset_progress("forest")
	assert_eq(SaveManager.load_progress("forest"), 1)


func test_set_progress_can_lower_the_saved_level() -> void:
	SaveManager.save_progress("forest", 9)
	SaveManager.set_progress("forest", 3)
	assert_eq(SaveManager.load_progress("forest"), 3)


func test_load_last_world_returns_empty_when_no_save_file() -> void:
	assert_eq(SaveManager.load_last_world(), "")


func test_save_and_load_last_world_roundtrip() -> void:
	SaveManager.save_last_world("sky")
	assert_eq(SaveManager.load_last_world(), "sky")


func test_save_last_world_preserves_progress() -> void:
	SaveManager.save_progress("forest", 4)
	SaveManager.save_last_world("sky")
	assert_eq(SaveManager.load_progress("forest"), 4)


func test_save_manager_progress_key_formats_world_difficulty_and_shuffle() -> void:
	assert_eq(SaveManager.progress_key("forest", "easy"), "forest:easy")
	assert_eq(SaveManager.progress_key("sky", "hard", true), "shuffle:sky:hard")


func test_save_manager_difficulty_defaults_to_easy_and_roundtrips() -> void:
	assert_eq(SaveManager.load_difficulty(), "easy")
	SaveManager.save_difficulty("hard")
	assert_eq(SaveManager.load_difficulty(), "hard")


func test_save_manager_invalid_difficulty_loads_as_easy() -> void:
	SaveManager.save_difficulty("impossible")
	assert_eq(SaveManager.load_difficulty(), "easy")


func test_save_manager_play_mode_defaults_to_worlds_and_roundtrips() -> void:
	assert_eq(SaveManager.load_play_mode(), "worlds")
	SaveManager.save_play_mode("shuffle")
	assert_eq(SaveManager.load_play_mode(), "shuffle")


func test_save_manager_migrate_progress_low_level_moves_to_easy() -> void:
	SaveManager.set_progress("forest", 7)
	SaveManager.migrate_progress(["forest", "sky"])
	assert_eq(SaveManager.load_progress("forest:easy"), 7)
	assert_eq(SaveManager.load_progress("forest:hard"), 1)
	var cfg := ConfigFile.new()
	cfg.load(SaveManager.save_path)
	assert_false(cfg.has_section_key("progress", "forest"))
	SaveManager.reload()
	assert_eq(SaveManager.load_progress("forest:easy"), 7, "the move was written to the file")


func test_save_manager_migrate_progress_high_level_moves_to_hard() -> void:
	SaveManager.set_progress("sky", 14)
	SaveManager.migrate_progress(["forest", "sky"])
	assert_eq(SaveManager.load_progress("sky:easy"), 1)
	assert_eq(SaveManager.load_progress("sky:hard"), 14)


func test_save_manager_migrate_progress_leaves_new_keys_alone() -> void:
	SaveManager.set_progress("forest:easy", 4)
	SaveManager.set_progress("forest", 9)
	SaveManager.migrate_progress(["forest"])
	assert_eq(SaveManager.load_progress("forest:easy"), 4)


func test_save_manager_sound_settings_default_to_on() -> void:
	assert_true(SaveManager.load_music_enabled())
	assert_true(SaveManager.load_effects_enabled())


func test_save_manager_sound_settings_survive_a_restart() -> void:
	SaveManager.save_music_enabled(false)
	SaveManager.save_effects_enabled(false)
	SaveManager.reload()
	assert_false(SaveManager.load_music_enabled())
	assert_false(SaveManager.load_effects_enabled())


func test_save_manager_sound_settings_are_separate() -> void:
	SaveManager.save_music_enabled(false)
	assert_true(SaveManager.load_effects_enabled())


func test_save_manager_invalid_sound_setting_loads_as_on() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "music_enabled", "no")
	cfg.save(SaveManager.save_path)
	SaveManager.reload()
	assert_true(SaveManager.load_music_enabled())
