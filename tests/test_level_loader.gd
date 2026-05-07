extends GutTest

# get_levels_for_world("fixture_world") constructs path world_fixture_world/,
# and load_level("world_fixture_world_01") splits to folder world_fixture_world.
# Both must match the fixture directory name.
const FIXTURE_DIR := "res://data/levels/world_fixture_world/"
const FIXTURE_INDEX := FIXTURE_DIR + "levels.json"
const FIXTURE_LEVEL_A := FIXTURE_DIR + "world_fixture_world_01.json"
const FIXTURE_LEVEL_B := FIXTURE_DIR + "world_fixture_world_02.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(FIXTURE_DIR)
	)
	_write_file(FIXTURE_INDEX, '["world_fixture_world_01", "world_fixture_world_02"]')
	_write_file(FIXTURE_LEVEL_A, JSON.stringify({
		"id": "world_fixture_world_01",
		"world": "fixture_world",
		"mechanic": "placement",
		"target_count": 1,
		"narrative_key": "test_key_a",
		"skill_tags": ["counting"]
	}))
	_write_file(FIXTURE_LEVEL_B, JSON.stringify({
		"id": "world_fixture_world_02",
		"world": "fixture_world",
		"mechanic": "placement",
		"target_count": 2,
		"narrative_key": "test_key_b",
		"skill_tags": ["counting"]
	}))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_LEVEL_A))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_LEVEL_B))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_INDEX))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))


func _write_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()


func test_load_level_valid_file_returns_dictionary() -> void:
	var result := LevelLoader.load_level("world_fixture_world_01")
	assert_eq(result.get("id"), "world_fixture_world_01")
	assert_eq(result.get("target_count"), 1)


func test_load_level_missing_file_returns_empty_dict() -> void:
	var result := LevelLoader.load_level("nonexistent_level_99")
	assert_eq(result, {})


func test_load_level_malformed_json_returns_empty_dict() -> void:
	_write_file(FIXTURE_LEVEL_A, "this is not json {{{{")
	var result := LevelLoader.load_level("world_fixture_world_01")
	assert_eq(result, {})


func test_get_levels_for_world_returns_levels_in_order() -> void:
	var result := LevelLoader.get_levels_for_world("fixture_world")
	assert_eq(result.size(), 2)
	assert_eq(result[0].get("id"), "world_fixture_world_01")
	assert_eq(result[1].get("id"), "world_fixture_world_02")


func test_get_levels_for_world_missing_index_returns_empty_array() -> void:
	var result := LevelLoader.get_levels_for_world("nonexistent_world")
	assert_eq(result, [])
