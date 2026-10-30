extends GutTest

const REQUIRED_FIELDS := [
	"id", "world", "mechanic", "plates", "items", "narrative_key", "skill_tags"
]

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("picnic")


func _items(level: Dictionary) -> Array:
	return level["items"].map(func(entry: Dictionary) -> String: return entry["item"])


func _max_share(level: Dictionary) -> int:
	return int(level["items"][0]["share"]["max"])


func test_world_picnic_has_20_levels_in_order() -> void:
	assert_eq(_levels.size(), 20)
	for i in _levels.size():
		assert_eq(_levels[i]["id"], "world_picnic_%02d" % (i + 1))


func test_world_picnic_all_levels_have_required_fields() -> void:
	for level in _levels:
		for field in REQUIRED_FIELDS:
			assert_true(level.has(field), "%s missing %s" % [level.get("id", "?"), field])


func test_world_picnic_all_levels_use_sharing_mechanic() -> void:
	for level in _levels:
		assert_eq(level["mechanic"], "sharing")
		assert_eq(level["world"], "picnic")


func test_world_picnic_levels_1_to_5_share_strawberry_only() -> void:
	for i in range(0, 5):
		assert_eq(_items(_levels[i]), ["strawberry"], _levels[i]["id"])


func test_world_picnic_levels_6_to_10_share_strawberry_and_apple() -> void:
	for i in range(5, 10):
		assert_eq(_items(_levels[i]), ["strawberry", "apple"], _levels[i]["id"])


func test_world_picnic_levels_11_to_20_share_all_three() -> void:
	for i in range(10, 20):
		assert_eq(_items(_levels[i]), ["strawberry", "apple", "banana"], _levels[i]["id"])


func test_world_picnic_plates_between_2_and_5() -> void:
	for level in _levels:
		var plates_min: int = level["plates"]["min"]
		var plates_max: int = level["plates"]["max"]
		assert_lte(plates_min, plates_max, level["id"])
		assert_gte(plates_min, 2, level["id"])
		assert_lte(plates_max, 5, level["id"])


func test_world_picnic_share_between_2_and_10() -> void:
	for level in _levels:
		for entry: Dictionary in level["items"]:
			var share_min: int = entry["share"]["min"]
			var share_max: int = entry["share"]["max"]
			assert_lte(share_min, share_max, level["id"])
			assert_gte(share_min, 2, level["id"])
			assert_lte(share_max, 10, level["id"])


func test_world_picnic_share_max_never_decreases_within_block() -> void:
	for block: Vector2i in [Vector2i(0, 5), Vector2i(5, 10), Vector2i(10, 20)]:
		for i in range(block.x + 1, block.y):
			assert_gte(_max_share(_levels[i]), _max_share(_levels[i - 1]), _levels[i]["id"])
	assert_eq(_max_share(_levels[19]), 10)
