extends GutTest

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("forest")


func test_world_forest_get_levels_for_world_returns_10_levels() -> void:
	assert_eq(_levels.size(), 10)


func test_world_forest_levels_are_in_order() -> void:
	var expected_ids: Array[String] = [
		"world_forest_01", "world_forest_02", "world_forest_03",
		"world_forest_04", "world_forest_05", "world_forest_06",
		"world_forest_07", "world_forest_08", "world_forest_09",
		"world_forest_10"
	]
	for i in _levels.size():
		assert_eq(_levels[i].get("id"), expected_ids[i])


func test_world_forest_all_levels_have_required_fields() -> void:
	var required: Array[String] = ["id", "world", "mechanic", "target_count", "narrative_key", "skill_tags"]
	for level in _levels:
		for field in required:
			assert_true(level.has(field), "Missing field '%s' in level '%s'" % [field, level.get("id", "?")])


func test_world_forest_all_levels_use_placement_mechanic() -> void:
	for level in _levels:
		assert_eq(level.get("mechanic"), "placement")


func test_world_forest_level_01_target_count_is_1() -> void:
	assert_eq(_levels[0].get("target_count"), 1)


func test_world_forest_level_02_target_count_is_2() -> void:
	assert_eq(_levels[1].get("target_count"), 2)


func test_world_forest_level_03_target_count_is_2() -> void:
	assert_eq(_levels[2].get("target_count"), 2)


func test_world_forest_level_04_target_count_is_3() -> void:
	assert_eq(_levels[3].get("target_count"), 3)


func test_world_forest_level_05_target_count_is_3() -> void:
	assert_eq(_levels[4].get("target_count"), 3)


func test_world_forest_level_06_target_count_is_3() -> void:
	assert_eq(_levels[5].get("target_count"), 3)


func test_world_forest_level_07_target_count_is_4() -> void:
	assert_eq(_levels[6].get("target_count"), 4)


func test_world_forest_level_08_target_count_is_4() -> void:
	assert_eq(_levels[7].get("target_count"), 4)


func test_world_forest_level_09_target_count_is_5() -> void:
	assert_eq(_levels[8].get("target_count"), 5)


func test_world_forest_level_10_target_count_is_5() -> void:
	assert_eq(_levels[9].get("target_count"), 5)
