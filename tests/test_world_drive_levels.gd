extends GutTest

const REQUIRED_FIELDS := ["id", "world", "mode", "cols", "rows", "obstacles", "turns", "max_tiles"]

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("drive")


func test_world_drive_has_20_levels_in_order() -> void:
	assert_eq(_levels.size(), 20)
	for i in _levels.size():
		assert_eq(_levels[i]["id"], "world_drive_%02d" % (i + 1))


func test_world_drive_all_levels_have_required_fields() -> void:
	for level in _levels:
		for field in REQUIRED_FIELDS:
			assert_true(level.has(field), "%s missing %s" % [level.get("id", "?"), field])
		assert_eq(level["world"], "drive")


func test_world_drive_easy_is_global_and_hard_is_relative() -> void:
	var easy: Vector2i = LevelLoader.get_difficulty_range("easy")
	for i in _levels.size():
		assert_eq(_levels[i]["mode"], "global" if i <= easy.y else "relative", _levels[i]["id"])


func test_world_drive_fields_fit_the_screen() -> void:
	for level in _levels:
		assert_between(int(level["cols"]), 4, 7, level["id"])
		assert_between(int(level["rows"]), 3, 5, level["id"])


func test_world_drive_max_tiles_leaves_room_in_the_strip() -> void:
	for level in _levels:
		assert_lt(int(level["max_tiles"]), DriveProgram.MAX_TILES, level["id"])


func test_world_drive_ranges_are_ordered() -> void:
	for level in _levels:
		assert_lte(int(level["obstacles"]["min"]), int(level["obstacles"]["max"]), level["id"])
		assert_lte(int(level["turns"]["min"]), int(level["turns"]["max"]), level["id"])


func test_world_drive_field_never_shrinks_within_difficulty() -> void:
	for difficulty in LevelLoader.DIFFICULTIES:
		var level_range: Vector2i = LevelLoader.get_difficulty_range(difficulty)
		for i in range(level_range.x + 1, level_range.y + 1):
			var area: int = int(_levels[i]["cols"]) * int(_levels[i]["rows"])
			var before: int = int(_levels[i - 1]["cols"]) * int(_levels[i - 1]["rows"])
			assert_gte(area, before, _levels[i]["id"])
