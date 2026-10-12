extends GutTest


func test_game_registry_lists_forest_then_sky() -> void:
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(ids, ["forest", "sky"])


func test_game_registry_world_scenes_and_icons_exist() -> void:
	for world in GameRegistry.get_worlds():
		assert_true(ResourceLoader.exists(world["scene"]), world["scene"])
		assert_true(ResourceLoader.exists(world["icon"]), world["icon"])


func test_game_registry_unknown_world_is_empty() -> void:
	assert_eq(GameRegistry.get_world("nowhere"), {})


func test_game_registry_level_counts_match_level_data() -> void:
	assert_eq(GameRegistry.get_level_count("forest"), 20)
	assert_eq(GameRegistry.get_level_count("sky"), 20)


func test_game_registry_requested_level_is_taken_once() -> void:
	GameRegistry.request_level("sky", 4)
	assert_eq(GameRegistry.take_requested_level("sky"), 4)
	assert_eq(GameRegistry.take_requested_level("sky"), -1)
