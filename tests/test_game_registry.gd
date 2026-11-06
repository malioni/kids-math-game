extends GutTest


func before_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = false


func after_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = true
	GameRegistry.last_world_request = ""
	GameRegistry.last_scene_request = ""


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


func test_game_registry_every_world_has_levels_for_every_difficulty() -> void:
	for world in GameRegistry.get_worlds():
		var count: int = LevelLoader.get_levels_for_world(world["id"]).size()
		for difficulty in LevelLoader.DIFFICULTIES:
			var last: int = LevelLoader.get_difficulty_range(difficulty).y
			assert_gt(count, last, "%s has levels up to %s's last" % [world["id"], difficulty])


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


func test_game_registry_go_to_menu_without_scene_changes_records_request() -> void:
	GameRegistry.go_to_menu()
	assert_eq(GameRegistry.last_scene_request, GameRegistry.MENU_SCENE)


func test_game_registry_go_to_world_records_scene_path() -> void:
	GameRegistry.go_to_world("sky")
	assert_eq(GameRegistry.last_scene_request, GameRegistry.get_world("sky")["scene"])


func test_game_registry_go_to_world_with_scene_changes_uses_transition() -> void:
	var changer: Callable = Transition.scene_changer
	var paths: Array = []
	Transition.scene_changer = func(path: String) -> void: paths.append(path)
	GameRegistry.change_scenes = true
	GameRegistry.go_to_world("market")
	GameRegistry.change_scenes = false
	Transition.scene_changer = changer
	assert_eq(paths, [GameRegistry.get_world("market")["scene"]])


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
