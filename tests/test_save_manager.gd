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
