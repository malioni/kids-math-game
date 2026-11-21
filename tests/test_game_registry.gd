extends GutTest


func before_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = false


func after_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = true
	GameRegistry.last_world_request = ""
	GameRegistry.last_scene_request = ""


func test_game_registry_lists_forest_then_sky() -> void:
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(ids.slice(0, 2), ["forest", "sky"])


func test_game_registry_market_world_registered_after_sky() -> void:
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(ids.slice(0, 3), ["forest", "sky", "market"])


func test_game_registry_picnic_world_registered_after_market() -> void:
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(ids.slice(0, 4), ["forest", "sky", "market", "picnic"])


func test_game_registry_drive_world_registered_after_memory() -> void:
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(ids, ["forest", "sky", "market", "picnic", "memory", "drive"])


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


func test_game_registry_next_difficulty_follows_current_difficulty() -> void:
	GameRegistry.set_difficulty("easy")
	assert_eq(GameRegistry.next_difficulty(), "hard")
	GameRegistry.set_difficulty("hard")
	assert_eq(GameRegistry.next_difficulty(), "")


func _ids() -> Array[String]:
	var ids: Array[String] = []
	for world in GameRegistry.get_worlds():
		ids.append(world["id"])
	return ids


func test_game_registry_shuffle_worlds_defaults_to_every_world() -> void:
	assert_eq(GameRegistry.shuffle_worlds(), _ids())


func test_game_registry_switched_off_world_is_not_in_shuffle_worlds() -> void:
	assert_true(GameRegistry.set_shuffle_world_on("memory", false))
	assert_false("memory" in GameRegistry.shuffle_worlds())
	assert_eq(GameRegistry.shuffle_worlds().size(), _ids().size() - 1)
	assert_true(GameRegistry.set_shuffle_world_on("memory", true))
	assert_eq(GameRegistry.shuffle_worlds(), _ids())


func test_game_registry_shuffle_world_choice_is_saved() -> void:
	GameRegistry.set_shuffle_world_on("sky", false)
	SaveManager.reload()
	assert_false("sky" in GameRegistry.shuffle_worlds())
	assert_eq(SaveManager.load_shuffle_off(), ["sky"] as Array[String])


func test_game_registry_cannot_switch_off_below_two_worlds() -> void:
	var ids: Array[String] = _ids()
	for i in range(2, ids.size()):
		assert_true(GameRegistry.set_shuffle_world_on(ids[i], false))
	assert_false(GameRegistry.set_shuffle_world_on(ids[0], false))
	assert_eq(GameRegistry.shuffle_worlds(), [ids[0], ids[1]] as Array[String])


func test_game_registry_unregistered_off_ids_are_ignored() -> void:
	SaveManager.save_shuffle_off(["castle", "sky"] as Array[String])
	var expected: Array[String] = _ids()
	expected.erase("sky")
	assert_eq(GameRegistry.shuffle_worlds(), expected)


func test_game_registry_fewer_than_two_worlds_on_in_save_means_every_world() -> void:
	var off: Array[String] = _ids()
	off.remove_at(0)
	SaveManager.save_shuffle_off(off)
	assert_eq(GameRegistry.shuffle_worlds(), _ids())


func test_game_registry_shuffle_next_index_wraps_past_range_end() -> void:
	SaveManager.set_progress(SaveManager.progress_key("sky", "easy", true), 11)
	assert_eq(GameRegistry.shuffle_next_index("sky"), 0)
	GameRegistry.set_difficulty("hard")
	SaveManager.set_progress(SaveManager.progress_key("sky", "hard", true), 21)
	assert_eq(GameRegistry.shuffle_next_index("sky"), 10)


func test_game_registry_shuffle_next_index_keeps_place_on_new_round() -> void:
	SaveManager.set_progress(SaveManager.progress_key("sky", "easy", true), 6)
	SaveManager.save_shuffle_round_played(GameRegistry.SHUFFLE_ROUND_LENGTH)
	GameRegistry.start_shuffle()
	assert_eq(GameRegistry.shuffle_next_index("sky"), 5)


func test_game_registry_shuffle_position_counts_to_round_length() -> void:
	assert_eq(GameRegistry.shuffle_position(), Vector2i(1, 10))
	SaveManager.save_shuffle_round_played(4)
	assert_eq(GameRegistry.shuffle_position(), Vector2i(5, 10))
	SaveManager.save_shuffle_round_played(10)
	assert_eq(GameRegistry.shuffle_position(), Vector2i(10, 10))


func test_game_registry_round_finished_after_ten_wins() -> void:
	SaveManager.save_shuffle_round_played(9)
	assert_false(GameRegistry.is_shuffle_round_finished())
	SaveManager.save_shuffle_round_played(10)
	assert_true(GameRegistry.is_shuffle_round_finished())


func test_game_registry_start_new_shuffle_round_resets_count_only() -> void:
	SaveManager.save_shuffle_round_played(7)
	SaveManager.set_progress(SaveManager.progress_key("market", "easy", true), 4)
	GameRegistry.start_new_shuffle_round()
	assert_eq(SaveManager.load_shuffle_round_played(), 0)
	assert_eq(GameRegistry.shuffle_next_index("market"), 3)


func test_game_registry_start_shuffle_after_finished_round_resets_count() -> void:
	SaveManager.save_shuffle_round_played(10)
	GameRegistry.start_shuffle()
	assert_eq(SaveManager.load_shuffle_round_played(), 0)


func test_game_registry_start_shuffle_mid_round_keeps_count() -> void:
	SaveManager.save_shuffle_round_played(6)
	GameRegistry.start_shuffle()
	assert_eq(SaveManager.load_shuffle_round_played(), 6)


func test_game_registry_round_count_survives_leaving_shuffle() -> void:
	SaveManager.save_shuffle_round_played(3)
	GameRegistry.set_shuffle(false)
	GameRegistry.set_difficulty("hard")
	GameRegistry.go_to_world("sky", 12)
	GameRegistry.take_requested_level("sky")
	assert_eq(SaveManager.load_shuffle_round_played(), 3)
	GameRegistry.start_shuffle()
	assert_eq(GameRegistry.shuffle_position(), Vector2i(4, 10))


func test_game_registry_next_shuffle_world_only_picks_switched_on_worlds() -> void:
	for id in ["forest", "market", "picnic", "memory"]:
		GameRegistry.set_shuffle_world_on(id, false)
	for run in 30:
		assert_has(["sky", "drive"], GameRegistry.next_shuffle_world())


func test_game_registry_next_shuffle_world_never_returns_previous() -> void:
	for run in 30:
		assert_ne(GameRegistry.next_shuffle_world("market"), "market")
