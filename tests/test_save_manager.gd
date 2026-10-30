extends GutTest

const _SAVE_PATH := "user://save.cfg"


func before_each() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


func after_each() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


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
	cfg.save(_SAVE_PATH)
	assert_eq(SaveManager.load_progress("forest"), 1)


func test_get_session_count_returns_0_when_no_save_file() -> void:
	assert_eq(SaveManager.get_session_count(), 0)


func test_increment_and_get_session_count() -> void:
	SaveManager.increment_session_count()
	SaveManager.increment_session_count()
	assert_eq(SaveManager.get_session_count(), 2)


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
	cfg.load(_SAVE_PATH)
	assert_false(cfg.has_section_key("progress", "forest"))


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
