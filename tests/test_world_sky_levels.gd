extends GutTest

const REQUIRED_FIELDS := [
	"id",
	"world",
	"mechanic",
	"balloon_count",
	"balloon_value",
	"pop_count",
	"total_max",
	"max_solutions",
	"narrative_key",
	"skill_tags",
]

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("sky")


func test_world_sky_has_20_levels_in_order() -> void:
	assert_eq(_levels.size(), 20)
	for i in _levels.size():
		assert_eq(_levels[i]["id"], "world_sky_%02d" % (i + 1))


func test_world_sky_all_levels_have_required_fields() -> void:
	for level in _levels:
		for field in REQUIRED_FIELDS:
			assert_true(level.has(field), "%s missing %s" % [level.get("id", "?"), field])


func test_world_sky_all_levels_use_balloon_pop_mechanic() -> void:
	for level in _levels:
		assert_eq(level["mechanic"], "balloon_pop")
		assert_eq(level["world"], "sky")


func test_world_sky_ranges_are_valid() -> void:
	for level in _levels:
		var count: int = level["balloon_count"]
		assert_lte(level["balloon_value"]["min"], level["balloon_value"]["max"], level["id"])
		assert_gte(int(level["balloon_value"]["min"]), 1, level["id"])
		assert_lte(level["pop_count"]["min"], level["pop_count"]["max"], level["id"])
		assert_gte(int(level["pop_count"]["min"]), 1, level["id"])
		assert_lt(int(level["pop_count"]["max"]), count, level["id"])
		assert_gte(int(level["max_solutions"]), 1, level["id"])
		assert_lte(count, 8, level["id"])


func test_world_sky_total_max_never_decreases() -> void:
	for i in range(1, _levels.size()):
		assert_gte(_levels[i]["total_max"], _levels[i - 1]["total_max"], _levels[i]["id"])


func test_world_sky_level_01_total_below_10() -> void:
	assert_lt(int(_levels[0]["total_max"]), 10)
