extends Node

## Every difficulty, easiest first.
const DIFFICULTIES: Array[String] = ["easy", "hard"]
## Level range of each difficulty.
const DIFFICULTY_PATH := "res://data/levels/difficulty.json"


## Loads a single level by ID from data/levels/.
## Returns {} on missing file, malformed JSON, or if the parsed result is not a Dictionary.
func load_level(level_id: String) -> Dictionary:
	var parts: PackedStringArray = level_id.split("_")
	parts.resize(parts.size() - 1)
	var folder: String = "_".join(parts)
	var path: String = "res://data/levels/%s/%s.json" % [folder, level_id]

	if not FileAccess.file_exists(path):
		push_warning("LevelLoader: file not found: %s" % path)
		return {}

	var content: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var err: Error = json.parse(content)

	if err != OK:
		push_warning("LevelLoader: failed to parse JSON in %s: %s" % [path, json.get_error_message()])
		return {}

	var parsed: Variant = json.data

	if not parsed is Dictionary:
		push_warning(
			"LevelLoader: expected Dictionary, got %s in %s" % [type_string(typeof(parsed)), path]
		)
		return {}

	return parsed


## Returns all levels for a world in index order. Returns [] on any error.
func get_levels_for_world(world_name: String) -> Array[Dictionary]:
	var index_path: String = "res://data/levels/world_%s/levels.json" % world_name

	if not FileAccess.file_exists(index_path):
		push_warning("LevelLoader: index not found: %s" % index_path)
		return []

	var content: String = FileAccess.get_file_as_string(index_path)
	var json: JSON = JSON.new()
	var err: Error = json.parse(content)

	if err != OK:
		push_warning(
			"LevelLoader: failed to parse JSON in %s: %s" % [index_path, json.get_error_message()]
		)
		return []

	var parsed: Variant = json.data

	if not parsed is Array:
		push_warning("LevelLoader: expected Array in index %s" % index_path)
		return []

	var levels: Array[Dictionary] = []
	for level_id in parsed:
		var level: Dictionary = load_level(level_id)
		if not level.is_empty():
			levels.append(level)
	return levels


## Returns the 0-based first and last level index (as x and y) the difficulty covers, read from
## data/levels/difficulty.json. An unknown difficulty gets the easy range.
func get_difficulty_range(difficulty: String) -> Vector2i:
	var content: String = FileAccess.get_file_as_string(DIFFICULTY_PATH)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary or not parsed.has("easy"):
		push_warning("LevelLoader: could not read %s" % DIFFICULTY_PATH)
		return Vector2i(0, 9)
	var entry: Dictionary = parsed.get(difficulty, parsed["easy"])
	return Vector2i(int(entry["first"]) - 1, int(entry["last"]) - 1)
