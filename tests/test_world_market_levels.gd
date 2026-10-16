extends GutTest

const REQUIRED_FIELDS := ["id", "world", "mechanic", "items", "narrative_key", "skill_tags"]
const BAG_SIZES := {
	"tomato": Vector2i(2, 4),
	"potato": Vector2i(5, 7),
	"carrot": Vector2i(8, 10),
}

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("market")


func _items(level: Dictionary) -> Array:
	return level["items"].map(func(entry: Dictionary) -> String: return entry["item"])


func _max_count(level: Dictionary) -> int:
	return int(level["items"][0]["bag_count"]["max"])


func test_world_market_has_20_levels_in_order() -> void:
	assert_eq(_levels.size(), 20)
	for i in _levels.size():
		assert_eq(_levels[i]["id"], "world_market_%02d" % (i + 1))


func test_world_market_all_levels_have_required_fields() -> void:
	for level in _levels:
		for field in REQUIRED_FIELDS:
			assert_true(level.has(field), "%s missing %s" % [level.get("id", "?"), field])


func test_world_market_all_levels_use_market_mechanic() -> void:
	for level in _levels:
		assert_eq(level["mechanic"], "market")
		assert_eq(level["world"], "market")


func test_world_market_levels_1_to_5_order_tomato_only() -> void:
	for i in range(0, 5):
		assert_eq(_items(_levels[i]), ["tomato"], _levels[i]["id"])


func test_world_market_levels_6_to_10_order_tomato_and_potato() -> void:
	for i in range(5, 10):
		assert_eq(_items(_levels[i]), ["tomato", "potato"], _levels[i]["id"])


func test_world_market_levels_11_to_20_order_all_three() -> void:
	for i in range(10, 20):
		assert_eq(_items(_levels[i]), ["tomato", "potato", "carrot"], _levels[i]["id"])


func test_world_market_bag_sizes_match_item_ranges() -> void:
	for level in _levels:
		for entry: Dictionary in level["items"]:
			var allowed: Vector2i = BAG_SIZES[entry["item"]]
			var size_min: int = entry["bag_size"]["min"]
			var size_max: int = entry["bag_size"]["max"]
			assert_lte(size_min, size_max, level["id"])
			assert_gte(size_min, allowed.x, "%s %s" % [level["id"], entry["item"]])
			assert_lte(size_max, allowed.y, "%s %s" % [level["id"], entry["item"]])


func test_world_market_bag_counts_between_2_and_10() -> void:
	for level in _levels:
		for entry: Dictionary in level["items"]:
			var count_min: int = entry["bag_count"]["min"]
			var count_max: int = entry["bag_count"]["max"]
			assert_lte(count_min, count_max, level["id"])
			assert_gte(count_min, 2, level["id"])
			assert_lte(count_max, 10, level["id"])


func test_world_market_bag_count_max_never_decreases_within_block() -> void:
	for block: Vector2i in [Vector2i(0, 5), Vector2i(5, 10), Vector2i(10, 20)]:
		for i in range(block.x + 1, block.y):
			assert_gte(_max_count(_levels[i]), _max_count(_levels[i - 1]), _levels[i]["id"])
	assert_eq(_max_count(_levels[19]), 10)
