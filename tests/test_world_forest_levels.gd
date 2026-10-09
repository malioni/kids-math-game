extends GutTest

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("forest")


func test_world_forest_get_levels_for_world_returns_20_levels() -> void:
	assert_eq(_levels.size(), 20)


func test_world_forest_levels_are_in_order() -> void:
	for i in _levels.size():
		assert_eq(_levels[i].get("id"), "world_forest_%02d" % (i + 1))


func test_world_forest_all_levels_have_required_fields() -> void:
	var required: Array[String] = [
		"id",
		"world",
		"mechanic",
		"bridge_length",
		"plank_length",
		"plank_count",
		"max_solutions",
		"narrative_key",
		"skill_tags",
	]
	for level in _levels:
		for field in required:
			var msg := "Missing field '%s' in level '%s'" % [field, level.get("id", "?")]
			assert_true(level.has(field), msg)


func test_world_forest_all_levels_use_placement_mechanic() -> void:
	for level in _levels:
		assert_eq(level.get("mechanic"), "placement")


func test_world_forest_all_ranges_have_min_le_max() -> void:
	for level in _levels:
		for field in ["bridge_length", "plank_length"]:
			var range_dict: Dictionary = level[field]
			assert_lte(range_dict["min"], range_dict["max"], "%s in %s" % [field, level["id"]])


func test_world_forest_level_01_bridge_length_below_5() -> void:
	assert_lt(_levels[0]["bridge_length"]["max"], 5)


func test_world_forest_level_10_bridge_length_around_30() -> void:
	assert_gte(_levels[9]["bridge_length"]["min"], 25)
	assert_lte(_levels[9]["bridge_length"]["max"], 35)


func test_world_forest_level_20_bridge_length_around_50() -> void:
	assert_gte(_levels[19]["bridge_length"]["min"], 45)
	assert_lte(_levels[19]["bridge_length"]["max"], 55)


func test_world_forest_only_last_level_uses_final_narrative_key() -> void:
	for i in _levels.size():
		var is_final: bool = _levels[i]["narrative_key"] == "forest_bridge_final"
		assert_eq(is_final, i == _levels.size() - 1, "level %d" % (i + 1))


func test_world_forest_bridge_length_min_never_decreases_between_levels() -> void:
	for i in range(1, _levels.size()):
		assert_gte(_levels[i]["bridge_length"]["min"], _levels[i - 1]["bridge_length"]["min"])


func test_world_forest_max_solutions_is_at_least_1() -> void:
	for level in _levels:
		assert_gte(level["max_solutions"], 1)
