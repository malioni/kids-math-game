extends GutTest

const REQUIRED_FIELDS := ["id", "world", "pairs", "must_include", "pool", "preview_seconds"]
const SCENE := preload("res://scenes/worlds/memory/memory.tscn")

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("memory")


func test_world_memory_has_20_levels_in_order() -> void:
	assert_eq(_levels.size(), 20)
	for i in _levels.size():
		assert_eq(_levels[i]["id"], "world_memory_%02d" % (i + 1))


func test_world_memory_all_levels_have_required_fields() -> void:
	for level in _levels:
		for field in REQUIRED_FIELDS:
			assert_true(level.has(field), "%s missing %s" % [level.get("id", "?"), field])


func test_world_memory_all_levels_belong_to_memory() -> void:
	for level in _levels:
		assert_eq(level["world"], "memory")


func test_world_memory_every_level_includes_fox() -> void:
	for level in _levels:
		assert_has(level["must_include"], "fox", level["id"])


func test_world_memory_pairs_between_2_and_10() -> void:
	for level in _levels:
		assert_between(int(level["pairs"]), 2, 10, level["id"])


func test_world_memory_pool_large_enough_for_pairs() -> void:
	for level in _levels:
		var needed: int = int(level["pairs"]) - level["must_include"].size()
		assert_gte(level["pool"].size(), needed, level["id"])


func test_world_memory_pool_has_no_duplicates_or_fox() -> void:
	for level in _levels:
		var seen := {}
		for animal: String in level["pool"]:
			assert_false(seen.has(animal), "%s repeats %s" % [level["id"], animal])
			assert_ne(animal, "fox", level["id"])
			seen[animal] = true


func test_world_memory_pairs_never_decrease_within_difficulty() -> void:
	for difficulty in LevelLoader.DIFFICULTIES:
		var level_range: Vector2i = LevelLoader.get_difficulty_range(difficulty)
		for i in range(level_range.x + 1, level_range.y + 1):
			assert_gte(int(_levels[i]["pairs"]), int(_levels[i - 1]["pairs"]), _levels[i]["id"])


func test_world_memory_easy_levels_have_preview_hard_levels_none() -> void:
	var easy: Vector2i = LevelLoader.get_difficulty_range("easy")
	for i in _levels.size():
		var preview: float = _levels[i]["preview_seconds"]
		if i <= easy.y:
			assert_gt(preview, 0.0, _levels[i]["id"])
		else:
			assert_eq(preview, 0.0, _levels[i]["id"])


func test_world_memory_every_animal_has_a_texture_in_world_scene() -> void:
	var world: Node = SCENE.instantiate()
	var textures: Dictionary = world.get_node("MemoryMechanic").card_textures
	for level in _levels:
		for animal: String in level["must_include"] + level["pool"]:
			assert_true(textures.get(animal) is Texture2D, "%s has no texture" % animal)
	world.free()
