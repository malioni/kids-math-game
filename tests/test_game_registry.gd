extends GutTest

const _SAVE_PATH := "user://save.cfg"


func before_each() -> void:
	_clear_save()
	GameRegistry.change_scenes = false


func after_each() -> void:
	_clear_save()
	GameRegistry.change_scenes = true
	GameRegistry.last_world_request = ""


func _clear_save() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


## Marks shuffle as having played every level of the current difficulty in the given world.
func _finish_shuffle(world_id: String) -> void:
	var key: String = SaveManager.progress_key(world_id, GameRegistry.get_difficulty(), true)
	SaveManager.set_progress(key, GameRegistry.get_level_range().y + 2)


func test_game_registry_lists_forest_then_sky() -> void:
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(ids.slice(0, 2), ["forest", "sky"])


func test_game_registry_market_world_registered_after_sky() -> void:
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(ids.slice(0, 3), ["forest", "sky", "market"])


func test_game_registry_picnic_world_registered_after_market() -> void:
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(ids, ["forest", "sky", "market", "picnic"])


func test_game_registry_world_scenes_and_icons_exist() -> void:
	for world in GameRegistry.get_worlds():
		assert_true(ResourceLoader.exists(world["scene"]), world["scene"])
		assert_true(ResourceLoader.exists(world["icon"]), world["icon"])


func test_game_registry_unknown_world_is_empty() -> void:
	assert_eq(GameRegistry.get_world("nowhere"), {})


func test_game_registry_level_counts_match_level_data() -> void:
	assert_eq(GameRegistry.get_level_count("forest"), 20)
	assert_eq(GameRegistry.get_level_count("sky"), 20)


func test_game_registry_market_level_count_is_20() -> void:
	assert_eq(GameRegistry.get_level_count("market"), 20)


func test_game_registry_picnic_level_count_is_20() -> void:
	assert_eq(GameRegistry.get_level_count("picnic"), 20)


func test_game_registry_requested_level_is_taken_once() -> void:
	GameRegistry.request_level("sky", 4)
	assert_eq(GameRegistry.take_requested_level("sky"), 4)
	assert_eq(GameRegistry.take_requested_level("sky"), -1)


func test_game_registry_level_range_follows_difficulty() -> void:
	assert_eq(GameRegistry.get_level_range(), Vector2i(0, 9))
	GameRegistry.set_difficulty("hard")
	assert_eq(GameRegistry.get_level_range(), Vector2i(10, 19))


func test_game_registry_shuffle_next_index_starts_at_range_start() -> void:
	assert_eq(GameRegistry.shuffle_next_index("sky"), 0)
	GameRegistry.set_difficulty("hard")
	assert_eq(GameRegistry.shuffle_next_index("sky"), 10)


func test_game_registry_next_shuffle_world_skips_finished_worlds() -> void:
	for world_id in ["forest", "sky", "picnic"]:
		_finish_shuffle(world_id)
	for run in 20:
		assert_eq(GameRegistry.next_shuffle_world(), "market")


func test_game_registry_next_shuffle_world_empty_when_all_finished() -> void:
	for world in GameRegistry.get_worlds():
		_finish_shuffle(world["id"])
	assert_eq(GameRegistry.next_shuffle_world(), "")


func test_game_registry_set_shuffle_persists_mode() -> void:
	assert_false(GameRegistry.is_shuffle())
	GameRegistry.set_shuffle(true)
	assert_true(GameRegistry.is_shuffle())
	assert_eq(SaveManager.load_play_mode(), "shuffle")


func test_game_registry_go_to_world_without_scene_changes_records_request() -> void:
	GameRegistry.go_to_world("sky", 4)
	assert_eq(GameRegistry.last_world_request, "sky")
	assert_eq(GameRegistry.take_requested_level("sky"), 4)


func test_game_registry_start_shuffle_goes_to_a_world_and_turns_shuffle_on() -> void:
	GameRegistry.start_shuffle()
	assert_true(GameRegistry.is_shuffle())
	assert_true(GameRegistry.get_world(GameRegistry.last_world_request).size() > 0)


func test_game_registry_start_shuffle_resets_when_all_finished() -> void:
	for world in GameRegistry.get_worlds():
		_finish_shuffle(world["id"])
	GameRegistry.start_shuffle()
	assert_ne(GameRegistry.last_world_request, "")
	for world in GameRegistry.get_worlds():
		assert_eq(GameRegistry.shuffle_next_index(world["id"]), 0)


func test_game_registry_shuffle_position_counts_played_levels_across_worlds() -> void:
	var total: int = 10 * GameRegistry.get_worlds().size()
	assert_eq(GameRegistry.shuffle_position(), Vector2i(1, total))
	SaveManager.set_progress(SaveManager.progress_key("forest", "easy", true), 3)
	SaveManager.set_progress(SaveManager.progress_key("picnic", "easy", true), 2)
	assert_eq(GameRegistry.shuffle_position(), Vector2i(4, total))


func test_game_registry_shuffle_position_on_hard_also_starts_at_1() -> void:
	GameRegistry.set_difficulty("hard")
	SaveManager.set_progress(SaveManager.progress_key("sky", "hard", true), 13)
	assert_eq(GameRegistry.shuffle_position(), Vector2i(3, 10 * GameRegistry.get_worlds().size()))


func test_game_registry_shuffle_position_never_passes_total() -> void:
	for world in GameRegistry.get_worlds():
		_finish_shuffle(world["id"])
	var position: Vector2i = GameRegistry.shuffle_position()
	assert_eq(position.x, position.y)
